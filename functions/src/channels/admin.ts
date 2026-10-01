import {resolveAttribution} from "../domain/story-attribution.js";
import {evidenceEntry} from "../domain/editorial-catalogs.js";
import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth, type UserRecord} from "firebase-admin/auth";
import {FieldPath, FieldValue, getFirestore, Timestamp, type DocumentData, type Query} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {createHash} from "node:crypto";

import {geminiApiKey, region} from "../config.js";
import {loadGeneralReport, reportRange, selectedSections, createGeneralReportPdf, generalReportFilename} from "../services/general-report.js";
import {loadUsageMetrics} from "../services/analytics.js";
import {createAuditReport, type AuditReportKind, type AuditReportRow} from "../services/audit-report.js";
import {enforceRateLimit} from "../services/rate-limit.js";
import {roleOf, type EditorialRole} from "../domain/editorial-auth.js";
import {requireCurrentEditorialUser, requireEditorialRole as requireRole} from "../services/editorial-auth.js";
import {
  catalogEntry,
  loadEditorialCatalogs,
  normalizeCatalogs,
  parseCatalogs,
  type EditorialCatalogs,
} from "../domain/editorial-catalogs.js";
import {
  defaultDarditoParameters,
  normalizeDarditoParameters,
} from "../domain/dardito-parameters.js";
import {
  darditoParametersReference,
  invalidateDarditoParametersCache,
  loadDarditoParameters,
} from "../services/dardito-parameters.js";
import {storyContributionOrigin} from "../domain/public-story.js";
import {extractStoriesFromPdf} from "../services/document-story-extraction.js";

if (getApps().length === 0) initializeApp();

type StoryStatus = "draft" | "in_review" | "published" | "archived";

interface AdminStory {
  id: string;
  title: string;
  summary: string;
  body: string;
  category: string;
  neighborhood: string;
  evidence: string;
  status: StoryStatus;
  period: string;
  readingMinutes: number;
  latitude: number;
  longitude: number;
  keywords: string[];
  sourceName: string;
  sourceUrl: string;
  featured: boolean;
  sources: number;
  images: number;
  sourceResourceId: string;
}

type ResourceKind = "document" | "link" | "image";
type ResourceRights = "pending" | "verified" | "authorized" | "restricted";

interface ResourceInput {
  name: string;
  kind: ResourceKind;
  storyId: string;
  sourceUrl: string;
  rights: ResourceRights;
  notes: string;
}

const statuses: StoryStatus[] = ["draft", "in_review", "published", "archived"];
const editorialRoles: EditorialRole[] = ["reviewer", "editor", "admin"];
const resourceKinds: ResourceKind[] = ["document", "link", "image"];
const resourceRights: ResourceRights[] = ["pending", "verified", "authorized", "restricted"];
const resourceContentTypes = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
]);
const maximumDocumentResourceBytes = 1024 * 1024 * 1024;
const maximumOtherResourceBytes = 20 * 1024 * 1024;
const readRuntime = {region, enforceAppCheck: true};
const writeRuntime = {region, enforceAppCheck: true, consumeAppCheckToken: true};
const resourceWriteRuntime = {
  ...writeRuntime,
  cpu: "gcf_gen1" as const,
};
const monitoringRuntime = {region, enforceAppCheck: true, secrets: [geminiApiKey]};
const extractionRuntime = {
  region,
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  secrets: [geminiApiKey],
  memory: "8GiB" as const,
  cpu: 2,
  timeoutSeconds: 3_600,
  concurrency: 1,
  maxInstances: 1,
};
const reportRuntime = {
  region,
  enforceAppCheck: true,
  consumeAppCheckToken: true,
  memory: "512MiB" as const,
  timeoutSeconds: 120,
};

function normalizeEditorialEmail(value: unknown): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", "El correo es obligatorio.");
  const email = value.trim().toLocaleLowerCase("en-US");
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "El correo no es válido.");
  }
  return email;
}

function accessDocumentId(email: string): string {
  return createHash("sha256").update(`editorial-access:${email}`).digest("hex");
}

function claimsForRole(existing: Record<string, unknown>, role: EditorialRole | null): Record<string, unknown> {
  const claims = {...existing};
  delete claims.admin;
  delete claims.editor;
  delete claims.reviewer;
  delete claims.role;
  if (role) {
    claims.role = role;
    claims[role] = true;
  }
  return claims;
}

async function userByEmail(email: string): Promise<UserRecord | null> {
  try {
    return await getAuth().getUserByEmail(email);
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") return null;
    throw error;
  }
}

async function adminRateLimit(uid: string, action: string, maximum: number, windowMilliseconds = 60_000) {
  try {
    await enforceRateLimit(`admin:${action}:${uid}`, maximum, windowMilliseconds);
  } catch (error) {
    if (error instanceof Error && error.message === "RATE_LIMITED") {
      throw new HttpsError("resource-exhausted", "Demasiadas operaciones. Esperá antes de continuar.");
    }
    throw error;
  }
}

function requiredString(value: unknown, field: string, max: number): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", `${field} es obligatorio.`);
  const normalized = value.replace(/\u0000/g, "").trim();
  if (!normalized || normalized.length > max) {
    throw new HttpsError("invalid-argument", `${field} no cumple la longitud permitida.`);
  }
  return normalized;
}

function optionalString(value: unknown, field: string, max: number): string {
  if (value === undefined || value === null || value === "") return "";
  if (typeof value !== "string") throw new HttpsError("invalid-argument", `${field} es inválido.`);
  const normalized = value.replace(/\u0000/g, "").trim();
  if (normalized.length > max) {
    throw new HttpsError("invalid-argument", `${field} supera la longitud permitida.`);
  }
  return normalized;
}

function optionalHttpsUrl(value: unknown): string {
  const normalized = optionalString(value, "sourceUrl", 1_000);
  if (!normalized) return "";
  try {
    const parsed = new URL(normalized);
    if (parsed.protocol !== "https:") throw new Error("INVALID_PROTOCOL");
    return parsed.toString();
  } catch {
    throw new HttpsError("invalid-argument", "sourceUrl debe ser una URL HTTPS válida.");
  }
}

function resourceHttpsUrl(value: unknown): string {
  const normalized = optionalString(value, "sourceUrl", 1_000);
  if (!normalized) return "";
  try {
    const parsed = new URL(normalized);
    if (parsed.protocol !== "https:") throw new Error("INVALID_PROTOCOL");
    return parsed.toString();
  } catch {
    throw new HttpsError("invalid-argument", "El enlace del recurso debe usar HTTPS.");
  }
}

function parseResourceInput(value: unknown): ResourceInput {
  if (!value || typeof value !== "object") throw new HttpsError("invalid-argument", "El recurso es obligatorio.");
  const input = value as Record<string, unknown>;
  const kind = input.kind as ResourceKind;
  const rights = input.rights as ResourceRights;
  if (!resourceKinds.includes(kind)) throw new HttpsError("invalid-argument", "El tipo de recurso es inválido.");
  if (!resourceRights.includes(rights)) throw new HttpsError("invalid-argument", "El estado de derechos es inválido.");
  const sourceUrl = resourceHttpsUrl(input.sourceUrl);
  if (kind === "link" && !sourceUrl) throw new HttpsError("invalid-argument", "Un enlace debe incluir una URL HTTPS.");
  return {
    name: requiredString(input.name, "name", 180),
    kind,
    storyId: optionalString(input.storyId, "storyId", 120).replace(/[^a-zA-Z0-9_-]/g, "-"),
    sourceUrl,
    rights,
    notes: optionalString(input.notes, "notes", 1_500),
  };
}

function uploadExtension(contentType: string): string {
  const extensions: Record<string, string> = {
    "application/pdf": "pdf",
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
  };
  return extensions[contentType] ?? "bin";
}

