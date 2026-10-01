import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth, type DecodedIdToken} from "firebase-admin/auth";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {createHash} from "node:crypto";
import {logger} from "firebase-functions";
import {onCall, HttpsError, onRequest, type Request} from "firebase-functions/v2/https";

import {allowedOrigins, geminiApiKey, region} from "../config.js";
import {
  maxPhotoBytes,
  maxTotalPhotoBytes,
  parseStorySubmission,
  StorySubmissionError,
} from "../domain/story-submission.js";
import type {ChatRequest} from "../domain/types.js";
import {parseLegacyKnowledge} from "../domain/legacy-knowledge.js";
import {trustedClientIdentity} from "../domain/client-identity.js";
import {toPublicStory} from "../domain/public-story.js";
import {
  createNotFoundHtml,
  createSitemapXml,
  createStoryHtml,
} from "../domain/public-story-page.js";
import {loadEditorialCatalogs} from "../domain/editorial-catalogs.js";
import {nextStoryLikeState} from "../domain/story-likes.js";
import {
  hasRequiredConsent,
  parseRequiredConsent,
} from "../domain/auth-access.js";
import {answerChat} from "../services/chat.js";
import {
  recordApiError,
  recordApiRequest,
  recordUsageEvent,
  type ApiMetric,
} from "../services/analytics.js";
import {enforceRateLimit, privacyHash} from "../services/rate-limit.js";
import {requireEditorialRole} from "../services/editorial-auth.js";
import {
  cancelStoryUpload, completeStoryUpload, prepareStoryUpload, readStoryUploadForFinalize,
  StoryUploadError, storyUploadReservationsRequired,
} from "../services/story-upload-reservations.js";

if (getApps().length === 0) initializeApp();

interface HttpResponse {
  set(field: string, value?: string | string[]): unknown;
  status(code: number): HttpResponse;
  send(body?: unknown): unknown;
  json(body: unknown): unknown;
}

function configureCors(request: Request, response: HttpResponse): boolean {
  response.set("Cache-Control", "no-store");
  response.set("X-Content-Type-Options", "nosniff");
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
  if (request.rawBody && request.rawBody.length > 64 * 1024) {
    response.status(413).json({error: "La solicitud supera el tamaño permitido."});
    return true;
  }
  return false;
}

