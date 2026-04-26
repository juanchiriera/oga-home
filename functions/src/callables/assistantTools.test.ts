import { describe, expect, it } from "vitest";

import {
  buildPlannerTraceabilitySummary,
  chunkTextForNdjson,
  classifyAssistantToolExecution,
  createAssistantTaskPlanner,
  registerPlannerToolExecution,
} from "./assistantOpenRouterTools.js";
import { hashToolPayload, redactToolArgsForAudit } from "./assistantToolAudit.js";
import { idempotencyDocId, toolUsesIdempotencyStore } from "./assistantToolIdempotency.js";

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

  it("create_expense usa almacén de idempotencia", () => {
    expect(toolUsesIdempotencyStore("create_expense")).toBe(true);
  });

  it("chunkTextForNdjson parte el texto", () => {
    const text = "a".repeat(40);
    const parts = [...chunkTextForNdjson(text, 16)];
    expect(parts.join("")).toBe(text);
    expect(parts.length).toBeGreaterThan(1);
  });

  it("clasifica bloqueo por pending_confirmation", () => {
    const out = classifyAssistantToolExecution("create_expense", {
      ok: false,
      rejected: true,
      pending_confirmation: true,
      reason: "confirmar en UI",
    });
    expect(out.blocking).toBe(true);
    expect(out.status).toBe("blocked");
    expect(out.result).toContain("blocked:");
  });

  it("planner marca silent_auto_step para herramientas seguras", () => {
    const planner = createAssistantTaskPlanner("Actualizar stock y responder");
    registerPlannerToolExecution(planner, "list_stock_items", { ok: true, items: [] });
    registerPlannerToolExecution(planner, "update_stock_status", { ok: true, item_id: "x" });
    const summary = buildPlannerTraceabilitySummary(planner);
    expect(summary).toContain("silent_auto_step");
    expect(summary).toContain("Resultado: completado automáticamente.");
  });

  it("planner reporta resultado bloqueado cuando hay error", () => {
    const planner = createAssistantTaskPlanner("Eliminar gasto");
    registerPlannerToolExecution(planner, "delete_expense", {
      ok: false,
      rejected: true,
      pending_confirmation: true,
      reason: "requiere confirmación",
    });
    const summary = buildPlannerTraceabilitySummary(planner);
    expect(summary).toContain("user_intervention");
    expect(summary).toContain("Resultado: bloqueado");
  });
});
