import {createHmac, timingSafeEqual} from "node:crypto";

export interface WhatsAppTextMessage {
  id: string;
  from: string;
  timestamp?: string;
  type: string;
  text?: {body?: string};
}

interface WebhookQuery {
  [key: string]: unknown;
}

export function verificationChallenge(
  query: WebhookQuery,
  expectedToken: string,
): string | null {
  const mode = query["hub.mode"];
  const token = query["hub.verify_token"];
  const challenge = query["hub.challenge"];
  return expectedToken.length > 0 &&
    mode === "subscribe" &&
    token === expectedToken &&
    typeof challenge === "string" && challenge.length <= 8192
    ? challenge
    : null;
}

export function hasValidMetaSignature(
  rawBody: Buffer,
  signature: string | undefined,
  appSecret: string,
): boolean {
  if (!signature?.startsWith("sha256=") || !appSecret) return false;
  const received = signature.slice("sha256=".length).toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(received)) return false;
  const expected = createHmac("sha256", appSecret)
    .update(rawBody)
    .digest("hex");
  return timingSafeEqual(Buffer.from(received, "hex"), Buffer.from(expected, "hex"));
}

export function extractWhatsAppMessages(payload: unknown, expectedPhoneNumberId?: string): WhatsAppTextMessage[] {
  if (!payload || typeof payload !== "object") return [];
  const entries = (payload as {entry?: unknown[]}).entry;
  if (!Array.isArray(entries)) return [];
  const output: WhatsAppTextMessage[] = [];
  for (const entry of entries.slice(0, 100)) {
    const changes = (entry as {changes?: unknown[]})?.changes;
    if (!Array.isArray(changes)) continue;
    for (const change of changes.slice(0, 100)) {
      const value = (change as {value?: {messages?: unknown[]; metadata?: {phone_number_id?: unknown}}})?.value;
      if (expectedPhoneNumberId && value?.metadata?.phone_number_id !== expectedPhoneNumberId) continue;
      const messages = value?.messages;
      if (!Array.isArray(messages)) continue;
      for (const message of messages.slice(0, 100)) {
        if (!message || typeof message !== "object") continue;
        const candidate = message as Partial<WhatsAppTextMessage>;
        if (
          typeof candidate.id === "string" && candidate.id.length > 0 && candidate.id.length <= 256 &&
          typeof candidate.from === "string" && /^[0-9]{6,20}$/.test(candidate.from) &&
          typeof candidate.type === "string" && candidate.type.length > 0 && candidate.type.length <= 64 &&
          (candidate.type !== "text" || typeof candidate.text?.body === "string")
        ) {
          output.push(candidate as WhatsAppTextMessage);
          if (output.length >= 100) return output;
        }
      }
    }
  }
  return output;
}
