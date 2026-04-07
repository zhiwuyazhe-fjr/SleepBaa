import assert from "node:assert/strict";
import test from "node:test";
import { normalizeCloudBasePhoneNumber } from "../src/http/app_api";

test("normalizeCloudBasePhoneNumber adds +86 for mainland China numbers", () => {
  assert.equal(normalizeCloudBasePhoneNumber("13800138000"), "+86 13800138000");
});

test("normalizeCloudBasePhoneNumber preserves normalized numbers", () => {
  assert.equal(
    normalizeCloudBasePhoneNumber("+86 13800138000"),
    "+86 13800138000",
  );
});

test("normalizeCloudBasePhoneNumber normalizes explicit country code separators", () => {
  assert.equal(
    normalizeCloudBasePhoneNumber("+86-13800138000"),
    "+86 13800138000",
  );
});
