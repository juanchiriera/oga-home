import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const region = "southamerica-east1";

const PENDING = "pending_card_cycle";
const CONFIRMED = "confirmed";
const CREDIT = "credit_card";

function requireAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  return request.auth.uid;
}

function parseIsoDateOnly(raw: string): { y: number; m: number; d: number } {
  const s = String(raw ?? "").trim();
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) {
    throw new HttpsError(
      "invalid-argument",
      "La fecha debe tener formato YYYY-MM-DD",
    );
  }
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) {
    throw new HttpsError("invalid-argument", "Fecha inválida");
  }
  return { y, m: mo, d };
}

function utcStartOfCalendarDay(parts: {
  y: number;
  m: number;
  d: number;
}): Timestamp {
  return Timestamp.fromDate(
    new Date(Date.UTC(parts.y, parts.m - 1, parts.d, 0, 0, 0, 0)),
  );
}

function utcEndOfCalendarDayInclusive(parts: {
  y: number;
  m: number;
  d: number;
}): Timestamp {
  return Timestamp.fromDate(
    new Date(Date.UTC(parts.y, parts.m - 1, parts.d, 23, 59, 59, 999)),
  );
}

async function assertFamilyMember(
  db: admin.firestore.Firestore,
  familyId: string,
  uid: string,
): Promise<void> {
  const snap = await db
    .collection("families")
    .doc(familyId)
    .collection("members")
    .doc(uid)
    .get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "No sos miembro de esta familia");
  }
}

async function assertCreditPaymentMethod(
  db: admin.firestore.Firestore,
  familyId: string,
  paymentMethodId: string,
): Promise<void> {
  const snap = await db
    .collection("families")
    .doc(familyId)
    .collection("paymentMethods")
    .doc(paymentMethodId)
    .get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Método de pago no encontrado");
  }
  if (snap.get("type") !== CREDIT) {
    throw new HttpsError(
      "failed-precondition",
      "Solo aplica a métodos tipo tarjeta de crédito",
    );
  }
}

async function collectPendingForCard(
  expensesCol: admin.firestore.CollectionReference,
  paymentMethodId: string,
  occurredAtMax?: Timestamp,
): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  const out: admin.firestore.QueryDocumentSnapshot[] = [];
  let last: admin.firestore.QueryDocumentSnapshot | undefined;
  const page = 300;
  for (;;) {
    let q: admin.firestore.Query = expensesCol
      .where("paymentMethodId", "==", paymentMethodId)
      .where("status", "==", PENDING);
    if (occurredAtMax !== undefined) {
      q = q.where("occurredAt", "<=", occurredAtMax);
    }
    q = q.orderBy("occurredAt", "asc").limit(page);
    if (last !== undefined) {
      q = q.startAfter(last);
    }
    const snap = await q.get();
    if (snap.empty) {
      break;
    }
    out.push(...snap.docs);
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < page) {
      break;
    }
  }
  return out;
}

