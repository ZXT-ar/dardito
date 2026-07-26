import {createHash} from "node:crypto";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";

const defaultWindowMilliseconds = 60_000;
const defaultMaxRequestsPerWindow = 30;

export function privacyHash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export async function enforceRateLimit(
  identity: string,
  maxRequestsPerWindow = defaultMaxRequestsPerWindow,
  windowMilliseconds = defaultWindowMilliseconds,
): Promise<void> {
  const reference = getFirestore().collection("rate_limits").doc(privacyHash(identity));
  const now = Date.now();

  await getFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data();
    const windowStartedAt = data?.windowStartedAt instanceof Timestamp
      ? data.windowStartedAt.toMillis()
      : 0;
    const currentCount = typeof data?.count === "number" ? data.count : 0;
    const expired = now - windowStartedAt >= windowMilliseconds;

    if (!expired && currentCount >= maxRequestsPerWindow) {
      throw new Error("RATE_LIMITED");
    }

    transaction.set(reference, {
      windowStartedAt: expired ? Timestamp.fromMillis(now) : data?.windowStartedAt,
      count: expired ? 1 : currentCount + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}
