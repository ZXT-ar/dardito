import assert from "node:assert/strict";
import test from "node:test";

import {
  defaultDarditoParameters,
  normalizeDarditoParameters,
  renderDarditoParameterInstruction,
  responseTokenBudget,
  responseWordRange,
} from "./dardito-parameters.js";

test("normaliza límites y limpia vocabulario", () => {
  const result = normalizeDarditoParameters({
    formality: 180,
    responseLength: -20,
    naturalTone: 42.4,
    preferredWords: ["  platense  ", "", 4],
    avoidedWords: ["robot"],
    signaturePhrases: ["¿Por dónde empezamos?"],
    rules: {useVoseo: false},
  });

  assert.equal(result.formality, 100);
  assert.equal(result.responseLength, 0);
  assert.equal(result.naturalTone, 42);
  assert.deepEqual(result.preferredWords, ["platense"]);
  assert.equal(result.rules.useVoseo, false);
  assert.equal(result.rules.mentionEvidence, true);
});

test("la extensión modifica el rango y el presupuesto de respuesta", () => {
  const brief = {...defaultDarditoParameters, responseLength: 0};
  const extensive = {...defaultDarditoParameters, responseLength: 100};

  assert.ok(responseWordRange(brief, "web").maximum < responseWordRange(extensive, "web").maximum);
  assert.ok(responseTokenBudget(brief, "web") < responseTokenBudget(extensive, "web"));
});

test("reserva tokens para razonamiento además del relato en ambos canales", () => {
  for (const channel of ["web", "whatsapp"] as const) {
    for (const responseLength of [0, 48, 100]) {
      const parameters = {...defaultDarditoParameters, responseLength};
      const answerTokens = Math.ceil(responseWordRange(parameters, channel).maximum * 2.4);
      assert.ok(responseTokenBudget(parameters, channel) >= answerTokens + 2_048);
    }
  }
});

test("la instrucción refleja personalidad, vocabulario y reglas", () => {
  const instruction = renderDarditoParameterInstruction({
    ...defaultDarditoParameters,
    formality: 90,
    naturalTone: 20,
    preferredWords: ["diagonales"],
    avoidedWords: ["libro-mapa"],
    signaturePhrases: ["Sigamos caminando."],
    rules: {...defaultDarditoParameters.rules, closingQuestion: false},
  }, "web");

  assert.match(instruction, /sin sonar institucional/i);
  assert.match(instruction, /diagonales/);
  assert.match(instruction, /libro-mapa/);
  assert.match(instruction, /Sigamos caminando\./);
  assert.match(instruction, /Pregunta de continuidad desactivada/i);
});
