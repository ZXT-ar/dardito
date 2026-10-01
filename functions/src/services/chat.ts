import {sanitizeMessage} from "../domain/chat-message.js";
import {randomUUID} from "node:crypto";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";

import {decideInteraction} from "../domain/guardrails.js";
import {knowledgeV2Enabled} from "../domain/knowledge-query.js";
import {logger} from "firebase-functions";
import type {
  ChatRequest,
  ChatResponse,
  ChatTurn,
  CorpusItem,
  ModerationResult,
} from "../domain/types.js";
import {retrieveCorpus} from "./corpus.js";
import {generateDarditoAnswer} from "./llm.js";
import {enforceModeration, moderationAnswer} from "./moderation.js";
import {enforceRateLimit, privacyHash} from "./rate-limit.js";


const maxInlineCorpusItems = 20;
const maxInlineCorpusCharacters = 20_000;
const webMaxRequestsPerMinute = 6;

function validateInlineCorpus(items: CorpusItem[] | undefined): CorpusItem[] {
  if (!items) return [];
  if (items.length > maxInlineCorpusItems) throw new Error("INVALID_CORPUS");
  const valid = items.filter((item) =>
    item &&
    typeof item.id === "string" &&
    typeof item.title === "string" &&
    typeof item.summary === "string" &&
    typeof item.body === "string" &&
    typeof item.category === "string" &&
    typeof item.neighborhood === "string" &&
    typeof item.evidence === "string" && /^[a-z0-9_-]{1,80}$/.test(item.evidence) &&
    item.status === "published" &&
    Array.isArray(item.keywords),
  );
  if (valid.length !== items.length) throw new Error("INVALID_CORPUS");
  const characters = valid.reduce(
    (total, item) => total + item.title.length + item.summary.length + item.body.length,
    0,
  );
  if (characters > maxInlineCorpusCharacters) throw new Error("INVALID_CORPUS");
  return valid;
}

const retentionMilliseconds = 30 * 24 * 60 * 60 * 1_000;

function conversationReference(conversationId: string, userId?: string) {
  const db = getFirestore();
  return userId
    ? db.collection("users").doc(userId).collection("chats").doc(conversationId)
    : db.collection("conversations").doc(conversationId);
}

async function loadHistory(conversationId: string, userId?: string, includeSources = false): Promise<ChatTurn[]> {
  const snapshot = await conversationReference(conversationId, userId)
    .collection("messages")
    .orderBy("createdAtMs", "desc")
    .limit(20)
    .get();

  return snapshot.docs.reverse().flatMap((doc) => {
    const data = doc.data();
    if (!["user", "model"].includes(data.role) || typeof data.text !== "string") {
      return [];
    }
    return [{role: data.role, text: data.text,
      ...(includeSources && data.role === "model" && Array.isArray(data.sourceIds)
        ? {sourceIds: data.sourceIds.filter((id: unknown): id is string => typeof id === "string" && /^[a-zA-Z0-9_-]{1,120}$/.test(id)).slice(0, 6)} : {}),
    } as ChatTurn];
  });
}

