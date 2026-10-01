import assert from "node:assert/strict";
import test from "node:test";

import {
  parseStorySubmission,
  StorySubmissionError,
} from "./story-submission.js";

const valid = {
  submissionId: "abcdefghijklmnopqrstuvwx",
  title: "Un recuerdo de Tolosa",
  story: "Mi abuelo atendía este almacén y el barrio todavía recuerda sus tardes.",
  category: "memory",
  neighborhood: "Tolosa",
  period: "Década de 1960",
  evidence: "oral_tradition",
  materialConsent: true,
  legalConsent: true,
  contactConsent: true,
  photoPaths: [],
};

test("acepta un aporte válido y sanea espacios", () => {
  const parsed = parseStorySubmission({...valid, title: "  Un   recuerdo de Tolosa "});
  assert.equal(parsed.title, "Un recuerdo de Tolosa");
  assert.equal(parsed.contactConsent, true);
  assert.equal(parsed.period, "Década de 1960");
  assert.equal(parsed.evidence, "oral_tradition");
});

test("rechaza contenido sensible antes de persistir", () => {
  assert.throws(
    () => parseStorySubmission({...valid, story: `${valid.story} Incluye una violación.`}),
    (error: unknown) =>
      error instanceof StorySubmissionError &&
      error.code === "CONTENT_REVIEW_REQUIRED",
  );
});

test("rechaza exceso de fotos y consentimientos incompletos", () => {
  assert.throws(
    () => parseStorySubmission({
      ...valid,
      legalConsent: false,
      photoPaths: ["a", "b", "c", "d"],
    }),
    (error: unknown) =>
      error instanceof StorySubmissionError &&
      error.code === "INVALID_SUBMISSION",
  );
});

test("exige período, evidencia válida y las tres declaraciones", () => {
  for (const invalid of [
    {...valid, period: ""},
    {...valid, evidence: "rumor"},
    {...valid, materialConsent: false},
    {...valid, legalConsent: false},
    {...valid, contactConsent: false},
  ]) {
    assert.throws(
      () => parseStorySubmission(invalid),
      (error: unknown) =>
        error instanceof StorySubmissionError &&
        error.code === "INVALID_SUBMISSION",
    );
  }
});
