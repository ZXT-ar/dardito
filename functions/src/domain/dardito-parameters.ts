import type {Channel} from "./types.js";

export const darditoParameterRuleKeys = [
  "useVoseo",
  "mentionEvidence",
  "closingQuestion",
  "contextualGreeting",
] as const;

export type DarditoParameterRule = typeof darditoParameterRuleKeys[number];

export interface DarditoParameters {
  version: 1;
  formality: number;
  responseLength: number;
  naturalTone: number;
  preferredWords: string[];
  avoidedWords: string[];
  signaturePhrases: string[];
  rules: Record<DarditoParameterRule, boolean>;
}

export const defaultDarditoParameters: DarditoParameters = {
  version: 1,
  formality: 55,
  responseLength: 48,
  naturalTone: 72,
  preferredWords: [],
  avoidedWords: [],
  signaturePhrases: [],
  rules: {
    useVoseo: true,
    mentionEvidence: true,
    closingQuestion: true,
    contextualGreeting: true,
  },
};

const maxVocabularyItems = 40;
const maxVocabularyItemLength = 80;

function boundedInteger(value: unknown, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(0, Math.min(100, Math.round(value)));
}

function vocabularyList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const raw of value) {
    if (typeof raw !== "string") continue;
    const normalized = raw.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
    if (!normalized || normalized.length > maxVocabularyItemLength) continue;
    const key = normalized.toLocaleLowerCase("es-AR");
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
    if (result.length === maxVocabularyItems) break;
  }
  return result;
}

export function normalizeDarditoParameters(value: unknown): DarditoParameters {
  const input = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const inputRules = input.rules && typeof input.rules === "object"
    ? input.rules as Record<string, unknown>
    : {};
  return {
    version: 1,
    formality: boundedInteger(input.formality, defaultDarditoParameters.formality),
    responseLength: boundedInteger(input.responseLength, defaultDarditoParameters.responseLength),
    naturalTone: boundedInteger(input.naturalTone, defaultDarditoParameters.naturalTone),
    preferredWords: vocabularyList(input.preferredWords),
    avoidedWords: vocabularyList(input.avoidedWords),
    signaturePhrases: vocabularyList(input.signaturePhrases),
    rules: {
      useVoseo: typeof inputRules.useVoseo === "boolean" ? inputRules.useVoseo : true,
      mentionEvidence: typeof inputRules.mentionEvidence === "boolean" ? inputRules.mentionEvidence : true,
      closingQuestion: typeof inputRules.closingQuestion === "boolean" ? inputRules.closingQuestion : true,
      contextualGreeting: typeof inputRules.contextualGreeting === "boolean" ? inputRules.contextualGreeting : true,
    },
  };
}

function formalityInstruction(value: number): string {
  if (value >= 76) return "Usá un registro preciso y respetuoso, manteniendo la voz cercana de personaje y sin sonar institucional.";
  if (value >= 41) return "Usá un registro cuidado y cercano, equilibrando claridad editorial y calidez.";
  return "Usá un registro cotidiano y relajado, manteniendo siempre respeto y rigor.";
}

function naturalToneInstruction(value: number): string {
  if (value >= 76) return "Soná muy natural y conversacional: variá el ritmo y evitá fórmulas mecánicas.";
  if (value >= 41) return "Soná cercano y natural, con una estructura clara y sin excesos expresivos.";
  return "Priorizá una formulación sintética, directa y estructurada, sin perder la identidad de Dardito.";
}

export function responseWordRange(parameters: DarditoParameters, channel: Channel): {minimum: number; maximum: number} {
  const minimum = Math.round(35 + parameters.responseLength * 0.85);
  const maximum = Math.round(80 + parameters.responseLength * 2.7);
  if (channel === "whatsapp") return {minimum: Math.min(minimum, 90), maximum: Math.min(maximum, 180)};
  return {minimum, maximum};
}

export function responseTokenBudget(parameters: DarditoParameters, channel: Channel): number {
  const range = responseWordRange(parameters, channel);
  const answerTokens = Math.max(512, Math.min(channel === "whatsapp" ? 1200 : 2048, Math.round(range.maximum * 2.4)));
  // Gemini counts reasoning and visible text against the same output limit.
  // Keep the editorial length in the prompt and reserve room for reasoning here.
  return answerTokens + 2_048;
}

export function renderDarditoParameterInstruction(parameters: DarditoParameters, channel: Channel): string {
  const range = responseWordRange(parameters, channel);
  const vocabulary = [
    parameters.preferredWords.length > 0
      ? `- Vocabulario preferido: incorporá de manera natural, solo cuando sea pertinente, alguna de estas expresiones: ${parameters.preferredWords.join("; ")}.`
      : "",
    parameters.avoidedWords.length > 0
      ? `- Expresiones a evitar: no uses estas expresiones en tu respuesta: ${parameters.avoidedWords.join("; ")}.`
      : "",
    parameters.signaturePhrases.length > 0
      ? `- Giros característicos: podés usar como máximo uno y solo si encaja naturalmente: ${parameters.signaturePhrases.join("; ")}.`
      : "",
  ].filter(Boolean);

  return [
    "CONFIGURACIÓN EDITORIAL ACTIVA",
    "Esta configuración ajusta únicamente la forma de expresarte. Nunca reemplaza las reglas de seguridad, la identidad aprobada, el funcionamiento real del proyecto ni la obligación de basar las historias en el corpus.",
    `- Formalidad (${parameters.formality}/100): ${formalityInstruction(parameters.formality)}`,
    `- Extensión (${parameters.responseLength}/100): apuntá a ${range.minimum}-${range.maximum} palabras cuando la consulta lo justifique; una pregunta simple puede responderse con menos. Nunca rellenes para alcanzar el máximo.`,
    `- Naturalidad (${parameters.naturalTone}/100): ${naturalToneInstruction(parameters.naturalTone)}`,
    parameters.rules.useVoseo
      ? "- Voseo rioplatense activo: usá «vos» y conjugaciones rioplatenses con naturalidad."
      : "- Voseo desactivado: evitá «vos» y sus conjugaciones; usá español neutro.",
    parameters.rules.mentionEvidence
      ? "- Aclaración de evidencia activa: cuando relates contenido del corpus, diferenciá su nivel de evidencia de manera comprensible."
      : "- Aclaración de evidencia desactivada: no anuncies la clasificación editorial salvo que sea necesaria para no presentar una versión no verificada como hecho.",
    parameters.rules.closingQuestion
      ? "- Pregunta de continuidad activa: cuando resulte pertinente, cerrá con una invitación breve para seguir explorando."
      : "- Pregunta de continuidad desactivada: concluí la respuesta sin agregar una pregunta final automática.",
    parameters.rules.contextualGreeting
      ? "- Saludo contextual activo: si corresponde saludar, variá el saludo según el momento y el curso de la conversación."
      : "- Saludo contextual desactivado: saludá de forma breve y sobria, sin referencias al momento del día.",
    ...vocabulary,
  ].join("\n");
}
