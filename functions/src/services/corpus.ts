import {evidenceEntry} from "../domain/editorial-catalogs.js";
import {getFirestore} from "firebase-admin/firestore";

import type {CorpusMode} from "../domain/guardrails.js";
import type {CorpusItem} from "../domain/types.js";
import {catalogEntry, loadEditorialCatalogs, type EditorialCatalogs} from "../domain/editorial-catalogs.js";

const maxStoredCorpus = 100;
const maxContextItems = 6;
const stopWords = new Set([
  "algo", "como", "con", "cual", "cuando", "del", "desde", "donde",
  "esta", "este", "estos", "hay", "las", "los", "para", "pero", "por",
  "que", "sobre", "son", "una", "uno", "unos",
]);

function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9ñ]+/g, " ")
    .trim();
}

function tokens(value: string): Set<string> {
  return new Set(
    normalize(value)
      .split(/\s+/)
      .filter((token) => token.length >= 3 && !stopWords.has(token)),
  );
}

function score(item: CorpusItem, query: Set<string>): number {
  const title = tokens(item.title);
  const neighborhood = tokens(item.neighborhood);
  const category = tokens(item.category);
  const keywords = new Set(item.keywords.map(normalize));
  const body = tokens(`${item.summary} ${item.body}`);

  let total = 0;
  for (const queryToken of query) {
    if (title.has(queryToken)) total += 8;
    if (neighborhood.has(queryToken)) total += 7;
    if (category.has(queryToken)) total += 5;
    if (keywords.has(queryToken)) total += 6;
    if (body.has(queryToken)) total += 1;
  }
  return total;
}

function parseStoredCorpus(id: string, raw: FirebaseFirestore.DocumentData, catalogs: EditorialCatalogs): CorpusItem | null {
  const evidence = raw.evidence;
  if (typeof evidence !== "string" || !/^[a-z0-9_-]{1,80}$/.test(evidence)) {
    return null;
  }
  if (typeof raw.title !== "string" || typeof raw.body !== "string") {
    return null;
  }

  return {
    id,
    title: raw.title,
    summary: typeof raw.summary === "string" ? raw.summary : "",
    body: raw.body,
    category: typeof raw.category === "string" ? raw.category : "general",
    neighborhood: typeof raw.neighborhood === "string" ? raw.neighborhood : "La Plata",
    period: typeof raw.period === "string" ? raw.period : undefined,
    evidence,
    evidenceLabel: evidenceEntry(evidence)?.label ?? evidence,
    sourceName: typeof raw.sourceName === "string" ? raw.sourceName : undefined,
    sourceUrl: typeof raw.sourceUrl === "string" ? raw.sourceUrl : undefined,
    keywords: Array.isArray(raw.keywords)
      ? raw.keywords.filter((value: unknown): value is string => typeof value === "string")
      : [],
    status: "published",
  };
}

export async function retrieveCorpus(
  message: string,
  inlineCorpus: CorpusItem[] = [],
  mode: Exclude<CorpusMode, "none"> = "search",
): Promise<CorpusItem[]> {
  const [snapshot, catalogs] = await Promise.all([
    getFirestore().collection("knowledge").where("status", "==", "published").limit(maxStoredCorpus).get(),
    loadEditorialCatalogs(),
  ]);

  const stored = snapshot.docs
    .map((doc) => parseStoredCorpus(doc.id, doc.data(), catalogs))
    .filter((item): item is CorpusItem => item !== null);

  const unique = new Map<string, CorpusItem>();
  for (const item of [...stored, ...inlineCorpus]) {
    if (item.status === "published") unique.set(item.id, item);
  }

  if (mode === "random") {
    const candidates = [...unique.values()];
    const selected = candidates[Math.floor(Math.random() * candidates.length)];
    return selected ? [selected] : [];
  }

  const query = tokens(message);
  const ranked = [...unique.values()]
    .map((item) => ({item, score: score(item, query)}))
    .sort((a, b) => b.score - a.score || a.item.title.localeCompare(b.item.title));

  const topScore = ranked[0]?.score ?? 0;
  const minimumRelevantScore = Math.max(3, Math.ceil(topScore * 0.25));
  const relevant = ranked.filter((entry) => entry.score >= minimumRelevantScore);
  return relevant.slice(0, maxContextItems).map((entry) => entry.item);
}