function configurePublicReadCors(request: Request, response: HttpResponse): boolean {
  const origin = request.headers.origin;
  const allowed = new Set(allowedOrigins.value().split(",").map((value) => value.trim()));
  if (origin && allowed.has(origin)) {
    response.set("Access-Control-Allow-Origin", origin);
    response.set("Vary", "Origin");
  }
  response.set("Access-Control-Allow-Headers", "Accept, Content-Type");
  response.set("Access-Control-Allow-Methods", "GET, OPTIONS");
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
  return trustedClientIdentity(request);
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

async function authenticatedAccount(request: Request): Promise<{
  token: DecodedIdToken;
  ip: string;
  ipHash: string;
  userData: Record<string, unknown>;
}> {
  const token = await authenticatedUser(request);
  const ip = clientIdentity(request);
  const ipHash = privacyHash(`dardito-ip:${ip}`);
  const db = getFirestore();
  const userReference = db.collection("users").doc(token.uid);
  const networkReference = db.collection("moderation_sessions")
    .doc(privacyHash(`web:web-ip:${ip}`));
  const [userSnapshot, networkSnapshot] = await Promise.all([
    userReference.get(),
    networkReference.get(),
  ]);
  const userData = userSnapshot.data() ?? {};
  if (!hasRequiredConsent(userData.consent)) throw new Error("CONSENT_REQUIRED");
  const moderation = userData.moderation && typeof userData.moderation === "object"
    ? userData.moderation as Record<string, unknown>
    : {};
  if (moderation.banned === true) throw new Error("ACCOUNT_BANNED");
  const blockedUntil = networkSnapshot.data()?.blockedUntil;
  if (blockedUntil instanceof Timestamp && blockedUntil.toMillis() > Date.now()) {
    await userReference.set({
      security: {ipHash},
      moderation: {ipBlocked: true, blockedUntil},
      lastAccessAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    throw new Error("IP_BLOCKED");
  }
  return {token, ip, ipHash, userData};
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
  const code = (error as Error & {code?: string}).code;
  if (typeof code === "string" && code.startsWith("auth/")) return 401;
  if (error.message === "UNAUTHENTICATED") return 401;
  if (error.message === "EMAIL_NOT_VERIFIED") return 403;
  if (error.message === "RATE_LIMITED") return 429;
  if (error.message === "CONSENT_REQUIRED") return 428;
  if (error.message === "ACCOUNT_BANNED" || error.message === "IP_BLOCKED") return 403;
  if (error.message.startsWith("Firebase ID token")) return 401;
  return null;
}

async function measureRequest(metric: ApiMetric): Promise<void> {
  try {
    await recordApiRequest(metric);
  } catch (error) {
    logger.warn("No fue posible registrar una métrica de solicitud", {metric, error});
  }
}

async function measureError(): Promise<void> {
  try {
    await recordApiError();
  } catch (error) {
    logger.warn("No fue posible registrar una métrica de error", error);
  }
}

function publicStoryId(request: Request, prefix: string): string | null {
  const rawPath = request.path || request.url.split("?")[0] || "";
  const rawValue = rawPath.startsWith(prefix) ? rawPath.slice(prefix.length) : rawPath.split("/").at(-1) ?? "";
  try {
    const value = decodeURIComponent(rawValue).trim();
    return /^[a-zA-Z0-9_-]{1,120}$/.test(value) ? value : null;
  } catch {
    return null;
  }
}

async function authorizedStoryImage(storyId: string): Promise<Record<string, unknown> | null> {
  const snapshot = await getFirestore().collection("editorial_resources")
    .where("storyId", "==", storyId)
    .limit(50)
    .get();
  const resource = snapshot.docs
    .map((document) => document.data())
    .find((data) =>
      data.kind === "image" &&
      data.status === "ready" &&
      data.rights === "authorized" &&
      typeof data.storagePath === "string" &&
      /^editorial_media\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]+\/resource\.(jpg|png|webp)$/.test(data.storagePath) &&
      ["image/jpeg", "image/png", "image/webp"].includes(String(data.contentType ?? ""))
    );
  return resource ?? null;
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
      await measureRequest("profiles");
      const body = request.body && typeof request.body === "object"
        ? request.body as Record<string, unknown>
        : {};
      const client = body.client && typeof body.client === "object"
        ? body.client as Record<string, unknown>
        : {};
      const consent = parseRequiredConsent(body.consent);
      const reference = getFirestore().collection("users").doc(user.uid);
      const networkReference = getFirestore().collection("moderation_sessions")
        .doc(privacyHash(`web:web-ip:${ip}`));
      await getFirestore().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        const networkSnapshot = await transaction.get(networkReference);
        if (snapshot.data()?.moderation?.banned === true) {
          throw new Error("ACCOUNT_BANNED");
        }
        const networkBlockedUntil = networkSnapshot.data()?.blockedUntil;
        if (
          networkBlockedUntil instanceof Timestamp &&
          networkBlockedUntil.toMillis() > Date.now()
        ) {
          throw new Error("IP_BLOCKED");
        }
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
          consent: {
            ...consent,
            acceptedAt: FieldValue.serverTimestamp(),
          },
          security: {
            ...serverClientMetadata(request),
            ipHash: privacyHash(`dardito-ip:${ip}`),
          },
          moderation: {
            banned: snapshot.data()?.moderation?.banned === true,
            ipBlocked: false,
          },
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
      await measureError();
      response.status(500).json({error: "No fue posible registrar el perfil."});
    }
  },
);

