import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onCall, HttpsError, onRequest, type Request} from "firebase-functions/v2/https";

import {allowedOrigins, geminiApiKey, region} from "../config.js";
import type {ChatRequest, CorpusItem} from "../domain/types.js";
import {answerChat} from "../services/chat.js";
import {enforceRateLimit} from "../services/rate-limit.js";

if (getApps().length === 0) initializeApp();

interface HttpResponse {
  set(field: string, value?: string | string[]): unknown;
  status(code: number): HttpResponse;
  send(body?: unknown): unknown;
  json(body: unknown): unknown;
}

function configureCors(request: Request, response: HttpResponse): boolean {
  const origin = request.headers.origin;
  const allowed = new Set(allowedOrigins.value().split(",").map((value) => value.trim()));
  if (origin && allowed.has(origin)) {
    response.set("Access-Control-Allow-Origin", origin);
    response.set("Vary", "Origin");
  }
  response.set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Firebase-AppCheck");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return true;
  }
  if (origin && !allowed.has(origin)) {
    response.status(403).json({error: "Origen no permitido."});
    return true;
  }
  return false;
}

function clientIdentity(request: Request): string {
  const forwarded = request.headers["x-forwarded-for"];
  const ip = Array.isArray(forwarded) ? forwarded[0] : forwarded?.split(",")[0];
  return ip?.trim() || request.ip || "anonymous";
}

export const darditoChat = onRequest(
  {
    region,
    secrets: [geminiApiKey],
    timeoutSeconds: 60,
    memory: "512MiB",
    maxInstances: 20,
  },
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }

    try {
      const body = request.body as Partial<ChatRequest> | undefined;
      if (!body || typeof body.message !== "string") {
        response.status(400).json({error: "El campo message es obligatorio."});
        return;
      }
      const ipIdentity = clientIdentity(request);
      await enforceRateLimit(`web-ip:${ipIdentity}`, 120);
      const conversationIdentity = typeof body.conversationId === "string"
        ? `web-conversation:${ipIdentity}:${body.conversationId}`
        : `web-anonymous:${ipIdentity}`;
      const result = await answerChat({
        message: body.message,
        conversationId: typeof body.conversationId === "string" ? body.conversationId : undefined,
        participantId: conversationIdentity,
        channel: "web",
      });
      response.status(200).json(result);
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).json({error: "Demasiadas consultas. Probá de nuevo en un minuto."});
        return;
      }
      if (error instanceof Error && [
        "INVALID_MESSAGE",
        "INVALID_CORPUS",
        "INVALID_CONVERSATION_ID",
      ].includes(error.message)) {
        response.status(400).json({error: "La consulta o el corpus no son válidos."});
        return;
      }
      logger.error("Error al responder chat web", error);
      response.status(500).json({error: "Dardito no pudo responder en este momento."});
    }
  },
);

export const submitStory = onRequest(
  {region, timeoutSeconds: 20, memory: "256MiB", maxInstances: 10},
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    const body = request.body as Record<string, unknown> | undefined;
    const title = typeof body?.title === "string" ? body.title.trim() : "";
    const story = typeof body?.story === "string" ? body.story.trim() : "";
    const consent = body?.consent === true;
    if (!title || title.length > 160 || story.length < 30 || story.length > 12_000 || !consent) {
      response.status(400).json({error: "El aporte no cumple los requisitos mínimos."});
      return;
    }
    const reference = await getFirestore().collection("story_submissions").add({
      title,
      story,
      neighborhood: typeof body?.neighborhood === "string" ? body.neighborhood.trim() : null,
      category: typeof body?.category === "string" ? body.category.trim() : null,
      contactEmail: typeof body?.contactEmail === "string" ? body.contactEmail.trim() : null,
      consent,
      status: "pending_review",
      createdAt: FieldValue.serverTimestamp(),
    });
    response.status(202).json({id: reference.id, status: "pending_review"});
  },
);

export const upsertKnowledge = onCall({region}, async (request) => {
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "Se requiere rol editorial administrador.");
  }
  const item = request.data as Partial<CorpusItem> | undefined;
  if (
    !item ||
    typeof item.id !== "string" ||
    typeof item.title !== "string" ||
    typeof item.summary !== "string" ||
    typeof item.body !== "string" ||
    typeof item.category !== "string" ||
    typeof item.neighborhood !== "string" ||
    !["documented", "oral_tradition", "community"].includes(item.evidence ?? "") ||
    !["published", "draft", "archived"].includes(item.status ?? "") ||
    !Array.isArray(item.keywords) ||
    !item.keywords.every((keyword) => typeof keyword === "string")
  ) {
    throw new HttpsError("invalid-argument", "El documento de corpus es inválido.");
  }
  const id = item.id.replace(/[^a-zA-Z0-9_-]/g, "-").slice(0, 120);
  if (!id) throw new HttpsError("invalid-argument", "El ID del corpus es inválido.");
  await getFirestore().collection("knowledge").doc(id).set({
    ...item,
    id,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: request.auth.uid,
  }, {merge: true});
  return {id};
});

export const health = onRequest({region, cors: true}, (_request, response) => {
  response.status(200).json({service: "dardito-backend", status: "ok"});
});
