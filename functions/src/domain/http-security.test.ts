import assert from "node:assert/strict";
import {EventEmitter} from "node:events";
import test, {type TestContext} from "node:test";
import {getAuth, type UserRecord} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

import {
  darditoChat, publicSitemap, publicStoryImage, publicStoryPage, submitStory,
  upsertKnowledge, upsertUserProfile, userAccessStatus,
} from "../channels/http.js";
import {activateEditorialAccess} from "../channels/admin.js";
import {requireEditorialRole} from "../services/editorial-auth.js";
import {privacyHash} from "../services/rate-limit.js";
import {storyUploadReservationsRequired} from "../services/story-upload-reservations.js";
import {privacyVersion, termsVersion} from "./auth-access.js";

type Handler = typeof darditoChat;

class Response extends EventEmitter {
  statusCode = 200;
  body: unknown;
  headers: Record<string, string> = {};
  set(key: string, value: string) { this.headers[key.toLowerCase()] = value; return this; }
  setHeader(key: string, value: string) { return this.set(key, value); }
  getHeader(key: string) { return this.headers[key.toLowerCase()]; }
  status(value: number) { this.statusCode = value; return this; }
  send(body: unknown) { this.body = body; this.emit("finish"); return this; }
  json(body: unknown) { return this.send(body); }
  end(body: unknown) { return this.send(body); }
}

async function invoke(handler: Handler, options: {
  method?: string; body?: unknown; token?: string; path?: string; rawBody?: Buffer;
} = {}) {
  const headers: Record<string, string> = {"content-type": "application/json", "x-forwarded-for": "192.0.2.1"};
  if (options.token) headers.authorization = `Bearer ${options.token}`;
  const request = {
    method: options.method ?? "POST", headers, ip: "192.0.2.1", body: options.body ?? {},
    path: options.path ?? "/", url: options.path ?? "/", rawBody: options.rawBody ?? Buffer.from("{}"),
    header: (key: string) => headers[key.toLowerCase()],
  } as unknown as Parameters<Handler>[0];
  const response = new Response();
  await handler(request, response as unknown as Parameters<Handler>[1]);
  return response;
}

const authTime = Date.parse("2026-09-07T18:00:00Z") / 1_000;
const activeUser = {
  uid: "editor-uid", email: "editor@example.com", disabled: false, emailVerified: true,
  customClaims: {admin: true}, tokensValidAfterTime: new Date(authTime * 1_000).toISOString(),
} as unknown as UserRecord;
const consent = {accepted: true, termsVersion, privacyVersion};

function memoryDatabase(t: TestContext, initial: Record<string, Record<string, unknown>>) {
  const records = new Map(Object.entries(initial));
  type Reference = {path: string};
  const read = (reference: Reference) => ({exists: records.has(reference.path), data: () => records.get(reference.path)});
  const write = (reference: Reference, data: Record<string, unknown>) => {
    records.set(reference.path, {...records.get(reference.path), ...data});
  };
  const reference = (path: string): unknown => ({
    path, get: async () => read({path}), set: async (data: Record<string, unknown>) => write({path}, data),
    update: async (data: Record<string, unknown>) => write({path}, data),
    collection: (name: string) => collection(`${path}/${name}`),
  });
  let automaticId = 0;
  const collection = (name: string) => ({doc: (id = `generated-${++automaticId}`) => reference(`${name}/${id}`)});
  t.mock.method(getFirestore(), "collection", collection);
  t.mock.method(getFirestore(), "runTransaction", async (operation: (transaction: unknown) => Promise<unknown>) => {
    const pending: Array<() => void> = [];
    const transaction = {
      get: async (ref: Reference) => { assert.equal(pending.length, 0, "All transaction reads must precede writes"); return read(ref); },
      getAll: async (...refs: Reference[]) => { assert.equal(pending.length, 0); return refs.map(read); },
      set: (ref: Reference, data: Record<string, unknown>) => pending.push(() => write(ref, data)),
      update: (ref: Reference, data: Record<string, unknown>) => pending.push(() => write(ref, data)),
      create: (ref: Reference, data: Record<string, unknown>) => pending.push(() => {
        assert.equal(records.has(ref.path), false); write(ref, data);
      }),
    };
    const result = await operation(transaction);
    pending.forEach((commit) => commit());
    return result;
  });
  return records;
}

