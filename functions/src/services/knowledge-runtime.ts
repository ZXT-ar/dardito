import {geminiApiKey, geminiModel} from "../config.js";
import {loadDarditoParameters} from "./dardito-parameters.js";
import {createKnowledgeModel} from "./knowledge-model.js";
import {loadKnowledgeSnapshot, hasPublicStoryImage} from "./knowledge-corpus.js";
import {answerWithKnowledge, type KnowledgeInput} from "./knowledge-answer.js";
import {generateDarditoAnswer} from "./llm.js";

let cached: {key: string; model: ReturnType<typeof createKnowledgeModel>} | undefined;
export async function answerKnowledgeCanary(input: KnowledgeInput) {
  const parameters = await loadDarditoParameters();
  const key = JSON.stringify([geminiModel.value(), parameters]);
  if (!cached || cached.key !== key) cached = {key, model: createKnowledgeModel(geminiApiKey.value(), geminiModel.value(), parameters)};
  return answerWithKnowledge(input, {
    ...cached.model,
    // Preserve the deployed narrator and editorial tone controls for existing flows.
    narrative: generateDarditoAnswer,
    // Embeddings have their own opt-in, so the initial canary has predictable cost.
    semantic: process.env.DARDITO_KNOWLEDGE_V2_SEMANTIC === "true" ? cached.model.semantic : undefined,
    snapshot: loadKnowledgeSnapshot,
    imageAvailable: hasPublicStoryImage,
  });
}
