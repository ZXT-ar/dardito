import assert from "node:assert/strict";
import test from "node:test";

import {parseLegacyKnowledge} from "./legacy-knowledge.js";

const valid = {
  id: "historia-1", title: "Historia", summary: "Resumen", body: "Contenido\nSegundo párrafo",
  category: "Cultura", neighborhood: "Centro", evidence: "documented", status: "draft", keywords: ["ciudad"],
};

test("el callable original conserva su esquema de contenido válido", () => {
  assert.deepEqual(parseLegacyKnowledge(valid), valid);
  assert.equal(parseLegacyKnowledge({...valid, sourceUrl: "https://example.com", featured: true}).sourceUrl, "https://example.com/");
});

test("rechaza modificación de metadatos del servidor, rutas, URL activas y cargas excesivas", () => {
  const inputs = [
    {...valid, updatedBy: "otro-uid"}, {...valid, revision: 99}, {...valid, likeCount: 99},
    {...valid, id: "story/versions/id"}, {...valid, body: "x".repeat(18_001)},
    {...valid, keywords: Array(25).fill("keyword")}, {...valid, keywords: [{text: "keyword"}]},
    {...valid, keywords: ["x".repeat(61)]}, {...valid, sourceUrl: "javascript:alert(1)"},
    {...valid, sourceUrl: "https://name:password@example.com"}, {...valid, latitude: Infinity},
    {...valid, longitude: 181}, {...valid, readingMinutes: 1.5}, {...valid, featured: "true"},
    {...valid, body: "texto\u0000oculto"}, {...valid, title: ""}, [], null,
  ];
  for (const input of inputs) assert.throws(() => parseLegacyKnowledge(input), /INVALID_KNOWLEDGE/);
});
