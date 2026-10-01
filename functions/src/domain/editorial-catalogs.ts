import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export interface CatalogEntry {
  id: string;
  label: string;
  description?: string;
}

export interface EditorialCatalogs {
  categories: CatalogEntry[];
  neighborhoods: CatalogEntry[];
  evidenceLevels: CatalogEntry[];
}

export const defaultCatalogs: EditorialCatalogs = {
  categories: [
    {id: "architecture", label: "Arquitectura"},
    {id: "mystery", label: "Misterios"},
    {id: "culture", label: "Cultura"},
    {id: "neighborhood", label: "Barrios"},
    {id: "memory", label: "Memoria viva"},
  ],
  neighborhoods: [
    "Casco Urbano",
    "Centro",
    "Plaza Moreno",
    "Tolosa",
    "Meridiano V",
    "Gonnet",
    "El Bosque",
    "City Bell",
  ].map((label) => ({id: slugify(label), label})),
  evidenceLevels: [
    {id: "documented", label: "Documentada", description: "Historia respaldada y validada a partir de fuentes, archivos, publicaciones, documentos, registros u otros materiales verificables."},
    {id: "community", label: "Aporte de vecinos", description: "Historia, dato, testimonio o material compartido por vecinos, familias, comercios, clubes, escuelas o instituciones, que luego puede ser revisado, ampliado y contrastado por el equipo."},
  ],
};

export function slugify(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("es-AR")
    .replace(/[^a-z0-9_]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function normalizeEntries(value: unknown, fallback: CatalogEntry[]): CatalogEntry[] {
  if (!Array.isArray(value)) return fallback.map((entry) => ({...entry}));
  const entries: CatalogEntry[] = [];
  for (const item of value) {
    if (typeof item === "string") {
      const label = item.trim();
      const legacy = fallback.find((entry) =>
        entry.id === slugify(label) || entry.label.toLocaleLowerCase("es-AR") === label.toLocaleLowerCase("es-AR"),
      );
      if (legacy) entries.push({...legacy});
      else if (label) entries.push({id: slugify(label), label});
      continue;
    }
    if (!item || typeof item !== "object") continue;
    const raw = item as Record<string, unknown>;
    const label = typeof raw.label === "string" ? raw.label.trim() : "";
    const id = typeof raw.id === "string" ? slugify(raw.id) : slugify(label);
    const description = typeof raw.description === "string" ? raw.description.trim() : "";
    if (label && id) entries.push({id, label, ...(description ? {description} : {})});
  }
  const unique = new Map<string, CatalogEntry>();
  for (const entry of entries) unique.set(entry.id, entry);
  return unique.size ? [...unique.values()] : fallback.map((entry) => ({...entry}));
}

export function normalizeCatalogs(value: unknown): EditorialCatalogs {
  const raw = value && typeof value === "object" ? value as Record<string, unknown> : {};
  return {
    categories: normalizeEntries(raw.categories, defaultCatalogs.categories),
    neighborhoods: normalizeEntries(raw.neighborhoods, defaultCatalogs.neighborhoods),
    evidenceLevels: defaultCatalogs.evidenceLevels.map((entry) => ({...entry})),
  };
}

function parseEntries(value: unknown, field: string, minimum: number): CatalogEntry[] {
  if (!Array.isArray(value) || value.length < minimum || value.length > 120) {
    throw new HttpsError("invalid-argument", `${field} es inválido.`);
  }
  const entries = value.map((item) => {
    if (!item || typeof item !== "object") {
      throw new HttpsError("invalid-argument", `${field} contiene un valor inválido.`);
    }
    const raw = item as Record<string, unknown>;
    const label = typeof raw.label === "string" ? raw.label.replace(/\u0000/g, "").trim() : "";
    const id = typeof raw.id === "string" ? slugify(raw.id) : slugify(label);
    const description = typeof raw.description === "string" ? raw.description.replace(/\u0000/g, "").trim() : "";
    if (!id || !label || label.length > 100) {
      throw new HttpsError("invalid-argument", `${field} contiene un valor inválido.`);
    }
    if (description.length > 500) {
      throw new HttpsError("invalid-argument", `${field} contiene una descripción demasiado extensa.`);
    }
    return {id, label, ...(description ? {description} : {})};
  });
  if (new Set(entries.map((entry) => entry.id)).size !== entries.length) {
    throw new HttpsError("invalid-argument", `${field} contiene identificadores duplicados.`);
  }
  if (new Set(entries.map((entry) => entry.label.toLocaleLowerCase("es-AR"))).size !== entries.length) {
    throw new HttpsError("invalid-argument", `${field} contiene nombres duplicados.`);
  }
  return entries;
}

export function parseCatalogs(value: unknown): EditorialCatalogs {
  const raw = value && typeof value === "object" ? value as Record<string, unknown> : {};
  parseEntries(raw.evidenceLevels, "evidenceLevels", 1);
  return {
    categories: parseEntries(raw.categories, "categories", 1),
    neighborhoods: parseEntries(raw.neighborhoods, "neighborhoods", 1),
    evidenceLevels: defaultCatalogs.evidenceLevels.map((entry) => ({...entry})),
  };
}

export async function loadEditorialCatalogs(): Promise<EditorialCatalogs> {
  const snapshot = await getFirestore().collection("editorial_config").doc("catalogs").get();
  return normalizeCatalogs(snapshot.data());
}

export function catalogEntry(
  entries: CatalogEntry[],
  value: unknown,
): CatalogEntry | null {
  if (typeof value !== "string") return null;
  const input = value.trim();
  const normalized = slugify(input);
  return entries.find((entry) =>
    entry.id === normalized || entry.label.toLocaleLowerCase("es-AR") === input.toLocaleLowerCase("es-AR"),
  ) ?? null;
}

/** Legacy evidence remains stored verbatim; normalize only at interpretation boundaries. */
export function evidenceEntry(value: unknown): CatalogEntry | null {
  if (typeof value !== "string") return null;
  const key = slugify(value);
  if (["documented", "documentada"].includes(key)) return defaultCatalogs.evidenceLevels[0]!;
  if (["oral_tradition", "tradicion-oral", "community", "memoria-comunitaria", "aporte-de-vecinos"].includes(key)) return defaultCatalogs.evidenceLevels[1]!;
  // Custom historical values must remain readable, without becoming selectable.
  return null;
}
