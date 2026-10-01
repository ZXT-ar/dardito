import assert from "node:assert/strict";
import test from "node:test";
import {reportRange, selectedSections, createGeneralReportPdf, generalReportFilename, type GeneralReport} from "../services/general-report.js";
import {PDFDocument} from "pdf-lib";
test("rejects invalid or excessive report date ranges", () => {
  for (const [from, to] of [["2026-02-30", "2026-03-05"], ["2025-01-01", "2026-02-01"], ["2026-05-03", "2026-05-01"], ["x", "y"], ["2999-01-01", "2999-01-02"]]) assert.throws(() => reportRange(from, to));
  assert.deepEqual(reportRange("2026-01-01", "2026-01-01"), {from: "2026-01-01", to: "2026-01-01"});
});
test("sections must be valid and nonempty", () => {
  assert.throws(() => selectedSections([])); assert.throws(() => selectedSections(["users"]));
  assert.deepEqual(selectedSections(["audience", "audience"]), ["audience"]);
});
const report: GeneralReport = {website: {status: "unavailable"},from: "2026-01-01", to: "2026-01-01", generatedBy: "prueba@example.test", generatedAt: "2026-01-02T12:00:00Z", daily: [], totals: {sessions: 0, chats: 0, storyViews: 0, requests: 0, submissions: 0, errors: 0}, observedDays: 0, durationSamples: 0, averageDuration: null, uniqueVisitors: null, returningVisitors: null, content: {total: 0, published: 0, likes: 0, categories: {}}, topLiked: [], topViewed: [], notes: ["Datos sintéticos exclusivos de prueba."]};
test("PDF exports only selected sections with author and title metadata", async () => {
  const audience = await PDFDocument.load(await createGeneralReportPdf(report, ["audience"]));
  assert.equal(audience.getPageCount(), 2); assert.equal(audience.getAuthor(), report.generatedBy);
  assert.equal(audience.getTitle(), "El Mapa de las Historias de La Plata");
  const all = await PDFDocument.load(await createGeneralReportPdf(report, ["audience", "activity", "content", "daily"]));
  assert.equal(all.getPageCount(), 6);
  assert.match(generalReportFilename(report), /2026-01-02.*prueba@example.test\.pdf$/);
});
