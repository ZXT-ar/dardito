import assert from "node:assert/strict";
import test from "node:test";

import {normalizeCatalogs, parseCatalogs} from "./editorial-catalogs.js";

test("conserva la descripción de categorías y admite registros anteriores", () => {
  const catalogs = normalizeCatalogs({
    categories: [
      {id: "architecture", label: "Arquitectura", description: "Edificios y espacios que definen la ciudad."},
      {id: "memory", label: "Memoria viva"},
    ],
    neighborhoods: [{id: "centro", label: "Centro"}],
    evidenceLevels: [{id: "documented", label: "Documentada"}],
  });

  assert.equal(catalogs.categories[0]!.description, "Edificios y espacios que definen la ciudad.");
  assert.equal(catalogs.categories[1]!.description, undefined);
});

test("sanea y limita las descripciones guardadas desde el panel", () => {
  const catalogs = parseCatalogs({
    categories: [{id: "culture", label: "Cultura", description: "  Prácticas y expresiones culturales.  "}],
    neighborhoods: [{id: "centro", label: "Centro"}],
    evidenceLevels: [{id: "documented", label: "Documentada"}],
  });

  assert.equal(catalogs.categories[0]!.description, "Prácticas y expresiones culturales.");
  assert.throws(() => parseCatalogs({
    categories: [{id: "culture", label: "Cultura", description: "x".repeat(501)}],
    neighborhoods: [{id: "centro", label: "Centro"}],
    evidenceLevels: [{id: "documented", label: "Documentada"}],
  }));
});

test("catálogo de dos niveles conserva interpretación de valores anteriores", async () => {
  const {evidenceEntry} = await import("./editorial-catalogs.js");
  const catalogs = normalizeCatalogs({evidenceLevels: [{id: "oral_tradition", label: "Tradición oral"}]});
  assert.deepEqual(catalogs.evidenceLevels.map((entry) => entry.id), ["documented", "community"]);
  for (const value of ["oral_tradition", "community", "Tradición oral", "Memoria comunitaria"]) assert.equal(evidenceEntry(value)?.id, "community");
  assert.equal(evidenceEntry("documented")?.id, "documented");
  assert.ok(catalogs.evidenceLevels.every((entry) => entry.description));
});
