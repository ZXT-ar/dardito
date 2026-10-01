export const termsVersion = "2026-08-15";
export const privacyVersion = "2026-08-15";

export interface RequiredConsent {
  accepted: true;
  termsVersion: string;
  privacyVersion: string;
}

export function parseRequiredConsent(input: unknown): RequiredConsent {
  if (!input || typeof input !== "object") throw new Error("CONSENT_REQUIRED");
  const consent = input as Record<string, unknown>;
  if (
    consent.accepted !== true ||
    consent.termsVersion !== termsVersion ||
    consent.privacyVersion !== privacyVersion
  ) {
    throw new Error("CONSENT_REQUIRED");
  }
  return {
    accepted: true,
    termsVersion,
    privacyVersion,
  };
}

export function hasRequiredConsent(input: unknown): boolean {
  try {
    parseRequiredConsent(input);
    return true;
  } catch {
    return false;
  }
}
