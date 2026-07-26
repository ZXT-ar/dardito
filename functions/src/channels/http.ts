import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth, type DecodedIdToken} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions";
import {onCall, HttpsError, onRequest, type Request} from "firebase-functions/v2/https";

import {allowedOrigins, geminiApiKey, region} from "../config.js";
import {
  maxPhotoBytes,
  maxTotalPhotoBytes,
  parseStorySubmission,
  StorySubmissionError,
} from "../domain/story-submission.js";
import type {ChatRequest, CorpusItem} from "../domain/types.js";
import {answerChat} from "../services/chat.js";
import {enforceRateLimit, privacyHash} from "../services/rate-limit.js";

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
  if (request.ip) return request.ip;
  const forwarded = request.headers["x-forwarded-for"];
  const values = Array.isArray(forwarded) ? forwarded : forwarded?.split(",");
  return values?.at(-1)?.trim() || "anonymous";
}

async function authenticatedUser(request: Request): Promise<DecodedIdToken> {
  const authorization = request.headers.authorization ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  const rawToken = match?.[1];
  if (!rawToken) throw new Error("UNAUTHENTICATED");
  const token = await getAuth().verifyIdToken(rawToken, true);
  if (!token.email || token.email_verified !== true) {
    throw new Error("EMAIL_NOT_VERIFIED");
  }
  return token;
}

function serverClientMetadata(request: Request): Record<string, unknown> {
  return {
    ipHash: privacyHash(`dardito-ip:${clientIdentity(request)}`),
    userAgent: String(request.headers["user-agent"] ?? "").slice(0, 500),
    language: String(request.headers["accept-language"] ?? "").slice(0, 160),
  };
}

function authErrorStatus(error: unknown): number | null {
  if (!(error instanceof Error)) return null;
  if (error.message === "UNAUTHENTICATED") return 401;
  if (error.message === "EMAIL_NOT_VERIFIED") return 403;
  if (error.message === "RATE_LIMITED") return 429;
  if (error.message.startsWith("Firebase ID token")) return 401;
  return null;
}

