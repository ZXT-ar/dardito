import {createHash} from "node:crypto";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";

export type ApiMetric = "publicStories" | "chat" | "storySubmissions" | "profiles";

const dailyCollection = "analytics_daily";
const sessionCollection = "analytics_sessions";
const storyCollection = "analytics_story_daily";

function dayKey(date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

function safeDocumentId(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export async function recordApiRequest(metric: ApiMetric, success = true): Promise<void> {
  const counters: Record<string, unknown> = {
    requestsTotal: FieldValue.increment(1),
    [`request_${metric}`]: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!success) counters.errors = FieldValue.increment(1);
  await getFirestore().collection(dailyCollection).doc(dayKey()).set(counters, {merge: true});
}

export async function recordApiError(): Promise<void> {
  await getFirestore().collection(dailyCollection).doc(dayKey()).set({
    errors: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

export async function recordUsageEvent(input: {
  type: "session_start" | "session_ping" | "story_view";
  sessionId: string;
  elapsedSeconds?: number;
  storyId?: string;
}): Promise<void> {
  const db = getFirestore();
  const day = dayKey();
  const sessionId = safeDocumentId(`mhdlp-session:${input.sessionId}`);
  const sessionReference = db.collection(sessionCollection).doc(sessionId);
  const dailyReference = db.collection(dailyCollection).doc(day);

  if (input.type === "story_view") {
    const storyId = input.storyId ?? "";
    const story = await db.collection("knowledge").doc(storyId).get();
    if (!story.exists || story.data()?.status !== "published") return;
    const storyReference = db.collection(storyCollection).doc(`${day}_${safeDocumentId(storyId).slice(0, 32)}`);
    const batch = db.batch();
    batch.set(storyReference, {
      day,
      storyId,
      title: String(story.data()?.title ?? "Historia sin título").slice(0, 180),
      views: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    batch.set(dailyReference, {
      storyViews: FieldValue.increment(1),
      usageEvents: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await batch.commit();
    return;
  }

  const elapsedSeconds = Math.max(0, Math.min(43_200, Math.round(input.elapsedSeconds ?? 0)));
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(sessionReference);
    const isNew = !existing.exists;
    const previousDuration = Number(existing.data()?.durationSeconds ?? 0);
    transaction.set(sessionReference, {
      day: existing.data()?.day ?? day,
      startedAt: existing.data()?.startedAt ?? FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      durationSeconds: Math.max(previousDuration, elapsedSeconds),
      expiresAt: Timestamp.fromMillis(Date.now() + 90 * 24 * 60 * 60_000),
    }, {merge: true});
    transaction.set(dailyReference, {
      sessions: isNew ? FieldValue.increment(1) : FieldValue.increment(0),
      sessionPings: FieldValue.increment(1),
      usageEvents: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

export async function loadUsageMetrics(periodDays = 30): Promise<Record<string, unknown>> {
  const db = getFirestore();
  const cutoff = new Date(Date.now() - (periodDays - 1) * 24 * 60 * 60_000).toISOString().slice(0, 10);
  const [dailySnapshot, storySnapshot, sessionSnapshot] = await Promise.all([
    db.collection(dailyCollection).limit(120).get(),
    db.collection(storyCollection).limit(2_000).get(),
    db.collection(sessionCollection).orderBy("lastSeenAt", "desc").limit(1_000).get(),
  ]);

  const daily = dailySnapshot.docs
    .filter((document) => document.id >= cutoff)
    .map((document) => {
      const data = document.data();
      return {
        date: document.id,
        requests: Number(data.requestsTotal ?? 0),
        chats: Number(data.request_chat ?? 0),
        submissions: Number(data.request_storySubmissions ?? 0),
        storyViews: Number(data.storyViews ?? 0),
        sessions: Number(data.sessions ?? 0),
        errors: Number(data.errors ?? 0),
      };
    })
    .sort((left, right) => left.date.localeCompare(right.date));

  const totals = daily.reduce((result, item) => ({
    requests: result.requests + item.requests,
    chats: result.chats + item.chats,
    submissions: result.submissions + item.submissions,
    storyViews: result.storyViews + item.storyViews,
    sessions: result.sessions + item.sessions,
    errors: result.errors + item.errors,
  }), {requests: 0, chats: 0, submissions: 0, storyViews: 0, sessions: 0, errors: 0});

  const durations = sessionSnapshot.docs
    .map((document) => document.data())
    .filter((data) => String(data.day ?? "") >= cutoff)
    .map((data) => Number(data.durationSeconds ?? 0))
    .filter((duration) => Number.isFinite(duration) && duration >= 0);
  const averageRetentionSeconds = durations.length === 0
    ? 0
    : Math.round(durations.reduce((sum, duration) => sum + duration, 0) / durations.length);
  const activeCutoff = Date.now() - 5 * 60_000;
  const activeSessions = sessionSnapshot.docs.filter((document) => {
    const value = document.data().lastSeenAt;
    return value instanceof Timestamp && value.toMillis() >= activeCutoff;
  }).length;

  const stories = new Map<string, {storyId: string; title: string; views: number}>();
  for (const document of storySnapshot.docs) {
    const data = document.data();
    if (String(data.day ?? "") < cutoff) continue;
    const storyId = String(data.storyId ?? "");
    if (!storyId) continue;
    const current = stories.get(storyId) ?? {storyId, title: String(data.title ?? storyId), views: 0};
    current.views += Number(data.views ?? 0);
    stories.set(storyId, current);
  }

  return {
    checkedAt: new Date().toISOString(),
    periodDays,
    totals: {
      ...totals,
      averageRetentionSeconds,
      activeSessions,
      errorRate: totals.requests > 0 ? Number(((totals.errors / totals.requests) * 100).toFixed(2)) : 0,
    },
    daily,
    topStories: [...stories.values()].sort((left, right) => right.views - left.views).slice(0, 10),
  };
}
