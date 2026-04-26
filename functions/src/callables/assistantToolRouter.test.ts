import { describe, expect, it } from "vitest";

import {
  CREATE_EXPENSE_FIELDS_POLICY,
  resolveCreateExpenseDraft,
} from "./assistantToolRouter.js";

describe("resolveCreateExpenseDraft", () => {
  it("completa campos inferibles con defaults", () => {
    const out = resolveCreateExpenseDraft(
      { amount: 1250 },
      {
        currency: "ARS",
        occurredAtIso: "2026-04-26",
        paymentMethodId: "pm_cash",
      },
    );

    expect(out.missingCritical).toEqual([]);
    expect(out.draft).toEqual({
      amount: 1250,
      currency: "ARS",
      category_key: "other",
      occurred_at: "2026-04-26",
      payment_method_id: "pm_cash",
      merchant: "",
      note: "",
    });
    expect(out.assumptions.map((entry) => entry.field).sort()).toEqual([
      "category_key",
      "currency",
      "merchant",
      "note",
      "occurred_at",
      "payment_method_id",
    ]);
  });

  it("marca amount como crítico faltante", () => {
    const out = resolveCreateExpenseDraft(
      {
        currency: "USD",
        category_key: "food",
        occurred_at: "2026-01-10",
      },
      {
        currency: "ARS",
        occurredAtIso: "2026-04-26",
        paymentMethodId: "pm_cash",
      },
    );

    expect(out.missingCritical).toEqual([...CREATE_EXPENSE_FIELDS_POLICY.critical]);
    expect(out.draft.amount).toBeUndefined();
    expect(out.draft.currency).toBe("USD");
    expect(out.draft.category_key).toBe("food");
  });

  it("respeta overrides explícitos y solo completa inválidos", () => {
    const out = resolveCreateExpenseDraft(
      {
        amount: 99.5,
        currency: "abc",
        category_key: "transport",
        occurred_at: "fecha-mala",
        payment_method_id: "pm_debit",
        merchant: "Kiosco",
      },
      {
        currency: "EUR",
        occurredAtIso: "2026-04-26",
        paymentMethodId: "pm_cash",
      },
    );

    expect(out.missingCritical).toEqual([]);
    expect(out.draft.currency).toBe("EUR");
    expect(out.draft.occurred_at).toBe("2026-04-26");
    expect(out.draft.payment_method_id).toBe("pm_debit");
    expect(out.draft.category_key).toBe("transport");
    expect(out.draft.merchant).toBe("Kiosco");
    expect(out.draft.note).toBe("");

    const fieldsWithAssumptions = out.assumptions.map((entry) => entry.field);
    expect(fieldsWithAssumptions).toContain("currency");
    expect(fieldsWithAssumptions).toContain("occurred_at");
    expect(fieldsWithAssumptions).toContain("note");
    expect(fieldsWithAssumptions).not.toContain("payment_method_id");
  });
});
