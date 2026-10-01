import assert from "node:assert/strict";
import test from "node:test";
import {readMetric} from "../services/site-report.js";
test("rejects malformed metrics instead of presenting invented zeros", () => {
  assert.equal(readMetric(undefined), 0);
  assert.equal(readMetric("0.42"), 0.42);
  for (const value of ["NaN", "Infinity", "-1", "invalid"]) assert.throws(() => readMetric(value));
});
