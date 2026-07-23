import {createHmac, timingSafeEqual} from "node:crypto";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onRequest} from "firebase-functions/v2/https";

import {
  geminiApiKey,
  region,
} from "../config.js";
import {
  whatsappAccessToken,
  whatsappAppSecret,
  whatsappGraphVersion,
  whatsappPhoneNumberId,
  whatsappVerifyToken,
} from "../whatsapp-config.js";
import {answerChat} from "../services/chat.js";
import {privacyHash} from "../services/rate-limit.js";

if (getApps().length === 0) initializeApp();

function hasValidMetaSignature(rawBody: Buffer, signature: string | undefined): boolean {
  if (!signature?.startsWith("sha256=")) return false;
  const expected = createHmac("sha256", whatsappAppSecret.value())
    .update(rawBody)
    .digest("hex");
  const received = signature.slice("sha256=".length);
  if (received.length !== expected.length) return false;
  return timingSafeEqual(Buffer.from(received, "hex"), Buffer.from(expected, "hex"));
}

interface WhatsAppTextMessage {
  id: string;
  from: string;
  timestamp?: string;
  type: string;
  text?: {body?: string};
}

function extractMessages(payload: unknown): WhatsAppTextMessage[] {
  if (!payload || typeof payload !== "object") return [];
  const entries = (payload as {entry?: unknown[]}).entry;
  if (!Array.isArray(entries)) return [];
  const output: WhatsAppTextMessage[] = [];
  for (const entry of entries) {
    const changes = (entry as {changes?: unknown[]})?.changes;
    if (!Array.isArray(changes)) continue;
    for (const change of changes) {
      const messages = (change as {value?: {messages?: unknown[]}})?.value?.messages;
      if (!Array.isArray(messages)) continue;
      for (const message of messages) {
        const candidate = message as WhatsAppTextMessage;
        if (candidate.id && candidate.from && candidate.type) output.push(candidate);
      }
    }
  }
  return output;
}

export const whatsappWebhook = onRequest(
  {
    region,
    secrets: [whatsappVerifyToken, whatsappAppSecret],
    timeoutSeconds: 20,
    maxInstances: 10,
  },
  async (request, response) => {
    if (request.method === "GET") {
      const mode = request.query["hub.mode"];
      const token = request.query["hub.verify_token"];
      const challenge = request.query["hub.challenge"];
      if (mode === "subscribe" && token === whatsappVerifyToken.value() && typeof challenge === "string") {
        response.status(200).send(challenge);
      } else {
        response.sendStatus(403);
      }
      return;
    }
    if (request.method !== "POST") {
      response.sendStatus(405);
      return;
    }
    const signature = request.header("x-hub-signature-256");
    if (!hasValidMetaSignature(request.rawBody, signature)) {
      response.sendStatus(401);
      return;
    }

    await Promise.all(extractMessages(request.body).map(async (message) => {
      const safeId = message.id.replace(/[^a-zA-Z0-9_-]/g, "-");
      const reference = getFirestore().collection("whatsapp_inbound").doc(safeId);
      try {
        await reference.create({
          messageId: message.id,
          senderHash: privacyHash(message.from),
          sender: message.from,
          type: message.type,
          text: message.text?.body?.trim() || null,
          status: "pending",
          receivedAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        // Meta reintenta webhooks. El ID de mensaje funciona como clave idempotente.
        logger.info("Mensaje de WhatsApp ya recibido", {messageId: message.id});
      }
    }));
    response.sendStatus(200);
  },
);

async function sendWhatsAppText(to: string, body: string): Promise<void> {
  const url = `https://graph.facebook.com/${whatsappGraphVersion.value()}/` +
    `${whatsappPhoneNumberId.value()}/messages`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${whatsappAccessToken.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to,
      type: "text",
      text: {preview_url: false, body},
    }),
  });
  if (!response.ok) {
    throw new Error(`WhatsApp respondió ${response.status}: ${await response.text()}`);
  }
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
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();
    if (data.status !== "pending") return;

    if (data.type !== "text" || typeof data.text !== "string" || !data.text) {
      await snapshot.ref.update({status: "ignored", processedAt: FieldValue.serverTimestamp()});
      return;
    }

    try {
      const result = await answerChat({
        message: data.text,
        conversationId: `wa-${data.senderHash}`,
        participantId: data.senderHash,
        channel: "whatsapp",
      });
      await sendWhatsAppText(data.sender, result.answer);
      await snapshot.ref.update({
        status: "sent",
        conversationId: result.conversationId,
        sender: FieldValue.delete(),
        processedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      logger.error("No se pudo procesar el mensaje de WhatsApp", error);
      await snapshot.ref.update({
        lastError: error instanceof Error ? error.message.slice(0, 500) : "unknown",
        attempts: FieldValue.increment(1),
        lastAttemptAt: FieldValue.serverTimestamp(),
      });
      throw error;
    }
  },
);