export const userAccessStatus = onRequest(
  {region, timeoutSeconds: 15, memory: "256MiB", maxInstances: 10},
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    try {
      const account = await authenticatedAccount(request);
      await Promise.all([
        enforceRateLimit(`access-user:${account.token.uid}`, 120),
        enforceRateLimit(`access-ip:${account.ip}`, 600),
      ]);
      await getFirestore().collection("users").doc(account.token.uid).set({
        security: {
          ...serverClientMetadata(request),
          ipHash: account.ipHash,
        },
        moderation: {ipBlocked: false},
        lastAccessAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      response.set("Cache-Control", "no-store");
      response.status(200).json({allowed: true});
    } catch (error) {
      const reason = error instanceof Error
        ? {
          CONSENT_REQUIRED: "consent_required",
          ACCOUNT_BANNED: "banned",
          IP_BLOCKED: "ip_blocked",
          UNAUTHENTICATED: "invalid_session",
        }[error.message] ?? "invalid_session"
        : "invalid_session";
      response.status(authErrorStatus(error) ?? 401).json({allowed: false, reason});
    }
  },
);

export const storyLikes = onRequest(
  {region, timeoutSeconds: 20, memory: "256MiB", maxInstances: 20},
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    try {
      const account = await authenticatedAccount(request);
      await Promise.all([
        enforceRateLimit(`story-like-user:${account.token.uid}`, 120, 60 * 60_000),
        enforceRateLimit(`story-like-ip:${account.ip}`, 240, 60 * 60_000),
      ]);
      const body = request.body && typeof request.body === "object"
        ? request.body as Record<string, unknown>
        : {};
      const storyId = typeof body.storyId === "string" ? body.storyId.trim() : "";
      const action = body.action;
      if (!/^[a-zA-Z0-9_-]{1,120}$/.test(storyId) || !["status", "toggle"].includes(String(action))) {
        response.status(400).json({error: "Solicitud de Me gusta inválida."});
        return;
      }

      const db = getFirestore();
      const storyReference = db.collection("knowledge").doc(storyId);
      const likeReference = db.collection("users").doc(account.token.uid)
        .collection("story_likes").doc(storyId);

      if (action === "status") {
        const [storySnapshot, likeSnapshot] = await Promise.all([
          storyReference.get(),
          likeReference.get(),
        ]);
        if (!storySnapshot.exists || storySnapshot.data()?.status !== "published") {
          response.status(404).json({error: "La historia no está disponible."});
          return;
        }
        const storedCount = Number(storySnapshot.data()?.likeCount ?? 0);
        response.set("Cache-Control", "no-store");
        response.status(200).json({
          storyId,
          liked: likeSnapshot.exists,
          likeCount: Number.isSafeInteger(storedCount) && storedCount >= 0 ? storedCount : 0,
        });
        return;
      }

      const result = await db.runTransaction(async (transaction) => {
        const storySnapshot = await transaction.get(storyReference);
        const likeSnapshot = await transaction.get(likeReference);
        if (!storySnapshot.exists || storySnapshot.data()?.status !== "published") {
          throw new Error("STORY_NOT_AVAILABLE");
        }
        const nextState = nextStoryLikeState(
          storySnapshot.data()?.likeCount,
          likeSnapshot.exists,
        );
        const {liked, likeCount: nextCount} = nextState;
        transaction.update(storyReference, {
          likeCount: nextCount,
          likesUpdatedAt: FieldValue.serverTimestamp(),
        });
        if (liked) {
          transaction.set(likeReference, {
            storyId,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        } else {
          transaction.delete(likeReference);
        }
        transaction.set(db.collection("users").doc(account.token.uid), {
          lastLikeAt: FieldValue.serverTimestamp(),
          lastAccessAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {liked, likeCount: nextCount};
      });
      response.set("Cache-Control", "no-store");
      response.status(200).json({storyId, ...result});
    } catch (error) {
      if (error instanceof Error && error.message === "STORY_NOT_AVAILABLE") {
        response.status(404).json({error: "La historia no está disponible."});
        return;
      }
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).json({error: "Demasiadas acciones. Probá nuevamente más tarde."});
        return;
      }
      const accessStatus = authErrorStatus(error);
      if (accessStatus) {
        response.status(accessStatus).json({error: "La cuenta no está habilitada."});
        return;
      }
      logger.error("Error al actualizar Me gusta", error);
      await measureError();
      response.status(500).json({error: "No fue posible actualizar Me gusta."});
    }
  },
);

const chatHandler: Parameters<typeof onRequest>[0] =
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }

    try {
      const account = await authenticatedAccount(request);
      const body = request.body as Partial<ChatRequest> | undefined;
      if (!body || typeof body.message !== "string") {
        response.status(400).json({error: "El campo message es obligatorio."});
        return;
      }
      const ipIdentity = account.ip;
      await enforceRateLimit(`web-ip:${ipIdentity}`, 120);
      await measureRequest("chat");
      const requestedSessionId = typeof body.sessionId === "string"
        ? body.sessionId.trim()
        : "";
      if (requestedSessionId && !/^[a-zA-Z0-9_-]{16,160}$/.test(requestedSessionId)) {
        response.status(400).json({error: "El identificador de sesión no es válido."});
        return;
      }
      const conversationIdentity = `web-user:${account.token.uid}`;
      const moderationScopes = [conversationIdentity, `web-ip:${ipIdentity}`];
      const result = await answerChat({
        message: body.message,
        conversationId: typeof body.conversationId === "string" ? body.conversationId : undefined,
        participantId: conversationIdentity,
        userId: account.token.uid,
        sessionId: requestedSessionId || undefined,
        moderationScopeIds: moderationScopes,
        channel: "web",
      });
      await getFirestore().collection("users").doc(account.token.uid).set({
        security: {
          ...serverClientMetadata(request),
          ipHash: account.ipHash,
        },
        moderation: {
          banned: account.userData.moderation &&
            typeof account.userData.moderation === "object" &&
            (account.userData.moderation as Record<string, unknown>).banned === true,
          ipBlocked: result.moderation.action === "red" || result.moderation.action === "blocked",
          yellowCount: result.moderation.yellowCount,
          blockedUntil: result.moderation.blockedUntil
            ? Timestamp.fromDate(new Date(result.moderation.blockedUntil))
            : FieldValue.delete(),
        },
        lastChatAt: FieldValue.serverTimestamp(),
        lastAccessAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      response.status(200).json(result);
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).json({error: "Demasiadas consultas. Probá de nuevo en un minuto."});
        return;
      }
      const accessStatus = authErrorStatus(error);
      if (accessStatus) {
        response.status(accessStatus).json({
          error: "La cuenta no está habilitada para conversar.",
          code: error instanceof Error ? error.message : "UNAUTHENTICATED",
        });
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
      await measureError();
      response.status(500).json({error: "Dardito no pudo responder en este momento."});
    }
  };

export const darditoChat = onRequest(
  {region, secrets: [geminiApiKey], timeoutSeconds: 60, memory: "512MiB", maxInstances: 20},
  chatHandler,
);

// Separate deployment target: production keeps its existing deployed revision.
export const darditoChatPreproduction = onRequest(
  {region, secrets: [geminiApiKey], timeoutSeconds: 60, memory: "512MiB", maxInstances: 20},
  chatHandler,
);

export const publicStories = onRequest(
  {region, timeoutSeconds: 20, memory: "256MiB", maxInstances: 20},
  async (request, response) => {
    if (configurePublicReadCors(request, response)) return;
    if (request.method !== "GET") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    try {
      await enforceRateLimit(`public-stories-ip:${clientIdentity(request)}`, 240);
      await measureRequest("publicStories");
      const [snapshot, catalogs] = await Promise.all([
        getFirestore().collection("knowledge").where("status", "==", "published").limit(250).get(),
        loadEditorialCatalogs(),
      ]);
      const stories = snapshot.docs
        .map((document) => toPublicStory(document.id, document.data(), catalogs))
        .filter((story) => story !== null)
        .sort((left, right) =>
          Number(right.featured) - Number(left.featured) ||
          left.title.localeCompare(right.title, "es-AR"));
      const payload = JSON.stringify({schemaVersion: 1, stories});
      const etag = `"${createHash("sha256").update(payload).digest("base64url")}"`;
      response.set("Cache-Control", "public, max-age=60, s-maxage=120, stale-while-revalidate=300");
      response.set("Content-Type", "application/json; charset=utf-8");
      response.set("ETag", etag);
      response.set("X-Content-Type-Options", "nosniff");
      response.set("Referrer-Policy", "no-referrer");
      if (request.headers["if-none-match"] === etag) {
        response.status(304).send("");
        return;
      }
      response.status(200).send(payload);
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).json({error: "Demasiadas consultas. Probá nuevamente en un minuto."});
        return;
      }
      logger.error("Error al publicar historias", error);
      await measureError();
      response.status(500).json({error: "No fue posible cargar las historias publicadas."});
    }
  },
);

