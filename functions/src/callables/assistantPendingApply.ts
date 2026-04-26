import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { appendAssistantActionLog, hashToolPayload, redactToolArgsForAudit } from "./assistantToolAudit.js";
import { requireCallAuth, assertFamilyMember } from "./assistantCore.js";

const region = "southamerica-east1";

const EXPENSE_CATEGORY_KEYS = new Set([
  "housing",
  "food",
  "transport",
  "shopping",
  "utilities",
  "health",
  "education",
  "leisure",
  "other",
]);

const PENDING = "pending_card_cycle";
const CONFIRMED = "confirmed";
const CREDIT = "credit_card";

function parseIsoDateOnly(raw: string): { y: number; m: number; d: number } {
  const s = String(raw ?? "").trim();
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) {
    throw new HttpsError("invalid-argument", "Fecha inválida (usar YYYY-MM-DD)");
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) {
    throw new HttpsError("invalid-argument", "Fecha inválida");
  }
  return { y, m: mo, d };
}

function utcStartOfDay(parts: { y: number; m: number; d: number }): Timestamp {
  return Timestamp.fromDate(new Date(Date.UTC(parts.y, parts.m - 1, parts.d, 0, 0, 0, 0)));
}

function asRecord(x: unknown): Record<string, unknown> {
  return x && typeof x === "object" && !Array.isArray(x) ? (x as Record<string, unknown>) : {};
}

function statusForPaymentMethodType(t: string): string {
  return t === CREDIT ? PENDING : CONFIRMED;
}

/**
 * Aplica en servidor una herramienta de alto riesgo tras confirmación explícita en la app (§8.1).
 * No cubre cierre/pago de tarjeta: el cliente llama a `registerCardCycleClose` / `registerCardPayment`.
 */
