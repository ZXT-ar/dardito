import assert from "node:assert/strict";
import test from "node:test";

import {createSitemapXml, createStoryHtml, storyPublicUrl} from "./public-story-page.js";
import type {PublicStory} from "./public-story.js";

const story: PublicStory = {
  id: "historia-1",
  title: "La historia <central>",
  subtitle: "Una bajada",
  summary: "Resumen con <script>alert(1)</script>",
  body: "Relato",
  categoryId: "mystery",
  categoryLabel: "Misterios",
  neighborhood: "Centro",
  period: "1882",
  evidence: "documented",
  evidenceLabel: "Documentada",
  sourceName: "Archivo",
  latitude: -34.92,
  longitude: -57.95,
  featured: true,
  readingMinutes: 3,
  likeCount: 0,
  contributionOrigin: "dardito_team",
};

test("genera metadata social, canónica y datos estructurados sin inyección HTML", () => {
  const html = createStoryHtml(story, true);
  assert.match(html, /property="og:title"/);
  assert.match(html, /property="og:image"/);
  assert.match(html, /rel="canonical"/);
  assert.match(html, /application\/ld\+json/);
  assert.match(html, /La historia &lt;central&gt;/);
  assert.doesNotMatch(html, /<script>alert\(1\)<\/script>/);
  assert.match(html, /\\u003cscript>/);
  assert.match(html, /Proporcionada por el equipo de Dardito/);
});

test("crea URLs estables y sitemap sólo con historias indicadas", () => {
  assert.equal(storyPublicUrl("historia-1"), "https://dardito-742d2.web.app/historias/historia-1");
  const sitemap = createSitemapXml([{id: "historia-1", lastModified: "2026-08-11"}]);
  assert.match(sitemap, /historias\/historia-1/);
  assert.match(sitemap, /2026-08-11/);
});
