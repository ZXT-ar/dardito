import assert from "node:assert/strict";
import test from "node:test";

import {
  hasRequiredConsent,
  parseRequiredConsent,
  privacyVersion,
  termsVersion,
} from "./auth-access.js";

test("acepta únicamente el consentimiento explícito y versionado", () => {
  const consent = parseRequiredConsent({
    accepted: true,
    termsVersion,
    privacyVersion,
  });
  assert.equal(consent.accepted, true);
  assert.equal(hasRequiredConsent(consent), true);
});

test("rechaza consentimiento implícito, incompleto o desactualizado", () => {
  assert.equal(hasRequiredConsent(undefined), false);
  assert.equal(hasRequiredConsent({accepted: false}), false);
  assert.equal(hasRequiredConsent({
    accepted: true,
    termsVersion: "anterior",
    privacyVersion,
  }), false);
});
