import assert from "node:assert/strict";
import test from "node:test";

import {isActiveEditorialSession, roleOf} from "./editorial-auth.js";

const user = {
  disabled: false,
  email: "editor@example.com",
  emailVerified: true,
  tokensValidAfterTime: "2026-09-07T18:00:00Z",
};
const authTime = Date.parse(user.tokensValidAfterTime) / 1_000;

test("la revocación editorial usa la autenticación original, no la emisión renovada del JWT", () => {
  assert.equal(isActiveEditorialSession(user, {auth_time: authTime - 1, iat: authTime + 300}), false);
  assert.equal(isActiveEditorialSession(user, {auth_time: authTime}), true);
  assert.equal(isActiveEditorialSession(user, {auth_time: authTime + 1}), true);
});

test("rechaza cuentas deshabilitadas, correos no verificados y sesiones sin auth_time válido", () => {
  assert.equal(isActiveEditorialSession({...user, disabled: true}, {auth_time: authTime}), false);
  assert.equal(isActiveEditorialSession({...user, emailVerified: false}, {auth_time: authTime}), false);
  assert.equal(isActiveEditorialSession({...user, email: undefined}, {auth_time: authTime}), false);
  for (const auth_time of [undefined, "123", NaN, Infinity, -1, 0, 1.5]) {
    assert.equal(isActiveEditorialSession(user, {auth_time}), false);
  }
  assert.equal(isActiveEditorialSession({...user, tokensValidAfterTime: "invalid"}, {auth_time: authTime}), false);
  assert.equal(isActiveEditorialSession({...user, tokensValidAfterTime: undefined}, {auth_time: authTime}), true);
});

test("conserva los roles editoriales existentes", () => {
  assert.equal(roleOf({admin: true}), "admin");
  assert.equal(roleOf({role: "editor"}), "editor");
  assert.equal(roleOf({reviewer: true}), "reviewer");
  assert.equal(roleOf({admin: "true"}), null);
  assert.equal(roleOf({}), null);
});
