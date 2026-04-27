import { describe, expect, it } from "vitest";

import { shouldDeferPeriodForStartKey } from "./generateRecurringExpenses.js";

describe("shouldDeferPeriodForStartKey", () => {
  it("no aplaza sin startPeriodKey", () => {
    expect(shouldDeferPeriodForStartKey("2026-03", null)).toBe(false);
    expect(shouldDeferPeriodForStartKey("2026-03", undefined)).toBe(false);
    expect(shouldDeferPeriodForStartKey("2026-03", "")).toBe(false);
  });

  it("ignora formato inválido", () => {
    expect(shouldDeferPeriodForStartKey("2026-03", "2026-3")).toBe(false);
    expect(shouldDeferPeriodForStartKey("2026-03", "bad")).toBe(false);
  });

  it("aplaza si el período es anterior al inicio", () => {
    expect(shouldDeferPeriodForStartKey("2026-03", "2026-04")).toBe(true);
    expect(shouldDeferPeriodForStartKey("2025-12", "2026-01")).toBe(true);
  });

  it("no aplaza en el mes de inicio o posterior", () => {
    expect(shouldDeferPeriodForStartKey("2026-04", "2026-04")).toBe(false);
    expect(shouldDeferPeriodForStartKey("2026-05", "2026-04")).toBe(false);
  });
});
