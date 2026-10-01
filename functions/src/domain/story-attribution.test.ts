import assert from "node:assert/strict";
import test from "node:test";
import {resolveAttribution, publicAttribution} from "./story-attribution.js";
const current = {sourceSubmissionId: "submission-1"};
const submission = {userId: "uid", email: "vecino@example.com"};
test("autor anónimo por defecto; nunca expone correo interno automáticamente", () => {
  assert.deepEqual(resolveAttribution({}, current, submission, "admin"), {authorDisplay: "user", publicAuthor: "Un usuario"});
  assert.equal(publicAttribution({...current, email: submission.email}), "Un usuario");
});
test("correo solo desde aporte original; ignora correo y autor falsificados", () => {
  const result = resolveAttribution({authorDisplay: "email", email: "otro@example.com", publicAuthor: "falso"}, current, submission, "admin");
  assert.equal(result.publicAuthor, submission.email);
  assert.throws(() => resolveAttribution({authorDisplay: "email"}, current, undefined, "admin"));
});
test("historias del sistema nunca muestran identidad aunque la solicite el cliente", () => {
  const result = resolveAttribution({authorDisplay: "email"}, {}, submission, "admin");
  assert.equal(result.publicAuthor, "");
  assert.equal(publicAttribution({...result, contributionOrigin: "community"}), null);
});
test("solo admin cambia identidad, también después de publicada", () => {
  assert.throws(() => resolveAttribution({authorDisplay: "email"}, current, submission, "editor"));
  const named = resolveAttribution({authorDisplay: "name", authorName: " Club del barrio "}, current, submission, "admin");
  assert.equal(named.publicAuthor, "Club del barrio");
  const hidden = resolveAttribution({authorDisplay: "user"}, {...current, ...named, status: "published"}, submission, "admin");
  assert.equal(hidden.publicAuthor, "Un usuario");
  assert.equal(publicAttribution({...current, ...hidden}), "Un usuario");
});
test("rechaza nombres vacíos, HTML, controles, exceso y modos desconocidos", () => {
  for (const authorName of ["", " ", "<script>alert(1)</script>", "a\n", "a".repeat(101)]) assert.throws(() => resolveAttribution({authorDisplay: "name", authorName}, current, submission, "admin"));
  assert.throws(() => resolveAttribution({authorDisplay: "all"}, current, submission, "admin"));
});
