import {randomUUID} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onRequest} from "firebase-functions/v2/https";

import {geminiApiKey, region} from "../config.js";
import {
  whatsappAccessToken,
  whatsappAppSecret,
  whatsappGraphVersion,
  whatsappPhoneNumberId,
  whatsappVerifyToken,
} from "../whatsapp-config.js";
import {answerChat} from "../services/chat.js";
import {privacyHash} from "../services/rate-limit.js";
import {extractWhatsAppMessages, hasValidMetaSignature, verificationChallenge} from "../domain/whatsapp.js";
import {needsWhatsAppFormatNotice} from "../domain/whatsapp-content.js";
import {
  processWhatsAppJob,
  WhatsAppDeliveryError,
  whatsappMaximumAgeMs,
  whatsappRetentionMs,
  type WhatsAppJob,
} from "../domain/whatsapp-worker.js";

if (getApps().length === 0) initializeApp();

export const whatsappWebhook = onRequest(
  {
    region,
    secrets: [whatsappVerifyToken, whatsappAppSecret, whatsappPhoneNumberId],
    timeoutSeconds: 20,
    maxInstances: 10,
  },
  async (request, response) => {
    if (request.method === "GET") {
      const challenge = verificationChallenge(request.query, whatsappVerifyToken.value());
      if (challenge !== null) response.status(200).type("text/plain").send(challenge);
      else response.sendStatus(403);
      return;
    }
    if (request.method !== "POST") {
      response.sendStatus(405);
      return;
    }
    if (request.rawBody.byteLength > 1024 * 1024) {
      response.sendStatus(413);
      return;
    }
    if (!hasValidMetaSignature(request.rawBody, request.header("x-hub-signature-256"), whatsappAppSecret.value())) {
      response.sendStatus(401);
      return;
    }
    const expectedPhone = whatsappPhoneNumberId.value();
    if (!/^[0-9]{6,30}$/.test(expectedPhone)) {
      response.sendStatus(503);
      return;
    }
    const now = Date.now();
    await Promise.all(extractWhatsAppMessages(request.body, expectedPhone).map(async (message) => {
      // Message IDs are opaque. Hashing avoids collisions caused by replacing punctuation.
      const reference = getFirestore().collection("whatsapp_inbound").doc(privacyHash(message.id));
      const legacyReference = getFirestore().collection("whatsapp_inbound").doc(message.id.replace(/[^a-zA-Z0-9_-]/g, "-"));
      const receivedAtMs = Number(message.timestamp) * 1000;
      const validTime = Number.isFinite(receivedAtMs) && receivedAtMs > 0 &&
        receivedAtMs <= now + 5 * 60_000 && now - receivedAtMs <= whatsappMaximumAgeMs;
      const text = typeof message.text?.body === "string" ? message.text.body.trim() : "";
      const validText = message.type === "text" && text.length > 0 && text.length <= 2000;
      const formatNotice = needsWhatsAppFormatNotice(message.type);
      const status = message.type !== "text" && !formatNotice
        ? "ignored" : validTime && (validText || formatNotice) ? "pending" : "failed";
      // Keep the old ID check during migration so a retried pre-release webhook cannot enqueue twice.
      await getFirestore().runTransaction(async (transaction) => {
        const [current, legacy] = await transaction.getAll(reference, legacyReference);
        if (current?.exists || legacy?.exists) return;
        transaction.create(reference, {
          messageId: message.id,
          senderHash: privacyHash(message.from),
          // Never persist media, captions, URLs, filenames or contact/location payloads.
          ...(status === "pending" ? {sender: message.from, ...(validText ? {text} : {})} : {}),
          type: message.type,
          status,
          attempts: 0,
          receivedAtMs: validTime ? receivedAtMs : now,
          receivedAt: FieldValue.serverTimestamp(),
          expiresAt: Timestamp.fromMillis(now + whatsappRetentionMs),
          ...(status !== "pending" ? {
            processedAt: FieldValue.serverTimestamp(),
            lastError: status === "failed" ? "INVALID_MESSAGE" : null,
          } : {}),
        });
      });
    }));
    response.sendStatus(200);
  },
);

async function sendWhatsAppText(to: string, body: string): Promise<void> {
  if (body.length > 4096) throw new WhatsAppDeliveryError("permanent", "META_MESSAGE_TOO_LONG");
  let response: Response;
  try {
    response = await fetch(`https://graph.facebook.com/${whatsappGraphVersion.value()}/${whatsappPhoneNumberId.value()}/messages`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${whatsappAccessToken.value()}`,
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(15_000),
      body: JSON.stringify({
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to,
        type: "text",
        text: {preview_url: false, body},
      }),
    });
  } catch {
    throw new WhatsAppDeliveryError("uncertain", "META_DELIVERY_UNCONFIRMED");
  }
  if (response.ok) return;
  // A lost connection or server error may occur after Meta accepted delivery.
  // Only an explicit throttling response is safe to retry automatically.
  throw new WhatsAppDeliveryError(
    response.status === 429 ? "retry" : response.status >= 500 || response.status === 408 ? "uncertain" : "permanent",
    `META_HTTP_${response.status}`,
  );
}

export const processWhatsAppInbound = onDocumentCreated(
  {
    document: "whatsapp_inbound/{messageId}",
    region,
    secrets: [geminiApiKey, whatsappAccessToken, whatsappPhoneNumberId],
    timeoutSeconds: 120,
    retry: true,
  },
  async (event) => {
    if (!event.data) return;
    const reference = event.data.ref;
    await processWhatsAppJob({
      owner: randomUUID(),
      now: Date.now,
      store: {
        transaction: (change) => getFirestore().runTransaction(async (transaction) => {
          const snapshot = await transaction.get(reference);
          if (!snapshot.exists) return null;
          const data = snapshot.data()!;
          const current = {
            ...data,
            receivedAtMs: data.receivedAtMs ?? (data.receivedAt instanceof Timestamp ? data.receivedAt.toMillis() : NaN),
          } as WhatsAppJob;
          const patch = change(current);
          if (!patch) return null;
          const storedPatch: Record<string, unknown> = {...patch};
          for (const key of ["sender", "text", "answer", "leaseOwner", "leaseUntilMs", "lastError"] as const) {
            if (patch[key] === null) storedPatch[key] = FieldValue.delete();
          }
          if (patch.expiresAtMs !== undefined) storedPatch.expiresAt = Timestamp.fromMillis(patch.expiresAtMs);
          if (patch.processedAtMs !== undefined) storedPatch.processedAt = Timestamp.fromMillis(patch.processedAtMs);
          transaction.update(reference, storedPatch);
          return {...current, ...patch};
        }),
      },
      generate: (job) => answerChat({
        message: job.text!,
        conversationId: `wa-${job.senderHash}`,
        participantId: job.senderHash!,
        channel: "whatsapp",
      }),
      send: sendWhatsAppText,
    }).catch((error: unknown) => {
      // No provider payload, phone, text or access token is written to logs.
      logger.warn("Procesamiento de WhatsApp pendiente de reintento", {
        code: error instanceof Error && /^[A-Z_0-9]{1,80}$/.test(error.message) ? error.message : "WORKER_RETRY",
      });
      throw new Error("WHATSAPP_WORKER_RETRY");
    });
  },
);
