import {publicAttribution} from "./story-attribution.js";
import {evidenceEntry} from "./editorial-catalogs.js";
import {catalogEntry, slugify, type EditorialCatalogs} from "./editorial-catalogs.js";

export interface PublicStory {
  id: string;
  title: string;
  subtitle: string;
  summary: string;
  body: string;
  categoryId: string;
  categoryLabel: string;
  neighborhood: string;
  period: string;
  evidence: string;
  evidenceLabel: string;
  sourceName: string;
  latitude: number;
  longitude: number;
  featured: boolean;
  readingMinutes: number;
  likeCount: number;
  publicAuthor?: string | null;
  contributionOrigin: "community" | "dardito_team";
}

const categories = new Map<string, {id: string; label: string}>([
  ["arquitectura", {id: "architecture", label: "Arquitectura"}],
  ["architecture", {id: "architecture", label: "Arquitectura"}],
  ["misterios", {id: "mystery", label: "Misterios"}],
  ["misterio", {id: "mystery", label: "Misterios"}],
  ["mystery", {id: "mystery", label: "Misterios"}],
  ["cultura", {id: "culture", label: "Cultura"}],
  ["culture", {id: "culture", label: "Cultura"}],
  ["barrios", {id: "neighborhood", label: "Barrios"}],
  ["barrio", {id: "neighborhood", label: "Barrios"}],
  ["neighborhood", {id: "neighborhood", label: "Barrios"}],
  ["memoria viva", {id: "memory", label: "Memoria viva"}],
  ["memoria", {id: "memory", label: "Memoria viva"}],
  ["memory", {id: "memory", label: "Memoria viva"}],
]);

function normalized(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("es-AR")
    .trim();
}

function safeString(value: unknown, maximum: number): string | null {
  if (typeof value !== "string") return null;
  const result = value.replace(/\u0000/g, "").trim();
  if (!result || result.length > maximum) return null;
  return result;
}

function safeCoordinate(value: unknown, minimum: number, maximum: number): number | null {
  const result = Number(value);
  if (!Number.isFinite(result) || result < minimum || result > maximum) return null;
  return result;
}

function estimatedReadingMinutes(body: string): number {
  const words = body.split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.min(60, Math.ceil(words / 200)));
}

export function storyContributionOrigin(
  raw: Record<string, unknown>,
): PublicStory["contributionOrigin"] {
  if (typeof raw.sourceSubmissionId === "string" && raw.sourceSubmissionId.trim()) {
    return "community";
  }
  return raw.contributionOrigin === "community" ? "community" : "dardito_team";
}

/**
 * Converts an internal Firestore document into the strict public contract.
 * Unknown/internal fields are discarded by construction.
 */
export function toPublicStory(id: string, raw: Record<string, unknown>, catalogs?: EditorialCatalogs): PublicStory | null {
  if (raw.status !== "published" || !/^[a-zA-Z0-9_-]{1,120}$/.test(id)) return null;
  const title = safeString(raw.title, 120);
  const summary = safeString(raw.summary, 420);
  const body = safeString(raw.body, 18_000);
  const neighborhood = safeString(raw.neighborhood, 100);
  const period = safeString(raw.period, 100);
  const sourceName = safeString(raw.sourceName, 300);
  const rawCategory = safeString(raw.category, 80);
  const latitude = safeCoordinate(raw.latitude, -35.25, -34.55);
  const longitude = safeCoordinate(raw.longitude, -58.35, -57.55);
  const evidence = raw.evidence;
  if (
    !title || !summary || !body || !neighborhood || !period ||
    !sourceName || !rawCategory || latitude === null || longitude === null ||
    typeof evidence !== "string" || !evidence.trim()
  ) {
    return null;
  }
  const configuredCategory = catalogs ? catalogEntry(catalogs.categories, rawCategory) : null;
  const category = configuredCategory ?? categories.get(normalized(rawCategory)) ?? {
    id: slugify(rawCategory) || "other",
    label: rawCategory,
  };
  const configuredEvidence = evidenceEntry(evidence);
  const configuredMinutes = Number(raw.readingMinutes);
  const readingMinutes = Number.isInteger(configuredMinutes) &&
    configuredMinutes >= 1 && configuredMinutes <= 60
    ? configuredMinutes
    : estimatedReadingMinutes(body);
  const configuredLikeCount = Number(raw.likeCount);
  const likeCount = Number.isSafeInteger(configuredLikeCount) && configuredLikeCount >= 0
    ? configuredLikeCount
    : 0;

  return {
    id,
    title,
    subtitle: safeString(raw.subtitle, 420) ?? summary,
    summary,
    body,
    categoryId: category.id,
    categoryLabel: category.label,
    neighborhood,
    period,
    evidence: String(evidence),
    evidenceLabel: configuredEvidence?.label ?? String(evidence),
    sourceName,
    latitude,
    longitude,
    featured: raw.featured === true,
    readingMinutes,
    likeCount,
    publicAuthor: publicAttribution(raw),
    contributionOrigin: storyContributionOrigin(raw),
  };
}
