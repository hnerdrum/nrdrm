import assert from "node:assert/strict";
import { test } from "node:test";
import { sensitiveData } from "../src/policy.ts";

test("ignores ordinary text", () => {
  assert.equal(sensitiveData("a recipe for bread"), undefined);
});

test("finds an email address", () => {
  assert.equal(sensitiveData("write me at ada@example.com"), "email");
});

test("finds an 11-digit national id", () => {
  assert.equal(sensitiveData("id 12345678901"), "national-id");
});

test("finds a spaced national id", () => {
  assert.equal(sensitiveData("id 010101 12345"), "national-id");
});

test("finds a local phone number", () => {
  assert.equal(sensitiveData("call 91234567"), "phone");
});

test("finds a spaced phone number", () => {
  assert.equal(sensitiveData("call 412 34 567"), "phone");
});

test("finds an international phone number", () => {
  assert.equal(sensitiveData("call +47 91234567"), "phone");
});
