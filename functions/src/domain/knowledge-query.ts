import type {ChatTurn, CorpusItem} from "./types.js";

export interface KnowledgeSnapshot {
  items: CorpusItem[];
  complete: boolean;
  scanned: number;
  excluded: number;
}

export type QueryKind = "story" | "list" | "fact" | "compare" | "source" | "evidence" | "photo" | "places" | "oldest";
export interface KnowledgePlan {
  kind: QueryKind;
  items: CorpusItem[];
  answer?: string;
  matched: number;
}

export const normalizeKnowledge = (value: string): string => value.normalize("NFD")
  .replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
const contains = (text: string, phrase: string): boolean => (` ${text} `).includes(` ${phrase} `);
const stop = new Set(("que cuales cual hay alguna algun historias historia contame contarme contanos sobre " +
  "relacionadas relacionada relacionados relacionado hablan habla tenes tienen tengo tiene esta este " +
  "las los una uno unos del con por para como donde cuando quien personas persona aparecen aparece " +
  "saber mas quiero podes puedes me de la el en un y a o se al es son lo tu esa ese exactamente " +
  "profesion tenia vivia llamaba despues testigos ocurrido ocurrio ano anos fecha dato sacaste habia fueron momento realmente").split(" "));

// Search vocabulary, not historical assertions. These aliases never become facts.
const concepts: Array<{name: string; aliases: string[]}> = [
  {name: "Plaza Moreno", aliases: ["plaza moreno", "plaza mariano moreno"]},
  {name: "Catedral", aliases: ["catedral", "catedral de la inmaculada concepcion"]},
  {name: "Teatro Argentino", aliases: ["teatro argentino"]},
  {name: "estudiantes", aliases: ["estudiantes", "estudiantil", "universitarios", "universitaria", "universidad", "alumnos", "facultad"]},
  {name: "encuentros", aliases: ["bares", "bar", "cafes", "cafe", "lugares de encuentro", "lugar de encuentro", "punto de encuentro", "espacios de encuentro", "encuentros culturales", "tertulias", "gastronomia"]},
  {name: "dictadura", aliases: ["dictadura", "dictadura militar", "terrorismo de estado", "desaparecidos", "desaparecidas", "represion", "noche de los lapices"]},
  {name: "fallecidos", aliases: ["murieron", "murio", "fallecido", "fallecida", "fallecidos", "fallecio", "fallecieron", "fallecimiento", "fallecidas", "asesinado", "asesinada"]},
];

function textOf(item: CorpusItem): string {
  return normalizeKnowledge([item.title, item.summary, item.body, item.neighborhood, item.category, ...item.keywords].join(" "));
}

export function rankKnowledge(message: string, items: CorpusItem[], semanticIds: string[] = []): CorpusItem[] {
  const query = normalizeKnowledge(message);
  const terms = [...new Set(query.split(" ").filter((t) => t && !stop.has(t)))];
  const streets = [...query.matchAll(/\b(?:calle|avenida|diagonal) (\d+[a-z]?)\b/g)].map((m) => m[0]);
  const namedPlaces = [...query.matchAll(/\b(?:plaza|teatro|parque)\s+([a-z]+(?:\s+[a-z]+){0,3})/g)]
    .map((m) => {
      const words = m[0].split(" ");
      const end = words.findIndex((word, index) => index > 0 && stop.has(word));
      return words.slice(0, end < 0 ? words.length : end).join(" ");
    }).filter((phrase) => phrase.includes(" "));
  const places = concepts.slice(0, 3).filter((c) => c.aliases.some((a) => contains(query, a)));
  const themes = concepts.slice(3).filter((c) => c.aliases.some((a) => contains(query, a)));
  const semantic = new Set(semanticIds);
  return items.filter((i) => i.status === "published").map((item) => {
    const text = textOf(item);
    const title = normalizeKnowledge(item.title);
    // Named streets/landmarks are mandatory, not a weak ranking hint.
    if (streets.length && !streets.every((s) => contains(text, s))) return {item, score: 0};
    if (namedPlaces.length && !namedPlaces.every((s) => {
      const known = concepts.slice(0, 3).find((c) => c.aliases.includes(s));
      return (known?.aliases ?? [s]).some((alias) => contains(text, alias));
    })) return {item, score: 0};
    if (places.length && !places.every((p) => p.aliases.some((a) => contains(text, a)))) return {item, score: 0};
    const titleMatch = title.length > 5 && contains(query, title);
    const themeMatch = themes.length > 0 && themes.every((c) => c.aliases.some((a) => contains(text, a)));
    let score = titleMatch ? 1000 : 0;
    for (const term of terms) {
      if (contains(title, term)) score += 8;
      else if (contains(normalizeKnowledge(item.neighborhood), term)) score += 7;
      else if (contains(text, term)) score += 2;
    }
    if (themeMatch) score += 15;
    if (semantic.has(item.id)) score += 12;
    if (themes.length && !themeMatch && !semantic.has(item.id) && !titleMatch) score = 0;
    return {item, score};
  }).filter((entry) => entry.score >= 2)
    .sort((a, b) => b.score - a.score || a.item.title.localeCompare(b.item.title, "es"))
    .map(({item}) => item);
}