export const assistantApplyPendingTool = onCall({ region }, async (request) => {
  const uid = requireCallAuth(request);
  const data = asRecord(request.data);
  const familyId = String(data.familyId ?? "").trim();
  const tool = String(data.tool ?? "").trim();
  const args = asRecord(data.args);
  const conversationId = String(data.conversationId ?? "").trim() || "pending-apply";

  if (!familyId || !tool) {
    throw new HttpsError("invalid-argument", "familyId y tool son obligatorios");
  }

  const db = admin.firestore();
  await assertFamilyMember(db, familyId, uid);

  const logCtx = {
    db,
    familyId,
    userId: uid,
    conversationId,
    toolName: tool,
    clientRequestId: undefined as string | undefined,
    payloadHash: hashToolPayload(args),
    payloadRedacted: redactToolArgsForAudit(tool, args),
  };

  const okLog = () => appendAssistantActionLog({ ...logCtx, result: "ok" });
  const errLog = () => appendAssistantActionLog({ ...logCtx, result: "error" });

  try {
    if (tool === "create_expense") {
      const amount = Number(args.amount);
      if (!Number.isFinite(amount) || amount <= 0) {
        throw new HttpsError("invalid-argument", "Monto inválido");
      }
      const currency = String(args.currency ?? "").trim().toUpperCase();
      if (!["ARS", "USD", "EUR"].includes(currency)) {
        throw new HttpsError("invalid-argument", "Moneda inválida");
      }
      const categoryKey = String(args.category_key ?? "").trim();
      if (!EXPENSE_CATEGORY_KEYS.has(categoryKey)) {
        throw new HttpsError("invalid-argument", "Categoría no reconocida");
      }
      const occurredAt = utcStartOfDay(parseIsoDateOnly(String(args.occurred_at ?? "")));
      let paymentMethodId = String(args.payment_method_id ?? "").trim();
      if (!paymentMethodId) {
        const pms = await db
          .collection("families")
          .doc(familyId)
          .collection("paymentMethods")
          .orderBy("name")
          .limit(1)
          .get();
        if (pms.empty) {
          throw new HttpsError(
            "failed-precondition",
            "No hay métodos de pago: agregá uno en Gastos.",
          );
        }
        paymentMethodId = pms.docs[0].id;
      }
      const pmSnap = await db
        .collection("families")
        .doc(familyId)
        .collection("paymentMethods")
        .doc(paymentMethodId)
        .get();
      if (!pmSnap.exists) {
        throw new HttpsError("not-found", "Método de pago no encontrado");
      }
      const pmType = String(pmSnap.get("type") ?? "other");
      const status = statusForPaymentMethodType(pmType);
      const merchant = args.merchant != null ? String(args.merchant).trim() : "";
      const note = args.note != null ? String(args.note).trim() : "";
      const now = FieldValue.serverTimestamp();
      const col = db.collection("families").doc(familyId).collection("expenses");
      const ref = await col.add({
        amount,
        currency,
        categoryKey: categoryKey,
        occurredAt,
        paymentMethodId,
        status,
        merchant,
        note,
        createdAt: now,
        updatedAt: now,
        createdBy: uid,
      });
      await okLog();
      return { ok: true, expenseId: ref.id };
    }

    if (tool === "delete_expense") {
      const expenseId = String(args.expense_id ?? "").trim();
      if (!expenseId) {
        throw new HttpsError("invalid-argument", "expense_id es obligatorio");
      }
      const ref = db
        .collection("families")
        .doc(familyId)
        .collection("expenses")
        .doc(expenseId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Gasto no encontrado");
      }
      await ref.delete();
      await okLog();
      return { ok: true, deletedId: expenseId };
    }

    if (tool === "update_expense") {
      const expenseId = String(args.expense_id ?? "").trim();
      if (!expenseId) {
        throw new HttpsError("invalid-argument", "expense_id es obligatorio");
      }
      const ref = db
        .collection("families")
        .doc(familyId)
        .collection("expenses")
        .doc(expenseId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Gasto no encontrado");
      }
      const payload: Record<string, unknown> = {
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (args.amount != null) {
        const a = Number(args.amount);
        if (!Number.isFinite(a) || a <= 0) {
          throw new HttpsError("invalid-argument", "Monto inválido");
        }
        payload.amount = a;
      }
      if (args.category_key != null) {
        const ck = String(args.category_key).trim();
        if (!EXPENSE_CATEGORY_KEYS.has(ck)) {
          throw new HttpsError("invalid-argument", "Categoría no reconocida");
        }
        payload.categoryKey = ck;
      }
      if (args.payment_method_id != null) {
        const pm = String(args.payment_method_id).trim();
        const pmDoc = await db
          .collection("families")
          .doc(familyId)
          .collection("paymentMethods")
          .doc(pm)
          .get();
        if (!pmDoc.exists) {
          throw new HttpsError("not-found", "Método de pago no encontrado");
        }
        payload.paymentMethodId = pm;
        const pmType = String(pmDoc.get("type") ?? "other");
        payload.status = statusForPaymentMethodType(pmType);
      }
      if (args.merchant != null) {
        payload.merchant = String(args.merchant);
      }
      if (args.note != null) {
        payload.note = String(args.note);
      }
      if (args.occurred_at != null) {
        payload.occurredAt = utcStartOfDay(
          parseIsoDateOnly(String(args.occurred_at)),
        );
      }
      await ref.update(payload);
      await okLog();
      return { ok: true, expenseId };
    }

    if (tool === "archive_stock_item") {
      const itemId = String(args.item_id ?? "").trim();
      if (!itemId) {
        throw new HttpsError("invalid-argument", "item_id es obligatorio");
      }
      const ref = db
        .collection("families")
        .doc(familyId)
        .collection("stockItems")
        .doc(itemId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Ítem no encontrado");
      }
      await ref.delete();
      await okLog();
      return { ok: true, itemId };
    }

    if (tool === "propose_new_category") {
      const label = String(args.label ?? "").trim();
      if (!label) {
        throw new HttpsError("invalid-argument", "label es obligatorio");
      }
      await okLog();
      return {
        ok: true,
        message:
          "Registramos la sugerencia. En esta versión usá las categorías existentes al crear el gasto; pronto podrán sumarse personalizadas.",
        label,
        suggestedKey: args.key != null ? String(args.key).trim() : null,
      };
    }

    if (tool === "start_receipt_import") {
      await errLog();
      throw new HttpsError(
        "failed-precondition",
        "Abrí Gastos y usá el flujo de importar ticket / escanear comprobante.",
      );
    }

    if (
      tool === "register_card_cycle_close" ||
      tool === "register_card_payment"
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Esta acción se confirma con las funciones registerCardCycleClose / registerCardPayment desde el cliente.",
      );
    }

    throw new HttpsError("invalid-argument", `Herramienta no soportada: ${tool}`);
  } catch (e) {
    if (e instanceof HttpsError) {
      throw e;
    }
    logger.error("assistantApplyPendingTool:unexpected", e);
    try {
      await errLog();
    } catch (logE) {
      logger.warn("assistantApplyPendingTool:log_err2", logE);
    }
    throw new HttpsError("internal", "No se pudo aplicar la acción");
  }
});
