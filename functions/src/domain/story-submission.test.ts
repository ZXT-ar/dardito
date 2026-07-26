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
  materialConsent: true,
  legalConsent: true,
  contactConsent: false,
  photoPaths: [],
};

test("acepta un aporte válido y sanea espacios", () => {
  const parsed = parseStorySubmission({...valid, title: "  Un   recuerdo de Tolosa "});
  assert.equal(parsed.title, "Un recuerdo de Tolosa");
  assert.equal(parsed.contactConsent, false);
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