async function persistExchange(input: {
  conversationId: string;
  participant: string;
  channel: ChatRequest["channel"];
  userText: string;
  answer: string;
  sourceIds: string[];
  moderation: ModerationResult;
  userId?: string;
}): Promise<void> {
  const db = getFirestore();
  const conversation = conversationReference(input.conversationId, input.userId);
  const existingConversation = await conversation.get();
  const createdAtMs = Date.now();
  const expiresAt = Timestamp.fromMillis(createdAtMs + retentionMilliseconds);
  const moderated = input.moderation.action !== "none";
  const batch = db.batch();
  batch.set(conversation, {
    channel: input.channel,
    participantHash: privacyHash(input.participant),
    expiresAt,
    updatedAt: FieldValue.serverTimestamp(),
    ...(!existingConversation.exists ? {createdAt: FieldValue.serverTimestamp()} : {}),
  }, {merge: true});
  batch.set(conversation.collection("messages").doc(), {
    role: "user",
    text: moderated ? "[mensaje moderado]" : input.userText,
    moderationAction: input.moderation.action,
    moderationCategories: input.moderation.categories,
    createdAtMs,
    expiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(conversation.collection("messages").doc(), {
    role: "model",
    text: input.answer,
    sourceIds: input.sourceIds,
    moderationAction: input.moderation.action,
    createdAtMs: createdAtMs + 1,
    expiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
}

export async function answerChat(request: ChatRequest): Promise<ChatResponse> {
  const message = sanitizeMessage(request.message);
  const requestedConversationId = request.conversationId?.trim();
  if (requestedConversationId && !/^[a-zA-Z0-9_-]{8,120}$/.test(requestedConversationId)) {
    throw new Error("INVALID_CONVERSATION_ID");
  }
  const conversationId = requestedConversationId || randomUUID();
  const participant = request.participantId?.trim() || conversationId;
  const userId = request.userId?.trim();
  if (userId && !/^[a-zA-Z0-9_-]{1,128}$/.test(userId)) {
    throw new Error("INVALID_USER_ID");
  }
  await enforceRateLimit(
    `${request.channel}:${participant}`,
    request.channel === "web" ? webMaxRequestsPerMinute : undefined,
  );

  const inlineCorpus = validateInlineCorpus(request.corpus);
  const moderation = await enforceModeration({
    channel: request.channel,
    scopes: request.moderationScopeIds?.length
      ? request.moderationScopeIds
      : [participant],
    conversationId,
    message,
  });
  if (moderation.action !== "none") {
    const answer = moderationAnswer(moderation);
    await persistExchange({
      conversationId,
      participant,
      channel: request.channel,
      userText: message,
      answer,
      sourceIds: [],
      moderation,
      userId,
    });
    return {answer, conversationId, sources: [], moderation};
  }

  const useKnowledgeV2 = knowledgeV2Enabled(request);
  const history = await loadHistory(conversationId, userId, useKnowledgeV2);
  if (useKnowledgeV2) {
    let answer: string;
    let corpus: CorpusItem[] = [];
    try {
      const {answerKnowledgeCanary} = await import("./knowledge-runtime.js");
      const result = await answerKnowledgeCanary({channel: request.channel, message, history});
      answer = result.answer;
      corpus = result.corpus;
      logger.info("knowledge_v2", {kind: result.kind, matched: result.matched, diagnostic: result.diagnostic ?? null});
    } catch {
      logger.warn("knowledge_v2_unavailable");
      // Never turn an incomplete aggregate or failed evidence check into an invented answer.
      answer = "No pude consultar las historias en este momento. Probá nuevamente en un rato.";
    }
    await persistExchange({conversationId, participant, channel: request.channel, userText: message,
      answer, sourceIds: corpus.map((item) => item.id), moderation, userId});
    return {answer, conversationId, moderation, sources: corpus.map((item) => ({
      id: item.id, title: item.title, evidence: item.evidence, sourceName: item.sourceName, sourceUrl: item.sourceUrl,
    }))};
  }
  const decision = decideInteraction(message, history.length > 0);
  const retrievalQuery = decision.useHistoryForSearch
    ? `${history
      .slice(-6)
      .filter((turn) => turn.role === "user")
      .map((turn) => turn.text)
      .join(" ")} ${message}`
    : message;
  const corpus = decision.corpusMode === "none"
    ? []
    : await retrieveCorpus(retrievalQuery, inlineCorpus, decision.corpusMode);
  const answer = decision.fixedAnswer ?? await generateDarditoAnswer({
    channel: request.channel,
    message,
    history,
    corpus,
  });

  await persistExchange({
    conversationId,
    participant,
    channel: request.channel,
    userText: message,
    answer,
    sourceIds: corpus.map((item) => item.id),
    moderation,
    userId,
  });

  return {
    answer,
    conversationId,
    sources: corpus.map((item) => ({
      id: item.id,
      title: item.title,
      evidence: item.evidence,
      sourceName: item.sourceName,
      sourceUrl: item.sourceUrl,
    })),
    moderation,
  };
}
