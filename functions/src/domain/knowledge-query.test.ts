import assert from "node:assert/strict";
import test from "node:test";
import {readFileSync} from "node:fs";
import type {ChatTurn, CorpusItem} from "./types.js";
import {knowledgeV2Enabled, periodRange, placeCounts, planKnowledgeQuery, rankKnowledge, validatedQuotes} from "./knowledge-query.js";
import {publicKnowledgeItem} from "../services/knowledge-corpus.js";
import {answerWithKnowledge, type KnowledgeDependencies} from "../services/knowledge-answer.js";
import {cosine} from "../services/knowledge-model.js";

const seed: CorpusItem[] = JSON.parse(readFileSync(new URL("../../seed/corpus.json", import.meta.url), "utf8"));
const sample = (id: string, title: string, body: string, extra: Partial<CorpusItem> = {}): CorpusItem => ({
  id, title, body, summary: body, category: "Memoria", neighborhood: "Centro", keywords: [], evidence: "community", status: "published", ...extra,
});
const fixtures = [
  ...seed,
  sample("calle7", "La reunión de la calle 7", "En la calle 7 se reunían estudiantes universitarios en un café.", {period: "1930"}),
  sample("calle70", "La reunión de la calle 70", "En la calle 70 había otro café."),
  sample("teatro", "Una noche en el Teatro Argentino", "El Teatro Argentino fue lugar de encuentro.", {period: "1920"}),
  sample("memoria", "Cuadernos de memoria", "Durante la dictadura, estudiantes conservaron sus recuerdos."),
  sample("ana", "Las cartas de Ana", "Ana fue maestra. Falleció en 1980. Su casa estaba en la calle 9.", {period: "1930"}),
  sample("otra-ana", "El diario de Ana", "Una mujer llamada Ana escribió este diario.", {period: "1935"}),
];
const snapshot = {items: fixtures, complete: true, scanned: fixtures.length, excluded: 0};
const history: ChatTurn[] = [{role: "user", text: "Contame una historia de la Catedral"}, {role: "model", text: "Fue en 1882 (error anterior de prueba).", sourceIds: ["catedral"]}];

for (const [question, expected] of [
  ["¿Qué historias hay sobre la Plaza Moreno?", ["catedral"]],
  ["Contame una historia relacionada con la Catedral.", ["catedral"]],
  ["¿Qué historias hablan de la calle 7?", ["calle7"]],
  ["¿Hay alguna historia sobre el Teatro Argentino?", ["teatro"]],
  ["¿Qué historias están relacionadas con estudiantes?", ["calle7", "memoria"]],
  ["¿Hay historias sobre bares o lugares de encuentro?", ["calle7", "teatro", "meridiano", "citybell"]],
  ["¿Hay historias relacionadas con la dictadura?", ["memoria"]],
  ["¿Qué historias hablan de personas que ya murieron?", ["ana"]],
] as const) {
  test(`recuperación: ${question}`, () => {
    const plan = planKnowledgeQuery(question, [], snapshot);
    for (const id of expected) assert.ok(plan.items.some((i) => i.id === id), `${id}: ${plan.items.map((i) => i.id)}`);
    if (question.includes("calle 7")) assert.deepEqual(plan.items.map((i) => i.id), ["calle7"]);
  });
}

for (const question of [
  "¿Quién era el dueño de la casa de esta historia?", "¿En qué año ocurrió exactamente esta historia?",
  "¿Cómo se llamaba la persona que aparece en esta historia?", "¿Qué profesión tenía?",
  "¿Dónde vivía exactamente?", "¿Qué pasó después?", "¿Quiénes fueron testigos?",
  "¿Tenés alguna foto de ese momento?", "¿Esto ocurrió realmente o es una leyenda?", "¿De dónde sacaste ese dato?",
  "¿No había ocurrido en 1882?",
]) {
  test(`seguimiento con fuente persistida: ${question}`, () => {
    const plan = planKnowledgeQuery(question, history, snapshot);
    assert.deepEqual(plan.items.map((i) => i.id), ["catedral"]);
    assert.ok(!plan.answer?.includes("Fue en 1882"));
  });
}

test("una comparación recupera las dos historias, y nunca confirma homónimos automáticamente", () => {
  const plan = planKnowledgeQuery("¿La persona de Las cartas de Ana es la misma que aparece en El diario de Ana?", [], snapshot);
  assert.equal(plan.kind, "compare");
  assert.deepEqual(plan.items.map((i) => i.id), ["ana", "otra-ana"]);
  assert.equal(plan.answer, undefined);
});

