import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import {
  appendAssistantActionLog,
  hashToolPayload,
  redactToolArgsForAudit,
  type AssistantAuditResult,
} from "./assistantToolAudit.js";
import {
  readIdempotentToolResult,
  toolUsesIdempotencyStore,
  writeIdempotentToolResult,
} from "./assistantToolIdempotency.js";
import { draftRecipeFromUrlAsMember } from "./recipeCallables.js";

const EXPENSE_CATEGORIES: Array<{ key: string; label: string; system: boolean }> = [
  { key: "housing", label: "Vivienda", system: true },
  { key: "food", label: "Comida", system: true },
  { key: "transport", label: "Transporte", system: true },
  { key: "shopping", label: "Compras", system: true },
  { key: "utilities", label: "Servicios", system: true },
  { key: "health", label: "Salud", system: true },
  { key: "education", label: "Educación", system: true },
  { key: "leisure", label: "Ocio", system: true },
  { key: "other", label: "Otros", system: true },
];
const ALLOWED_EXPENSE_CURRENCIES = new Set(["ARS", "USD", "EUR"]);

const SUPPORTED_EXPENSE_CURRENCIES = new Set(["ARS", "USD", "EUR"]);
const CASH_PAYMENT_METHOD_TYPE = "cash";
const DEFAULT_EXPENSE_CATEGORY_KEY = "other";

export const CREATE_EXPENSE_FIELDS_POLICY = {
  critical: ["amount"] as const,
  inferable: [
    "currency",
    "category_key",
    "occurred_at",
    "payment_method_id",
    "merchant",
    "note",
  ] as const,
};

type CreateExpenseAssumption = {
  field: (typeof CREATE_EXPENSE_FIELDS_POLICY.inferable)[number];
  value: unknown;
  reason: string;
};

type CreateExpenseDefaultsContext = {
  currency: string;
  occurredAtIso: string;
  paymentMethodId: string | null;
};

export type CreateExpenseResolvedDraft = {
  draft: {
    amount?: number;
    currency: string;
    category_key: string;
    occurred_at: string;
    payment_method_id: string | null;
    merchant: string;
    note: string;
  };
  assumptions: CreateExpenseAssumption[];
  missingCritical: Array<(typeof CREATE_EXPENSE_FIELDS_POLICY.critical)[number]>;
};

function parseIsoDateOnly(raw: string): { y: number; m: number; d: number } {
  const s = String(raw ?? "").trim();
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) {
    throw new Error("Fecha inválida (usar YYYY-MM-DD)");
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) {
    throw new Error("Fecha inválida");
  }
  return { y, m: mo, d };
}

function utcStartOfDay(parts: { y: number; m: number; d: number }): Timestamp {
  return Timestamp.fromDate(new Date(Date.UTC(parts.y, parts.m - 1, parts.d, 0, 0, 0, 0)));
}

function utcEndOfDayInclusive(parts: { y: number; m: number; d: number }): Timestamp {
  return Timestamp.fromDate(
    new Date(Date.UTC(parts.y, parts.m - 1, parts.d, 23, 59, 59, 999)),
  );
}

function isoDateTodayUtc(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

function normalizeCurrency(raw: unknown, fallback: string): string {
  const picked = String(raw ?? "").trim().toUpperCase();
  if (SUPPORTED_EXPENSE_CURRENCIES.has(picked)) {
    return picked;
  }
  const safeFallback = String(fallback ?? "").trim().toUpperCase();
  return SUPPORTED_EXPENSE_CURRENCIES.has(safeFallback) ? safeFallback : "ARS";
}

function parsePositiveAmount(raw: unknown): number | null {
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) {
    return null;
  }
  return n;
}

function normalizeIsoDateOrNull(raw: unknown): string | null {
  const value = String(raw ?? "").trim();
  if (!value) {
    return null;
  }
  try {
    parseIsoDateOnly(value);
    return value;
  } catch {
    return null;
  }
}