async function storyTitle(storyId: string): Promise<string> {
  if (!storyId) return "";
  const snapshot = await getFirestore().collection("knowledge").doc(storyId).get();
  if (!snapshot.exists) throw new HttpsError("invalid-argument", "La historia vinculada no existe.");
  return typeof snapshot.data()?.title === "string" ? snapshot.data()?.title : storyId;
}

async function syncStoryResourceCounts(storyId: string) {
  if (!storyId) return;
  const snapshot = await getFirestore().collection("editorial_resources")
    .where("storyId", "==", storyId)
    .limit(250)
    .get();
  const readyResources = snapshot.docs.filter((document) => document.data().status === "ready");
  const images = readyResources.filter((document) => document.data().kind === "image").length;
  await getFirestore().collection("knowledge").doc(storyId).set({
    images,
    sources: readyResources.length - images,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

interface SubmissionPhoto {
  path: string;
  size: number;
  contentType: "image/jpeg" | "image/png" | "image/webp";
  originalName: string;
}

function submissionPhotos(
  value: unknown,
  submissionId: string,
  userId: string,
): SubmissionPhoto[] {
  if (!Array.isArray(value)) return [];
  if (value.length > 3) {
    throw new HttpsError("failed-precondition", "El aporte supera el máximo de tres fotografías.");
  }
  const prefix = `story_submissions/${userId}/${submissionId}/`;
  return value.map((raw, index) => {
    if (!raw || typeof raw !== "object") {
      throw new HttpsError("failed-precondition", "Una fotografía del aporte tiene metadatos inválidos.");
    }
    const photo = raw as Record<string, unknown>;
    const path = optionalString(photo.path, "photo.path", 500);
    const contentType = optionalString(photo.contentType, "photo.contentType", 80);
    const size = Number(photo.size);
    if (
      !path.startsWith(prefix) ||
      !/^photo_[0-2]\.(jpg|jpeg|png|webp)$/.test(path.slice(prefix.length)) ||
      !["image/jpeg", "image/png", "image/webp"].includes(contentType) ||
      !Number.isInteger(size) || size <= 0 || size > 8 * 1024 * 1024
    ) {
      throw new HttpsError("failed-precondition", "Una fotografía del aporte no supera la validación editorial.");
    }
    const extension = uploadExtension(contentType);
    const originalName = typeof photo.originalName === "string" && photo.originalName.trim()
      ? photo.originalName.replace(/[\u0000-\u001f]/g, "").trim().slice(0, 180)
      : `foto_${index + 1}.${extension}`;
    return {path, size, contentType: contentType as SubmissionPhoto["contentType"], originalName};
  });
}

async function ensureSubmissionMediaLinked(input: {
  submissionId: string;
  knowledgeId: string;
  submission: Record<string, unknown>;
  actor: {uid: string; role: EditorialRole; email?: string};
}): Promise<number> {
  const userId = optionalString(input.submission.userId, "userId", 180).replace(/[^a-zA-Z0-9_-]/g, "");
  if (!userId) throw new HttpsError("failed-precondition", "El aporte no conserva una identidad válida.");
  const photos = submissionPhotos(input.submission.photos, input.submissionId, userId);
  if (!photos.length) {
    await syncStoryResourceCounts(input.knowledgeId);
    return 0;
  }

  const consent = input.submission.consent as Record<string, unknown> | undefined;
  if (consent?.material !== true || consent?.legal !== true) {
    throw new HttpsError("failed-precondition", "No se pueden vincular fotografías sin los consentimientos requeridos.");
  }

  const db = getFirestore();
  const bucket = getStorage().bucket();
  const title = typeof input.submission.title === "string" && input.submission.title.trim()
    ? input.submission.title.trim().slice(0, 120)
    : input.knowledgeId;
  let linked = 0;

  for (const [index, photo] of photos.entries()) {
    const fingerprint = createHash("sha256")
      .update(`${input.submissionId}:${photo.path}`)
      .digest("hex")
      .slice(0, 32);
    const resourceId = `submission-media-${fingerprint}`;
    const resourceReference = db.collection("editorial_resources").doc(resourceId);
    const current = await resourceReference.get();
    if (current.exists && current.data()?.status === "ready" && current.data()?.storyId === input.knowledgeId) {
      linked += 1;
      continue;
    }

    const extension = uploadExtension(photo.contentType);
    const storagePath = `editorial_media/${userId}/${resourceId}/resource.${extension}`;
    const sourceFile = bucket.file(photo.path);
    const [sourceExists] = await sourceFile.exists();
    if (!sourceExists) {
      throw new HttpsError("failed-precondition", `No encontramos la fotografía ${index + 1} en el almacenamiento privado.`);
    }
    const targetFile = bucket.file(storagePath);
    await sourceFile.copy(targetFile);
    await targetFile.setMetadata({
      contentType: photo.contentType,
      metadata: {
        sourceSubmissionId: input.submissionId,
        sourceStoragePath: photo.path,
        importedBy: input.actor.uid,
      },
    });

    const now = FieldValue.serverTimestamp();
    await resourceReference.set({
      id: resourceId,
      name: photo.originalName,
      kind: "image",
      storyId: input.knowledgeId,
      storyTitle: title,
      sourceUrl: "",
      rights: "authorized",
      notes: "Fotografía aportada por la comunidad y vinculada durante la revisión editorial.",
      status: "ready",
      storagePath,
      contentType: photo.contentType,
      sizeBytes: photo.size,
      sourceSubmissionId: input.submissionId,
      sourceStoragePath: photo.path,
      importedPhotoIndex: index,
      createdBy: input.actor.uid,
      updatedBy: input.actor.uid,
      createdAt: current.exists ? current.data()?.createdAt ?? now : now,
      updatedAt: now,
    }, {merge: true});
    await db.collection("editorial_audit").add(auditEntry("resource.imported_from_submission", input.actor, resourceId, {
      submissionId: input.submissionId,
      storyId: input.knowledgeId,
      storagePath,
    }));
    linked += 1;
  }

  await syncStoryResourceCounts(input.knowledgeId);
  return linked;
}

function optionalCount(value: unknown, field: string, max: number): number {
  const numeric = Number(value ?? 0);
  if (!Number.isInteger(numeric) || numeric < 0 || numeric > max) {
    throw new HttpsError("invalid-argument", `${field} es inválido.`);
  }
  return numeric;
}

function coordinate(value: unknown, field: string, min: number, max: number): number {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric < min || numeric > max) {
    throw new HttpsError("invalid-argument", `${field} es inválida.`);
  }
  return numeric;
}

function parseStory(value: unknown, catalogs: EditorialCatalogs): AdminStory {
  if (!value || typeof value !== "object") throw new HttpsError("invalid-argument", "La historia es obligatoria.");
  const input = value as Record<string, unknown>;
  const status = input.status as StoryStatus;
  const category = catalogEntry(catalogs.categories, input.category);
  const neighborhood = catalogEntry(catalogs.neighborhoods, input.neighborhood);
  const evidence = evidenceEntry(input.evidence);
  if (!statuses.includes(status)) throw new HttpsError("invalid-argument", "El estado editorial es inválido.");
  if (!category) throw new HttpsError("invalid-argument", "La categoría no pertenece al catálogo vigente.");
  if (!neighborhood) throw new HttpsError("invalid-argument", "El barrio no pertenece al catálogo vigente.");
  if (!evidence && (typeof input.evidence !== "string" || !/^[a-z0-9_-]{1,80}$/.test(input.evidence))) throw new HttpsError("invalid-argument", "El nivel de evidencia es inválido.");
  const keywords = Array.isArray(input.keywords) ? input.keywords : [];
  if (keywords.length > 24 || !keywords.every((item) => typeof item === "string" && item.trim().length <= 60)) {
    throw new HttpsError("invalid-argument", "Las palabras clave son inválidas.");
  }
  const id = requiredString(input.id, "id", 120).replace(/[^a-zA-Z0-9_-]/g, "-");
  const sourceName = optionalString(input.sourceName, "sourceName", 300);
  if (status === "published" && !sourceName) {
    throw new HttpsError("failed-precondition", "Una historia publicada debe indicar su fuente editorial.");
  }
  return {
    id,
    title: requiredString(input.title, "title", 120),
    summary: requiredString(input.summary, "summary", 420),
    body: requiredString(input.body, "body", 18_000),
    category: category.label,
    neighborhood: neighborhood.label,
    evidence: evidence?.id ?? String(input.evidence),
    status,
    period: requiredString(input.period, "period", 100),
    readingMinutes: optionalCount(input.readingMinutes, "readingMinutes", 60),
    latitude: coordinate(input.latitude, "latitude", -35.25, -34.55),
    longitude: coordinate(input.longitude, "longitude", -58.35, -57.55),
    keywords: keywords.map((item) => String(item).trim().toLocaleLowerCase("es-AR")),
    sourceName,
    sourceUrl: optionalHttpsUrl(input.sourceUrl),
    featured: input.featured === true,
    sources: optionalCount(input.sources, "sources", 250),
    images: optionalCount(input.images, "images", 40),
    sourceResourceId: optionalString(input.sourceResourceId, "sourceResourceId", 160)
      .replace(/[^a-zA-Z0-9_-]/g, ""),
  };
}

function serialize(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>).map(([key, item]) => [key, serialize(item)]));
  }
  return value;
}