export const upsertUserProfile = onRequest(
  {region, timeoutSeconds: 20, memory: "256MiB", maxInstances: 10},
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    try {
      const user = await authenticatedUser(request);
      const ip = clientIdentity(request);
      await Promise.all([
        enforceRateLimit(`profile-user:${user.uid}`, 12, 60 * 60_000),
        enforceRateLimit(`profile-ip:${ip}`, 30, 60 * 60_000),
      ]);
      const body = request.body && typeof request.body === "object"
        ? request.body as Record<string, unknown>
        : {};
      const client = body.client && typeof body.client === "object"
        ? body.client as Record<string, unknown>
        : {};
      const reference = getFirestore().collection("users").doc(user.uid);
      await getFirestore().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        transaction.set(reference, {
          uid: user.uid,
          email: user.email,
          displayName: typeof user.name === "string" ? user.name.slice(0, 120) : null,
          photoURL: typeof user.picture === "string" ? user.picture.slice(0, 500) : null,
          emailVerified: true,
          providers: Array.isArray(user.firebase?.sign_in_provider)
            ? user.firebase.sign_in_provider
            : [user.firebase?.sign_in_provider ?? "google.com"],
          client: Object.fromEntries(Object.entries(client).slice(0, 12)),
          security: serverClientMetadata(request),
          createdAt: snapshot.exists
            ? snapshot.data()?.createdAt ?? FieldValue.serverTimestamp()
            : FieldValue.serverTimestamp(),
          lastSignInAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      response.status(200).json({uid: user.uid, status: "ready"});
    } catch (error) {
      const status = authErrorStatus(error);
      if (status) {
        response.status(status).json({
          error: status === 429
            ? "Demasiados intentos. Esperá antes de volver a intentar."
            : "La sesión de Google no es válida.",
        });
        return;
      }
      logger.error("Error al registrar perfil", error);
      response.status(500).json({error: "No fue posible registrar el perfil."});
    }
  },
);

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
      const requestedSessionId = typeof body.sessionId === "string"
        ? body.sessionId.trim()
        : "";
      if (requestedSessionId && !/^[a-zA-Z0-9_-]{16,160}$/.test(requestedSessionId)) {
        response.status(400).json({error: "El identificador de sesión no es válido."});
        return;
      }
      const conversationIdentity = requestedSessionId
        ? `web-session:${requestedSessionId}`
        : typeof body.conversationId === "string"
          ? `web-conversation:${body.conversationId}`
        : `web-anonymous:${ipIdentity}`;
      const moderationScopes = requestedSessionId
        ? [`web-session:${requestedSessionId}`, `web-ip:${ipIdentity}`]
        : [conversationIdentity, `web-ip:${ipIdentity}`];
      const result = await answerChat({
        message: body.message,
        conversationId: typeof body.conversationId === "string" ? body.conversationId : undefined,
        participantId: conversationIdentity,
        sessionId: requestedSessionId || undefined,
        moderationScopeIds: moderationScopes,
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
  {region, timeoutSeconds: 45, memory: "512MiB", maxInstances: 10},
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    try {
      const user = await authenticatedUser(request);
      const input = parseStorySubmission(request.body);
      const ip = clientIdentity(request);
      await Promise.all([
        enforceRateLimit(`story-user:${user.uid}`, 5, 60 * 60_000),
        enforceRateLimit(`story-ip:${ip}`, 10, 60 * 60_000),
      ]);

      const expectedPrefix = `story_submissions/${user.uid}/${input.submissionId}/`;
      const photos: Array<Record<string, unknown>> = [];
      let totalBytes = 0;
      for (const [index, path] of input.photoPaths.entries()) {
        if (
          !path.startsWith(expectedPrefix) ||
          !new RegExp(`^${expectedPrefix}photo_${index}\\.(jpe?g|png|webp)$`, "i").test(path)
        ) {
          throw new StorySubmissionError("INVALID_PHOTO", "La ruta de una foto no es válida.");
        }
        const file = getStorage().bucket().file(path);
        const [exists] = await file.exists();
        if (!exists) {
          throw new StorySubmissionError("INVALID_PHOTO", "No encontramos una de las fotos.");
        }
        const [metadata] = await file.getMetadata();
        const size = Number(metadata.size ?? 0);
        const contentType = String(metadata.contentType ?? "");
        if (
          !Number.isFinite(size) ||
          size <= 0 ||
          size > maxPhotoBytes ||
          !["image/jpeg", "image/png", "image/webp"].includes(contentType)
        ) {
          throw new StorySubmissionError("INVALID_PHOTO", "Una foto no cumple formato o peso.");
        }
        totalBytes += size;
        const [header] = await file.download({start: 0, end: 15});
        const isJpeg = header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff;
        const isPng = header.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
        const isWebp = header.subarray(0, 4).toString() === "RIFF" &&
          header.subarray(8, 12).toString() === "WEBP";
        if (!isJpeg && !isPng && !isWebp) {
          throw new StorySubmissionError("INVALID_PHOTO", "Una foto no contiene una imagen válida.");
        }
        photos.push({path, size, contentType, originalName: metadata.metadata?.originalName ?? null});
      }
      if (totalBytes > maxTotalPhotoBytes) {
        throw new StorySubmissionError("INVALID_PHOTO", "Las fotos superan el peso total permitido.");
      }

      const submissionReference = getFirestore()
        .collection("story_submissions")
        .doc(input.submissionId);
      const userReference = getFirestore().collection("users").doc(user.uid);
      const userSubmissionReference = userReference
        .collection("story_submissions")
        .doc(input.submissionId);
      let alreadyExists = false;
      await getFirestore().runTransaction(async (transaction) => {
        const existing = await transaction.get(submissionReference);
        if (existing.exists) {
          if (existing.data()?.userId !== user.uid) throw new Error("IDEMPOTENCY_CONFLICT");
          alreadyExists = true;
          return;
        }
        const audit = {
          ...serverClientMetadata(request),
          client: input.client ?? {},
        };
        transaction.set(userReference, {
          uid: user.uid,
          email: user.email,
          displayName: typeof user.name === "string" ? user.name.slice(0, 120) : null,
          photoURL: typeof user.picture === "string" ? user.picture.slice(0, 500) : null,
          emailVerified: true,
          security: serverClientMetadata(request),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.create(submissionReference, {
          id: input.submissionId,
          userId: user.uid,
          email: user.email,
          contactEmail: input.contactConsent ? user.email : null,
          title: input.title,
          story: input.story,
          category: input.category,
          neighborhood: input.neighborhood,
          photos,
          status: "pending_review",
          consent: {
            material: input.materialConsent,
            legal: input.legalConsent,
            contact: input.contactConsent,
            version: "2026-07-24",
            acceptedAt: FieldValue.serverTimestamp(),
          },
          audit,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(userSubmissionReference, {
          submissionId: input.submissionId,
          status: "pending_review",
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      response.status(alreadyExists ? 200 : 202).json({
        id: input.submissionId,
        status: "pending_review",
        duplicate: alreadyExists,
      });
    } catch (error) {
      const authStatus = authErrorStatus(error);
      if (authStatus) {
        response.status(authStatus).json({
          code: authStatus === 429 ? "RATE_LIMITED" : "UNAUTHENTICATED",
          error: authStatus === 429
            ? "Alcanzaste el límite de aportes. Probá más tarde."
            : "Necesitás una cuenta de Google verificada.",
        });
        return;
      }
      if (error instanceof StorySubmissionError) {
        response.status(error.code === "CONTENT_REVIEW_REQUIRED" ? 422 : 400).json({
          code: error.code,
          error: error.message,
          details: error.details,
        });
        return;
      }
      if (error instanceof Error && error.message === "IDEMPOTENCY_CONFLICT") {
        response.status(409).json({code: "CONFLICT", error: "El envío ya existe."});
        return;
      }
      logger.error("Error al recibir aporte", error);
      response.status(500).json({error: "No fue posible guardar la historia."});
    }
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
