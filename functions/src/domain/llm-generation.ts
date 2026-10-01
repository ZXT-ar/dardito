type TextGenerationResult = {
  text?: string;
  candidates?: Array<{finishReason?: string}>;
};

export async function generateCompleteText(
  generate: (maxOutputTokens: number) => Promise<TextGenerationResult>,
  initialTokenBudget: number,
): Promise<string> {
  let result = await generate(initialTokenBudget);
  if (result.candidates?.some((candidate) => candidate.finishReason === "MAX_TOKENS")) {
    result = await generate(Math.min(initialTokenBudget * 2, 8_192));
    if (result.candidates?.some((candidate) => candidate.finishReason === "MAX_TOKENS")) {
      throw new Error("INCOMPLETE_LLM_RESPONSE");
    }
  }
  return result.text ?? "";
}