interface AuditFilters {
  actorEmail: string;
  action: string;
  dateFrom: Timestamp | null;
  dateTo: Timestamp | null;
}

const auditActions = new Set([
  "knowledge.created",
  "knowledge.updated",
  "knowledge.transitioned",
  "submission.request_info",
  "submission.reject",
  "submission.convert",
  "catalogs.updated",
  "resource.created",
  "resource.uploaded",
  "resource.upload_discarded",
  "resource.updated",
  "resource.deleted",
  "resource.extraction_completed",
  "resource.extraction_failed",
  "session.started",
  "editorial_access.invited",
  "editorial_access.activated",
  "editorial_access.confirmed",
  "editorial_access.role_changed",
  "editorial_access.revoked",
]);

function auditDate(value: unknown, field: string): Timestamp | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string" || value.length > 40) {
    throw new HttpsError("invalid-argument", `${field} es inválida.`);
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new HttpsError("invalid-argument", `${field} es inválida.`);
  return Timestamp.fromDate(date);
}

function auditFilters(value: unknown): AuditFilters {
  const input = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const actorEmail = input.actorEmail ? normalizeEditorialEmail(input.actorEmail) : "";
  const action = optionalString(input.action, "action", 80);
  if (action && !auditActions.has(action)) throw new HttpsError("invalid-argument", "La acción de auditoría no es válida.");
  const dateFrom = auditDate(input.dateFrom, "dateFrom");
  const dateTo = auditDate(input.dateTo, "dateTo");
  if (dateFrom && dateTo && dateFrom.toMillis() > dateTo.toMillis()) {
    throw new HttpsError("invalid-argument", "El rango de fechas no es válido.");
  }
  return {actorEmail, action, dateFrom, dateTo};
}

function filteredAuditQuery(filters: AuditFilters): Query {
  let query: Query = getFirestore().collection("editorial_audit");
  if (filters.actorEmail) query = query.where("actorEmail", "==", filters.actorEmail);
  if (filters.action) query = query.where("action", "==", filters.action);
  if (filters.dateFrom) query = query.where("createdAt", ">=", filters.dateFrom);
  if (filters.dateTo) query = query.where("createdAt", "<=", filters.dateTo);
  return query;
}

function auditCursor(value: unknown): {createdAt: Timestamp; id: string} | null {
  if (!value || typeof value !== "object") return null;
  const input = value as Record<string, unknown>;
  const id = optionalString(input.id, "cursor.id", 180);
  const createdAt = auditDate(input.createdAt, "cursor.createdAt");
  if (!id || !createdAt) throw new HttpsError("invalid-argument", "El cursor de paginación no es válido.");
  return {id, createdAt};
}

function reportPeriodStart(period: unknown): {start: Timestamp; label: string} {
  const now = new Date();
  if (period === "today") {
    const argentina = new Date(now.getTime() - 3 * 60 * 60 * 1000);
    const start = new Date(Date.UTC(argentina.getUTCFullYear(), argentina.getUTCMonth(), argentina.getUTCDate(), 3));
    return {start: Timestamp.fromDate(start), label: "Hoy"};
  }
  const periods: Record<string, {days: number; label: string}> = {
    week: {days: 7, label: "Últimos 7 días"},
    "15days": {days: 15, label: "Últimos 15 días"},
    month: {days: 30, label: "Últimos 30 días"},
  };
  const selected = typeof period === "string" ? periods[period] : undefined;
  if (!selected) throw new HttpsError("invalid-argument", "El período del informe no es válido.");
  return {start: Timestamp.fromMillis(now.getTime() - selected.days * 24 * 60 * 60 * 1000), label: selected.label};
}

function auditRow(document: {id: string; data(): DocumentData}): AuditReportRow {
  const data = document.data();
  const createdAt = data.createdAt instanceof Timestamp ? data.createdAt.toDate().toISOString() : "";
  return {
    action: String(data.action ?? "unknown"),
    actorEmail: String(data.actorEmail ?? ""),
    actorRole: String(data.actorRole ?? ""),
    target: String(data.target ?? document.id),
    createdAt,
  };
}

function auditEntry(action: string, actor: {uid: string; role: EditorialRole; email?: string}, target: string, details: Record<string, unknown> = {}) {
  return {
    action,
    actorId: actor.uid,
    actorRole: actor.role,
    actorEmail: actor.email ?? null,
    target,
    details,
    createdAt: FieldValue.serverTimestamp(),
  };
}

async function serviceProbe(
  id: string,
  name: string,
  operation: () => Promise<string>,
): Promise<Record<string, unknown>> {
  const startedAt = Date.now();
  try {
    const detail = await operation();
    return {id, name, status: "online", detail, latencyMs: Date.now() - startedAt};
  } catch (error) {
    return {
      id,
      name,
      status: "offline",
      detail: error instanceof Error ? error.message.slice(0, 180) : "Comprobación fallida",
      latencyMs: Date.now() - startedAt,
    };
  }
}

export const adminListKnowledge = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "list-knowledge", 120);
  const input = request.data && typeof request.data === "object" ? request.data as Record<string, unknown> : {};
  const status = typeof input.status === "string" && statuses.includes(input.status as StoryStatus) ? input.status as StoryStatus : null;
  const search = typeof input.search === "string" ? input.search.trim().toLocaleLowerCase("es-AR").slice(0, 120) : "";
  const snapshot = await getFirestore().collection("knowledge").limit(250).get();
  const items = snapshot.docs.map((document) => {
    const data = document.data();
    return {
      id: document.id,
      ...data,
      contributionOrigin: storyContributionOrigin(data),
    };
  }).filter((item) => {
    const data = item as Record<string, unknown>;
    if (status && data.status !== status) return false;
    if (!search) return true;
    return `${data.title ?? ""} ${data.category ?? ""} ${data.neighborhood ?? ""}`.toLocaleLowerCase("es-AR").includes(search);
  }).sort((a, b) => {
    const left = (a as Record<string, unknown>).updatedAt;
    const right = (b as Record<string, unknown>).updatedAt;
    const leftMillis = left instanceof Timestamp ? left.toMillis() : 0;
    const rightMillis = right instanceof Timestamp ? right.toMillis() : 0;
    return rightMillis - leftMillis;
  });
  return {items: serialize(items)};
});

export const adminGetKnowledge = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "get-knowledge", 120);
  const id = requiredString((request.data as Record<string, unknown> | undefined)?.id, "id", 120);
  const snapshot = await getFirestore().collection("knowledge").doc(id).get();
  if (!snapshot.exists) throw new HttpsError("not-found", "La historia no existe.");
  const data = snapshot.data() ?? {};
  return {item: serialize({
    id: snapshot.id,
    ...data,
    contributionOrigin: storyContributionOrigin(data),
  })};
});