test("un claim admin viejo no autoriza el callable legacy ni roles editoriales actuales", async (t) => {
  const auth = getAuth();
  t.mock.method(auth, "getUser", async () => ({...activeUser, customClaims: {}}));
  const request = {auth: {uid: activeUser.uid, token: {admin: true, auth_time: authTime}}, data: {}};
  await assert.rejects(requireEditorialRole(request, ["admin"]), {code: "permission-denied"});
  await assert.rejects(upsertKnowledge.run(request as unknown as Parameters<typeof upsertKnowledge.run>[0]), {code: "permission-denied"});
});

test("la activación y la autorización editorial rechazan cuenta deshabilitada y sesión revocada", async (t) => {
  let user = {...activeUser, disabled: true};
  t.mock.method(getAuth(), "getUser", async () => user);
  const request = {auth: {uid: activeUser.uid, token: {admin: true, auth_time: authTime}}, data: {}};
  for (const state of [
    {...activeUser, disabled: true},
    {...activeUser, emailVerified: false},
    {...activeUser, tokensValidAfterTime: new Date((authTime + 1) * 1_000).toISOString()},
  ]) {
    user = state;
    await assert.rejects(requireEditorialRole(request, ["admin"]), {code: "unauthenticated"});
    await assert.rejects(activateEditorialAccess.run(request as unknown as Parameters<typeof activateEditorialAccess.run>[0]), {code: "unauthenticated"});
  }
  user = activeUser;
  assert.deepEqual(await requireEditorialRole(request, ["admin"]), {
    uid: activeUser.uid, email: activeUser.email, role: "admin",
  });
});

test("el wrapper legacy exige App Check antes de ejecutar una escritura", async (t) => {
  const getUser = t.mock.method(getAuth(), "getUser", async () => activeUser);
  const response = await invoke(upsertKnowledge as Handler, {body: {data: {}}});
  assert.equal(response.statusCode, 401);
  assert.equal(getUser.mock.callCount(), 0);
});

test("los POST anónimos o con JWT inválido no escriben métricas", async (t) => {
  const collection = t.mock.method(getFirestore(), "collection", () => { throw new Error("Unexpected database access"); });
  for (const handler of [darditoChat, upsertUserProfile, submitStory]) {
    assert.equal((await invoke(handler)).statusCode, 401);
  }
  t.mock.method(getAuth(), "verifyIdToken", async () => {
    throw Object.assign(new Error("Invalid token format"), {code: "auth/argument-error"});
  });
  for (const handler of [darditoChat, upsertUserProfile, submitStory]) {
    assert.equal((await invoke(handler, {token: "invalid"})).statusCode, 401);
  }
  assert.equal(collection.mock.callCount(), 0);
});

test("los payloads HTTP excesivos se rechazan antes de autenticar o acceder a datos", async (t) => {
  const verify = t.mock.method(getAuth(), "verifyIdToken", () => { throw new Error("Unexpected authentication"); });
  const response = await invoke(darditoChat, {rawBody: Buffer.alloc(64 * 1024 + 1)});
  assert.equal(response.statusCode, 413);
  assert.equal(verify.mock.callCount(), 0);
  assert.equal(response.headers["cache-control"], "no-store");
  assert.equal(response.headers["x-content-type-options"], "nosniff");
});