export function queryKind(message: string): QueryKind {
  const q = normalizeKnowledge(message);
  if (/\blugares\b.*\b(mas|frecuentes|repetidos)\b/.test(q)) return "places";
  if (/\b(historia|historias)\b.*\b(mas antigua|mas antiguas|mas vieja)\b/.test(q)) return "oldest";
  if (/\b(misma persona|mismo personaje|es la misma|es el mismo|comparar|compara|relacion entre)\b/.test(q)) return "compare";
  if (/\b(foto|fotos|fotografia|fotografias|imagen|imagenes)\b/.test(q)) return "photo";
  if (/\b(fuente|fuentes|de donde sacaste|de donde sale|de donde salio|autor|autoria)\b/.test(q)) return "source";
  if (/\b(realmente|leyenda|comprobado|es real|es verdad|ocurrio de verdad)\b/.test(q)) return "evidence";
  if (/\b(que historias|cuales historias|historias.*(?:hablan|relacionadas|sobre)|hay alguna historia|hay historias)\b/.test(q)) return "list";
  if (/\b(quien|quienes|como se llamaba|profesion|vivia|domicilio|dueno|testigos|que paso despues|cuando|en que ano|habia ocurrido|no fue|no era|esa fecha|ese dato|estas seguro)\b/.test(q)) return "fact";
  return "story";
}

export function isEditorialQuestion(message: string): boolean {
  const q = normalizeKnowledge(message);
  return /\b(julieta|quien te creo|quien te hizo|quien te invento|sos una inteligencia artificial|sos ia|sos un libro|tenes una hoja|tus ojos|tenes familia|tu familia|tu edad|cuantos anos tenes|donde vivis|de quien sos|sos del pro|sos de julieta|a quien votas|autoría visible|autoria visible)\b/.test(q) ||
    /\b(sumar|compartir|enviar|aportar|contarte|subir|registrar|publicar)\b.*\b(historia|foto|audio|documento|relato|aporte)\b/.test(q) ||
    /\b(formulario|la pones en el mapa|la ubico en el mapa|como participo|como colaborar|quien impulsa el proyecto)\b/.test(q);
}

function historyAnchors(history: ChatTurn[]): string[] {
  for (const turn of [...history].reverse()) {
    if (turn.role === "model" && turn.sourceIds?.length) return turn.sourceIds;
  }
  return [];
}

function isFollowUp(message: string, kind: QueryKind): boolean {
  const q = normalizeKnowledge(message);
  return ["fact", "photo", "source", "evidence", "compare"].includes(kind) ||
    /\b(esa historia|esta historia|ese lugar|esa persona|ese momento|lo anterior)\b/.test(q) ||
    /^(y despues|contame mas|segui|continua|de que epoca es|donde queda)( por favor)?$/.test(q);
}