export const adminSaveKnowledge = onCall(resourceWriteRuntime, async (request) => {
  const actor = await requireRole(request, ["editor", "admin"]);
  // Editorial sessions often involve importing or correcting many stories in
  // succession. Keep a per-user ceiling, but do not lock out a legitimate
  // working session after only a few minutes of sustained editing.
  await adminRateLimit(actor.uid, "save-knowledge", 120, 15 * 60_000);
  const catalogs = await loadEditorialCatalogs();
  const item = parseStory(request.data, catalogs);
  if (item.status === "published" && actor.role !== "admin") {
    throw new HttpsError("permission-denied", "Solo un admin puede publicar.");
  }
  const db = getFirestore();
  const sourceResource = item.sourceResourceId
    ? await db.collection("editorial_resources").doc(item.sourceResourceId).get()
    : null;
  if (sourceResource && (!sourceResource.exists || sourceResource.data()?.kind !== "document" || sourceResource.data()?.status !== "ready")) {
    throw new HttpsError("failed-precondition", "El documento de origen ya no está disponible para esta historia.");
  }
  const reference = db.collection("knowledge").doc(item.id);
  const versionReference = reference.collection("versions").doc();
  const auditReference = db.collection("editorial_audit").doc();
  let nextRevision = 1;
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(reference);
    const contributionOrigin = current.exists
      ? storyContributionOrigin(current.data() ?? {})
      : "dardito_team";
    const stored = current.data() ?? {};
    if (!evidenceEntry(item.evidence) && item.evidence !== stored.evidence) throw new HttpsError("invalid-argument", "El nivel de evidencia no pertenece al catálogo vigente.");
    const submission = typeof stored.sourceSubmissionId === "string" && stored.sourceSubmissionId
      ? await transaction.get(db.collection("story_submissions").doc(stored.sourceSubmissionId)) : null;
    const attribution = resolveAttribution(request.data, stored, submission?.data(), actor.role);
    // Preserve a legacy evidence value when its visible classification is unchanged.
    const savedEvidence = typeof stored.evidence === "string" && evidenceEntry(stored.evidence)?.id === item.evidence
      ? stored.evidence : item.evidence;
    nextRevision = Number(current.data()?.revision ?? 0) + 1;
    if (current.exists) {
      transaction.create(versionReference, {
        revision: Number(current.data()?.revision ?? 0),
        snapshot: current.data(),
        replacedBy: actor.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.set(reference, {
      ...item,
      evidence: savedEvidence,
      ...attribution,
      contributionOrigin,
      revision: nextRevision,
      updatedBy: actor.uid,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: current.exists ? current.data()?.createdAt ?? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
      publishedAt: item.status === "published" ? current.data()?.publishedAt ?? FieldValue.serverTimestamp() : null,
    }, {merge: true});
    transaction.create(auditReference, auditEntry(current.exists ? "knowledge.updated" : "knowledge.created", actor, item.id, {
      revision: nextRevision,
      status: item.status,
      contributionOrigin,
    }));
  });
  if (sourceResource) {
    await sourceResource.ref.update({
      derivedStoryIds: FieldValue.arrayUnion(item.id),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    });
  }
  return {id: item.id, revision: nextRevision};
});

export const adminExtractDocumentStories = onCall(extractionRuntime, async (request) => {
  const actor = await requireRole(request, ["editor", "admin"]);
  // La versión anterior contabilizó intentos fallidos durante la puesta en marcha.
  // El namespace versionado renueva ese cupo y permite reintentos humanos sin
  // dejar abierta una vía de consumo ilimitado del proveedor.
  await adminRateLimit(actor.uid, "extract-document-stories-v3", 8, 60 * 60_000);
  const resourceId = requiredString(
    (request.data as Record<string, unknown> | undefined)?.resourceId,
    "resourceId",
    160,
  );
  const db = getFirestore();
  const resource = await db.collection("editorial_resources").doc(resourceId).get();
  if (!resource.exists) throw new HttpsError("not-found", "El documento no existe.");
  const data = resource.data() ?? {};
  const storagePath = requiredString(data.storagePath, "storagePath", 500);
  if (
    data.kind !== "document" ||
    data.status !== "ready" ||
    data.contentType !== "application/pdf" ||
    !storagePath.startsWith("editorial_media/") ||
    Number(data.sizeBytes ?? 0) < 1 ||
    Number(data.sizeBytes ?? 0) > maximumDocumentResourceBytes
  ) {
    throw new HttpsError("failed-precondition", "El recurso seleccionado no es un PDF disponible para extracción.");
  }
  const extractionId = db.collection("_ids").doc().id;
  const auditReference = db.collection("editorial_audit").doc();
  try {
    const catalogs = await loadEditorialCatalogs();
    const stories = await extractStoriesFromPdf({
      file: getStorage().bucket().file(storagePath),
      resourceId,
      resourceName: requiredString(data.name, "resourceName", 180),
      originalFileName: optionalString(data.originalFileName, "originalFileName", 180),
      sizeBytes: Number(data.sizeBytes),
      catalogs,
      extractionId,
    });
    await auditReference.create(auditEntry("resource.extraction_completed", actor, resourceId, {
      extractionId,
      stories: stories.length,
      sizeBytes: Number(data.sizeBytes),
    }));
    return {extractionId, resourceId, stories};
  } catch (error) {
    const reason = error instanceof Error ? error.message.slice(0, 1_000) : "UNKNOWN";
    logger.error("Falló la extracción editorial de un PDF.", {
      resourceId,
      extractionId,
      sizeBytes: Number(data.sizeBytes ?? 0),
      reason,
    });
    await auditReference.create(auditEntry("resource.extraction_failed", actor, resourceId, {
      extractionId,
      reason: reason.slice(0, 300),
    })).catch(() => undefined);
    if (error instanceof HttpsError) throw error;
    const message = reason;
    if (message.includes("429") || message.includes("RESOURCE_EXHAUSTED")) {
      throw new HttpsError("resource-exhausted", "El servicio de análisis está ocupado. Intentá nuevamente más tarde.");
    }
    if (message.includes("50MB") || message.includes("file size") || message.includes("too large")) {
      throw new HttpsError("failed-precondition", "El proveedor no pudo procesar el tamaño o la estructura de este PDF.");
    }
    if (
      message.includes("DOCUMENT_PDF_NORMALIZATION_FAILED") ||
      message.includes("DOCUMENT_PAGE_TOO_LARGE") ||
      message.includes("DOCUMENT_WITHOUT_PAGES")
    ) {
      throw new HttpsError("failed-precondition", "El PDF está cifrado, dañado o contiene una página demasiado grande para analizar.");
    }
    throw new HttpsError("internal", "No fue posible analizar el documento. El archivo original no fue modificado.");
  }
});

export const adminListResources = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "list-resources", 90);
  const snapshot = await getFirestore().collection("editorial_resources").limit(500).get();
  const items = snapshot.docs
    .map((document) => ({id: document.id, ...document.data()}))
    .sort((left, right) => {
      const leftValue = (left as Record<string, unknown>).updatedAt;
      const rightValue = (right as Record<string, unknown>).updatedAt;
      return (rightValue instanceof Timestamp ? rightValue.toMillis() : 0) -
        (leftValue instanceof Timestamp ? leftValue.toMillis() : 0);
    });
  return {items: serialize(items)};
});

