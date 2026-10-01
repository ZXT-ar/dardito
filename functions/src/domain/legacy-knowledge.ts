import type {CorpusItem} from "./types.js";

const allowedFields = new Set([
  "id", "title", "summary", "body", "category", "neighborhood", "evidence", "status", "keywords",
  "period", "subtitle", "latitude", "longitude", "featured", "readingMinutes", "evidenceLabel", "sourceName", "sourceUrl",
]);

function invalid(): never {
  throw new Error("INVALID_KNOWLEDGE");
}

function boundedString(input: Record<string, unknown>, key: string, max: number, required = true): string {
  const value = input[key];
  if (value === undefined && !required) return "";
  if (typeof value !== "string" || /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(value)) invalid();
  const normalized = value.trim();
  if ((required && !normalized) || normalized.length > max) invalid();
  return normalized;
}

/** Compatibility input for the original callable, excluding server-owned metadata. */
export function parseLegacyKnowledge(value: unknown): CorpusItem {
  if (!value || typeof value !== "object" || Array.isArray(value)) invalid();
  const input = value as Record<string, unknown>;
  if (Object.keys(input).some((key) => !allowedFields.has(key))) invalid();
  const id = boundedString(input, "id", 120);
  if (!/^[a-zA-Z0-9_-]{1,120}$/.test(id)) invalid();
  if (typeof input.evidence !== "string" || !["documented", "oral_tradition", "community"].includes(input.evidence) ||
      typeof input.status !== "string" || !["published", "draft", "archived"].includes(input.status)) invalid();
  if (!Array.isArray(input.keywords) || input.keywords.length > 24 ||
      !input.keywords.every((keyword) => typeof keyword === "string" && keyword.trim().length > 0 &&
        keyword.length <= 60 && !/[\u0000-\u001F\u007F]/.test(keyword))) invalid();
  const item: CorpusItem = {
    id,
    title: boundedString(input, "title", 120),
    summary: boundedString(input, "summary", 420),
    body: boundedString(input, "body", 18_000),
    category: boundedString(input, "category", 120),
    neighborhood: boundedString(input, "neighborhood", 120),
    evidence: input.evidence as string,
    status: input.status as CorpusItem["status"],
    keywords: input.keywords.map((keyword) => String(keyword).trim()),
  };
  for (const [key, max] of [
    ["period", 100], ["subtitle", 300], ["evidenceLabel", 120], ["sourceName", 300], ["sourceUrl", 1_000],
  ] as const) {
    if (input[key] !== undefined) item[key] = boundedString(input, key, max, false);
  }
  if (item.sourceUrl) {
    let parsed: URL;
    try {
      parsed = new URL(item.sourceUrl);
    } catch {
      invalid();
    }
    if (parsed.protocol !== "https:" || parsed.username || parsed.password) invalid();
    item.sourceUrl = parsed.toString();
  }
  for (const [key, min, max] of [["latitude", -90, 90], ["longitude", -180, 180], ["readingMinutes", 0, 60]] as const) {
    const numeric = input[key];
    if (numeric === undefined) continue;
    if (typeof numeric !== "number" || !Number.isFinite(numeric) || numeric < min || numeric > max ||
        (key === "readingMinutes" && !Number.isInteger(numeric))) invalid();
    item[key] = numeric;
  }
  if (input.featured !== undefined) {
    if (typeof input.featured !== "boolean") invalid();
    item.featured = input.featured;
  }
  return item;
}