export const publicCatalogs = onRequest(
  {region, timeoutSeconds: 15, memory: "256MiB", maxInstances: 20},
  async (request, response) => {
    if (configurePublicReadCors(request, response)) return;
    if (request.method !== "GET") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    try {
      await enforceRateLimit(`public-catalogs-ip:${clientIdentity(request)}`, 240);
      await measureRequest("publicStories");
      const catalogs = await loadEditorialCatalogs();
      const payload = JSON.stringify({schemaVersion: 1, catalogs});
      const etag = `"${createHash("sha256").update(payload).digest("base64url")}"`;
      response.set("Cache-Control", "public, max-age=60, s-maxage=120, stale-while-revalidate=300");
      response.set("Content-Type", "application/json; charset=utf-8");
      response.set("ETag", etag);
      response.set("X-Content-Type-Options", "nosniff");
      response.set("Referrer-Policy", "no-referrer");
      if (request.headers["if-none-match"] === etag) {
        response.status(304).send("");
        return;
      }
      response.status(200).send(payload);
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).json({error: "Demasiadas consultas. Probá nuevamente en un minuto."});
        return;
      }
      logger.error("Error al publicar catálogos", error);
      await measureError();
      response.status(500).json({error: "No fue posible cargar los catálogos editoriales."});
    }
  },
);

