import {FieldValue, getFirestore, Timestamp, type DocumentReference, type Transaction} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {defineString} from "firebase-functions/params";

import {
  assertStoryUploadActive, assertStoryUploadManifest, nextStoryUploadQuota,
  parseStoryUploadPhotos, StoryUploadError, storyUploadIpQuota,
  storyUploadLifetimeMilliseconds, storyUploadPaths, storyUploadUserQuota,
  validateStoryUploadIdentity, type StoryUploadReservation,
} from "../domain/story-upload-reservation.js";
import {privacyHash} from "./rate-limit.js";

export {StoryUploadError} from "../domain/story-upload-reservation.js";

// Migration switch only: enable together with reservation-aware Storage rules
// after publishing the client that calls prepare before uploading photographs.
// False does NOT close the direct-upload quota gap for old clients.
export const storyUploadReservationsRequired = defineString("STORY_UPLOAD_RESERVATIONS_REQUIRED", {default: "false"});

function reservationFromData(data: Record<string, unknown>): StoryUploadReservation {
  return {
    ownerUid: String(data.ownerUid ?? ""), status: String(data.status ?? ""),
    expiresAtMs: data.expiresAt instanceof Timestamp ? data.expiresAt.toMillis() : 0,
    photos: parseStoryUploadPhotos(data.manifest),
  };
}

function quotaFromData(data: Record<string, unknown> | undefined) {
  if (!data || !(data.windowStartedAt instanceof Timestamp)) return null;
  return {count: typeof data.count === "number" ? data.count : 0, windowStartedAtMs: data.windowStartedAt.toMillis()};
}

export async function prepareStoryUpload(input: {uid: string; ip: string; submissionId: unknown; photos: unknown}) {
  const submissionId = validateStoryUploadIdentity(input.uid, input.submissionId);
  const photos = parseStoryUploadPhotos(input.photos);
  const db = getFirestore();
  const reservationRef = db.collection("story_upload_reservations").doc(submissionId);
  const quotaRefs = [
    db.collection("rate_limits").doc(privacyHash(`story-upload-user:${input.uid}`)),
    db.collection("rate_limits").doc(privacyHash(`story-upload-ip:${input.ip}`)),
  ];
  return db.runTransaction(async (transaction) => {
    const [existing, user, submitted, ...quotas] = await transaction.getAll(
      reservationRef, db.collection("users").doc(input.uid),
      db.collection("story_submissions").doc(submissionId), ...quotaRefs,
    );
    if (!existing || !user || !submitted || quotas.length !== 2) throw new Error("INCOMPLETE_UPLOAD_TRANSACTION_READ");
    const now = Date.now();
    if (user.data()?.moderation?.banned === true) throw new StoryUploadError("ACCOUNT_BANNED", "Esta cuenta no puede enviar aportes.", 403);
    if (submitted.exists) throw new StoryUploadError("UPLOAD_RESERVATION_CLOSED", "Este aporte ya fue enviado.", 409);
    if (existing.exists) {
      const reservation = reservationFromData(existing.data() ?? {});
      assertStoryUploadActive(reservation, input.uid, now);
      assertStoryUploadManifest(reservation.photos, photos);
      return {submissionId, expiresAt: new Date(reservation.expiresAtMs).toISOString(), photoPaths: storyUploadPaths(input.uid, submissionId, photos)};
    }
    // Reservation and both counters commit atomically. A retry of this ID never
    // consumes a second quota slot and concurrent IDs cannot exceed either cap.
    const nextQuotas = quotas.map((snapshot, index) => nextStoryUploadQuota(
      quotaFromData(snapshot.data()), index === 0 ? storyUploadUserQuota : storyUploadIpQuota, now,
    ));
    const expiresAtMs = now + storyUploadLifetimeMilliseconds;
    transaction.create(reservationRef, {
      ownerUid: input.uid, status: "uploading", manifest: photos,
      photos: Object.fromEntries(photos.map((photo) => [photo.name, {size: photo.size, contentType: photo.contentType}])),
      expiresAt: Timestamp.fromMillis(expiresAtMs), expiresAtMs, createdAt: FieldValue.serverTimestamp(),
    });
    nextQuotas.forEach((quota, index) => transaction.set(quotaRefs[index]!, {
      count: quota.count, windowStartedAt: Timestamp.fromMillis(quota.windowStartedAtMs), updatedAt: FieldValue.serverTimestamp(),
    }));
    return {submissionId, expiresAt: new Date(expiresAtMs).toISOString(), photoPaths: storyUploadPaths(input.uid, submissionId, photos)};
  });
}