async function applyConfirmations(
  db: admin.firestore.Firestore,
  docs: admin.firestore.DocumentSnapshot[],
  fechaEfectiva: Timestamp,
): Promise<number> {
  const chunk = 400;
  for (let i = 0; i < docs.length; i += chunk) {
    const batch = db.batch();
    for (const doc of docs.slice(i, i + chunk)) {
      batch.update(doc.ref, {
        status: CONFIRMED,
        fecha_efectiva: fechaEfectiva,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
  return docs.length;
}

export const registerCardCycleClose = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const familyId = String(request.data?.familyId ?? "").trim();
  const paymentMethodId = String(request.data?.paymentMethodId ?? "").trim();
  const closingDateIso = String(request.data?.closingDate ?? "").trim();
  if (!familyId || !paymentMethodId || !closingDateIso) {
    throw new HttpsError(
      "invalid-argument",
      "familyId, paymentMethodId y closingDate (YYYY-MM-DD) son obligatorios",
    );
  }

  const parts = parseIsoDateOnly(closingDateIso);
  const fechaEfectiva = utcStartOfCalendarDay(parts);
  const occurredAtMax = utcEndOfCalendarDayInclusive(parts);

  const db = admin.firestore();
  await assertFamilyMember(db, familyId, uid);
  await assertCreditPaymentMethod(db, familyId, paymentMethodId);

  const expensesCol = db
    .collection("families")
    .doc(familyId)
    .collection("expenses");

  const pending = await collectPendingForCard(
    expensesCol,
    paymentMethodId,
    occurredAtMax,
  );

  const eventRef = db
    .collection("families")
    .doc(familyId)
    .collection("expenseSettlementEvents")
    .doc();

  await eventRef.set({
    type: "card_cycle_close",
    paymentMethodId,
    closingDate: closingDateIso,
    fechaEfectiva,
    affectedCount: pending.length,
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  const updated = await applyConfirmations(db, pending, fechaEfectiva);
  logger.info("registerCardCycleClose", {
    familyId,
    paymentMethodId,
    closingDateIso,
    updated,
    eventId: eventRef.id,
  });

  return {
    eventId: eventRef.id,
    affectedCount: updated,
    closingDate: closingDateIso,
  };
});

export const registerCardPayment = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const familyId = String(request.data?.familyId ?? "").trim();
  const paymentMethodId = String(request.data?.paymentMethodId ?? "").trim();
  const effectiveDateIso = String(request.data?.effectiveDate ?? "").trim();
  const expenseIdsRaw = request.data?.expenseIds;

  if (!familyId || !paymentMethodId || !effectiveDateIso) {
    throw new HttpsError(
      "invalid-argument",
      "familyId, paymentMethodId y effectiveDate (YYYY-MM-DD) son obligatorios",
    );
  }

  const parts = parseIsoDateOnly(effectiveDateIso);
  const fechaEfectiva = utcStartOfCalendarDay(parts);

  const db = admin.firestore();
  await assertFamilyMember(db, familyId, uid);
  await assertCreditPaymentMethod(db, familyId, paymentMethodId);

  const expensesCol = db
    .collection("families")
    .doc(familyId)
    .collection("expenses");

  let pending: admin.firestore.DocumentSnapshot[];

  if (Array.isArray(expenseIdsRaw) && expenseIdsRaw.length > 0) {
    const ids = expenseIdsRaw.map((x: unknown) => String(x).trim()).filter(Boolean);
    pending = [];
    for (const id of ids) {
      const snap = await expensesCol.doc(id).get();
      if (!snap.exists) {
        throw new HttpsError("not-found", `Gasto inexistente: ${id}`);
      }
      const d = snap.data();
      if (d?.status !== PENDING) {
        throw new HttpsError(
          "failed-precondition",
          `El gasto ${id} no está pendiente de tarjeta`,
        );
      }
      if (d?.paymentMethodId !== paymentMethodId) {
        throw new HttpsError(
          "failed-precondition",
          `El gasto ${id} no pertenece al método indicado`,
        );
      }
      pending.push(snap);
    }
  } else {
    pending = await collectPendingForCard(expensesCol, paymentMethodId);
  }

  const eventRef = db
    .collection("families")
    .doc(familyId)
    .collection("expenseSettlementEvents")
    .doc();

  await eventRef.set({
    type: "card_payment",
    paymentMethodId,
    effectiveDate: effectiveDateIso,
    fechaEfectiva,
    affectedCount: pending.length,
    expenseIds:
      Array.isArray(expenseIdsRaw) && expenseIdsRaw.length > 0
        ? pending.map((d) => d.id)
        : null,
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  const updated = await applyConfirmations(db, pending, fechaEfectiva);
  logger.info("registerCardPayment", {
    familyId,
    paymentMethodId,
    effectiveDateIso,
    updated,
    eventId: eventRef.id,
  });

  return {
    eventId: eventRef.id,
    affectedCount: updated,
    effectiveDate: effectiveDateIso,
  };
});