export const publicStoryPage = onRequest(
  {region, timeoutSeconds: 20, memory: "256MiB", maxInstances: 20},
  async (request, response) => {
    response.set("Content-Type", "text/html; charset=utf-8");
    response.set("Cache-Control", "no-store");
    response.set("X-Content-Type-Options", "nosniff");
    response.set("Referrer-Policy", "strict-origin-when-cross-origin");
    response.set("X-Frame-Options", "SAMEORIGIN");
    response.set(
      "Content-Security-Policy",
      "default-src 'none'; img-src 'self' https: data:; style-src 'unsafe-inline'; " +
      "script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'",
    );
    if (request.method !== "GET" && request.method !== "HEAD") {
      response.status(405).send("Método no permitido.");
      return;
    }
    const id = publicStoryId(request, "/historias/");
    if (!id) {
      response.status(404).send(request.method === "HEAD" ? "" : createNotFoundHtml());
      return;
    }
    try {
      await enforceRateLimit(`public-story-page-ip:${clientIdentity(request)}`, 360);
      const [snapshot, catalogs] = await Promise.all([
        getFirestore().collection("knowledge").doc(id).get(),
        loadEditorialCatalogs(),
      ]);
      const story = snapshot.exists ? toPublicStory(snapshot.id, snapshot.data() ?? {}, catalogs) : null;
      if (!story) {
        response.status(404).send(request.method === "HEAD" ? "" : createNotFoundHtml());
        return;
      }
      const image = await authorizedStoryImage(id);
      const html = createStoryHtml(story, image !== null);
      response.set("Link", `<https://dardito-742d2.web.app/historias/${encodeURIComponent(id)}>; rel=\"canonical\"`);
      response.status(200).send(request.method === "HEAD" ? "" : html);
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).send("Demasiadas consultas.");
        return;
      }
      logger.error("Error al servir la página pública de una historia", {id, error});
      response.status(500).send("No fue posible abrir la historia.");
    }
  },
);

export const publicStoryImage = onRequest(
  {region, timeoutSeconds: 20, memory: "512MiB", maxInstances: 20},
  async (request, response) => {
    response.set("Cache-Control", "no-store");
    response.set("X-Content-Type-Options", "nosniff");
    response.set("Referrer-Policy", "no-referrer");
    if (request.method !== "GET" && request.method !== "HEAD") {
      response.status(405).send("");
      return;
    }
    const id = publicStoryId(request, "/api/story-images/");
    if (!id) {
      response.status(404).send("");
      return;
    }
    try {
      await enforceRateLimit(`public-story-image-ip:${clientIdentity(request)}`, 360);
      const story = await getFirestore().collection("knowledge").doc(id).get();
      if (!story.exists || story.data()?.status !== "published") {
        response.status(404).send("");
        return;
      }
      const image = await authorizedStoryImage(id);
      if (!image) {
        response.redirect(302, "/assets/assets/brand/mhdlp_logo_horizontal.jpg");
        return;
      }
      const storagePath = String(image.storagePath);
      const contentType = String(image.contentType);
      const file = getStorage().bucket().file(storagePath);
      const [metadata] = await file.getMetadata();
      const size = Number(metadata.size ?? 0);
      if (!Number.isFinite(size) || size < 1 || size > maxPhotoBytes * 3) {
        response.status(404).send("");
        return;
      }
      response.set("Content-Type", contentType);
      response.set("Content-Length", String(size));
      if (request.method === "HEAD") {
        response.status(200).send("");
        return;
      }
      const [buffer] = await file.download();
      response.status(200).send(buffer);
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).send("");
        return;
      }
      logger.error("Error al servir la imagen pública de una historia", {id, error});
      response.status(404).send("");
    }
  },
);

