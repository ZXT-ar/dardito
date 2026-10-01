import {FieldPath, getFirestore, type Firestore} from "firebase-admin/firestore";
import {evidenceEntry} from "../domain/editorial-catalogs.js";
import type {CorpusItem} from "../domain/types.js";
import type {KnowledgeSnapshot} from "../domain/knowledge-query.js";

export function publicKnowledgeItem(id: string, raw: Record<string, unknown>): CorpusItem | null {
  if (raw.status !== "published" || !/^[a-zA-Z0-9_-]{1,120}$/.test(id) ||
      typeof raw.title !== "string" || !raw.title.trim() || raw.title.length > 120 ||
      typeof raw.body !== "string" || !raw.body.trim() || raw.body.length > 18_000 ||
      typeof raw.evidence !== "string" || !/^[a-z0-9_-]{1,80}$/.test(raw.evidence)) return null;
  const field = (key: string, length: number): string => typeof raw[key] === "string" ? (raw[key] as string).slice(0, length) : "";
  const sourceUrl = field("sourceUrl", 1000);
  let safeUrl = "";
  try {
    const url = new URL(sourceUrl);
    if (url.protocol === "https:" && !url.username && !url.password) safeUrl = url.href;
  } catch { /* Missing URLs are legitimate. */ }
  // Explicit public projection: no authors' emails, submission IDs, notes or storage paths.
  return {id, title: raw.title, body: raw.body, summary: field("summary", 420),
    category: field("category", 100), neighborhood: field("neighborhood", 100), period: field("period", 100),
    evidence: raw.evidence, evidenceLabel: evidenceEntry(raw.evidence)?.label ?? raw.evidence,
    sourceName: field("sourceName", 300), ...(safeUrl ? {sourceUrl: safeUrl} : {}),
    keywords: Array.isArray(raw.keywords) ? raw.keywords.filter((k): k is string => typeof k === "string").slice(0, 24).map((k) => k.slice(0, 60)) : [],
    status: "published"};
}

export async function loadKnowledgeSnapshot(db: Firestore = getFirestore(), maximum = 2000): Promise<KnowledgeSnapshot> {
  // One consistent read transaction, paginated: edits/publication cannot produce mixed totals.
  // This is deliberately uncached in the canary so archived/edited stories disappear immediately.
  return db.runTransaction(async (transaction) => {
    const items: CorpusItem[] = [];
    let scanned = 0;
    let cursor: string | undefined;
    while (true) {
      let query = db.collection("knowledge").where("status", "==", "published").orderBy(FieldPath.documentId()).limit(Math.min(200, maximum + 1 - scanned));
      if (cursor) query = query.startAfter(cursor);
      const page = await transaction.get(query);
      scanned += page.size;
      if (scanned > maximum) throw new Error("KNOWLEDGE_CAPACITY_EXCEEDED");
      for (const document of page.docs) {
        const item = publicKnowledgeItem(document.id, document.data());
        if (item) items.push(item);
      }
      if (page.empty || page.size < Math.min(200, maximum + 1 - (scanned - page.size))) break;
      cursor = page.docs.at(-1)!.id;
    }
    return {items, complete: true, scanned, excluded: scanned - items.length};
  }, {readOnly: true});
}

export async function hasPublicStoryImage(storyId: string, db: Firestore = getFirestore()): Promise<boolean> {
  // Same eligibility AND same 50-document window as the existing public image endpoint.
  const snapshot = await db.collection("editorial_resources").where("storyId", "==", storyId).limit(50).get();
  return snapshot.docs.some((doc) => {
    const data = doc.data();
    return data.kind === "image" && data.status === "ready" && data.rights === "authorized" &&
      typeof data.storagePath === "string" && /^editorial_media\/[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]+\/resource\.(jpg|png|webp)$/.test(data.storagePath) &&
      ["image/jpeg", "image/png", "image/webp"].includes(String(data.contentType));
  });
}