async function loadCreateExpenseDefaults(
  db: admin.firestore.Firestore,
  familyId: string,
): Promise<CreateExpenseDefaultsContext> {
  const familyRef = db.collection("families").doc(familyId);
  const paymentMethodsRef = familyRef.collection("paymentMethods");
  const [familySnap, paymentMethodsSnap] = await Promise.all([
    familyRef.get(),
    paymentMethodsRef.orderBy("name").limit(30).get(),
  ]);

  const familyCurrency = familySnap.exists ? familySnap.get("baseCurrency") : null;
  const currency = normalizeCurrency(familyCurrency, "ARS");

  const methods = paymentMethodsSnap.docs.filter((doc) => doc.get("archived") !== true);
  const cashMethod =
    methods.find((doc) => String(doc.get("type") ?? "") === CASH_PAYMENT_METHOD_TYPE) ?? null;
  const fallbackMethod = methods[0] ?? null;
  const paymentMethodId = cashMethod?.id ?? fallbackMethod?.id ?? null;

  return {
    currency,
    occurredAtIso: isoDateTodayUtc(),
    paymentMethodId,
  };
}

export function resolveCreateExpenseDraft(
  raw: Record<string, unknown>,
  defaults: CreateExpenseDefaultsContext,
): CreateExpenseResolvedDraft {
  const assumptions: CreateExpenseAssumption[] = [];
  const missingCritical: Array<(typeof CREATE_EXPENSE_FIELDS_POLICY.critical)[number]> = [];

  const amount = parsePositiveAmount(raw.amount);
  if (amount == null) {
    missingCritical.push("amount");
  }

  const currencyInput = String(raw.currency ?? "").trim();
  const currency = normalizeCurrency(currencyInput, defaults.currency);
  if (!currencyInput || !SUPPORTED_EXPENSE_CURRENCIES.has(currencyInput.toUpperCase())) {
    assumptions.push({
      field: "currency",
      value: currency,
      reason: "default_currency",
    });
  }

  const categoryInput = String(raw.category_key ?? "").trim();
  const categoryKey = categoryInput || DEFAULT_EXPENSE_CATEGORY_KEY;
  if (!categoryInput) {
    assumptions.push({
      field: "category_key",
      value: categoryKey,
      reason: "default_category",
    });
  }

  const occurredAtInput = normalizeIsoDateOrNull(raw.occurred_at);
  const occurredAt = occurredAtInput ?? defaults.occurredAtIso;
  if (!occurredAtInput) {
    assumptions.push({
      field: "occurred_at",
      value: occurredAt,
      reason: "default_today",
    });
  }

  const paymentMethodInput = String(raw.payment_method_id ?? "").trim();
  const paymentMethodId = paymentMethodInput || defaults.paymentMethodId;
  if (!paymentMethodInput) {
    assumptions.push({
      field: "payment_method_id",
      value: paymentMethodId,
      reason: "default_payment_method",
    });
  }

  const merchantInput = raw.merchant != null ? String(raw.merchant).trim() : "";
  const noteInput = raw.note != null ? String(raw.note).trim() : "";
  if (raw.merchant == null) {
    assumptions.push({
      field: "merchant",
      value: "",
      reason: "default_empty",
    });
  }
  if (raw.note == null) {
    assumptions.push({
      field: "note",
      value: "",
      reason: "default_empty",
    });
  }

  return {
    draft: {
      ...(amount != null ? { amount } : {}),
      currency,
      category_key: categoryKey,
      occurred_at: occurredAt,
      payment_method_id: paymentMethodId,
      merchant: merchantInput,
      note: noteInput,
    },
    assumptions,
    missingCritical,
  };
}

function asRecord(args: unknown): Record<string, unknown> {
  return args && typeof args === "object" && !Array.isArray(args)
    ? (args as Record<string, unknown>)
    : {};
}

