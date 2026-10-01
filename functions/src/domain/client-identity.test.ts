import assert from "node:assert/strict";
import {test} from "node:test";
import {trustedClientIdentity} from "./client-identity.js";

test("identifica el mismo cliente aunque falsifique uno o varios prefijos XFF", () => {
  for (const header of ["198.51.100.10", "203.0.113.1, 198.51.100.10", "203.0.113.1, 203.0.113.2, 198.51.100.10"]) {
    assert.equal(trustedClientIdentity({headers: {"x-forwarded-for": header}, socket: {remoteAddress: "169.254.1.1"}}), "198.51.100.10");
  }
});

test("admite IPv6 y cabeceras múltiples sin confiar en prefijos", () => {
  assert.equal(trustedClientIdentity({headers: {"x-forwarded-for": ["203.0.113.1", "203.0.113.2, 2001:DB8::10"]}}), "2001:db8::10");
});

test("una cabecera malformada usa el transporte o un cupo común, nunca el prefijo", () => {
  assert.equal(trustedClientIdentity({headers: {"x-forwarded-for": "203.0.113.1, unknown"}, socket: {remoteAddress: "127.0.0.1"}}), "127.0.0.1");
  assert.equal(trustedClientIdentity({headers: {"x-forwarded-for": "203.0.113.1, "}}), "unresolved-transport");
  assert.equal(trustedClientIdentity({headers: {}}), "unresolved-transport");
});