let sitemapCache: {xml: string; expiresAt: number} | undefined;
let sitemapLoading: Promise<string> | undefined;

async function loadPublicSitemap(): Promise<string> {
  if (sitemapCache && sitemapCache.expiresAt > Date.now()) return sitemapCache.xml;
  if (sitemapLoading) return sitemapLoading;
  sitemapLoading = (async () => {
    const snapshot = await getFirestore().collection("knowledge")
      .where("status", "==", "published")
      .limit(1_000)
      .get();
    const stories = snapshot.docs.map((document) => {
      const updatedAt = document.data().updatedAt;
      return {
        id: document.id,
        lastModified: updatedAt instanceof Timestamp
          ? updatedAt.toDate().toISOString().slice(0, 10)
          : undefined,
      };
    }).filter((story) => /^[a-zA-Z0-9_-]{1,120}$/.test(story.id));
    const xml = createSitemapXml(stories);
    sitemapCache = {xml, expiresAt: Date.now() + 60_000};
    return xml;
  })();
  try {
    return await sitemapLoading;
  } finally {
    sitemapLoading = undefined;
  }
}

export const publicSitemap = onRequest(
  {region, timeoutSeconds: 20, memory: "256MiB", maxInstances: 10},
  async (request, response) => {
    if (request.method !== "GET" && request.method !== "HEAD") {
      response.status(405).send("");
      return;
    }
    try {
      await enforceRateLimit(`public-sitemap-ip:${clientIdentity(request)}`, 120);
      const xml = await loadPublicSitemap();
      response.set("Content-Type", "application/xml; charset=utf-8");
      response.set("Cache-Control", "public, max-age=60, s-maxage=60");
      response.set("X-Content-Type-Options", "nosniff");
      response.status(200).send(request.method === "HEAD" ? "" : xml);
    } catch (error) {
      response.set("Cache-Control", "no-store");
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).send("");
        return;
      }
      logger.error("Error al servir el sitemap", error);
      response.status(500).send("");
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
      const account = await authenticatedAccount(request);
      const user = account.token;
      const ip = account.ip;
      const uploadAction = request.body && typeof request.body === "object"
        ? request.body as Record<string, unknown>
        : {};
      if (uploadAction.action === "prepare") {
        await Promise.all([
          enforceRateLimit(`story-prepare-user:${user.uid}`, 60),
          enforceRateLimit(`story-prepare-ip:${ip}`, 240),
        ]);
        const reservation = await prepareStoryUpload({
          uid: user.uid, ip, submissionId: uploadAction.submissionId, photos: uploadAction.photos,
        });
        response.status(200).json(reservation);
        return;
      }
      if (uploadAction.action === "cancel") {
        await Promise.all([
          enforceRateLimit(`story-cancel-user:${user.uid}`, 30, 60 * 60_000),
          enforceRateLimit(`story-cancel-ip:${ip}`, 60, 60 * 60_000),
        ]);
        const result = await cancelStoryUpload({uid: user.uid, submissionId: uploadAction.submissionId});
        response.status(200).json(result);
        return;
      }
      if (uploadAction.action !== undefined) {
        response.status(400).json({error: "La acción de carga no es válida."});
        return;
      }
      await Promise.all([
        enforceRateLimit(`story-user:${user.uid}`, 5, 60 * 60_000),
        enforceRateLimit(`story-ip:${ip}`, 10, 60 * 60_000),
      ]);
      await measureRequest("storySubmissions");
      const input = parseStorySubmission(request.body, await loadEditorialCatalogs());

      const expectedPrefix = `story_submissions/${user.uid}/${input.submissionId}/`;
      const photos: Array<{path: string; size: number; contentType: string; originalName: unknown}> = [];
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
        const uploadReservation = await readStoryUploadForFinalize(transaction, {
          uid: user.uid, submissionId: input.submissionId, photos,
          requireReservation: storyUploadReservationsRequired.value() === "true",
        });
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
          period: input.period,
          evidence: input.evidence,
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
        if (uploadReservation) completeStoryUpload(transaction, uploadReservation);
      });
      response.status(alreadyExists ? 200 : 202).json({
        id: input.submissionId,
        status: "pending_review",
        duplicate: alreadyExists,
      });
    } catch (error) {
      if (error instanceof StoryUploadError) {
        response.status(error.status).json({code: error.code, error: error.message});
        return;
      }
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
      await measureError();
      response.status(500).json({error: "No fue posible guardar la historia."});
    }
  },
);

