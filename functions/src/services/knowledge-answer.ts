import type {Channel, ChatTurn, CorpusItem} from "../domain/types.js";
import {isEditorialQuestion, planKnowledgeQuery, queryKind, renderEvidenceAnswer, validatedQuotes, type KnowledgePlan, type KnowledgeSnapshot} from "../domain/knowledge-query.js";
import {decideInteraction} from "../domain/guardrails.js";

export interface KnowledgeInput {channel: Channel; message: string; history: ChatTurn[]}
export interface KnowledgeDependencies {
  snapshot: () => Promise<KnowledgeSnapshot>;
  narrative: (input: KnowledgeInput & {corpus: CorpusItem[]}) => Promise<string>;
  extract: (input: KnowledgeInput & {plan: KnowledgePlan}) => Promise<unknown>;
  semantic?: (message: string, items: CorpusItem[]) => Promise<string[]>;
  imageAvailable: (storyId: string) => Promise<boolean>;
  random?: () => number;
}
export interface KnowledgeAnswer {answer: string; corpus: CorpusItem[]; kind: string; matched: number; diagnostic?: string}

export async function answerWithKnowledge(input: KnowledgeInput, deps: KnowledgeDependencies): Promise<KnowledgeAnswer> {
  const decision = decideInteraction(input.message, input.history.length > 0);
  if (decision.fixedAnswer) return {answer: decision.fixedAnswer, corpus: [], kind: "guardrail", matched: 0};
  if (decision.corpusMode === "none" || isEditorialQuestion(input.message)) return {answer: await deps.narrative({...input, corpus: []}), corpus: [], kind: "social", matched: 0};
  const snapshot = await deps.snapshot();
  if (decision.corpusMode === "random") {
    const items = snapshot.items.filter((i) => i.status === "published");
    const selected = items[Math.floor((deps.random?.() ?? Math.random()) * items.length)];
    const corpus = selected ? [selected] : [];
    return {answer: selected ? await deps.narrative({...input, corpus}) : "Todavía no tengo una historia publicada disponible para contarte.", corpus, kind: "random", matched: corpus.length};
  }
  let plan = planKnowledgeQuery(input.message, input.history, snapshot);
  let diagnostic: string | undefined;
  if (deps.semantic && ["story", "list"].includes(queryKind(input.message))) {
    try {
      const ids = await deps.semantic(input.message, snapshot.items);
      plan = planKnowledgeQuery(input.message, input.history, snapshot, ids);
    } catch {
      diagnostic = "semantic_unavailable"; // Exact/lexical retrieval remains usable.
    }
  }
  let corpus = plan.items;
  let answer = plan.answer;
  if (!answer && plan.kind === "photo") {
    const item = plan.items[0]!;
    const available = await deps.imageAvailable(item.id);
    answer = available
      ? `Hay una imagen pública asociada a «${item.title}», pero no tengo información que confirme que sea una foto del momento narrado. Podés verla en la ficha: https://dardito-742d2.web.app/historias/${encodeURIComponent(item.id)}`
      : `No tengo una foto pública autorizada disponible para mostrar de «${item.title}». Eso no demuestra que no existan fotografías de ese momento.`;
  }
  if (!answer && ["fact", "compare", "source"].includes(plan.kind)) {
    let raw: unknown;
    try { raw = await deps.extract({...input, plan}); }
    catch { diagnostic = "evidence_unavailable"; }
    const extraction = raw && typeof raw === "object" && !Array.isArray(raw) ? raw as {quotes?: unknown; status?: unknown} : null;
    const supplied = extraction ? extraction.quotes : raw;
    const quotes = extraction?.status === "missing" || extraction?.status === "ambiguous" ? [] : validatedQuotes(supplied, plan.items);
    if (Array.isArray(supplied) && supplied.length && quotes.length !== supplied.length && extraction?.status !== "ambiguous" && extraction?.status !== "missing") diagnostic = "evidence_unavailable";
    answer = diagnostic === "evidence_unavailable"
      ? "No pude comprobar ese dato en este momento. Probá nuevamente; prefiero no afirmar algo sin revisar la historia."
      : renderEvidenceAnswer(plan, quotes, input.message);
    if (extraction?.status === "ambiguous") answer = "¿A qué persona o momento te referís dentro de esta historia? Hay más de una interpretación posible y prefiero revisar el dato correcto.";
    if (extraction?.status === "conflicting" && quotes.length >= 2) answer = `Los datos disponibles presentan versiones distintas; no puedo elegir una como cierta:\n\n${answer}`;
    // Keep scope for follow-ups even when the requested attribute is missing.
  }
  if (!answer) {
    // A request for one story needs one unambiguous memory anchor, not six candidates.
    corpus = plan.items.slice(0, 1);
    answer = await deps.narrative({...input, corpus});
  }
  return {answer, corpus, kind: plan.kind, matched: plan.matched, ...(diagnostic ? {diagnostic} : {})};
}