export interface PeriodRange {start: number; end: number; exact: boolean; label: string}
export function periodRange(period: string | undefined): PeriodRange | null {
  if (!period) return null;
  const q = normalizeKnowledge(period);
  if (/^\d{4}$/.test(q)) return {start: Number(q), end: Number(q), exact: true, label: period};
  const range = q.match(/^(\d{4}) (\d{4}|actualidad|presente)$/);
  if (range) {
    const start = Number(range[1]);
    const end = /^\d/.test(range[2]!) ? Number(range[2]) : Infinity;
    return start <= end ? {start, end, exact: false, label: period} : null;
  }
  const century = q.match(/^(?:(?:finales|principios|mediados) del )?siglo (xvi|xvii|xviii|xix|xx|xxi)$/);
  if (century) {
    const n = ["xvi", "xvii", "xviii", "xix", "xx", "xxi"].indexOf(century[1]!) + 16;
    // Do not invent a narrower interval for "finales" or "principios".
    return {start: (n - 1) * 100 + 1, end: n * 100, exact: false, label: period};
  }
  const decade = q.match(/^(?:decada de |anos )(\d{3}0)$/);
  if (decade) return {start: Number(decade[1]), end: Number(decade[1]) + 9, exact: false, label: period};
  return null;
}

function oldest(snapshot: KnowledgeSnapshot): KnowledgePlan {
  if (!snapshot.complete) return {kind: "oldest", items: [], matched: 0, answer: "No puedo comparar la antigüedad de todas las historias porque la consulta del catálogo está incompleta."};
  const dated = snapshot.items.flatMap((item) => {
    const range = periodRange(item.period);
    return range ? [{item, range}] : [];
  });
  if (!dated.length) return {kind: "oldest", items: [], matched: 0, answer: "No tengo períodos comparables suficientes para identificar la historia más antigua."};
  const earliestEnd = Math.min(...dated.map((v) => v.range.end));
  const candidates = dated.filter((v) => v.range.start <= earliestEnd)
    .sort((a, b) => a.range.start - b.range.start || a.item.title.localeCompare(b.item.title));
  const unknown = snapshot.items.length - dated.length + snapshot.excluded;
  const selected = candidates.slice(0, 6);
  const lines = selected.map(({item, range}) => `«${item.title}»: ${range.label}.`).join("\n");
  return {kind: "oldest", items: selected.map((v) => v.item), matched: candidates.length,
    answer: `${candidates.length === 1 ? "Entre las historias con períodos comparables, la más antigua es:" : "No puedo elegir una única historia más antigua: estos períodos se superponen:"}\n${lines}\nComparo el período narrado, no la fecha de carga.${candidates.length > 6 ? ` Hay ${candidates.length} candidatas; muestro 6.` : ""}${unknown ? ` Hay ${unknown} historias sin datos comparables; podrían cambiar el resultado.` : ""}`};
}

