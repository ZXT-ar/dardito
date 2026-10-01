import {maxPhotoBytes, maxPhotoCount, maxTotalPhotoBytes} from "./story-submission.js";

export const storyUploadLifetimeMilliseconds = 30 * 60_000;
export const storyUploadQuotaWindowMilliseconds = 60 * 60_000;
export const storyUploadUserQuota = 5;
export const storyUploadIpQuota = 10;

export class StoryUploadError extends Error {
  constructor(public readonly code: string, message: string, public readonly status = 400) {
    super(message);
  }
}

export interface StoryUploadPhoto {
  name: string;
  size: number;
  contentType: "image/jpeg" | "image/png" | "image/webp";
}

export interface StoryUploadReservation {
  ownerUid: string;
  status: string;
  expiresAtMs: number;
  photos: StoryUploadPhoto[];
}

export function validateStoryUploadIdentity(uid: string, submissionId: unknown): string {
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(uid) ||
      typeof submissionId !== "string" || !/^[a-zA-Z0-9_-]{20,80}$/.test(submissionId)) {
    throw new StoryUploadError("INVALID_UPLOAD_RESERVATION", "La identificación de la carga no es válida.");
  }
  return submissionId;
}

export function parseStoryUploadPhotos(value: unknown): StoryUploadPhoto[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > maxPhotoCount) {
    throw new StoryUploadError("INVALID_UPLOAD_RESERVATION", "Seleccioná entre una y tres fotografías.");
  }
  const extensions = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"} as const;
  const photos = value.map((raw: unknown, index): StoryUploadPhoto => {
    const photo = raw && typeof raw === "object" && !Array.isArray(raw) ? raw as Record<string, unknown> : {};
    const contentType = photo.contentType as keyof typeof extensions;
    if (typeof photo.contentType !== "string" || !Object.hasOwn(extensions, contentType) ||
        photo.name !== `photo_${index}.${extensions[contentType]}` ||
        typeof photo.size !== "number" || !Number.isSafeInteger(photo.size) ||
        photo.size <= 0 || photo.size > maxPhotoBytes) {
      throw new StoryUploadError("INVALID_UPLOAD_RESERVATION", "Una fotografía no cumple nombre, tipo o peso.");
    }
    return {name: photo.name as string, size: photo.size, contentType};
  });
  if (photos.reduce((total, photo) => total + photo.size, 0) > maxTotalPhotoBytes) {
    throw new StoryUploadError("INVALID_UPLOAD_RESERVATION", "Las fotografías superan el peso total permitido.");
  }
  return photos;
}

export function storyUploadPaths(uid: string, submissionId: string, photos: StoryUploadPhoto[]): string[] {
  validateStoryUploadIdentity(uid, submissionId);
  return photos.map((photo) => `story_submissions/${uid}/${submissionId}/${photo.name}`);
}

export function assertStoryUploadActive(reservation: StoryUploadReservation, uid: string, now: number): void {
  if (reservation.ownerUid !== uid) {
    throw new StoryUploadError("UPLOAD_RESERVATION_CONFLICT", "La carga pertenece a otra cuenta.", 403);
  }
  if (reservation.status !== "uploading") {
    throw new StoryUploadError("UPLOAD_RESERVATION_CLOSED", "La carga ya fue enviada o cancelada.", 409);
  }
  if (!Number.isFinite(reservation.expiresAtMs) || reservation.expiresAtMs <= now) {
    throw new StoryUploadError("UPLOAD_RESERVATION_EXPIRED", "La reserva de fotografías venció. Volvé a enviar el aporte.", 409);
  }
}

export function assertStoryUploadManifest(expected: StoryUploadPhoto[], actual: StoryUploadPhoto[]): void {
  if (expected.length !== actual.length || expected.some((photo, index) => {
    const other = actual[index];
    return !other || photo.name !== other.name || photo.size !== other.size || photo.contentType !== other.contentType;
  })) {
    throw new StoryUploadError("UPLOAD_RESERVATION_CONFLICT", "Las fotografías no coinciden con la carga autorizada.", 409);
  }
}

export function nextStoryUploadQuota(input: {count: number; windowStartedAtMs: number} | null, maximum: number, now: number): {count: number; windowStartedAtMs: number} {
  const expired = !input || now - input.windowStartedAtMs >= storyUploadQuotaWindowMilliseconds;
  if (expired) return {count: 1, windowStartedAtMs: now};
  if (input.count >= maximum) throw new StoryUploadError("RATE_LIMITED", "Alcanzaste el límite de cargas. Probá nuevamente en una hora.", 429);
  return {count: input.count + 1, windowStartedAtMs: input.windowStartedAtMs};
}