test("un usuario baneado, bloqueado o sin consentimiento no puede enviar aportes", async (t) => {
  const token = {uid: "community-user", email: "user@example.com", email_verified: true};
  t.mock.method(getAuth(), "verifyIdToken", async () => token);
  let userData: Record<string, unknown> = {consent, moderation: {banned: true}};
  let networkData: Record<string, unknown> = {};
  let writes = 0;
  t.mock.method(getFirestore(), "collection", (name: string) => {
    assert.ok(name === "users" || name === "moderation_sessions", `Unexpected collection ${name}`);
    return {doc: () => ({
      get: async () => ({data: () => name === "users" ? userData : networkData}),
      set: async () => { writes++; },
    })};
  });
  assert.equal((await invoke(submitStory, {token: "verified"})).statusCode, 403);
  assert.equal(writes, 0);
  userData = {consent};
  networkData = {blockedUntil: Timestamp.fromMillis(Date.now() + 60_000)};
  assert.equal((await invoke(submitStory, {token: "verified"})).statusCode, 403);
  assert.equal(writes, 1); // Only the existing account-block status, never a contribution.
  userData = {};
  networkData = {};
  assert.equal((await invoke(submitStory, {token: "verified"})).statusCode, 428);
});

test("el endpoint de acceso devuelve 429 sin actualizar perfil al superar su cupo", async (t) => {
  t.mock.method(getAuth(), "verifyIdToken", async () => ({uid: "active-user", email: "user@example.com", email_verified: true}));
  let writes = 0;
  t.mock.method(getFirestore(), "collection", (name: string) => ({doc: (id: string) => ({
    name, id,
    get: async () => ({data: () => name === "users" ? {consent} : {}}),
    set: async () => { writes++; },
  })}));
  t.mock.method(getFirestore(), "runTransaction", async (operation: (transaction: unknown) => Promise<unknown>) => operation({
    get: async (reference: {id: string}) => ({data: () => ({
      windowStartedAt: Timestamp.now(), count: reference.id === privacyHash("access-user:active-user") ? 120 : 600,
    })}),
    set: () => { writes++; },
  }));
  const response = await invoke(userAccessStatus, {token: "verified"});
  assert.equal(response.statusCode, 429);
  assert.equal(writes, 0);
});

test("el sitemap comparte una consulta entre solicitudes y aplica límite antes de consultar", async (t) => {
  let reads = 0;
  let limited = false;
  t.mock.method(getFirestore(), "collection", (name: string) => {
    if (name === "rate_limits") return {doc: () => ({})};
    assert.equal(name, "knowledge");
    return {where: () => ({limit: () => ({get: async () => {
      reads++;
      return {docs: [{id: "public-story", data: () => ({})}]};
    }})})};
  });
  t.mock.method(getFirestore(), "runTransaction", async (operation: (transaction: unknown) => Promise<unknown>) => operation({
    get: async () => ({data: () => limited ? {windowStartedAt: Timestamp.now(), count: 120} : undefined}),
    set: () => undefined,
  }));
  const responses = await Promise.all([invoke(publicSitemap, {method: "GET"}), invoke(publicSitemap, {method: "GET"})]);
  assert.equal(reads, 1);
  for (const response of responses) {
    assert.equal(response.statusCode, 200);
    assert.match(String(response.body), /public-story/);
  }
  limited = true;
  assert.equal((await invoke(publicSitemap, {method: "GET"})).statusCode, 429);
  assert.equal(reads, 1);
});

test("las páginas e imágenes revocables no autorizan caché persistente", async () => {
  for (const handler of [publicStoryPage, publicStoryImage]) {
    const response = await invoke(handler, {method: "GET", path: "/invalid%2fpath"});
    assert.equal(response.statusCode, 404);
    assert.equal(response.headers["cache-control"], "no-store");
  }
});