export function placeCounts(items: CorpusItem[]): Array<{name: string; ids: string[]}> {
  const names = new Map<string, string>();
  for (const item of items) {
    if (item.neighborhood.trim()) names.set(normalizeKnowledge(item.neighborhood), item.neighborhood);
    const text = `${item.title}\n${item.summary}\n${item.body}`;
    for (const match of text.matchAll(/\b(?:calle|avenida|diagonal)\s+\d+[a-z]?\b/giu)) {
      names.set(normalizeKnowledge(match[0]), match[0]);
    }
    // Conservative, reproducible named-place extraction from published text.
    // No inferred names and no generated editorial facts. Keep all original spellings.
    for (const match of text.matchAll(/\b(?:Plaza|Teatro|Parque|Museo|Estación|Palacio|Cementerio|Paseo|Café|Observatorio|Universidad|Facultad|República)(?:[ \t]+(?:(?:de|del|la|las|los|el|y)[ \t]+)*[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+){1,6}/gu)) {
      names.set(normalizeKnowledge(match[0]), match[0]);
    }
  }
  for (const c of concepts.slice(0, 3)) {
    for (const alias of c.aliases) names.delete(alias);
    names.set(normalizeKnowledge(c.name), c.name);
  }
  return [...names].map(([key, name]) => ({name, ids: items.filter((item) => {
    const c = concepts.slice(0, 3).find((c) => c.name === name);
    return (c?.aliases ?? [key]).some((alias) => contains(textOf(item), alias));
  }).map((i) => i.id)})).filter((v) => v.ids.length)
    .sort((a, b) => b.ids.length - a.ids.length || a.name.localeCompare(b.name, "es"));
}

export function planKnowledgeQuery(message: string, history: ChatTurn[], snapshot: KnowledgeSnapshot, semanticIds: string[] = []): KnowledgePlan {
  const items = snapshot.items.filter((i) => i.status === "published");
  const kind = queryKind(message);
  if (kind === "oldest") return oldest({...snapshot, items});
  if (kind === "places") {
    if (!snapshot.complete) return {kind, items: [], matched: 0, answer: "No puedo calcular frecuencias con un catálogo incompleto."};
    const counts = placeCounts(items).slice(0, 8);
    return {kind, items: [], matched: counts.length, answer: counts.length
      ? `Entre los lugares identificados en los relatos y sus barrios/zonas, aparecen más:\n${counts.map((v) => `${v.name}: ${v.ids.length} historia${v.ids.length === 1 ? "" : "s"}.`).join("\n")}\nConté cada lugar una vez por historia, sobre ${items.length} historias publicadas consultadas. La identificación automática puede omitir lugares o separar variantes de un nombre.${snapshot.excluded ? ` ${snapshot.excluded} registros no pudieron analizarse.` : ""}`
      : "No tengo lugares identificados suficientes para calcular frecuencias."};
  }
  const q = normalizeKnowledge(message);
  if (/\b(?:historia de|calle) [xy]\b/.test(q)) return {kind, items: [], matched: 0, answer: "Necesito el título o el lugar concreto de la historia: X e Y no identifican un relato. Con ese dato puedo revisarlo."};
  const quotedTitles = [...message.matchAll(/(?:historia|relato)\s*[“"«]([^”"»]+)[”"»]/giu)].map((m) => normalizeKnowledge(m[1]!));
  if (quotedTitles.some((title) => !items.some((item) => normalizeKnowledge(item.title) === title))) {
    return {kind, items: [], matched: 0, answer: "No tengo disponible una historia publicada con ese título exacto. No puedo completar su contenido con otro relato; revisá el título o su disponibilidad en el mapa."};
  }
  const explicit = items.filter((i) => contains(q, normalizeKnowledge(i.title)) || q === normalizeKnowledge(i.id));
  const ranked = rankKnowledge(message, items, semanticIds);
  const anchors = historyAnchors(history).map((id) => items.find((i) => i.id === id)).filter((i): i is CorpusItem => !!i);
  // A new named subject takes precedence over the previous conversation.
  const namedSubject = /\b(calle|avenida|diagonal) \d+\b/.test(q) || concepts.slice(0, 3).some((c) => c.aliases.some((a) => contains(q, a))) ||
    /\b(?:de|sobre|tenía|vivía)\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+/u.test(message) ||
    items.some((i) => i.neighborhood.length > 3 && contains(q, normalizeKnowledge(i.neighborhood)));
  let relevant = explicit.length ? explicit : isFollowUp(message, kind) && !namedSubject && anchors.length ? anchors : ranked;
  if (!relevant.length && !isFollowUp(message, kind)) relevant = ranked;
  if (!relevant.length) return {kind, items: [], matched: 0, answer: isFollowUp(message, kind) && !namedSubject && !explicit.length
    ? "¿A qué historia te referís? Decime el título o el lugar para revisar ese dato."
    : "No encontré una historia publicada que responda a esa consulta. Eso no significa que el hecho o el lugar no existan. Podés precisar el título, el lugar o el tema."};
  const matched = relevant.length;
  relevant = relevant.slice(0, 6);
  if (["fact", "source", "evidence", "photo"].includes(kind) && relevant.length > 1) return {kind, items: relevant, matched,
    answer: `Encontré más de una historia posible. ¿Sobre cuál querés que revise ese dato?\n${relevant.map((i) => `«${i.title}»`).join("\n")}`};
  if (kind === "compare" && relevant.length < 2) return {kind, items: relevant, matched,
    answer: "Necesito identificar las dos historias para compararlas. Decime sus títulos; no alcanza con que aparezca un nombre parecido."};
  if (kind === "list") return {kind, items: relevant, matched,
    answer: `Encontré ${matched} historia${matched === 1 ? "" : "s"} relacionada${matched === 1 ? "" : "s"}${matched > relevant.length ? `; te muestro ${relevant.length}` : ""}:\n${relevant.map((i) => `«${i.title}»: ${i.summary}`).join("\n\n")}`};
  if (kind === "source" && !/\b(autor|autoria|quien escribio|de quien)\b/.test(q)) return {kind, items: relevant, matched,
    answer: relevant.map((i) => `Para «${i.title}», la fuente editorial registrada es: ${i.sourceName || "no consta una fuente editorial"}.${i.sourceUrl ? `\n${i.sourceUrl}` : ""} No hice una verificación externa de esa fuente.`).join("\n")};
  if (kind === "evidence") return {kind, items: relevant, matched, answer: relevant.map((i) =>
    `«${i.title}» ${i.evidence === "documented" ? "está clasificada como Documentada, con respaldo editorial" : i.evidence === "oral_tradition" ? "recoge tradición oral o una versión no verificada; no puedo presentarla como un hecho comprobado" : "es un aporte cuya publicación no demuestra por sí sola todos los hechos narrados"}.${/\b(mito|leyenda|creencia)\b/.test(textOf(i)) ? " El relato incluye creencias o leyendas: la clasificación editorial no prueba que esas creencias sean ciertas." : ""}${i.sourceName ? ` Fuente registrada: ${i.sourceName}.` : ""}`).join("\n")};
  return {kind, items: relevant, matched};
}

export interface EvidenceQuote {storyId: string; field: "body" | "summary" | "period" | "sourceName"; quote: string}
export function validatedQuotes(value: unknown, items: CorpusItem[]): EvidenceQuote[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 6).flatMap((raw) => {
    if (!raw || typeof raw !== "object") return [];
    const {storyId, field, quote} = raw as Record<string, unknown>;
    if (typeof storyId !== "string" || !["body", "summary", "period", "sourceName"].includes(String(field)) || typeof quote !== "string" || quote.length < 3 || quote.length > 650) return [];
    const item = items.find((i) => i.id === storyId);
    const text = item?.[field as EvidenceQuote["field"]];
    if (typeof text !== "string" || !text.includes(quote)) return [];
    return [{storyId, field: field as EvidenceQuote["field"], quote}];
  });
}

export function renderEvidenceAnswer(plan: KnowledgePlan, quotes: EvidenceQuote[], message = ""): string {
  const q = normalizeKnowledge(message);
  const missing = /\bdueno\b/.test(q) ? "La historia no identifica al dueño de esa casa." :
    /\bprofesion\b/.test(q) ? "No tengo registrada la profesión de esa persona en esta historia." :
    /\btestigos\b/.test(q) ? "El relato no identifica testigos de ese hecho." :
    /\b(llamaba|nombre)\b/.test(q) ? "El relato no registra el nombre que me preguntás." :
    /\b(vivia|domicilio)\b/.test(q) ? "No tengo un domicilio documentado de esa persona en esta historia." :
    /\bdespues\b/.test(q) ? "El relato disponible no cuenta qué pasó después de ese momento." :
    /\b(autor|autoria|escribio)\b/.test(q) ? "La fuente disponible no identifica esa autoría; no puedo deducirla del título ni del nombre de quien envió el aporte." :
    "La historia disponible no aporta información suficiente para responder ese dato con seguridad.";
  if (!quotes.length) return plan.kind === "compare"
    ? "No tengo evidencia explícita suficiente para confirmar si las dos historias hablan de la misma persona. Coincidir en nombre, lugar o época no alcanza para establecer ese vínculo."
    : missing;
  const evidence = quotes.map((q) => {
    const item = plan.items.find((i) => i.id === q.storyId)!;
    return `En «${item.title}» consta: «${q.quote}»${item.sourceName ? `\nFuente registrada: ${item.sourceName}.` : ""}${item.evidence !== "documented" ? " Es una versión aportada; no confirma por sí sola que los hechos ocurrieran." : ""}`;
  }).join("\n\n");
  const imprecisePeriod = /\b(ano|fecha)\b/.test(q) && quotes.every((v) => v.field === "period" && !periodRange(v.quote)?.exact);
  return plan.kind === "compare" ? `${evidence}\nEstos son los datos explícitos de cada relato; no permiten agregar vínculos que las fuentes no establecen.` :
    `${imprecisePeriod ? "No tengo un año único para ese relato; consta un período:\n" : ""}${evidence}`;
}

export function knowledgeV2Enabled(request: {channel: string; userId?: string}, env: NodeJS.ProcessEnv = process.env): boolean {
  // No wildcard and no client-supplied flag. WhatsApp requires a later rollout.
  return env.DARDITO_KNOWLEDGE_V2 === "true" && request.channel === "web" && !!request.userId &&
    (env.DARDITO_KNOWLEDGE_V2_USERS ?? "").split(",").map((id) => id.trim()).filter((id) => id && id !== "*").includes(request.userId);
}
