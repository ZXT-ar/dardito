import assert from "node:assert/strict";
import test from "node:test";
import {
  assertStoryUploadActive, assertStoryUploadManifest, nextStoryUploadQuota,
  parseStoryUploadPhotos, StoryUploadError, storyUploadPaths, validateStoryUploadIdentity,
} from "./story-upload-reservation.js";

const jpeg = {name: "photo_0.jpg", size: 2048, contentType: "image/jpeg"};
const photos = parseStoryUploadPhotos([jpeg]);

test("reserva solo un manifiesto ordenado con rutas y tamaños acotados", () => {
  assert.deepEqual(photos, [jpeg]);
  assert.deepEqual(storyUploadPaths("user123", "abcdefghijklmnopqrst", photos), ["story_submissions/user123/abcdefghijklmnopqrst/photo_0.jpg"]);
  for (const value of [[], null, [jpeg, jpeg], [{...jpeg, name: "../../file.jpg"}], [{...jpeg, size: 0}], [{...jpeg, size: 1.5}], [{...jpeg, size: 8 * 1024 * 1024 + 1}], [{...jpeg, contentType: "text/html"}], [{...jpeg, contentType: ["image/jpeg"]}], [{...jpeg, contentType: null}], [{...jpeg, contentType: {}}], [{...jpeg, name: "photo_0.png"}]]) {
    assert.throws(() => parseStoryUploadPhotos(value), StoryUploadError);
  }
  assert.throws(() => parseStoryUploadPhotos([0, 1, 2].map((index) => ({...jpeg, name: `photo_${index}.jpg`, size: 8 * 1024 * 1024}))), StoryUploadError);
  assert.throws(() => validateStoryUploadIdentity("../user", "abcdefghijklmnopqrst"), StoryUploadError);
});

test("reserva ajena, vencida, enviada o cancelada no habilita finalización", () => {
  const reservation = {ownerUid: "user123", status: "uploading", expiresAtMs: 1000, photos};
  assert.doesNotThrow(() => assertStoryUploadActive(reservation, "user123", 999));
  for (const [candidate, uid, now] of [
    [reservation, "other", 999], [reservation, "user123", 1000],
    [{...reservation, status: "submitted"}, "user123", 999],
    [{...reservation, status: "cancelled"}, "user123", 999],
  ] as const) assert.throws(() => assertStoryUploadActive(candidate, uid, now), StoryUploadError);
});

test("reintentar el mismo manifiesto es válido pero cambiar foto, peso o MIME no", () => {
  assert.doesNotThrow(() => assertStoryUploadManifest(photos, parseStoryUploadPhotos([jpeg])));
  for (const candidate of [[], [{...photos[0]!, size: 2049}], [{...photos[0]!, name: "photo_0.png", contentType: "image/png" as const}]]) {
    assert.throws(() => assertStoryUploadManifest(photos, candidate), StoryUploadError);
  }
});

test("la cuota solo se renueva al completar la hora y aplica caps UID/IP", () => {
  const now = 5000;
  assert.deepEqual(nextStoryUploadQuota(null, 5, now), {count: 1, windowStartedAtMs: now});
  for (const maximum of [5, 10]) {
    assert.deepEqual(nextStoryUploadQuota({count: maximum - 1, windowStartedAtMs: now}, maximum, now + 1), {count: maximum, windowStartedAtMs: now});
    assert.throws(() => nextStoryUploadQuota({count: maximum, windowStartedAtMs: now}, maximum, now + 3599999), (error: unknown) => error instanceof StoryUploadError && error.status === 429);
    assert.deepEqual(nextStoryUploadQuota({count: maximum, windowStartedAtMs: now}, maximum, now + 3600000), {count: 1, windowStartedAtMs: now + 3600000});
  }
});