function assertHttpsUrl(raw: unknown): string {
  const value = String(raw ?? "").trim();
  if (!value) {
    throw new Error("URL requerida");
  }
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error("URL inválida");
  }
  if (parsed.protocol !== "https:") {
    throw new Error("Solo se admiten URLs https");
  }
  return parsed.toString();
}

export type ToolRouterContext = {
  db: admin.firestore.Firestore;
  familyId: string;
  userId: string;
  conversationId: string;
  clientRequestId: string | undefined;
};

export type ToolExecutionResult = {
  response: Record<string, unknown>;
  auditResult: AssistantAuditResult;
};

function rejected(message: string, extra?: Record<string, unknown>): ToolExecutionResult {
  return {
    response: { ok: false, rejected: true, reason: message, ...extra },
    auditResult: "rejected",
  };
}

async function handleListExpenses(
  db: admin.firestore.Firestore,
  familyId: string,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const col = db.collection("families").doc(familyId).collection("expenses");
  const limitRaw = Number(raw.limit ?? 40);
  const limit = Math.min(80, Math.max(1, Number.isFinite(limitRaw) ? limitRaw : 40));

  const dateFrom = raw.date_from != null ? String(raw.date_from).trim() : "";
  const dateTo = raw.date_to != null ? String(raw.date_to).trim() : "";
  const categoryKey = raw.category_key != null ? String(raw.category_key).trim() : "";
  const status = raw.status != null ? String(raw.status).trim() : "";
  const currency = raw.currency != null ? String(raw.currency).trim() : "";

  let q: admin.firestore.Query = col;

  if (categoryKey) {
    q = q.where("categoryKey", "==", categoryKey);
  }

  if (dateFrom && dateTo) {
    const t0 = utcStartOfDay(parseIsoDateOnly(dateFrom));
    const t1 = utcEndOfDayInclusive(parseIsoDateOnly(dateTo));
    q = q.where("occurredAt", ">=", t0).where("occurredAt", "<=", t1);
  } else if (dateFrom) {
    q = q.where("occurredAt", ">=", utcStartOfDay(parseIsoDateOnly(dateFrom)));
  } else if (dateTo) {
    q = q.where("occurredAt", "<=", utcEndOfDayInclusive(parseIsoDateOnly(dateTo)));
  }

  q = q.orderBy("occurredAt", "desc").limit(limit);
  const snap = await q.get();
  const items = snap.docs.map((d) => {
    const x = d.data();
    return {
      id: d.id,
      amount: x.amount,
      currency: x.currency,
      categoryKey: x.categoryKey,
      status: x.status,
      occurredAt: (x.occurredAt as Timestamp | undefined)?.toDate?.()?.toISOString?.() ?? null,
      merchant: x.merchant ?? "",
      note: x.note ?? "",
      paymentMethodId: x.paymentMethodId ?? null,
    };
  });
  let filtered = items;
  if (status) {
    filtered = filtered.filter((r) => r.status === status);
  }
  if (currency) {
    filtered = filtered.filter((r) => r.currency === currency);
  }
  return {
    response: { ok: true, expenses: filtered, count: filtered.length },
    auditResult: "ok",
  };
}

