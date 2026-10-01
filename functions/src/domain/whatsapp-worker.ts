import {needsWhatsAppFormatNotice, whatsappFormatNotice} from "./whatsapp-content.js";

export const whatsappMaximumAttempts = 5;
export const whatsappMaximumAgeMs = 24 * 60 * 60_000;
export const whatsappLeaseMs = 150_000;
export const whatsappRetentionMs = 30 * 24 * 60 * 60_000;

export interface WhatsAppJob {
  status: string;
  receivedAtMs: number;
  attempts?: number;
  sender?: string | null;
  senderHash?: string;
  text?: string | null;
  type?: string;
  answer?: string | null;
  conversationId?: string;
  leaseOwner?: string | null;
  leaseUntilMs?: number | null;
  expiresAtMs?: number;
  processedAtMs?: number;
  lastError?: string | null;
}

export interface WhatsAppJobStore {
  // The callback and its write MUST execute atomically against the current document.
  transaction(change: (current: WhatsAppJob) => Partial<WhatsAppJob> | null): Promise<WhatsAppJob | null>;
}

export class WhatsAppDeliveryError extends Error {
  constructor(readonly disposition: "retry" | "permanent" | "uncertain", readonly code: string) {
    super(code);
  }
}

const terminalStatuses = new Set(["sent", "failed", "ignored", "delivery_uncertain"]);
const permanentGenerationErrors = new Set([
  "INVALID_MESSAGE", "INVALID_CONVERSATION_ID", "INVALID_USER_ID", "INVALID_CORPUS",
  "INCOMPLETE_LLM_RESPONSE", "PROVIDER_REQUEST_REJECTED",
]);

function terminal(status: string, now: number, error: string | null = null): Partial<WhatsAppJob> {
  return {
    status,
    sender: null,
    text: null,
    answer: null,
    leaseOwner: null,
    leaseUntilMs: null,
    processedAtMs: now,
    expiresAtMs: now + whatsappRetentionMs,
    lastError: error,
  };
}

export async function processWhatsAppJob(input: {
  store: WhatsAppJobStore;
  owner: string;
  now(): number;
  generate(job: WhatsAppJob): Promise<{answer: string; conversationId: string}>;
  send(to: string, answer: string): Promise<void>;
}): Promise<void> {
  const job = await input.store.transaction((current) => {
    const now = input.now();
    if (terminalStatuses.has(current.status)) return null;
    if ((current.leaseUntilMs ?? 0) > now) throw new Error("WHATSAPP_WORKER_BUSY");
    // A previous invocation may have sent the message before it crashed. Never resend it.
    if (current.status === "sending") return terminal("delivery_uncertain", now, "DELIVERY_UNCONFIRMED");
    if (!Number.isFinite(current.receivedAtMs) || now - current.receivedAtMs > whatsappMaximumAgeMs) {
      return terminal("failed", now, "MESSAGE_EXPIRED");
    }
    if ((current.attempts ?? 0) >= whatsappMaximumAttempts) return terminal("failed", now, "ATTEMPTS_EXHAUSTED");
    if (current.type !== "text" && !needsWhatsAppFormatNotice(current.type)) return terminal("ignored", now);
    if ((current.type === "text" && (typeof current.text !== "string" || !current.text.trim() || current.text.length > 2_000)) ||
        !/^[0-9]{6,20}$/.test(current.sender ?? "") || !/^[a-f0-9]{64}$/.test(current.senderHash ?? "")) {
      return terminal("failed", now, "INVALID_MESSAGE");
    }
    return {
      status: current.answer ? "ready" : "processing",
      attempts: (current.attempts ?? 0) + 1,
      leaseOwner: input.owner,
      leaseUntilMs: now + whatsappLeaseMs,
      expiresAtMs: now + whatsappRetentionMs,
      lastError: null,
    };
  });
  if (!job || job.leaseOwner !== input.owner) return;

  const updateOwned = (patch: Partial<WhatsAppJob>) => input.store.transaction((current) => {
    if (current.leaseOwner !== input.owner) throw new Error("WHATSAPP_LEASE_LOST");
    return patch;
  });

  let generated: {answer: string; conversationId: string};
  try {
    generated = needsWhatsAppFormatNotice(job.type)
      ? {answer: whatsappFormatNotice, conversationId: `wa-${job.senderHash}`}
      : job.answer && job.conversationId
      ? {answer: job.answer, conversationId: job.conversationId}
      : await input.generate(job);
    await updateOwned({...generated, status: "ready"});
  } catch (error) {
    const providerStatus = error && typeof error === "object" && "status" in error ? error.status : null;
    const code = error instanceof Error && permanentGenerationErrors.has(error.message)
      ? error.message
      : [400, 401, 403, 404, 422].includes(Number(providerStatus)) ? "PROVIDER_REQUEST_REJECTED" : "GENERATION_FAILED";
    if (permanentGenerationErrors.has(code) || (job.attempts ?? 0) >= whatsappMaximumAttempts) {
      await updateOwned(terminal("failed", input.now(), code));
      return;
    }
    await updateOwned({status: "pending", leaseOwner: null, leaseUntilMs: null, lastError: code});
    throw new Error(code);
  }

  await updateOwned({status: "sending"});
  try {
    await input.send(job.sender!, generated.answer);
  } catch (error) {
    const delivery = error instanceof WhatsAppDeliveryError
      ? error : new WhatsAppDeliveryError("uncertain", "DELIVERY_UNCONFIRMED");
    if (delivery.disposition === "retry" && (job.attempts ?? 0) < whatsappMaximumAttempts) {
      await updateOwned({status: "ready", leaseOwner: null, leaseUntilMs: null, lastError: delivery.code});
      throw new Error(delivery.code);
    }
    await updateOwned(terminal(delivery.disposition === "uncertain" ? "delivery_uncertain" : "failed", input.now(), delivery.code));
    return;
  }
  await updateOwned(terminal("sent", input.now()));
}