export async function readStoryUploadForFinalize(transaction: Transaction, input: {
  uid: string; submissionId: string;
  photos: Array<{path: string; size: number; contentType: string}>;
  requireReservation: boolean;
}): Promise<DocumentReference | null> {
  validateStoryUploadIdentity(input.uid, input.submissionId);
  const reference = getFirestore().collection("story_upload_reservations").doc(input.submissionId);
  const snapshot = await transaction.get(reference);
  if (!snapshot.exists) {
    if (!input.photos.length) return null;
    if (!input.requireReservation) return null;
    throw new StoryUploadError("UPLOAD_RESERVATION_REQUIRED", "Actualizá la página antes de enviar fotografías.", 428);
  }
  const reservation = reservationFromData(snapshot.data() ?? {});
  assertStoryUploadActive(reservation, input.uid, Date.now());
  const prefix = `story_submissions/${input.uid}/${input.submissionId}/`;
  const actual = input.photos.length ? parseStoryUploadPhotos(input.photos.map((photo) => ({
    name: photo.path.startsWith(prefix) ? photo.path.slice(prefix.length) : "", size: photo.size, contentType: photo.contentType,
  }))) : [];
  assertStoryUploadManifest(reservation.photos, actual);
  return reference;
}

export function completeStoryUpload(transaction: Transaction, reference: DocumentReference): void {
  transaction.update(reference, {status: "submitted", submittedAt: FieldValue.serverTimestamp()});
}

export async function cancelStoryUpload(input: {uid: string; submissionId: unknown}) {
  const submissionId = validateStoryUploadIdentity(input.uid, input.submissionId);
  const db = getFirestore();
  const reference = db.collection("story_upload_reservations").doc(submissionId);
  const result = await db.runTransaction(async (transaction) => {
    const [snapshot, submission] = await transaction.getAll(reference, db.collection("story_submissions").doc(submissionId));
    if (!snapshot || !submission) throw new Error("INCOMPLETE_UPLOAD_TRANSACTION_READ");
    if (!snapshot.exists) return {status: "missing" as const, paths: [] as string[]};
    const data = snapshot.data() ?? {};
    if (data.ownerUid !== input.uid) throw new StoryUploadError("UPLOAD_RESERVATION_CONFLICT", "La carga pertenece a otra cuenta.", 403);
    // A client timeout can happen after submit succeeded. Never delete accepted
    // evidence, even when a cancellation request arrives after that timeout.
    if (submission.exists || data.status === "submitted") return {status: "submitted" as const, paths: [] as string[]};
    if (!["uploading", "cancelled"].includes(String(data.status))) throw new StoryUploadError("UPLOAD_RESERVATION_CLOSED", "La carga ya fue cerrada.", 409);
    const reservation = reservationFromData(data);
    transaction.update(reference, {status: "cancelled", cancelledAt: FieldValue.serverTimestamp()});
    return {status: "cancelled" as const, paths: storyUploadPaths(input.uid, submissionId, reservation.photos)};
  });
  if (result.status === "cancelled") {
    await Promise.all(result.paths.map((filePath) => getStorage().bucket().file(filePath).delete({ignoreNotFound: true})));
    await reference.update({storageCleanedAt: FieldValue.serverTimestamp()});
  }
  return {submissionId, status: result.status};
}
