import assert from "node:assert/strict";
import test from "node:test";

import {toPublicStory} from "./public-story.js";

const valid = {
  status: "published",
  title: "Una historia",
  subtitle: "Una bajada editorial",
  summary: "Resumen público",
  body: "Relato completo y revisado editorialmente.",
  category: "Misterios",
  neighborhood: "Centro",
  period: "1882",
  evidence: "documented",
  sourceName: "Archivo de prueba",
  latitude: -34.92,
  longitude: -57.95,
  readingMinutes: 4,
  featured: true,
  privateNote: "nunca debe salir",
};

test("expone solo el contrato público permitido", () => {
  const story = toPublicStory("historia-1", valid);
  assert.ok(story);
  assert.equal(story.categoryId, "mystery");
  assert.equal(story.readingMinutes, 4);
  assert.equal(story.likeCount, 0);
  assert.equal(story.contributionOrigin, "dardito_team");
  assert.equal("privateNote" in story, false);
});

test("clasifica como comunitaria una historia convertida desde un aporte", () => {
  const story = toPublicStory("aporte-1", {
    ...valid,
    contributionOrigin: "dardito_team",
    sourceSubmissionId: "submission-1",
  });
  assert.equal(story?.contributionOrigin, "community");
});

test("descarta borradores y documentos sin coordenadas", () => {
  assert.equal(toPublicStory("draft-1", {...valid, status: "draft"}), null);
  assert.equal(toPublicStory("invalid-1", {...valid, latitude: null}), null);
});

test("lectura pública mantiene historias con evidencia anterior y desconocida", () => {
  for (const evidence of ["oral_tradition", "community", "documented", "legacy_custom"]) {
    const raw = {...valid, evidence};
    const result = toPublicStory("legacy", raw);
    assert.ok(result);
    assert.equal(raw.evidence, evidence);
    assert.equal(result.evidence, evidence);
  }
  assert.equal(toPublicStory("legacy", {...valid, evidence: "oral_tradition"})?.evidenceLabel, "Aporte de vecinos");
});
test("contrato público solo entrega identidad seleccionada de un aporte", () => {
  const raw = {...valid, sourceSubmissionId: "submission", email: "privado@example.com", authorDisplay: "name", publicAuthor: "Club del barrio"};
  const story = toPublicStory("aporte", raw)!;
  assert.equal(story.publicAuthor, "Club del barrio");
  assert.equal("email" in story, false);
  assert.equal("sourceSubmissionId" in story, false);
  assert.equal(toPublicStory("sistema", {...raw, sourceSubmissionId: undefined})?.publicAuthor, null);
});
