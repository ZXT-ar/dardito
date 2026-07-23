import {randomInt} from "node:crypto";
import {GoogleGenAI} from "@google/genai";

import {geminiApiKey, geminiModel} from "../config.js";
import {darditoSystemInstruction, renderCorpus} from "../domain/prompt.js";
import type {Channel, ChatTurn, CorpusItem} from "../domain/types.js";

export async function generateDarditoAnswer(input: {
  channel: Channel;
  message: string;
  history: ChatTurn[];
  corpus: CorpusItem[];
}): Promise<string> {
  const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});
  const history = input.history
    .slice(-20)
    .map((turn) => `${turn.role === "user" ? "Usuario" : "Dardito"}: ${turn.text}`)
    .join("\n");

  const response = await ai.models.generateContent({
    model: geminiModel.value(),
    contents: [
      renderCorpus(input.corpus),
      history ? `CONVERSACIÓN RECIENTE:\n${history}` : "",
      `CONSULTA ACTUAL:\n${input.message}`,
    ].filter(Boolean).join("\n\n"),
    config: {
      systemInstruction: darditoSystemInstruction(input.channel),
      // Gemini's reasoning tokens share this budget with the visible answer.
      // Leave enough room to avoid returning a sentence cut in the middle.
      maxOutputTokens: input.channel === "whatsapp" ? 1200 : 2048,
      temperature: 0.9,
      topP: 0.95,
      // A fresh seed prevents identical social replies while keeping the same voice.
      seed: randomInt(1, 2_147_483_647),
    },
  });

  const answer = response.text
    ?.split("\n")
    .map((line) => line.trim())
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  if (!answer) {
    throw new Error("El proveedor LLM devolvió una respuesta vacía.");
  }
  return answer;
}