export const adminCreateResource = onCall(resourceWriteRuntime, async (request) => {
  const actor = await requireRole(request, ["editor", "admin"]);
  await adminRateLimit(actor.uid, "create-resource", 30, 15 * 60_000);
  const input = request.data && typeof request.data === "object" ? request.data as Record<string, unknown> : {};
  const resource = parseResourceInput(input);
  const fileInput = input.file && typeof input.file === "object" ? input.file as Record<string, unknown> : null;
  if (resource.kind === "link" && fileInput) throw new HttpsError("invalid-argument", "Un enlace no puede incluir un archivo.");
  if (resource.kind !== "link" && !fileInput) throw new HttpsError("invalid-argument", "Seleccioná el archivo del recurso.");

  let file: {name: string; size: number; contentType: string} | null = null;
  if (fileInput) {
    const contentType = requiredString(fileInput.contentType, "contentType", 100).toLocaleLowerCase("en-US");
    const size = Number(fileInput.size);
    const maximumBytes = contentType === "application/pdf" ? maximumDocumentResourceBytes : maximumOtherResourceBytes;
    if (!resourceContentTypes.has(contentType) || !Number.isInteger(size) || size < 1 || size > maximumBytes) {
      throw new HttpsError("invalid-argument", "El archivo no cumple el tipo o peso permitido.");
    }
    if (resource.kind === "image" && !contentType.startsWith("image/") ||
      resource.kind === "document" && contentType !== "application/pdf") {
      throw new HttpsError("invalid-argument", "El archivo no corresponde al tipo de recurso seleccionado.");
    }
    file = {name: requiredString(fileInput.name, "fileName", 180), size, contentType};
  }

  const db = getFirestore();
  const reference = db.collection("editorial_resources").doc();
  const linkedStoryTitle = await storyTitle(resource.storyId);
  const storagePath = file
    ? `editorial_media/${actor.uid}/${reference.id}/resource.${uploadExtension(file.contentType)}`
    : "";
  const now = FieldValue.serverTimestamp();
  await Promise.all([
    reference.create({
      ...resource,
      storyTitle: linkedStoryTitle,
      status: file ? "uploading" : "ready",
      storagePath,
      originalFileName: file?.name ?? "",
      contentType: file?.contentType ?? "",
      sizeBytes: file?.size ?? 0,
      createdBy: actor.uid,
      createdByEmail: actor.email,
      updatedBy: actor.uid,
      createdAt: now,
      updatedAt: now,
    }),
    db.collection("editorial_audit").add(auditEntry("resource.created", actor, reference.id, {
      kind: resource.kind,
      storyId: resource.storyId || null,
      hasFile: file !== null,
    })),
  ]);
  if (!file) await syncStoryResourceCounts(resource.storyId);
  return {id: reference.id, storagePath, requiresUpload: file !== null};
});

export const adminFinalizeResource = onCall(resourceWriteRuntime, async (request) => {
  const actor = await requireRole(request, ["editor", "admin"]);
  await adminRateLimit(actor.uid, "finalize-resource", 30, 15 * 60_000);
  const id = requiredString((request.data as Record<string, unknown> | undefined)?.id, "id", 160);
  const db = getFirestore();
  const reference = db.collection("editorial_resources").doc(id);
  const snapshot = await reference.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "El recurso no existe.");
  const data = snapshot.data() ?? {};
  if (data.createdBy !== actor.uid && actor.role !== "admin") throw new HttpsError("permission-denied", "No podés finalizar este recurso.");
  if (data.status === "ready") return {id, status: "ready"};
  const storagePath = requiredString(data.storagePath, "storagePath", 500);
  const [metadata] = await getStorage().bucket().file(storagePath).getMetadata();
  const actualSize = Number(metadata.size ?? 0);
  const actualType = String(metadata.contentType ?? "");
  const maximumBytes = actualType === "application/pdf" ? maximumDocumentResourceBytes : maximumOtherResourceBytes;
  if (actualSize !== Number(data.sizeBytes) || actualType !== data.contentType || actualSize > maximumBytes) {
    await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
    await reference.update({status: "rejected", updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.uid});
    throw new HttpsError("failed-precondition", "El archivo cargado no coincide con los datos validados.");
  }
  await Promise.all([
    reference.update({status: "ready", updatedAt: FieldValue.serverTimestamp(), updatedBy: actor.uid}),
    db.collection("editorial_audit").add(auditEntry("resource.uploaded", actor, id, {storyId: data.storyId ?? null})),
  ]);
  await syncStoryResourceCounts(typeof data.storyId === "string" ? data.storyId : "");
  return {id, status: "ready"};
});

export const adminDiscardResourceUpload = onCall(resourceWriteRuntime, async (request) => {
  const actor = await requireRole(request, ["editor", "admin"]);
  await adminRateLimit(actor.uid, "discard-resource-upload", 30, 15 * 60_000);
  const id = requiredString((request.data as Record<string, unknown> | undefined)?.id, "id", 160);
  const db = getFirestore();
  const reference = db.collection("editorial_resources").doc(id);
  const snapshot = await reference.get();
  if (!snapshot.exists) return {id};
  const data = snapshot.data() ?? {};
  if (data.status === "ready") throw new HttpsError("failed-precondition", "Un recurso incorporado no se descarta como carga incompleta.");
  if (data.createdBy !== actor.uid && actor.role !== "admin") throw new HttpsError("permission-denied", "No podés descartar esta carga.");
  const storagePath = typeof data.storagePath === "string" ? data.storagePath : "";
  if (storagePath) await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
  await Promise.all([
    reference.delete(),
    db.collection("editorial_audit").add(auditEntry("resource.upload_discarded", actor, id)),
  ]);
  return {id};
});

export const adminUpdateResource = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["editor", "admin"]);
  await adminRateLimit(actor.uid, "update-resource", 40, 15 * 60_000);
  const input = request.data && typeof request.data === "object" ? request.data as Record<string, unknown> : {};
  const id = requiredString(input.id, "id", 160);
  const resource = parseResourceInput(input);
  const db = getFirestore();
  const reference = db.collection("editorial_resources").doc(id);
  const current = await reference.get();
  if (!current.exists) throw new HttpsError("not-found", "El recurso no existe.");
  const currentData = current.data() ?? {};
  if (currentData.kind !== resource.kind) throw new HttpsError("failed-precondition", "El tipo de un recurso existente no se puede cambiar.");
  const linkedStoryTitle = await storyTitle(resource.storyId);
  await Promise.all([
    reference.update({...resource, storyTitle: linkedStoryTitle, updatedBy: actor.uid, updatedAt: FieldValue.serverTimestamp()}),
    db.collection("editorial_audit").add(auditEntry("resource.updated", actor, id, {
      beforeStoryId: currentData.storyId ?? null,
      storyId: resource.storyId || null,
      rights: resource.rights,
    })),
  ]);
  await Promise.all([
    syncStoryResourceCounts(typeof currentData.storyId === "string" ? currentData.storyId : ""),
    syncStoryResourceCounts(resource.storyId),
  ]);
  return {id};
});

export const adminDeleteResource = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "delete-resource", 20, 60 * 60_000);
  const id = requiredString((request.data as Record<string, unknown> | undefined)?.id, "id", 160);
  const db = getFirestore();
  const reference = db.collection("editorial_resources").doc(id);
  const snapshot = await reference.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "El recurso no existe.");
  const data = snapshot.data() ?? {};
  const storagePath = typeof data.storagePath === "string" ? data.storagePath : "";
  if (storagePath) await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
  await Promise.all([
    reference.delete(),
    db.collection("editorial_audit").add(auditEntry("resource.deleted", actor, id, {
      name: data.name ?? null,
      storyId: data.storyId ?? null,
    })),
  ]);
  await syncStoryResourceCounts(typeof data.storyId === "string" ? data.storyId : "");
  return {id};
});

