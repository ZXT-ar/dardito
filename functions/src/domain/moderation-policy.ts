import type {ModerationCategory} from "./types.js";

export interface ModerationClassification {
  categories: ModerationCategory[];
  severity: "none" | "yellow" | "red";
}

function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[@4]/g, "a")
    .replace(/[3]/g, "e")
    .replace(/[1!]/g, "i")
    .replace(/[0]/g, "o")
    .replace(/[5$]/g, "s")
    .replace(/[7]/g, "t")
    .replace(/[^a-z0-9ñ\s]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function matchesAny(value: string, patterns: RegExp[]): boolean {
  return patterns.some((pattern) => pattern.test(value));
}

const harassmentPatterns = [
  /\b(bolud[oa]|pelotud[oa]|idiota|imbecil|estupid[oa]|forr[oa]|mogolic[oa])s?\b/,
  /\b(hijo de p[u]?ta|la concha de tu madre|andate a la mierda|sos una mierda|jodete)\b/,
];

const sexualAnatomyPatterns = [
  /\b(pito|pene|culo|teta|tetas|concha|vagina|genital|genitales)\b/,
];

const obscenePatterns = [
  /\b(mandame|mostrame|genera|crea|escribi|describi|quiero|dame|busco)\b.*\b(porno|pornografia|sexo explicito|desnudos?|contenido sexual)\b/,
  /\b(porno infantil|material sexual infantil)\b/,
];

const weaponTerms = [
  /\b(arma|armas|pistola|revolver|rifle|escopeta|bomba|explosivo|granada|municion)\b/,
];
const weaponIntent = [
  /\b(como|pasos?|instrucciones?|fabricar|hacer|armar|construir|comprar|conseguir|usar|disparar|detonar|ocultar|modificar)\b/,
];

const violenceTerms = [
  /\b(matar|asesinar|torturar|descuartizar|apuñalar|degollar|hacer sufrir|lastimar gravemente)\b/,
];
const violenceIntent = [
  /\b(como|pasos?|instrucciones?|quiero|voy a|ayudame|decime|explicame|mostrame|detalladamente)\b/,
];

const credibleThreatPatterns = [
  /\b(voy a|quiero|planeo|pienso)\b.*\b(matar|asesinar|apuñalar|disparar|lastimar)\b.*\b(a|al|una|un|mi|te|lo|la)\b/,
  /\b(te voy a matar|los voy a matar|la voy a matar|lo voy a matar)\b/,
];

const sexualMinorsPatterns = [
  /\b(porno infantil|material sexual infantil|sexo con menores?|desnudos? de menores?)\b/,
  /\b(niñ[oa]s?|menores?)\b.*\b(sexo|sexual|porno|desnudos?)\b/,
];

/**
 * Clasificación conservadora y determinística. Un mensaje puede activar varias
 * categorías, pero siempre genera como máximo una infracción.
 */
export function classifyModeration(message: string): ModerationClassification {
  const value = normalize(message);
  const categories = new Set<ModerationCategory>();

  if (matchesAny(value, harassmentPatterns)) categories.add("harassment");
  if (matchesAny(value, sexualAnatomyPatterns)) categories.add("sexual_anatomy");
  if (matchesAny(value, obscenePatterns)) categories.add("obscene_request");
  if (
    matchesAny(value, weaponTerms) &&
    matchesAny(value, weaponIntent)
  ) {
    categories.add("weapons_instructions");
  }
  if (
    matchesAny(value, violenceTerms) &&
    matchesAny(value, violenceIntent)
  ) {
    categories.add("graphic_violence");
  }
  if (matchesAny(value, credibleThreatPatterns)) categories.add("credible_threat");
  if (matchesAny(value, sexualMinorsPatterns)) categories.add("sexual_minors");

  const result = [...categories];
  if (result.includes("credible_threat") || result.includes("sexual_minors")) {
    return {categories: result, severity: "red"};
  }
  return {
    categories: result,
    severity: result.length > 0 ? "yellow" : "none",
  };
}
