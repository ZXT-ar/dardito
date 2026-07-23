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
  /\bhistoria al azar\b/,
  /\bcontame (algo|una historia)\b/,
  /\bsorprendeme\b/,
  /\bcualquier historia\b/,
];

const contextualFollowUpPatterns = [
  /^(contame|decime|explicame|seguí|segui)\s+(mas|un poco mas|algo mas)(\s.*)?$/,
  /^(y despues|que paso despues|como siguio|donde queda|de que epoca es)(\s.*)?$/,
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

const darditoDomainPatterns = [
  /\b(la plata|platense|historia|historias|misterio|misterios|leyenda|leyendas)\b/,
  /\b(barrio|barrios|turismo|turistico|cultura|arquitectura|memoria|fundacion)\b/,
  /\b(diagonal|diagonales|plaza|catedral|tunel|tuneles|ferrocarril|bosque)\b/,
  /\b(tolosa|gonnet|city bell|meridiano|casco urbano|plaza moreno|dardo rocha)\b/,
  /\b(1882|pedro benoit|republica de los niños)\b/,
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

  if (matchesAny(value, randomStoryPatterns)) {
    return {corpusMode: "random"};
  }

  if (matchesAny(value, socialMessages)) {
    return {corpusMode: "none"};
  }

  if (matchesAny(value, darditoDomainPatterns)) {
    return {corpusMode: "search"};
  }

  if (hasHistory && matchesAny(value, contextualFollowUpPatterns)) {
    return {corpusMode: "search", useHistoryForSearch: true};
  }

  // Las conversaciones sociales y los desvíos de tema también pasan por el LLM.
  // El system prompt conserva la identidad y decide cómo redirigir con naturalidad.
  return {corpusMode: "none"};
}