test("preparar, validar y finalizar fotos usa la misma reserva; cancelar después del éxito conserva evidencia", async (t) => {
  const uid = "photo-user";
  const submissionId = "abcdefghijklmnopqrstuvwx";
  t.mock.method(getAuth(), "verifyIdToken", async () => ({uid, email: "photo@example.com", email_verified: true}));
  t.mock.method(storyUploadReservationsRequired, "value", () => "true");
  const records = memoryDatabase(t, {[`users/${uid}`]: {consent}});
  let actualSize = 120;
  const deleted: string[] = [];
  t.mock.method(getStorage(), "bucket", () => ({file: (path: string) => ({
    exists: async () => [true],
    getMetadata: async () => [{size: actualSize, contentType: "image/jpeg"}],
    download: async () => [Buffer.from([255, 216, 255, 0])],
    delete: async () => { deleted.push(path); },
  })}));
  const prepareBody = {action: "prepare", submissionId, photos: [{name: "photo_0.jpg", size: 120, contentType: "image/jpeg"}]};
  for (let retry = 0; retry < 2; retry++) {
    const response = await invoke(submitStory, {token: "verified", body: prepareBody});
    assert.equal(response.statusCode, 200);
  }
  assert.equal(records.get(`rate_limits/${privacyHash(`story-upload-user:${uid}`)}`)?.count, 1);
  assert.equal(records.get(`story_upload_reservations/${submissionId}`)?.status, "uploading");
  const contribution = {
    submissionId, title: "Un recuerdo de Tolosa",
    story: "Mi abuelo atendía este almacén y el barrio todavía recuerda sus tardes.",
    category: "memory", neighborhood: "Tolosa", period: "Década de 1960", evidence: "oral_tradition",
    materialConsent: true, legalConsent: true, contactConsent: true,
    photoPaths: [`story_submissions/${uid}/${submissionId}/photo_0.jpg`],
  };
  const omitted = await invoke(submitStory, {token: "verified", body: {...contribution, photoPaths: []}});
  assert.equal(omitted.statusCode, 409);
  assert.equal(records.has(`story_submissions/${submissionId}`), false);
  assert.equal(records.get(`story_upload_reservations/${submissionId}`)?.status, "uploading");
  actualSize = 121;
  const changed = await invoke(submitStory, {token: "verified", body: contribution});
  assert.equal(changed.statusCode, 409);
  assert.equal(records.has(`story_submissions/${submissionId}`), false);
  assert.equal(records.get(`story_upload_reservations/${submissionId}`)?.status, "uploading");
  actualSize = 120;
  const submitted = await invoke(submitStory, {token: "verified", body: contribution});
  assert.equal(submitted.statusCode, 202);
  assert.equal(records.get(`story_upload_reservations/${submissionId}`)?.status, "submitted");
  assert.equal(records.get(`story_submissions/${submissionId}`)?.userId, uid);
  const cancel = await invoke(submitStory, {token: "verified", body: {action: "cancel", submissionId}});
  assert.equal(cancel.statusCode, 200);
  assert.deepEqual(cancel.body, {submissionId, status: "submitted"});
  assert.deepEqual(deleted, []);
});

test("el modo estricto rechaza fotos sin reserva y el modo de migración conserva el cliente anterior", async (t) => {
  const uid = "photo-user";
  const submissionId = "strictphotowithoutreserve";
  t.mock.method(getAuth(), "verifyIdToken", async () => ({uid, email: "photo@example.com", email_verified: true}));
  let strict = true;
  t.mock.method(storyUploadReservationsRequired, "value", () => strict ? "true" : "false");
  const records = memoryDatabase(t, {[`users/${uid}`]: {consent}});
  t.mock.method(getStorage(), "bucket", () => ({file: () => ({
    exists: async () => [true], getMetadata: async () => [{size: 120, contentType: "image/jpeg"}],
    download: async () => [Buffer.from([255, 216, 255, 0])],
  })}));
  const body = {
    submissionId, title: "Un recuerdo de Tolosa",
    story: "Mi abuelo atendía este almacén y el barrio todavía recuerda sus tardes.",
    category: "memory", neighborhood: "Tolosa", period: "Década de 1960", evidence: "oral_tradition",
    materialConsent: true, legalConsent: true, contactConsent: true,
    photoPaths: [`story_submissions/${uid}/${submissionId}/photo_0.jpg`],
  };
  const response = await invoke(submitStory, {token: "verified", body});
  assert.equal(response.statusCode, 428);
  assert.equal(records.has(`story_submissions/${submissionId}`), false);
  strict = false;
  assert.equal((await invoke(submitStory, {token: "verified", body})).statusCode, 202);
  assert.equal(records.get(`story_submissions/${submissionId}`)?.userId, uid);
});