export const adminTransitionKnowledge = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "transition-knowledge", 30, 15 * 60_000);
  const input = request.data as Record<string, unknown> | undefined;
  const id = requiredString(input?.id, "id", 120);
  const status = input?.status as StoryStatus;
  if (!statuses.includes(status)) throw new HttpsError("invalid-argument", "Estado inválido.");
  if ((status === "published" || status === "archived") && actor.role !== "admin") {
    throw new HttpsError("permission-denied", "Solo un admin puede publicar o archivar.");
  }
  if (status === "draft" && actor.role === "reviewer") {
    throw new HttpsError("permission-denied", "Un reviewer no puede reabrir borradores.");
  }
  const db = getFirestore();
  const reference = db.collection("knowledge").doc(id);
  const auditReference = db.collection("editorial_audit").doc();
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(reference);
    if (!current.exists) throw new HttpsError("not-found", "La historia no existe.");
    const stored = current.data() ?? {};
    const submission = typeof stored.sourceSubmissionId === "string" && stored.sourceSubmissionId
      ? await transaction.get(db.collection("story_submissions").doc(stored.sourceSubmissionId)) : null;
    const attribution = resolveAttribution(input ?? {}, stored, submission?.data(), actor.role);
    transaction.update(reference, {
      ...attribution,
      status,
      updatedBy: actor.uid,
      updatedAt: FieldValue.serverTimestamp(),
      publishedAt: status === "published" ? current.data()?.publishedAt ?? FieldValue.serverTimestamp() : current.data()?.publishedAt ?? null,
    });
    transaction.create(auditReference, auditEntry("knowledge.transitioned", actor, id, {from: current.data()?.status ?? null, to: status}));
  });
  return {id, status};
});

export const adminListSubmissions = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "list-submissions", 90);
  const snapshot = await getFirestore().collection("story_submissions").limit(150).get();
  const items = snapshot.docs.map((document) => ({id: document.id, ...document.data()})).sort((a, b) => {
    const left = (a as Record<string, unknown>).createdAt;
    const right = (b as Record<string, unknown>).createdAt;
    return (right instanceof Timestamp ? right.toMillis() : 0) - (left instanceof Timestamp ? left.toMillis() : 0);
  });
  return {items: serialize(items)};
});

export const adminReviewSubmission = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "review-submission", 30, 15 * 60_000);
  const input = request.data as Record<string, unknown> | undefined;
  const id = requiredString(input?.id, "id", 160);
  const decision = input?.decision;
  if (!["request_info", "reject", "convert"].includes(String(decision))) {
    throw new HttpsError("invalid-argument", "Decisión inválida.");
  }
  if (decision === "convert" && actor.role === "reviewer") {
    throw new HttpsError("permission-denied", "Un reviewer no puede crear borradores editoriales.");
  }
  const note = typeof input?.note === "string" ? input.note.trim().slice(0, 1200) : "";
  const db = getFirestore();
  const catalogs = await loadEditorialCatalogs();
  const submissionReference = db.collection("story_submissions").doc(id);
  const auditReference = db.collection("editorial_audit").doc();
  let knowledgeId: string | null = null;
  let submissionData: Record<string, unknown> = {};
  await db.runTransaction(async (transaction) => {
    const submission = await transaction.get(submissionReference);
    if (!submission.exists) throw new HttpsError("not-found", "El aporte no existe.");
    const data = submission.data() ?? {};
    submissionData = data;
    if (decision === "convert") {
      knowledgeId = `aporte-${id}`.replace(/[^a-zA-Z0-9_-]/g, "-").slice(0, 120);
      const knowledgeReference = db.collection("knowledge").doc(knowledgeId);
      const existingKnowledge = await transaction.get(knowledgeReference);
      if (existingKnowledge.exists && existingKnowledge.data()?.sourceSubmissionId !== id) {
        throw new HttpsError("already-exists", "Ya existe otro borrador con este identificador.");
      }
      if (!existingKnowledge.exists) {
        transaction.create(knowledgeReference, {
          id: knowledgeId,
          title: data.title ?? "Aporte sin título",
          summary: "Pendiente de edición.",
          body: data.story ?? "",
          category: data.category ?? "Memoria viva",
          neighborhood: data.neighborhood ?? "Sin clasificar",
          evidence: typeof data.evidence === "string" && data.evidence.trim() ? data.evidence : "community",
          period: typeof data.period === "string" && data.period.trim()
            ? data.period.trim().slice(0, 100)
            : "Sin determinar",
          status: "draft",
          keywords: [],
          sources: 0,
          images: 0,
          sourceSubmissionId: id,
          contributionOrigin: "community",
          revision: 1,
          createdBy: actor.uid,
          updatedBy: actor.uid,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(knowledgeReference, {contributionOrigin: "community"}, {merge: true});
      }
    }
    const status = decision === "request_info" ? "needs_info" : decision === "reject" ? "rejected" : "converted";
    transaction.update(submissionReference, {status, reviewNote: note || null, reviewedBy: actor.uid, reviewedAt: FieldValue.serverTimestamp(), knowledgeId});
    transaction.create(auditReference, auditEntry(`submission.${decision}`, actor, id, {knowledgeId, note: note || null}));
  });
  let linkedMedia = 0;
  if (decision === "convert" && knowledgeId) {
    linkedMedia = await ensureSubmissionMediaLinked({
      submissionId: id,
      knowledgeId,
      submission: submissionData,
      actor,
    });
  }
  return {id, decision, knowledgeId, linkedMedia};
});

export const adminGetCatalogs = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "get-catalogs", 90);
  return {catalogs: await loadEditorialCatalogs()};
});

export const adminSaveCatalogs = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "save-catalogs", 20, 60 * 60_000);
  const catalogs = parseCatalogs(request.data);
  const db = getFirestore();
  const reference = db.collection("editorial_config").doc("catalogs");
  const currentSnapshot = await reference.get();
  const current = normalizeCatalogs(currentSnapshot.data());
  const removed = {
    categories: current.categories.filter((entry) => !catalogs.categories.some((next) => next.id === entry.id)),
    neighborhoods: current.neighborhoods.filter((entry) => !catalogs.neighborhoods.some((next) => next.id === entry.id)),
    evidenceLevels: current.evidenceLevels.filter((entry) => !catalogs.evidenceLevels.some((next) => next.id === entry.id)),
  };
  const renamed = {
    categories: current.categories.flatMap((entry) => {
      const next = catalogs.categories.find((candidate) => candidate.id === entry.id);
      return next && next.label !== entry.label ? [{before: entry, after: next}] : [];
    }),
    neighborhoods: current.neighborhoods.flatMap((entry) => {
      const next = catalogs.neighborhoods.find((candidate) => candidate.id === entry.id);
      return next && next.label !== entry.label ? [{before: entry, after: next}] : [];
    }),
  };
  const structureChanged = removed.categories.length || removed.neighborhoods.length || removed.evidenceLevels.length || renamed.categories.length || renamed.neighborhoods.length;
  let documents: Array<{reference: FirebaseFirestore.DocumentReference; data: FirebaseFirestore.DocumentData}> = [];
  if (structureChanged) {
    const [knowledge, submissions] = await Promise.all([
      db.collection("knowledge").limit(500).get(),
      db.collection("story_submissions").limit(500).get(),
    ]);
    documents = [...knowledge.docs, ...submissions.docs].map((document) => ({reference: document.ref, data: document.data()}));
    const inUse = documents.some(({data}) =>
      removed.categories.some((entry) => catalogEntry([entry], data.category) !== null) ||
      removed.neighborhoods.some((entry) => catalogEntry([entry], data.neighborhood) !== null) ||
      removed.evidenceLevels.some((entry) => catalogEntry([entry], data.evidence) !== null),
    );
    if (inUse) {
      throw new HttpsError(
        "failed-precondition",
        "No se puede quitar un valor que todavía está usado por historias o aportes.",
      );
    }
  }
  const cascadeUpdates = documents.flatMap(({reference: documentReference, data}) => {
    const changes: Record<string, unknown> = {};
    const categoryRename = renamed.categories.find(({before}) => catalogEntry([before], data.category) !== null);
    const neighborhoodRename = renamed.neighborhoods.find(({before}) => catalogEntry([before], data.neighborhood) !== null);
    if (categoryRename) changes.category = categoryRename.after.label;
    if (neighborhoodRename) changes.neighborhood = neighborhoodRename.after.label;
    return Object.keys(changes).length ? [{reference: documentReference, changes}] : [];
  });
  for (let offset = 0; offset < cascadeUpdates.length; offset += 400) {
    const batch = db.batch();
    for (const update of cascadeUpdates.slice(offset, offset + 400)) {
      batch.update(update.reference, {...update.changes, updatedAt: FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }
  await Promise.all([
    reference.set({...catalogs, schemaVersion: 2, updatedBy: actor.uid, updatedAt: FieldValue.serverTimestamp()}),
    db.collection("editorial_audit").add(auditEntry("catalogs.updated", actor, "catalogs", {before: current, after: catalogs})),
  ]);
  return {catalogs};
});

export const adminGetDarditoParameters = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "get-dardito-parameters", 90);
  return {parameters: await loadDarditoParameters()};
});