test("un tema nuevo reemplaza las anclas anteriores, pero una referencia ambigua pide precisión", () => {
  assert.deepEqual(planKnowledgeQuery("Contame una historia de Tolosa", history, snapshot).items.map((i) => i.id), ["tolosa"]);
  const ambiguous = planKnowledgeQuery("¿Qué profesión tenía?", [{role: "model", text: "Dos historias", sourceIds: ["ana", "otra-ana"]}], snapshot);
  assert.match(ambiguous.answer!, /cuál/);
  assert.match(planKnowledgeQuery("¿Qué pasó después?", [], snapshot).answer!, /qué historia/);
});

test("un lugar inexistente no recupera historias solo porque contienen 'historia'", () => {
  assert.equal(rankKnowledge("¿Qué historias hay sobre Plaza Inexistente?", fixtures).length, 0);
});

test("un retiro editorial elimina la historia anclada y los borradores no se cuentan", () => {
  const withdrawn = {...snapshot, items: fixtures.map((i) => i.id === "catedral" ? {...i, status: "archived" as const} : i)};
  assert.equal(planKnowledgeQuery("¿En qué año ocurrió?", history, withdrawn).items.length, 0);
  assert.match(planKnowledgeQuery('Contame la historia «Una catedral que esperó sus torres».', history, withdrawn).answer!, /No tengo disponible/);
});

test("nombres alternativos, fechas por década y flexiones de fallecimiento se recuperan", () => {
  assert.ok(rankKnowledge("historias sobre Plaza Mariano Moreno", fixtures).some((i) => i.id === "catedral"));
  assert.deepEqual(periodRange("Década de 1960"), {start: 1960, end: 1969, exact: false, label: "Década de 1960"});
  assert.equal(rankKnowledge("personas que ya murieron", [sample("recuerdo", "Un recuerdo", "El escritor, fallecido en 1920, dejó cartas.")]).length, 1);
});

test("no inventa una fecha cuando la fuente solo tiene un intervalo", async () => {
  const result = await answerWithKnowledge({message: "¿En qué año ocurrió exactamente?", history, channel: "web"}, dependencies({
    extract: async () => ({status: "supported", quotes: [{storyId: "catedral", field: "period", quote: "1884–1999"}]}),
  }));
  assert.match(result.answer, /No tengo un año único/);
});

test("la extracción ambigua pide una referencia y la contradictoria muestra ambas citas", async () => {
  const input = {message: "¿Qué profesión tenía?", history: [{role: "model" as const, text: "Relato", sourceIds: ["ana"]}], channel: "web" as const};
  const ambiguous = await answerWithKnowledge(input, dependencies({extract: async () => ({status: "ambiguous", quotes: []})}));
  assert.match(ambiguous.answer, /qué persona o momento/);
  const conflict = await answerWithKnowledge(input, dependencies({extract: async () => ({status: "conflicting", quotes: [
    {storyId: "ana", field: "body", quote: "Ana fue maestra."}, {storyId: "ana", field: "period", quote: "1930"},
  ]})}));
  assert.match(conflict.answer, /versiones distintas/);
});

test("fechas aproximadas, rangos y períodos superpuestos no se convierten en fechas exactas", () => {
  assert.deepEqual(periodRange("1884–1999"), {start: 1884, end: 1999, exact: false, label: "1884–1999"});
  assert.equal(periodRange("hacia 1882"), null);
  assert.equal(periodRange("sin fecha"), null);
  assert.equal(periodRange("1999–1884"), null);
  const plan = planKnowledgeQuery("¿Cuál es la historia más antigua que tenés?", [], snapshot);
  assert.match(plan.answer!, /se superponen/);
  assert.ok(plan.items.some((i) => i.id === "bosque"));
  assert.ok(plan.items.some((i) => i.id === "diagonales"));
  assert.doesNotMatch(plan.answer!, /más antigua es/);
});

test("conteos deduplican por historia y explicitan cobertura; nunca calculan sobre una muestra truncada", () => {
  const counts = placeCounts([sample("plaza", "Plaza Moreno", "Plaza Moreno, Plaza Moreno.", {neighborhood: "Plaza Mariano Moreno"})]);
  assert.deepEqual(counts, [{name: "Plaza Moreno", ids: ["plaza"]}]);
  for (const question of ["¿Qué lugares aparecen más veces en las historias?", "¿Cuál es la historia más antigua?"]) {
    assert.match(planKnowledgeQuery(question, [], {...snapshot, complete: false}).answer!, /incomplet/);
  }
  assert.match(planKnowledgeQuery("¿Qué lugares aparecen más veces en las historias?", [], snapshot).answer!, /una vez por historia/);
});

test("ningún ID, cita o campo inventado pasa la validación literal", () => {
  const quote = "Ana fue maestra.";
  assert.equal(validatedQuotes([{storyId: "ana", field: "body", quote}], fixtures).length, 1);
  for (const raw of [
    {storyId: "ana", field: "body", quote: "Ana fue médica."},
    {storyId: "catedral", field: "body", quote},
    {storyId: "ana", field: "email", quote},
    {storyId: "fake", field: "body", quote},
  ]) assert.deepEqual(validatedQuotes([raw], fixtures), []);
});