async function handleCreateExpense(
  ctx: ToolRouterContext,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const amount = Number(raw.amount ?? 0);
  const currency = String(raw.currency ?? "").trim().toUpperCase();
  const categoryKey = String(raw.category_key ?? "").trim();
  const occurredAtIso = String(raw.occurred_at ?? "").trim();
  const paymentMethodId = String(raw.payment_method_id ?? "").trim();
  const merchant = raw.merchant != null ? String(raw.merchant).trim() : "";
  const note = raw.note != null ? String(raw.note).trim() : "";

  if (!Number.isFinite(amount) || amount <= 0) {
    return rejected("amount debe ser un número mayor a 0");
  }
  if (!ALLOWED_EXPENSE_CURRENCIES.has(currency)) {
    return rejected("currency debe ser ARS, USD o EUR");
  }
  if (!EXPENSE_CATEGORIES.some((x) => x.key === categoryKey)) {
    return rejected("category_key no es una categoría permitida");
  }

  let occurredAt: Timestamp;
  try {
    occurredAt = utcStartOfDay(parseIsoDateOnly(occurredAtIso));
  } catch (e) {
    return rejected((e as Error).message);
  }

  let status = "confirmed";
  let resolvedPaymentMethodId: string | null = null;
  if (paymentMethodId) {
    const paymentMethodSnap = await ctx.db
      .collection("families")
      .doc(ctx.familyId)
      .collection("paymentMethods")
      .doc(paymentMethodId)
      .get();
    if (!paymentMethodSnap.exists) {
      return rejected("payment_method_id no es válido");
    }
    const paymentMethodType = String(paymentMethodSnap.get("type") ?? "").trim();
    status = paymentMethodType === "credit_card" ? "pending_card_cycle" : "confirmed";
    resolvedPaymentMethodId = paymentMethodId;
  }

  const now = FieldValue.serverTimestamp();
  const ref = await ctx.db.collection("families").doc(ctx.familyId).collection("expenses").add({
    amount,
    currency,
    categoryKey,
    occurredAt,
    paymentMethodId: resolvedPaymentMethodId,
    merchant,
    note,
    status,
    source: "chatbot",
    createdBy: ctx.userId,
    createdAt: now,
    updatedAt: now,
  });

  return {
    response: {
      ok: true,
      expense_id: ref.id,
      auto_executed: true,
      source: "chatbot",
      amount,
      currency,
      category_key: categoryKey,
      occurred_at: occurredAtIso,
      status,
    },
    auditResult: "ok",
  };
}

async function handleListStock(
  db: admin.firestore.Firestore,
  familyId: string,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const col = db.collection("families").doc(familyId).collection("stockItems");
  const state = raw.state != null ? String(raw.state).trim() : "";
  const limitRaw = Number(raw.limit ?? 60);
  const limit = Math.min(120, Math.max(1, Number.isFinite(limitRaw) ? limitRaw : 60));

  let q: admin.firestore.Query = col;
  if (state) {
    q = q.where("state", "==", state).orderBy("name").limit(limit);
  } else {
    q = q.orderBy("name").limit(limit);
  }
  const snap = await q.get();
  const items = snap.docs.map((d) => {
    const x = d.data();
    return {
      id: d.id,
      name: x.name,
      state: x.state,
      updatedAt: (x.updatedAt as Timestamp | undefined)?.toDate?.()?.toISOString?.() ?? null,
    };
  });
  return { response: { ok: true, items, count: items.length }, auditResult: "ok" };
}

async function handleListRecipes(
  db: admin.firestore.Firestore,
  familyId: string,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const col = db.collection("families").doc(familyId).collection("recipes");
  const limitRaw = Number(raw.limit ?? 30);
  const limit = Math.min(60, Math.max(1, Number.isFinite(limitRaw) ? limitRaw : 30));
  const snap = await col.orderBy("updatedAt", "desc").limit(limit).get();
  const items = snap.docs.map((d) => {
    const x = d.data();
    return {
      id: d.id,
      titulo: x.titulo,
      tiempoMin: x.tiempoMin,
      porciones: x.porciones,
      favorita: x.favorita,
    };
  });
  return { response: { ok: true, recipes: items, count: items.length }, auditResult: "ok" };
}

async function handleGetRecipe(
  db: admin.firestore.Firestore,
  familyId: string,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const id = String(raw.recipe_id ?? "").trim();
  if (!id) {
    return rejected("recipe_id es obligatorio");
  }
  const ref = db.collection("families").doc(familyId).collection("recipes").doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    return { response: { ok: false, error: "Receta no encontrada" }, auditResult: "error" };
  }
  return { response: { ok: true, id, data: snap.data() }, auditResult: "ok" };
}

