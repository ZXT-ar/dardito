import assert from "node:assert/strict";
import test from "node:test";

import {darditoSystemInstruction, isSelectedStoryRequest} from "./prompt.js";
import {defaultDarditoParameters} from "./dardito-parameters.js";

test("reconoce únicamente el mensaje automático de una historia seleccionada", () => {
  assert.equal(
    isSelectedStoryRequest("Quiero saber más sobre la historia “Los túneles bajo la ciudad”. Contame más."),
    true,
  );
  assert.equal(isSelectedStoryRequest("¿Cuándo ocurrió?"), false);
});

test("exige desarrollar la historia seleccionada sin habilitar invenciones", () => {
  const instruction = darditoSystemInstruction("web", defaultDarditoParameters, true);

  assert.match(instruction, /4 a 6 párrafos sustanciales/i);
  assert.match(instruction, /140 y 240 palabras/i);
  assert.match(instruction, /No rellenes ni inventes/i);
  assert.doesNotMatch(
    darditoSystemInstruction("web", defaultDarditoParameters),
    /DESARROLLO DE HISTORIA SELECCIONADA/,
  );
});

test("identidad y participación funcionan sin corpus y sin prohibiciones anteriores", () => {
  for (const channel of ["web", "whatsapp"] as const) {
    const instruction = darditoSystemInstruction(channel, {...defaultDarditoParameters, formality: 100});
    assert.match(instruction, /INFORMACIÓN EDITORIAL APROBADA/);
    assert.match(instruction, /incluso cuando no haya fragmentos/);
    assert.match(instruction, /guiño a Dardo Rocha/);
    assert.match(instruction, /sos un libro porque estás hecho de historias/);
    assert.match(instruction, /hoja es de tilo/);
    assert.match(instruction, /Julieta Quintero Chasman/);
    assert.match(instruction, /No recomendás candidatos/);
    assert.match(instruction, /no es una campaña política/);
    assert.match(instruction, /No inventes esposa, hijos, cumpleaños/);
    assert.doesNotMatch(instruction, /no te definas ni te compares con un libro|Nunca afirmes\s+que "Dardito" deriva|registro institucional,/);
  }
});

test("orienta al formulario real sin prometer publicación ni adjuntos inexistentes", () => {
  const instruction = darditoSystemInstruction("web");
  assert.match(instruction, /Compartí tu historia/);
  assert.match(instruction, /Contarla en el chat no envía el formulario ni publica/);
  assert.match(instruction, /Los aportes no se publican automáticamente/);
  assert.match(instruction, /hasta tres fotos/);
  assert.match(instruction, /no prometas adjuntar esos archivos directamente/);
  assert.match(instruction, /No reveles\s+correos privados/);
  assert.match(instruction, /No inventes autores, títulos, enlaces/);
});

test("conserva la advertencia oral aun con el nuevo nivel visible", async () => {
  const {renderCorpus} = await import("./prompt.js");
  const rendered = renderCorpus([{
    id: "relato", title: "Leyenda", summary: "Versión vecinal", body: "Un relato oral.",
    category: "Misterios", neighborhood: "Centro", evidence: "oral_tradition",
    evidenceLabel: "Aporte de vecinos", sourceName: "Publicación de referencia",
    keywords: [], status: "published",
  }]);
  assert.match(rendered, /Clasificación: Aporte de vecinos/);
  assert.match(rendered, /no presentar como hecho comprobado/);
  assert.match(rendered, /Fuente editorial: Publicación de referencia/);
  assert.doesNotMatch(rendered, /pendiente de revisión/);
});


test("identifica a Julieta como legisladora provincial según la definición aprobada", () => {
  for (const channel of ["web", "whatsapp"] as const) {
    const instruction = darditoSystemInstruction(channel, defaultDarditoParameters);
    assert.match(instruction, /Julieta Quintero Chasman es legisladora provincial/);
    assert.doesNotMatch(instruction, /Julieta es una dirigente política/);
  }
});
