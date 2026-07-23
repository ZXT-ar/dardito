import {randomUUID} from "node:crypto";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

import {decideInteraction} from "../domain/guardrails.js";
import type {ChatRequest, ChatResponse, ChatTurn, CorpusItem} from "../domain/types.js";
import {retrieveCorpus} from "./corpus.js";
import {generateDarditoAnswer} from "./llm.js";
import {enforceRateLimit, privacyHash} from "./rate-limit.js";

const maxMessageLength = 2_000;
const maxInlineCorpusItems = 20;
const maxInlineCorpusCharacters = 20_000;

function sanitizeMessage(message: string): string {
  const value = message.replace(/[\u0000-\u001F\u007F]/g, " ").trim();
  if (!value || value.length > maxMessageLength) {
    throw new Error("INVALID_MESSAGE");
  }
  return value;
}

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
    ["documented", "oral_tradition", "community"].includes(item.evidence) &&
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

async function loadHistory(conversationId: string): Promise<ChatTurn[]> {
  const snapshot = await getFirestore()
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .orderBy("createdAtMs", "desc")
    .limit(20)
    .get();

  return snapshot.docs.reverse().flatMap((doc) => {
    const data = doc.data();
    if (!["user", "model"].includes(data.role) || typeof data.text !== "string") {
      return [];
    }
    return [{role: data.role, text: data.text} as ChatTurn];
  });
}

export async function answerChat(request: ChatRequest): Promise<ChatResponse> {
  const message = sanitizeMessage(request.message);
  const requestedConversationId = request.conversationId?.trim();
  if (requestedConversationId && !/^[a-zA-Z0-9_-]{8,120}$/.test(requestedConversationId)) {
    throw new Error("INVALID_CONVERSATION_ID");
  }
  const conversationId = requestedConversationId || randomUUID();
  const participant = request.participantId?.trim() || conversationId;
  await enforceRateLimit(`${request.channel}:${participant}`);

  const inlineCorpus = validateInlineCorpus(request.corpus);
  const history = await loadHistory(conversationId);
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

  const db = getFirestore();
  const conversation = db.collection("conversations").doc(conversationId);
  const existingConversation = await conversation.get();
  const createdAtMs = Date.now();
  const batch = db.batch();
  batch.set(conversation, {
    channel: request.channel,
    participantHash: privacyHash(participant),
    updatedAt: FieldValue.serverTimestamp(),
    ...(!existingConversation.exists ? {createdAt: FieldValue.serverTimestamp()} : {}),
  }, {merge: true});
  batch.set(conversation.collection("messages").doc(), {
    role: "user",
    text: message,
    createdAtMs,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(conversation.collection("messages").doc(), {
    role: "model",
    text: answer,
    sourceIds: corpus.map((item) => item.id),
    createdAtMs: createdAtMs + 1,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

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
  };
}
