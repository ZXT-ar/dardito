import {test} from "node:test";
import assert from "node:assert/strict";
import {sanitizeMessage} from "./chat-message.js";

test("acepta hasta 350 caracteres y rechaza 351 sin truncar", () => {
  assert.equal(sanitizeMessage("a".repeat(350)).length, 350);
  assert.throws(() => sanitizeMessage("a".repeat(351)), /INVALID_MESSAGE/);
  assert.throws(() => sanitizeMessage(" ".repeat(350) + "a"), /INVALID_MESSAGE/);
  assert.throws(() => sanitizeMessage("\n\t  "), /INVALID_MESSAGE/);
});
test("cuenta grafemas igual que Flutter, incluidos emojis y acentos", () => {
  for (const character of ["👨‍👩‍👧‍👦", "e\u0301", "🇦🇷", "á"]) {
    assert.equal(sanitizeMessage(character.repeat(350)), character.repeat(350));
    assert.throws(() => sanitizeMessage(character.repeat(351)), /INVALID_MESSAGE/);
  }
  assert.equal(sanitizeMessage("hola\nDardito"), "hola Dardito");
});
