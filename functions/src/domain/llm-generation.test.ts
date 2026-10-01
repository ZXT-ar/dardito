import assert from "node:assert/strict";
import test from "node:test";

import {generateCompleteText} from "./llm-generation.js";

test("devuelve una respuesta completa sin repetir la generación", async () => {
  const budgets: number[] = [];
  const answer = await generateCompleteText(async (budget) => {
    budgets.push(budget);
    return {text: "La historia termina aquí.", candidates: [{finishReason: "STOP"}]};
  }, 2_048);

  assert.equal(answer, "La historia termina aquí.");
  assert.deepEqual(budgets, [2_048]);
});

test("reintenta una respuesta truncada y devuelve solo el texto completo", async () => {
  const budgets: number[] = [];
  const answer = await generateCompleteText(async (budget) => {
    budgets.push(budget);
    return budgets.length === 1
      ? {text: "La historia empieza pero", candidates: [{finishReason: "MAX_TOKENS"}]}
      : {text: "La historia empieza y termina.", candidates: [{finishReason: "STOP"}]};
  }, 2_048);

  assert.equal(answer, "La historia empieza y termina.");
  assert.deepEqual(budgets, [2_048, 4_096]);
});

test("rechaza dos respuestas truncadas sin devolver contenido parcial ni volver a intentar", async () => {
  const budgets: number[] = [];
  await assert.rejects(
    generateCompleteText(async (budget) => {
      budgets.push(budget);
      return {text: "Un fragmento incompleto", candidates: [{finishReason: "MAX_TOKENS"}]};
    }, 2_048),
    {message: "INCOMPLETE_LLM_RESPONSE"},
  );
  assert.deepEqual(budgets, [2_048, 4_096]);
});

test("propaga un error del proveedor sin reintentar", async () => {
  const providerError = new Error("PROVIDER_UNAVAILABLE");
  let calls = 0;
  await assert.rejects(
    generateCompleteText(async () => {
      calls += 1;
      throw providerError;
    }, 2_048),
    (error: unknown) => error === providerError,
  );
  assert.equal(calls, 1);
});

test("limita el presupuesto del único reintento a 8192 tokens", async () => {
  const budgets: number[] = [];
  const answer = await generateCompleteText(async (budget) => {
    budgets.push(budget);
    return budgets.length === 1
      ? {text: "Texto parcial", candidates: [{finishReason: "MAX_TOKENS"}]}
      : {text: "Texto completo.", candidates: [{finishReason: "STOP"}]};
  }, 6_144);

  assert.equal(answer, "Texto completo.");
  assert.deepEqual(budgets, [6_144, 8_192]);
});

test("devuelve vacío cuando no hay texto y no reintenta otros motivos de finalización", async () => {
  for (const finishReason of ["STOP", "SAFETY", undefined]) {
    let calls = 0;
    const answer = await generateCompleteText(async () => {
      calls += 1;
      return {candidates: [{finishReason}]};
    }, 2_048);

    assert.equal(answer, "");
    assert.equal(calls, 1);
  }
});
