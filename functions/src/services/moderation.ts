import {createHash, randomUUID} from "node:crypto";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";

import {classifyModeration} from "../domain/moderation-policy.js";
import type {Channel, ModerationResult} from "../domain/types.js";
import {privacyHash} from "./rate-limit.js";

const yellowLimit = 3 as const;
const blockMilliseconds = 72 * 60 * 60 * 1_000;

interface ModerationInput {
  channel: Channel;
  scopes: string[];
  conversationId: string;
  message: string;
}

export async function enforceModeration(input: ModerationInput): Promise<ModerationResult> {
  const classification = classifyModeration(input.message);
  const db = getFirestore();
  const scopes = [...new Set(input.scopes.filter(Boolean))];
  if (scopes.length === 0) throw new Error("INVALID_MODERATION_SCOPE");
  const references = scopes.map((scope) =>
    db.collection("moderation_sessions").doc(privacyHash(`${input.channel}:${scope}`))
  );
  const primaryReference = references[0]!;
  const now = Date.now();

  return db.runTransaction(async (transaction) => {
    const snapshots = [];
    for (const reference of references) {
      snapshots.push(await transaction.get(reference));
    }
    const activeBlock = snapshots
      .map((snapshot) => snapshot.data()?.blockedUntil)
      .filter((value): value is Timestamp => value instanceof Timestamp)
      .map((value) => value.toMillis())
      .filter((value) => value > now)
      .reduce((latest, value) => Math.max(latest, value), 0);
    const primarySnapshot = snapshots[0]!;
    const primaryData = primarySnapshot.data();
    const previousBlockedUntil = primaryData?.blockedUntil instanceof Timestamp
      ? primaryData.blockedUntil.toMillis()
      : 0;
    const previousCount = typeof primaryData?.yellowCount === "number"
      ? Math.max(0, Math.min(yellowLimit, Math.floor(primaryData.yellowCount)))
      : 0;

    if (activeBlock) {
      return {
        action: "blocked",
        yellowCount: yellowLimit,
        yellowLimit,
        categories: [],
        blockedUntil: new Date(activeBlock).toISOString(),
      };
    }

    const baseCount = previousBlockedUntil > 0 ? 0 : previousCount;
    if (classification.severity === "none") {
      for (let index = 0; index < snapshots.length; index++) {
        const blockedUntil = snapshots[index]?.data()?.blockedUntil;
        if (blockedUntil instanceof Timestamp && blockedUntil.toMillis() <= now) {
          transaction.set(references[index]!, {
            channel: input.channel,
            yellowCount: 0,
            blockedUntil: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      }
      return {
        action: "none",
        yellowCount: baseCount,
        yellowLimit,
        categories: [],
      };
    }

    const directRed = classification.severity === "red";
    const nextCount = directRed ? yellowLimit : Math.min(yellowLimit, baseCount + 1);
    const red = directRed || nextCount >= yellowLimit;
    const blockedUntilMs = red ? now + blockMilliseconds : 0;

    const blockedUntilValue = red
      ? Timestamp.fromMillis(blockedUntilMs)
      : FieldValue.delete();
    transaction.set(primaryReference, {
      channel: input.channel,
      scopeType: "session",
      yellowCount: nextCount,
      blockedUntil: blockedUntilValue,
      lastCategories: classification.categories,
      updatedAt: FieldValue.serverTimestamp(),
      ...(primarySnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
    }, {merge: true});

    if (red) {
      for (let index = 1; index < references.length; index++) {
        transaction.set(references[index]!, {
          channel: input.channel,
          scopeType: "network",
          yellowCount: yellowLimit,
          blockedUntil: blockedUntilValue,
          lastCategories: classification.categories,
          updatedAt: FieldValue.serverTimestamp(),
          ...(snapshots[index]?.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
        }, {merge: true});
      }
    }

    const event = primaryReference.collection("events").doc(randomUUID());
    transaction.set(event, {
      action: red ? "red" : "yellow",
      categories: classification.categories,
      conversationId: input.conversationId,
      messageHash: createHash("sha256").update(input.message).digest("hex"),
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      action: red ? "red" : "yellow",
      yellowCount: nextCount,
      yellowLimit,
      categories: classification.categories,
      ...(red ? {blockedUntil: new Date(blockedUntilMs).toISOString()} : {}),
    };
  });
}

export function moderationAnswer(result: ModerationResult): string {
  if (result.action === "yellow") {
    return "🟨 Tarjeta amarilla " +
      `(${result.yellowCount}/${result.yellowLimit}). ` +
      "Podemos seguir conversando, pero este mensaje cruza las reglas de convivencia. " +
      "Aunque contenga varias expresiones, cuenta como una sola infracción. " +
      "Cuidemos el trato y volvamos a las historias de La Plata.";
  }
  if (result.action === "red") {
    const direct = result.categories.includes("credible_threat") ||
      result.categories.includes("sexual_minors");
    return "🟥 Tarjeta roja. " +
      (direct
        ? "Este mensaje activa una regla crítica de seguridad. "
        : "La sesión alcanzó tres tarjetas amarillas. ") +
      "La conversación queda bloqueada durante 72 horas.";
  }
  if (result.action === "blocked") {
    const until = result.blockedUntil
      ? new Intl.DateTimeFormat("es-AR", {
        dateStyle: "short",
        timeStyle: "short",
        timeZone: "America/Argentina/Buenos_Aires",
      }).format(new Date(result.blockedUntil))
      : "el fin del bloqueo";
    return `🟥 Esta sesión continúa bloqueada hasta ${until}.`;
  }
  return "";
}