export const usageAnalytics = onRequest(
  {region, timeoutSeconds: 15, memory: "256MiB", maxInstances: 10},
  async (request, response) => {
    if (configureCors(request, response)) return;
    if (request.method !== "POST") {
      response.status(405).json({error: "Método no permitido."});
      return;
    }
    try {
      await enforceRateLimit(`usage-ip:${clientIdentity(request)}`, 360, 60 * 60_000);
      const input = request.body && typeof request.body === "object"
        ? request.body as Record<string, unknown>
        : {};
      const type = input.type;
      const sessionId = typeof input.sessionId === "string" ? input.sessionId.trim() : "";
      if (
        !["session_start", "session_ping", "story_view"].includes(String(type)) ||
        !/^[a-zA-Z0-9_-]{20,160}$/.test(sessionId)
      ) {
        response.status(400).json({error: "Evento de uso inválido."});
        return;
      }
      const storyId = typeof input.storyId === "string" ? input.storyId.trim() : undefined;
      if (type === "story_view" && (!storyId || !/^[a-zA-Z0-9_-]{1,120}$/.test(storyId))) {
        response.status(400).json({error: "Historia inválida."});
        return;
      }
      await recordUsageEvent({
        type: type as "session_start" | "session_ping" | "story_view",
        sessionId,
        elapsedSeconds: Number(input.elapsedSeconds ?? 0),
        storyId,
      });
      response.set("Cache-Control", "no-store");
      response.status(202).json({accepted: true});
    } catch (error) {
      if (error instanceof Error && error.message === "RATE_LIMITED") {
        response.status(429).json({error: "Demasiados eventos."});
        return;
      }
      logger.warn("No fue posible registrar el evento de uso", error);
      response.status(500).json({error: "No fue posible registrar el evento."});
    }
  },
);

export const upsertKnowledge = onCall({region, enforceAppCheck: true}, async (request) => {
  const actor = await requireEditorialRole(request, ["admin"]);
  try {
    await enforceRateLimit(`admin:legacy-upsert-knowledge:${actor.uid}`, 40, 15 * 60_000);
  } catch (error) {
    if (error instanceof Error && error.message === "RATE_LIMITED") {
      throw new HttpsError("resource-exhausted", "Demasiadas operaciones. Esperá antes de continuar.");
    }
    throw error;
  }
  let item;
  try {
    item = parseLegacyKnowledge(request.data);
  } catch {
    throw new HttpsError("invalid-argument", "El documento de corpus es inválido.");
  }
  const db = getFirestore();
  const batch = db.batch();
  batch.set(db.collection("knowledge").doc(item.id), {
    ...item,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: actor.uid,
  }, {merge: true});
  batch.create(db.collection("editorial_audit").doc(), {
    action: "knowledge.legacy_upserted",
    actorId: actor.uid,
    actorRole: actor.role,
    actorEmail: actor.email,
    target: item.id,
    details: {status: item.status},
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {id: item.id};
});

export const health = onRequest({region, cors: true}, (_request, response) => {
  response.status(200).json({service: "dardito-backend", status: "ok"});
});