test("proyección editorial descarta campos privados, estados no publicados y URLs inseguras", () => {
  const item = publicKnowledgeItem("ana", {...fixtures.find((i) => i.id === "ana"), email: "private@example.test", sourceSubmissionId: "secret", notes: "private", sourceUrl: "javascript:alert(1)"});
  assert.ok(item);
  assert.doesNotMatch(JSON.stringify(item), /private|secret|javascript/);
  assert.equal(publicKnowledgeItem("draft", {...fixtures[0], status: "draft"}), null);
});

test("la activación exige dos condiciones server-side y excluye WhatsApp y comodines", () => {
  const web = {channel: "web", userId: "tester"};
  assert.equal(knowledgeV2Enabled(web, {}), false);
  assert.equal(knowledgeV2Enabled(web, {DARDITO_KNOWLEDGE_V2: "true"}), false);
  assert.equal(knowledgeV2Enabled(web, {DARDITO_KNOWLEDGE_V2: "true", DARDITO_KNOWLEDGE_V2_USERS: "*"}), false);
  const env = {DARDITO_KNOWLEDGE_V2: "true", DARDITO_KNOWLEDGE_V2_USERS: " tester,other "};
  assert.equal(knowledgeV2Enabled(web, env), true);
  assert.equal(knowledgeV2Enabled({channel: "whatsapp", userId: "tester"}, env), false);
  assert.equal(knowledgeV2Enabled({channel: "web", userId: "visitor"}, env), false);
});

const dependencies = (overrides: Partial<KnowledgeDependencies> = {}): KnowledgeDependencies => ({
  snapshot: async () => snapshot, narrative: async ({corpus}) => corpus.length ? `Relato: ${corpus[0]!.body}` : "Hola, soy Dardito.",
  extract: async () => [], imageAvailable: async () => false, random: () => 0, ...overrides,
});

test("saludos, identidad y pedidos al azar mantienen su recorrido y no llaman a extracción", async () => {
  for (const message of ["Hola", "¿Quién sos?", "gracias", "¿Quién es Julieta Quintero Chasman?", "¿Cómo puedo sumar una historia?", "¿Por qué sos un libro?", "¿Y vos la ponés en el mapa?", "¿Y cómo la ubico en el mapa para que quede?"]) {
    const result = await answerWithKnowledge({message, history: [], channel: "web"}, dependencies({snapshot: async () => {throw new Error("No consultar corpus social");}}));
    assert.equal(result.kind, "social");
  }
  const result = await answerWithKnowledge({message: "Contame una historia", history: [], channel: "web"}, dependencies());
  assert.equal(result.kind, "random");
  assert.equal(result.corpus.length, 1);
});

test("se distingue una falla técnica de un dato ausente, y no se responde con una cita inventada", async () => {
  const input = {message: "¿Qué profesión tenía?", history, channel: "web" as const};
  const missing = await answerWithKnowledge(input, dependencies());
  assert.match(missing.answer, /No tengo registrada la profesión/);
  const failed = await answerWithKnowledge(input, dependencies({extract: async () => {throw new Error("offline");}}));
  assert.match(failed.answer, /No pude comprobar/);
  const fake = await answerWithKnowledge(input, dependencies({extract: async () => [{storyId: "catedral", field: "body", quote: "Era arquitecto"}]}));
  assert.doesNotMatch(fake.answer, /Era arquitecto/);
});

test("una foto asociada no se presenta como foto del momento ni se inventa un archivo", async () => {
  const result = await answerWithKnowledge({message: "¿Tenés alguna foto de ese momento?", history, channel: "web"}, dependencies({imageAvailable: async () => true}));
  assert.match(result.answer, /no tengo información que confirme/);
  assert.match(result.answer, /historias\/catedral/);
});

test("el fallo semántico conserva recuperación literal y jamás invalida un filtro de calle", async () => {
  const input = {message: "¿Qué historias hablan de la calle 7?", history: [], channel: "web" as const};
  const result = await answerWithKnowledge(input, dependencies({semantic: async () => ["calle70"]}));
  assert.deepEqual(result.corpus.map((i) => i.id), ["calle7"]);
  const failed = await answerWithKnowledge(input, dependencies({semantic: async () => {throw new Error("offline");}}));
  assert.equal(failed.diagnostic, "semantic_unavailable");
  assert.deepEqual(failed.corpus.map((i) => i.id), ["calle7"]);
});

test("la similitud rechaza vectores corruptos o de dimensiones diferentes", () => {
  assert.equal(cosine([1, 0], [1, 0]), 1);
  assert.equal(cosine([1], [1, 2]), 0);
  assert.equal(cosine([NaN], [1]), 0);
  assert.equal(cosine([0], [0]), 0);
});