async function handleListNotes(
  db: admin.firestore.Firestore,
  familyId: string,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const col = db.collection("families").doc(familyId).collection("sharedNotes");
  const limitRaw = Number(raw.limit ?? 40);
  const limit = Math.min(80, Math.max(1, Number.isFinite(limitRaw) ? limitRaw : 40));
  const snap = await col.orderBy("updatedAt", "desc").limit(limit).get();
  const notes = snap.docs.map((d) => {
    const x = d.data();
    const c = x.content as string | undefined;
    return {
      id: d.id,
      title: x.title,
      content:
        typeof c === "string" ? `${c.slice(0, 200)}${c.length > 200 ? "…" : ""}` : "",
      updatedAt: (x.updatedAt as Timestamp | undefined)?.toDate?.()?.toISOString?.() ?? null,
    };
  });
  return { response: { ok: true, notes, count: notes.length }, auditResult: "ok" };
}

async function handleCreateStockItem(
  ctx: ToolRouterContext,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const name = String(raw.name ?? "").trim();
  const state = String(raw.state ?? "").trim();
  if (!name || !state) {
    return rejected("name y state son obligatorios");
  }
  if (!["hay", "low", "out"].includes(state)) {
    return rejected("state debe ser hay, low u out");
  }
  const col = ctx.db.collection("families").doc(ctx.familyId).collection("stockItems");
  const dup = await col.where("name", "==", name).limit(1).get();
  if (!dup.empty) {
    return rejected("Ya existe un ítem con ese nombre; confirmá en la app si querés crear otro.", {
      existing_item_id: dup.docs[0].id,
    });
  }
  const now = FieldValue.serverTimestamp();
  const ref = await col.add({
    name,
    state,
    updatedAt: now,
    updatedBy: ctx.userId,
    clientUpdatedAt: Timestamp.now(),
    conflictPolicy: "lww-v1",
  });
  return {
    response: { ok: true, item_id: ref.id, name, state },
    auditResult: "ok",
  };
}

async function handleUpdateStockStatus(
  ctx: ToolRouterContext,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const itemId = String(raw.item_id ?? "").trim();
  const state = String(raw.state ?? "").trim();
  if (!itemId || !state) {
    return rejected("item_id y state son obligatorios");
  }
  if (!["hay", "low", "out"].includes(state)) {
    return rejected("state debe ser hay, low u out");
  }
  const ref = ctx.db
    .collection("families")
    .doc(ctx.familyId)
    .collection("stockItems")
    .doc(itemId);
  const snap = await ref.get();
  if (!snap.exists) {
    return { response: { ok: false, error: "Ítem no encontrado" }, auditResult: "error" };
  }
  const now = FieldValue.serverTimestamp();
  await ref.update({
    state,
    updatedAt: now,
    updatedBy: ctx.userId,
    clientUpdatedAt: Timestamp.now(),
    conflictPolicy: "lww-v1",
  });
  return { response: { ok: true, item_id: itemId, state }, auditResult: "ok" };
}

async function handleCreateNote(
  ctx: ToolRouterContext,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const title = String(raw.title ?? "");
  const content = String(raw.content ?? "");
  const col = ctx.db.collection("families").doc(ctx.familyId).collection("sharedNotes");
  const now = FieldValue.serverTimestamp();
  const ref = await col.add({
    title,
    content,
    createdAt: now,
    updatedAt: now,
  });
  return { response: { ok: true, note_id: ref.id }, auditResult: "ok" };
}

