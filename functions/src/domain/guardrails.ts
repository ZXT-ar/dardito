export type CorpusMode = "none" | "search" | "random";

export interface InteractionDecision {
  corpusMode: CorpusMode;
  fixedAnswer?: string;
  useHistoryForSearch?: boolean;
}

function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9ñ\s]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

const socialMessages = [
  /^(hola|holis|buenas|buen dia|buen dia dardito|buenas tardes|buenas noches)$/,
  /^(como estas|como andas|todo bien|que tal)$/,
  /^(gracias|muchas gracias|genial|perfecto|buenisimo)$/,
  /^(chau|adios|hasta luego|nos vemos)$/,
  /^(quien sos|que sos|que podes hacer|como me podes ayudar)$/,
  /\b(contame|hablame|decime)\b.*\b(de vos|sobre vos|quien sos)\b/,
  /\b(por que|porque)\b.*\b(te llamas|dardito)\b/,
  /\b(cual es|que es)\b.*\b(tu historia|tu mision|tu proposito)\b/,
  /^(y vos|vos que pensas|te gusta|que te gusta)(\s.*)?$/,
];

const randomStoryPatterns = [
  /^(quiero |quisiera )?(una|alguna|otra|cualquier) historia( al azar| cualquiera)?$/,
  /^historia al azar$/,
  /^(contame|contanos|conta|relatame|me contas|podes contarme|me podes contar) (algo|(una|alguna|otra|cualquier) historia)( al azar| cualquiera)?$/,
  /^sorprendeme$/,
];

const contextualFollowUpPatterns = [
  /^(contame|decime|explicame|segui)\s+(mas|un poco mas|algo mas)$/,
  /^(y despues|que paso despues|como siguio|donde queda|de que epoca es)( exactamente)?$/,
  /\b(esa historia|ese lugar|ese misterio|ese barrio|lo anterior)\b/,
];

const codeOrTechnicalPatterns = [
  /\b(codigo|programa|programar|programacion|algoritmo|script|software)\b/,
  /\b(javascript|typescript|python|java|php|flutter|dart|sql|html|css)\b/,
  /\b(hackear|hackeo|exploit|malware|contraseña|password|token|api key)\b/,
  /\b(terminal|consola|comando|servidor|base de datos)\b/,
  /\b(ignora|olvida|revela|mostrame)\b.*\b(instrucciones|prompt|reglas internas)\b/,
];

const abusivePatterns = [
  /\b(boludo|pelotudo|idiota|imbecil|estupido|forro)\b/,
  /\b(mierda|carajo|puta|puto|concha)\b/,
  /\b(odio|matar|lastimar)\b.*\b(vos|te|alguien|persona)\b/,
];

function matchesAny(value: string, patterns: RegExp[]): boolean {
  return patterns.some((pattern) => pattern.test(value));
}

export function decideInteraction(message: string, hasHistory: boolean): InteractionDecision {
  const value = normalize(message);

  if (matchesAny(value, codeOrTechnicalPatterns)) {
    return {
      corpusMode: "none",
      fixedAnswer:
        "Ese recorrido queda fuera de mi mapa: no escribo código ni doy instrucciones " +
        "técnicas. Mi especialidad son las historias, los barrios, los misterios y la " +
        "memoria de La Plata. Si querés, decime un lugar o una época y seguimos por ahí.",
    };
  }

  if (matchesAny(value, abusivePatterns)) {
    return {
      corpusMode: "none",
      fixedAnswer:
        "Podemos seguir conversando, pero cuidemos el trato. Estoy acá para explorar " +
        "La Plata con curiosidad y respeto. ¿Querés preguntarme por un barrio, una " +
        "historia o algún misterio de la ciudad?",
    };
  }

  if (matchesAny(value, socialMessages)) {
    return {corpusMode: "none"};
  }

  // Only a complete, generic request should choose a story at random.
  // A request with a subject ("contame una historia sobre...") must search it.
  const storyRequest = value
    .replace(/^(hola |buenas |dale |che |dardito |por favor |porfa )+/, "")
    .replace(/( por favor| porfa| dardito)+$/, "");
  if (matchesAny(storyRequest, randomStoryPatterns)) {
    return {corpusMode: "random"};
  }

  if (hasHistory && matchesAny(storyRequest, contextualFollowUpPatterns)) {
    return {corpusMode: "search", useHistoryForSearch: true};
  }

  // Published titles need not contain a fixed list of domain words. Let the
  // corpus relevance filter decide whether there is information for the query.
  // With no match, the LLM still receives an empty corpus and the editorial rules.
  return {corpusMode: "search"};
}
