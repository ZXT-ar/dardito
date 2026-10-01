import assert from "node:assert/strict";
import test from "node:test";

import {nextStoryLikeState} from "./story-likes.js";

test("agrega un único Me gusta", () => {
  assert.deepEqual(nextStoryLikeState(4, false), {liked: true, likeCount: 5});
});

test("el toggle quita el Me gusta sin producir contadores negativos", () => {
  assert.deepEqual(nextStoryLikeState(4, true), {liked: false, likeCount: 3});
  assert.deepEqual(nextStoryLikeState(0, true), {liked: false, likeCount: 0});
});

test("normaliza contadores internos inválidos", () => {
  assert.deepEqual(nextStoryLikeState(-8, false), {liked: true, likeCount: 1});
  assert.deepEqual(nextStoryLikeState("inválido", false), {liked: true, likeCount: 1});
});