async function handleCreateFamilyLink(
  ctx: ToolRouterContext,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  let url: string;
  try {
    url = assertHttpsUrl(raw.url);
  } catch (e) {
    return { response: { ok: false, error: (e as Error).message }, auditResult: "error" };
  }
  const title = raw.title != null ? String(raw.title).trim() : "";
  const note = raw.note != null ? String(raw.note).trim() : "";
  const payload: Record<string, unknown> = {
    url,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (title) {
    payload.title = title;
  }
  if (note) {
    payload.note = note;
  }
  const ref = await ctx.db
    .collection("families")
    .doc(ctx.familyId)
    .collection("family_links")
    .add(payload);
  return { response: { ok: true, link_id: ref.id }, auditResult: "ok" };
}

async function handleCreateExpense(
  ctx: ToolRouterContext,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const defaults = await loadCreateExpenseDefaults(ctx.db, ctx.familyId);
  const resolved = resolveCreateExpenseDraft(raw, defaults);
  if (resolved.missingCritical.length > 0) {
    return rejected("Falta un dato crítico para preparar el gasto", {
      tool: "create_expense",
      needs_user_input: true,
      missing_critical_fields: resolved.missingCritical,
      critical_fields: [...CREATE_EXPENSE_FIELDS_POLICY.critical],
      inferable_fields: [...CREATE_EXPENSE_FIELDS_POLICY.inferable],
      assumptions: resolved.assumptions,
      draft: resolved.draft,
    });
  }

  return rejected(
    "Acción pendiente de confirmación en la app (v1 del asistente no aplica mutaciones de alto riesgo).",
    {
      pending_confirmation: true,
      tool: "create_expense",
      critical_fields: [...CREATE_EXPENSE_FIELDS_POLICY.critical],
      inferable_fields: [...CREATE_EXPENSE_FIELDS_POLICY.inferable],
      assumptions: resolved.assumptions,
      draft: resolved.draft,
    },
  );
}

async function handleCreateRecipe(
  ctx: ToolRouterContext,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  const titulo = String(raw.titulo ?? "").trim();
  const descripcion = String(raw.descripcion ?? "").trim();
  const ingredientes = Array.isArray(raw.ingredientes)
    ? raw.ingredientes.map((x) => String(x ?? "").trim()).filter(Boolean)
    : [];
  const pasos = Array.isArray(raw.pasos)
    ? raw.pasos.map((x) => String(x ?? "").trim()).filter(Boolean)
    : [];
  const tiempoMin = Math.round(Number(raw.tiempo_min ?? 0));
  const porciones = Math.round(Number(raw.porciones ?? 0));
  const favorita = raw.favorita === true;
  const tags = Array.isArray(raw.tags)
    ? raw.tags.map((x) => String(x ?? "").trim()).filter(Boolean).slice(0, 12)
    : [];

  if (!titulo || !descripcion) {
    return rejected("titulo y descripcion son obligatorios");
  }
  if (ingredientes.length === 0 || pasos.length === 0) {
    return rejected("ingredientes y pasos no pueden estar vacíos");
  }
  if (!Number.isFinite(tiempoMin) || tiempoMin <= 0) {
    return rejected("tiempo_min inválido");
  }
  if (!Number.isFinite(porciones) || porciones <= 0) {
    return rejected("porciones inválido");
  }

  const col = ctx.db.collection("families").doc(ctx.familyId).collection("recipes");
  const now = FieldValue.serverTimestamp();
  const docPayload: Record<string, unknown> = {
    titulo,
    descripcion,
    ingredientes,
    pasos,
    tiempoMin,
    porciones,
    favorita,
    updatedBy: ctx.userId,
    updatedAt: now,
    clientUpdatedAt: Timestamp.now(),
    conflictPolicy: "lww-v1",
    createdBy: ctx.userId,
    createdAt: now,
  };
  if (tags.length > 0) {
    docPayload.tags = tags;
  }
  const ref = await col.add(docPayload);
  return { response: { ok: true, recipe_id: ref.id }, auditResult: "ok" };
}

async function dispatchTool(
  ctx: ToolRouterContext,
  toolName: string,
  raw: Record<string, unknown>,
): Promise<ToolExecutionResult> {
  switch (toolName) {
    case "list_expenses":
      try {
        return await handleListExpenses(ctx.db, ctx.familyId, raw);
      } catch (e) {
        return {
          response: { ok: false, error: (e as Error).message },
          auditResult: "error",
        };
      }
    case "list_categories":
      return {
        response: { ok: true, categories: EXPENSE_CATEGORIES },
        auditResult: "ok",
      };
    case "list_stock_items":
      return await handleListStock(ctx.db, ctx.familyId, raw);
    case "list_recipes":
      return await handleListRecipes(ctx.db, ctx.familyId, raw);
    case "get_recipe":
      return await handleGetRecipe(ctx.db, ctx.familyId, raw);
    case "list_notes":
      return await handleListNotes(ctx.db, ctx.familyId, raw);
    case "create_expense":
      return await handleCreateExpense(ctx, raw);
    case "update_expense":
    case "delete_expense":
    case "propose_new_category":
    case "register_card_cycle_close":
    case "register_card_payment":
    case "archive_stock_item":
    case "start_receipt_import":
      return rejected(
        "Acción pendiente de confirmación en la app (v1 del asistente no aplica mutaciones de alto riesgo).",
        { pending_confirmation: true, tool: toolName },
      );
    case "create_stock_item":
      return await handleCreateStockItem(ctx, raw);
    case "update_stock_status":
      return await handleUpdateStockStatus(ctx, raw);
    case "create_note":
      return await handleCreateNote(ctx, raw);
    case "create_family_link":
      return await handleCreateFamilyLink(ctx, raw);
    case "create_recipe":
      return await handleCreateRecipe(ctx, raw);
    case "import_recipe_from_url": {
      try {
        const url = String(raw.url ?? "").trim();
        const { draft, meta } = await draftRecipeFromUrlAsMember(
          ctx.db,
          ctx.familyId,
          ctx.userId,
          url,
        );
        return {
          response: {
            ok: true,
            preview: true,
            draft,
            meta,
            legalDisclaimer:
              "Verificá copyright y términos del sitio origen. Confirmá en la app antes de guardar.",
          },
          auditResult: "ok",
        };
      } catch (e) {
        if (e instanceof HttpsError) {
          return {
            response: { ok: false, error: e.message, code: e.code },
            auditResult: "error",
          };
        }
        return {
          response: { ok: false, error: (e as Error).message },
          auditResult: "error",
        };
      }
    }
    default:
      return { response: { ok: false, error: "Herramienta desconocida" }, auditResult: "error" };
  }
}

export async function executeAssistantTool(
  ctx: ToolRouterContext,
  toolName: string,
  args: unknown,
): Promise<ToolExecutionResult> {
  const raw = asRecord(args);
  const payloadHash = hashToolPayload(raw);
  const payloadRedacted = redactToolArgsForAudit(toolName, raw);

  if (ctx.clientRequestId && toolUsesIdempotencyStore(toolName)) {
    const cached = await readIdempotentToolResult(
      ctx.db,
      ctx.familyId,
      ctx.clientRequestId,
      toolName,
    );
    if (cached) {
      await appendAssistantActionLog({
        db: ctx.db,
        familyId: ctx.familyId,
        userId: ctx.userId,
        conversationId: ctx.conversationId,
        toolName,
        clientRequestId: ctx.clientRequestId,
        payloadHash,
        payloadRedacted: { ...payloadRedacted, idempotent_replay: true },
        result: "ok",
        source: toolName === "create_expense" ? "chatbot" : "assistant_tool",
      });
      return { response: cached, auditResult: "ok" };
    }
  }

  const out = await dispatchTool(ctx, toolName, raw);

  await appendAssistantActionLog({
    db: ctx.db,
    familyId: ctx.familyId,
    userId: ctx.userId,
    conversationId: ctx.conversationId,
    toolName,
    clientRequestId: ctx.clientRequestId,
    payloadHash,
    payloadRedacted,
    result: out.auditResult,
    source: toolName === "create_expense" ? "chatbot" : "assistant_tool",
  });

  if (
    ctx.clientRequestId &&
    toolUsesIdempotencyStore(toolName) &&
    out.auditResult === "ok"
  ) {
    await writeIdempotentToolResult(
      ctx.db,
      ctx.familyId,
      ctx.clientRequestId,
      toolName,
      out.response,
    );
  }

  return out;
}
