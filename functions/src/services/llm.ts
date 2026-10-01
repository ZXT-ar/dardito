import {randomInt} from "node:crypto";
import {GoogleGenAI, ThinkingLevel} from "@google/genai";

import {geminiApiKey, geminiModel} from "../config.js";
import {darditoSystemInstruction, isSelectedStoryRequest, renderCorpus} from "../domain/prompt.js";
import {responseTokenBudget} from "../domain/dardito-parameters.js";
import {generateCompleteText} from "../domain/llm-generation.js";
import {loadDarditoParameters} from "./dardito-parameters.js";
import type {Channel, ChatTurn, CorpusItem} from "../domain/types.js";

function normalizeAnswer(text: string | undefined): string {
  return text
    ?.split("\n")
    .map((line) => line.trim())
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim() ?? "";
}

export async function generateDarditoAnswer(input: {
  channel: Channel;
  message: string;
  history: ChatTurn[];
  corpus: CorpusItem[];
}): Promise<string> {
  const parameters = await loadDarditoParameters();
  const storyDevelopment = input.channel === "web" && isSelectedStoryRequest(input.message);
  const model = geminiModel.value();
  const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});
  const history = input.history
    .slice(-20)
    .map((turn) => `${turn.role === "user" ? "Usuario" : "Dardito"}: ${turn.text}`)
    .join("\n");

  const baseContents = [
    renderCorpus(input.corpus),
    history ? `CONVERSACIÓN RECIENTE:\n${history}` : "",
    `CONSULTA ACTUAL:\n${input.message}`,
  ].filter(Boolean).join("\n\n");
  const generate = async (contents: string): Promise<string> => {
    const tokenBudget = storyDevelopment
      ? Math.max(3_072, responseTokenBudget(parameters, input.channel))
      : responseTokenBudget(parameters, input.channel);
    const text = await generateCompleteText((maxOutputTokens) => ai.models.generateContent({
      model,
      contents,
      config: {
        systemInstruction: darditoSystemInstruction(input.channel, parameters, storyDevelopment),
        maxOutputTokens,
        // These are grounded chat replies; bound Gemini 3's reasoning effort.
        ...(/^gemini-3[.-]/.test(model)
          ? {thinkingConfig: {thinkingLevel: ThinkingLevel.LOW}}
          : {}),
        temperature: 0.9,
        topP: 0.95,
        // A fresh seed prevents identical social replies while keeping the same voice.
        seed: randomInt(1, 2_147_483_647),
      },
    }), tokenBudget);
    return normalizeAnswer(text);
  };

  const answer = await generate(baseContents);
  if (!answer) {
    throw new Error("El proveedor LLM devolvió una respuesta vacía.");
  }
  return answer;
}
