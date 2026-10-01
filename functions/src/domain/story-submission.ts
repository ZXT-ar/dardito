import {evidenceEntry as resolveEvidenceEntry} from "./editorial-catalogs.js";
import {classifyModeration} from "./moderation-policy.js";
import {catalogEntry, defaultCatalogs, type EditorialCatalogs} from "./editorial-catalogs.js";

export const storyTitleMaxLength = 25;
export const storyBodyMaxLength = 2_500;
export const storyPeriodMaxLength = 100;
export const maxPhotoCount = 3;
export const maxPhotoBytes = 8 * 1024 * 1024;
export const maxTotalPhotoBytes = 20 * 1024 * 1024;

const sensitivePatterns: Array<{label: string; expression: RegExp}> = [
  {
    label: "violencia sexual",
    expression: /\b(violaci[oó]n|violar|abuso sexual|agresi[oó]n sexual)\b/i,
  },
  {
    label: "contenido sexual con menores",
    expression: /\b(pedofilia|ped[oó]fil[oa]|pornograf[ií]a infantil|abuso infantil)\b/i,
  },
  {
    label: "violencia extrema",
    expression: /\b(descuartizar|degollar|torturar|mutilar|cad[aá]ver desmembrado)\b/i,
  },
];

export interface StorySubmissionInput {
  submissionId: string;
  title: string;
  story: string;
  category: string;
  neighborhood: string;
  period: string;
  evidence: string;
  materialConsent: boolean;
  legalConsent: boolean;
  contactConsent: boolean;
  photoPaths: string[];
  client?: Record<string, unknown>;
}

export class StorySubmissionError extends Error {
  constructor(
    public readonly code:
      | "INVALID_SUBMISSION"
      | "CONTENT_REVIEW_REQUIRED"
      | "INVALID_PHOTO",
    message: string,
    public readonly details: string[] = [],
  ) {
    super(message);
  }
}

function plainText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") return "";
  return value
    .normalize("NFC")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .replace(/[<>]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength + 1);
}

export function parseStorySubmission(body: unknown, catalogs: EditorialCatalogs = defaultCatalogs): StorySubmissionInput {
  const data = body && typeof body === "object"
    ? body as Record<string, unknown>
    : {};
  const submissionId = plainText(data.submissionId, 80);
  const title = plainText(data.title, storyTitleMaxLength);
  const story = plainText(data.story, storyBodyMaxLength);
  const category = plainText(data.category, 40);
  const neighborhood = plainText(data.neighborhood, 80);
  const period = plainText(data.period, storyPeriodMaxLength);
  const evidence = plainText(data.evidence, 30);
  const categoryEntry = catalogEntry(catalogs.categories, category);
  const neighborhoodEntry = catalogEntry(catalogs.neighborhoods, neighborhood);
  const evidenceEntry = resolveEvidenceEntry(evidence);
  const rawPhotoPaths = Array.isArray(data.photoPaths) ? data.photoPaths : [];
  const photoPaths = rawPhotoPaths
    .filter((value): value is string => typeof value === "string")
    .map((value) => plainText(value, 240));

  if (
    !/^[a-zA-Z0-9_-]{20,80}$/.test(submissionId) ||
    title.length < 3 ||
    title.length > storyTitleMaxLength ||
    story.length < 30 ||
    story.length > storyBodyMaxLength ||
    !categoryEntry ||
    !neighborhoodEntry ||
    period.length < 2 ||
    period.length > storyPeriodMaxLength ||
    !evidenceEntry ||
    data.materialConsent !== true ||
    data.legalConsent !== true ||
    data.contactConsent !== true ||
    photoPaths.length > maxPhotoCount ||
    new Set(photoPaths).size !== photoPaths.length
  ) {
    throw new StorySubmissionError(
      "INVALID_SUBMISSION",
      "El aporte no cumple los requisitos de validación.",
    );
  }

  const combined = `${title}\n${story}`;
  const moderation = classifyModeration(combined);
  const sensitive = sensitivePatterns
    .filter(({expression}) => expression.test(combined))
    .map(({label}) => label);
  const details = [
    ...moderation.categories.map((categoryName) => categoryName.replaceAll("_", " ")),
    ...sensitive,
  ];
  if (details.length > 0) {
    throw new StorySubmissionError(
      "CONTENT_REVIEW_REQUIRED",
      "Revisá el contenido antes de enviarlo.",
      [...new Set(details)],
    );
  }

  const client = data.client && typeof data.client === "object"
    ? Object.fromEntries(
      Object.entries(data.client as Record<string, unknown>)
        .filter(([, value]) =>
          typeof value === "string" ||
          typeof value === "number" ||
          typeof value === "boolean"
        )
        .slice(0, 12)
        .map(([key, value]) => [plainText(key, 40), value]),
    )
    : undefined;

  return {
    submissionId,
    title,
    story,
    category: categoryEntry.id,
    neighborhood: neighborhoodEntry.label,
    period,
    evidence: evidence === "oral_tradition" ? evidence : evidenceEntry.id,
    materialConsent: true,
    legalConsent: true,
    contactConsent: true,
    photoPaths,
    client,
  };
}
