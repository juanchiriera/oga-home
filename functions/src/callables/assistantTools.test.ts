import { describe, expect, it } from "vitest";

import { chunkTextForNdjson } from "./assistantOpenRouterTools.js";
import { hashToolPayload, redactToolArgsForAudit } from "./assistantToolAudit.js";
import { idempotencyDocId } from "./assistantToolIdempotency.js";

describe("assistant tools helpers", () => {
  it("hashToolPayload es estable ante orden de keys", () => {
    const a = hashToolPayload({ z: 1, a: "x" });
    const b = hashToolPayload({ a: "x", z: 1 });
    expect(a).toBe(b);
  });

  it("redactToolArgsForAudit acorta notas largas", () => {
    const long = "x".repeat(100);
    const r = redactToolArgsForAudit("create_note", { title: "t", content: long });
    expect(typeof r.content).toBe("string");
    expect((r.content as string).length).toBeLessThan(long.length);
  });

  it("idempotencyDocId es determinista", () => {
    expect(idempotencyDocId("abc", "create_note")).toBe(
      idempotencyDocId("abc", "create_note"),
    );
    expect(idempotencyDocId("abc", "create_note")).not.toBe(
      idempotencyDocId("abc", "create_recipe"),
    );
  });

  it("chunkTextForNdjson parte el texto", () => {
    const text = "a".repeat(40);
    const parts = [...chunkTextForNdjson(text, 16)];
    expect(parts.join("")).toBe(text);
    expect(parts.length).toBeGreaterThan(1);
  });
});
