import assert from "node:assert/strict";
import {createHmac} from "node:crypto";
import test from "node:test";

import {
  extractWhatsAppMessages,
  hasValidMetaSignature,
  verificationChallenge,
} from "./whatsapp.js";

test("verificationChallenge returns Meta's challenge only for matching values", () => {
  const query = {
    "hub.mode": "subscribe",
    "hub.verify_token": "verify-me",
    "hub.challenge": "123456",
  };
  assert.equal(verificationChallenge(query, "verify-me"), "123456");
  assert.equal(verificationChallenge(query, "another-token"), null);
  assert.equal(verificationChallenge({...query, "hub.mode": "unsubscribe"}, "verify-me"), null);
});

test("hasValidMetaSignature validates the raw body without throwing on malformed input", () => {
  const rawBody = Buffer.from('{"object":"whatsapp_business_account"}');
  const secret = "meta-app-secret";
  const signature = `sha256=${createHmac("sha256", secret).update(rawBody).digest("hex")}`;
  assert.equal(hasValidMetaSignature(rawBody, signature, secret), true);
  assert.equal(hasValidMetaSignature(rawBody, "sha256=not-hex", secret), false);
  assert.equal(hasValidMetaSignature(rawBody, undefined, secret), false);
  assert.equal(hasValidMetaSignature(Buffer.from("changed"), signature, secret), false);
});

test("extractWhatsAppMessages reads messages and ignores delivery status events", () => {
  const message = {
    object: "whatsapp_business_account",
    entry: [{
      changes: [{
        value: {
          messages: [{
            id: "wamid.example",
            from: "5492213000000",
            timestamp: "1788420000",
            type: "text",
            text: {body: "Hola, Dardito"},
          }],
        },
      }],
    }],
  };
  assert.deepEqual(extractWhatsAppMessages(message), [{
    id: "wamid.example",
    from: "5492213000000",
    timestamp: "1788420000",
    type: "text",
    text: {body: "Hola, Dardito"},
  }]);

  const status = {
    entry: [{changes: [{value: {statuses: [{id: "wamid.example", status: "read"}]}}]}],
  };
  assert.deepEqual(extractWhatsAppMessages(status), []);
});

test("extractWhatsAppMessages rejects other destination numbers and malformed text", () => {
  const payload = (phone: string, body: unknown) => ({
    entry: [{changes: [{value: {
      metadata: {phone_number_id: phone},
      messages: [{id: "wamid.example", from: "5492213000000", type: "text", text: {body}}],
    }}]}],
  });
  assert.equal(extractWhatsAppMessages(payload("123456", "Hola"), "123456").length, 1);
  assert.equal(extractWhatsAppMessages(payload("999999", "Hola"), "123456").length, 0);
  assert.equal(extractWhatsAppMessages(payload("123456", 42), "123456").length, 0);
});

test("extractWhatsAppMessages bounds a webhook batch", () => {
  const messages = Array.from({length: 200}, (_, index) => ({id: `wamid.${index}`, from: "5492213000000", type: "image"}));
  assert.equal(extractWhatsAppMessages({entry: [{changes: [{value: {messages}}]}]}).length, 100);
});