export const adminSaveDarditoParameters = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "save-dardito-parameters", 30, 60 * 60_000);
  const parameters = normalizeDarditoParameters(request.data?.parameters);
  const reference = darditoParametersReference();
  const auditReference = getFirestore().collection("editorial_audit").doc();
  const previousSnapshot = await reference.get();
  const previous = previousSnapshot.exists
    ? normalizeDarditoParameters(previousSnapshot.data())
    : defaultDarditoParameters;

  await getFirestore().runTransaction(async (transaction) => {
    transaction.set(reference, {
      ...parameters,
      schemaVersion: 1,
      updatedBy: actor.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(auditReference, auditEntry(
      "dardito.parameters.updated",
      actor,
      "dardito_parameters",
      {before: previous, after: parameters},
    ));
  });
  invalidateDarditoParametersCache();
  return {parameters};
});

export const adminListAudit = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "list-audit", 60);
  const snapshot = await getFirestore().collection("editorial_audit").orderBy("createdAt", "desc").limit(100).get();
  const items = snapshot.docs
    .map((document) => ({id: document.id, ...document.data()}) as Record<string, unknown>);
  return {items: serialize(items)};
});

export const adminQueryAudit = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "query-audit", 90);
  const input = request.data && typeof request.data === "object" ? request.data as Record<string, unknown> : {};
  const filters = auditFilters(input.filters);
  const cursor = auditCursor(input.cursor);
  const requestedPageSize = typeof input.pageSize === "number" && Number.isInteger(input.pageSize) ? input.pageSize : 25;
  const pageSize = Math.min(Math.max(requestedPageSize, 1), 25);

  const baseQuery = filteredAuditQuery(filters);
  let pageQuery = baseQuery
    .orderBy("createdAt", "desc")
    .orderBy(FieldPath.documentId(), "desc");
  if (cursor) pageQuery = pageQuery.startAfter(cursor.createdAt, cursor.id);

  const [snapshot, countSnapshot] = await Promise.all([
    pageQuery.limit(pageSize + 1).get(),
    baseQuery.count().get(),
  ]);
  const pageDocuments = snapshot.docs.slice(0, pageSize);
  const last = pageDocuments.at(-1);
  const lastCreatedAt = last?.data().createdAt;
  const nextCursor = snapshot.size > pageSize && last && lastCreatedAt instanceof Timestamp ? {
    id: last.id,
    createdAt: lastCreatedAt.toDate().toISOString(),
  } : null;

  return {
    items: serialize(pageDocuments.map((document) => ({id: document.id, ...document.data()}))),
    total: countSnapshot.data().count,
    pageSize,
    hasMore: nextCursor !== null,
    nextCursor,
  };
});

export const adminExportAuditReport = onCall(reportRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "export-audit-report", 5, 10 * 60_000);
  const input = request.data && typeof request.data === "object" ? request.data as Record<string, unknown> : {};
  const kind = input.kind as AuditReportKind;
  if (!["filtered", "stories_by_user", "approvals_by_user"].includes(kind)) {
    throw new HttpsError("invalid-argument", "El tipo de informe no es válido.");
  }

  let rows: AuditReportRow[] = [];
  let ranking: Array<{email: string; count: number}> = [];
  let total = 0;
  let title = "Informe general de auditoría";
  let subtitle = "Movimientos administrativos según los filtros seleccionados.";
  let filtersLabel = "Sin filtros";

  if (kind === "filtered") {
    const filters = auditFilters(input.filters);
    const query = filteredAuditQuery(filters).orderBy("createdAt", "desc").limit(2_500);
    const [snapshot, countSnapshot] = await Promise.all([query.get(), filteredAuditQuery(filters).count().get()]);
    rows = snapshot.docs.map(auditRow);
    total = countSnapshot.data().count;
    const labels = [
      filters.actorEmail ? `Usuario: ${filters.actorEmail}` : "",
      filters.action ? `Acción: ${filters.action}` : "",
      filters.dateFrom ? `Desde: ${filters.dateFrom.toDate().toLocaleDateString("es-AR")}` : "",
      filters.dateTo ? `Hasta: ${filters.dateTo.toDate().toLocaleDateString("es-AR")}` : "",
    ].filter(Boolean);
    filtersLabel = labels.join(" · ") || "Todos los movimientos";
    if (total > rows.length) subtitle += ` Se detallan los ${rows.length} movimientos más recientes de ${total}.`;
  } else {
    const period = reportPeriodStart(input.period);
    const action = kind === "stories_by_user" ? "knowledge.created" : "submission.convert";
    const snapshot = await getFirestore().collection("editorial_audit")
      .where("action", "==", action)
      .where("createdAt", ">=", period.start)
      .orderBy("createdAt", "desc")
      .limit(5_000)
      .get();
    const counts = new Map<string, number>();
    for (const document of snapshot.docs) {
      const email = String(document.data().actorEmail ?? "Sistema").trim() || "Sistema";
      counts.set(email, (counts.get(email) ?? 0) + 1);
    }
    ranking = [...counts.entries()]
      .map(([email, count]) => ({email, count}))
      .sort((left, right) => right.count - left.count || left.email.localeCompare(right.email));
    total = snapshot.size;
    filtersLabel = period.label;
    if (kind === "stories_by_user") {
      title = "Historias creadas por usuario";
      subtitle = "Participación editorial en la creación de historias del corpus.";
    } else {
      title = "Aportes aprobados por usuario";
      subtitle = "Decisiones editoriales que incorporaron aportes de la comunidad al corpus.";
    }
  }

  const buffer = await createAuditReport({
    kind,
    title,
    subtitle,
    generatedBy: actor.email,
    filtersLabel,
    rows,
    ranking,
    total,
  });
  const stamp = new Date().toISOString().slice(0, 10);
  return {
    filename: `auditoria-mapa-historias-${kind}-${stamp}.pdf`,
    contentType: "application/pdf",
    base64: buffer.toString("base64"),
    size: buffer.length,
  };
});

export const adminGetInfrastructureStatus = onCall(monitoringRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "infrastructure-status", 30);
  const db = getFirestore();
  const services = await Promise.all([
    serviceProbe("admin-api", "API administrativa", async () => "Callable autenticada y App Check válido"),
    serviceProbe("firestore", "Base de datos Firestore", async () => {
      await db.collection("editorial_config").limit(1).get();
      return "Lectura operativa";
    }),
    serviceProbe("authentication", "Firebase Authentication", async () => {
      const user = await getAuth().getUser(actor.uid);
      return user.disabled ? "Cuenta administrativa deshabilitada" : "Identidad y roles operativos";
    }),
    serviceProbe("storage", "Firebase Storage", async () => {
      const [metadata] = await getStorage().bucket().getMetadata();
      return `Bucket ${metadata.name ?? "principal"} accesible`;
    }),
    serviceProbe("public-corpus", "Servicio público de historias", async () => {
      const snapshot = await db.collection("knowledge").where("status", "==", "published").limit(250).get();
      return `${snapshot.size} historias publicadas disponibles`;
    }),
    serviceProbe("submissions", "Recepción de aportes", async () => {
      await db.collection("story_submissions").limit(1).get();
      return "Colección de aportes accesible";
    }),
    serviceProbe("dardito-chat", "Servicio conversacional de Dardito", async () => {
      if (geminiApiKey.value().trim().length < 20) throw new Error("Proveedor conversacional sin credencial activa");
      return "Proveedor configurado; secreto protegido";
    }),
  ]);
  const offline = services.filter((item) => item.status === "offline").length;
  return {
    checkedAt: new Date().toISOString(),
    overall: offline === 0 ? "online" : offline < services.length ? "degraded" : "offline",
    services,
  };
});

export const adminGetUsageMetrics = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "usage-metrics", 30);
  return loadUsageMetrics(30);
});

export const adminRegisterSession = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["reviewer", "editor", "admin"]);
  await adminRateLimit(actor.uid, "register-session", 120, 60 * 60_000);
  const userAgent = String(request.rawRequest.headers["user-agent"] ?? "").slice(0, 500);
  await getFirestore().collection("editorial_audit").add(auditEntry("session.started", actor, actor.email || actor.uid, {userAgent}));
  return {registered: true};
});

export const activateEditorialAccess = onCall(writeRuntime, async (request) => {
  const user = await requireCurrentEditorialUser(request);
  await adminRateLimit(user.uid, "activate-access", 8, 60 * 60_000);
  const email = normalizeEditorialEmail(user.email);
  const accessId = accessDocumentId(email);
  const accessReference = getFirestore().collection("editorial_users").doc(accessId);
  const access = await accessReference.get();
  const accessData = access.data() ?? {};
  const role = editorialRoles.includes(accessData.role as EditorialRole) ? accessData.role as EditorialRole : null;
  if (!access.exists || accessData.status === "revoked" || !role || accessData.email !== email) {
    throw new HttpsError("permission-denied", "Esta cuenta no tiene una invitación editorial vigente.");
  }
  await getAuth().setCustomUserClaims(user.uid, claimsForRole(user.customClaims ?? {}, role));
  const db = getFirestore();
  const batch = db.batch();
  batch.set(accessReference, {
    email,
    uid: user.uid,
    displayName: user.displayName ?? "",
    role,
    status: "active",
    activatedAt: accessData.activatedAt ?? FieldValue.serverTimestamp(),
    lastActivatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.create(db.collection("editorial_audit").doc(), auditEntry("editorial_access.activated", {uid: user.uid, role, email}, email, {accessId}));
  await batch.commit();
  return {role};
});

export const adminListEditorialUsers = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "list-editorial-users", 60);
  const db = getFirestore();
  const [accessSnapshot, authPage] = await Promise.all([
    db.collection("editorial_users").limit(500).get(),
    getAuth().listUsers(1_000),
  ]);
  const accessByEmail = new Map<string, Record<string, unknown>>();
  for (const document of accessSnapshot.docs) {
    const data = document.data();
    if (typeof data.email === "string") accessByEmail.set(data.email, {id: document.id, ...data});
  }
  const items = new Map<string, Record<string, unknown>>();
  for (const user of authPage.users) {
    if (!user.email) continue;
    const email = user.email.toLocaleLowerCase("en-US");
    const role = roleOf(user.customClaims ?? {});
    const access = accessByEmail.get(email);
    if (!role && !access) continue;
    items.set(email, {
      id: access?.id ?? accessDocumentId(email),
      email,
      uid: user.uid,
      displayName: user.displayName ?? access?.displayName ?? "",
      role: role ?? access?.role ?? null,
      status: role ? "active" : access?.status ?? "revoked",
      createdAt: access?.createdAt ?? user.metadata.creationTime,
      updatedAt: access?.updatedAt ?? null,
      lastSignInAt: user.metadata.lastSignInTime ?? null,
    });
    accessByEmail.delete(email);
  }
  for (const [email, access] of accessByEmail) {
    items.set(email, {
      id: access.id ?? accessDocumentId(email),
      email,
      uid: access.uid ?? null,
      displayName: access.displayName ?? "",
      role: access.role ?? null,
      status: access.status ?? "invited",
      createdAt: access.createdAt ?? null,
      updatedAt: access.updatedAt ?? null,
      lastSignInAt: null,
    });
  }
  return {items: serialize([...items.values()].sort((left, right) => String(left.email).localeCompare(String(right.email))))};
});

export const adminSetEditorialAccess = onCall(writeRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "set-editorial-access", 30, 60 * 60_000);
  const input = request.data && typeof request.data === "object" ? request.data as Record<string, unknown> : {};
  const email = normalizeEditorialEmail(input.email);
  const requestedRole = input.role === null || input.role === "revoked" ? null : input.role as EditorialRole;
  if (requestedRole !== null && !editorialRoles.includes(requestedRole)) {
    throw new HttpsError("invalid-argument", "El rol editorial es inválido.");
  }
  const targetUser = await userByEmail(email);
  const currentRole = targetUser ? roleOf(targetUser.customClaims ?? {}) : null;
  if (targetUser?.uid === actor.uid && requestedRole !== "admin") {
    throw new HttpsError("failed-precondition", "No podés revocar ni reducir tu propio acceso administrador.");
  }
  if (currentRole === "admin" && requestedRole !== "admin") {
    const authPage = await getAuth().listUsers(1_000);
    const adminCount = authPage.users.filter((user) => roleOf(user.customClaims ?? {}) === "admin").length;
    if (adminCount <= 1) throw new HttpsError("failed-precondition", "Debe permanecer al menos un administrador activo.");
  }

  const db = getFirestore();
  const accessId = accessDocumentId(email);
  const accessReference = db.collection("editorial_users").doc(accessId);
  const existingAccess = await accessReference.get();
  const now = FieldValue.serverTimestamp();
  if (targetUser) {
    await getAuth().setCustomUserClaims(targetUser.uid, claimsForRole(targetUser.customClaims ?? {}, requestedRole));
    if (targetUser.uid !== actor.uid || requestedRole !== currentRole) {
      await getAuth().revokeRefreshTokens(targetUser.uid);
    }
  }
  const status = requestedRole ? targetUser ? "active" : "invited" : "revoked";
  const action = requestedRole === null ? "editorial_access.revoked" :
    !existingAccess.exists ? "editorial_access.invited" : currentRole === requestedRole ? "editorial_access.confirmed" : "editorial_access.role_changed";
  const batch = db.batch();
  batch.set(accessReference, {
    email,
    uid: targetUser?.uid ?? existingAccess.data()?.uid ?? null,
    displayName: targetUser?.displayName ?? existingAccess.data()?.displayName ?? "",
    role: requestedRole,
    status,
    invitedBy: existingAccess.data()?.invitedBy ?? actor.uid,
    invitedAt: existingAccess.data()?.invitedAt ?? now,
    updatedBy: actor.uid,
    updatedAt: now,
    revokedAt: requestedRole === null ? now : null,
  }, {merge: true});
  batch.create(db.collection("editorial_audit").doc(), auditEntry(action, actor, email, {from: currentRole, to: requestedRole, status}));
  await batch.commit();
  return {id: accessId, email, role: requestedRole, status};
});

export const adminGeneralReport = onCall(readRuntime, async (request) => {
  const actor = await requireRole(request, ["admin"]);
  await adminRateLimit(actor.uid, "general-report", 15);
  let range;
  let sections;
  try {
    range = reportRange(request.data?.from, request.data?.to);
    sections = selectedSections(request.data?.sections);
  } catch (error) { throw new HttpsError("invalid-argument", (error as Error).message); }
  const report = await loadGeneralReport(range.from, range.to, actor.email || actor.uid);
  if (request.data?.format !== "pdf") return {report};
  const buffer = await createGeneralReportPdf(report, sections);
  return {base64: buffer.toString("base64"), filename: generalReportFilename(report)};
});
