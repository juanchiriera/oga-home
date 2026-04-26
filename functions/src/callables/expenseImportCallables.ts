import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";

import {
  OPENROUTER_CHAT_COMPLETIONS_URL,
  buildExpenseVisionChatPayload,
  extractChatCompletionMessageText,
} from "../llm/openRouterApi.js";
import { openRouterApiKey, openRouterRequestHeaders } from "./recipeCallables.js";

const region = "southamerica-east1";
const pendingCardCycle = "pending_card_cycle";
const confirmed = "confirmed";
const creditCardType = "credit_card";

const openRouterExpenseModel = defineString("OPENROUTER_EXPENSE_MODEL", {
  default: "openai/gpt-4o-mini",
});

type ImportLine = {
  amount: number;
  categoryKey: string;
  occurredAtIso: string;
  merchant: string;
  note: string;
  paymentMethodId: string;
  paymentMethodType: string;
};

type OcrProviderInput = {
  mimeType: string;
  base64Data: string;
  paymentMethods: Array<{ id: string; type: string; name: string }>;
  nowIsoDate: string;
};

interface ExpenseImportOcrProvider {
  extractLines(input: OcrProviderInput): Promise<ImportLine[]>;
}

class OpenRouterVisionOcrProvider implements ExpenseImportOcrProvider {
  async extractLines(input: OcrProviderInput): Promise<ImportLine[]> {
    const prompt = [
      "Sos un parser de tickets y resúmenes de tarjeta.",
      "Devolvés SOLO JSON válido sin markdown.",
      "Formato exacto: {\"lines\":[{\"amount\":number,\"categoryKey\":string,\"occurredAtIso\":\"YYYY-MM-DD\",\"merchant\":string,\"note\":string,\"paymentMethodId\":string}]}",
      "Si no se detecta campo, usá:",
      "- categoryKey: \"other\"",
      `- occurredAtIso: \"${input.nowIsoDate}\"`,
      "- merchant: \"\"",
      "- note: \"\"",
      "paymentMethodId debe ser uno de estos IDs exactos:",
      JSON.stringify(input.paymentMethods.map((method) => method.id)),
      "Inferí paymentMethodId por contexto; si no se puede, usar el primer método de la lista.",
      "amount debe ser > 0.",
    ].join("\n");

    const dataUrl = `data:${input.mimeType};base64,${input.base64Data}`;
    const model = openRouterExpenseModel.value().trim();
    const key = openRouterApiKey.value();
    const response = await fetch(OPENROUTER_CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: openRouterRequestHeaders(key),
      body: JSON.stringify(buildExpenseVisionChatPayload(model, prompt, dataUrl)),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new HttpsError(
        "internal",
        `Solicitud al proveedor de visión falló (${response.status})`,
        { errorText },
      );
    }

    const text = extractChatCompletionMessageText(await response.json());
    if (!text) {
      throw new HttpsError("data-loss", "El proveedor de IA no devolvió contenido");
    }

    let parsed: { lines?: Array<Record<string, unknown>> };
    try {
      parsed = JSON.parse(text) as { lines?: Array<Record<string, unknown>> };
    } catch {
      throw new HttpsError("data-loss", "El proveedor de IA devolvió JSON inválido");
    }

    const byId = new Map(input.paymentMethods.map((method) => [method.id, method]));
    const fallbackMethodId = input.paymentMethods[0]?.id ?? "";
    const fallbackMethodType = input.paymentMethods[0]?.type ?? "other";

    const lines = (parsed.lines ?? []).map((raw) => {
      const amount = Number(raw.amount ?? 0);
      const paymentMethodId = String(raw.paymentMethodId ?? "").trim() || fallbackMethodId;
      const paymentMethod = byId.get(paymentMethodId);
      return {
        amount: Number.isFinite(amount) && amount > 0 ? amount : 0,
        categoryKey: String(raw.categoryKey ?? "other").trim() || "other",
        occurredAtIso: normalizeIsoDate(String(raw.occurredAtIso ?? input.nowIsoDate)),
        merchant: String(raw.merchant ?? "").trim(),
        note: String(raw.note ?? "").trim(),
        paymentMethodId: paymentMethodId || fallbackMethodId,
        paymentMethodType: paymentMethod?.type ?? fallbackMethodType,
      } satisfies ImportLine;
    }).filter((line) => line.amount > 0 && line.paymentMethodId.length > 0);

    if (!lines.length) {
      throw new HttpsError(
        "failed-precondition",
        "No se pudieron extraer líneas válidas del archivo",
      );
    }

    return lines;
  }
}

function requireAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  return request.auth.uid;
}

function normalizeIsoDate(raw: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(raw).trim());
  if (!match) {
    return new Date().toISOString().slice(0, 10);
  }
  return `${match[1]}-${match[2]}-${match[3]}`;
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

function expenseStatusFromPaymentType(type: string): string {
  return type === creditCardType ? pendingCardCycle : confirmed;
}

function isoToTimestamp(iso: string): Timestamp {
  const safeIso = normalizeIsoDate(iso);
  return Timestamp.fromDate(new Date(`${safeIso}T00:00:00.000Z`));
}

function importJobRef(db: admin.firestore.Firestore, familyId: string, jobId: string) {
  return db.collection("families").doc(familyId).collection("importJobs").doc(jobId);
}

export const startExpenseImport = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const familyId = String(request.data?.familyId ?? "").trim();
  const fileName = String(request.data?.fileName ?? "ticket").trim() || "ticket";
  const mimeType = String(request.data?.mimeType ?? "application/octet-stream").trim();

  if (!familyId) {
    throw new HttpsError("invalid-argument", "familyId es obligatorio");
  }

  const db = admin.firestore();
  await assertFamilyMember(db, familyId, uid);

  const jobRef = db.collection("families").doc(familyId).collection("importJobs").doc();
  const safeFileName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
  const storagePath = `families/${familyId}/expense-imports/${jobRef.id}/${safeFileName}`;

  await jobRef.set({
    status: "uploaded",
    fileName: safeFileName,
    mimeType,
    storagePath,
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    provider: {
      ocrMode: "openrouter_vision_v1",
      providerKey: "openrouter",
    },
  });

  return {
    importJobId: jobRef.id,
    storagePath,
    bucket: admin.storage().bucket().name,
  };
});

export const processExpenseImport = onCall(
  { region, secrets: [openRouterApiKey] },
  async (request) => {
  const uid = requireAuth(request);
  const familyId = String(request.data?.familyId ?? "").trim();
  const importJobId = String(request.data?.importJobId ?? "").trim();
  if (!familyId || !importJobId) {
    throw new HttpsError("invalid-argument", "familyId e importJobId son obligatorios");
  }

  const db = admin.firestore();
  await assertFamilyMember(db, familyId, uid);
  const jobRef = importJobRef(db, familyId, importJobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) {
    throw new HttpsError("not-found", "ImportJob no encontrado");
  }

  const storagePath = String(jobSnap.get("storagePath") ?? "").trim();
  const mimeType = String(jobSnap.get("mimeType") ?? "application/octet-stream");
  if (!storagePath) {
    throw new HttpsError("failed-precondition", "ImportJob sin storagePath");
  }

  const paymentMethodsSnap = await db
    .collection("families")
    .doc(familyId)
    .collection("paymentMethods")
    .orderBy("name")
    .get();
  const paymentMethods = paymentMethodsSnap.docs.map((doc) => ({
    id: doc.id,
    type: String(doc.get("type") ?? "other"),
    name: String(doc.get("name") ?? ""),
  }));
  if (!paymentMethods.length) {
    throw new HttpsError(
      "failed-precondition",
      "Necesitás al menos un método de pago para importar",
    );
  }

  try {
    await jobRef.update({
      status: "processing",
      processingStartedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const file = admin.storage().bucket().file(storagePath);
    const [buffer] = await file.download();
    const provider: ExpenseImportOcrProvider = new OpenRouterVisionOcrProvider();
    const nowIsoDate = new Date().toISOString().slice(0, 10);
    const lines = await provider.extractLines({
      mimeType,
      base64Data: buffer.toString("base64"),
      paymentMethods,
      nowIsoDate,
    });

    await jobRef.update({
      status: "awaiting_confirmation",
      parsedAt: FieldValue.serverTimestamp(),
      parsedBy: uid,
      proposedLines: lines,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      importJobId,
      status: "awaiting_confirmation",
      proposedCount: lines.length,
    };
  } catch (error) {
    await jobRef.update({
      status: "failed",
      errorMessage: (error as Error).message ?? "Error de procesamiento",
      updatedAt: FieldValue.serverTimestamp(),
    });
    throw error;
  }
});

export const confirmExpenseImport = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const familyId = String(request.data?.familyId ?? "").trim();
  const importJobId = String(request.data?.importJobId ?? "").trim();
  const linesRaw = request.data?.lines;
  if (!familyId || !importJobId || !Array.isArray(linesRaw) || !linesRaw.length) {
    throw new HttpsError(
      "invalid-argument",
      "familyId, importJobId y lines son obligatorios",
    );
  }

  const db = admin.firestore();
  await assertFamilyMember(db, familyId, uid);
  const jobRef = importJobRef(db, familyId, importJobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) {
    throw new HttpsError("not-found", "ImportJob no encontrado");
  }
  if (String(jobSnap.get("status") ?? "") !== "awaiting_confirmation") {
    throw new HttpsError(
      "failed-precondition",
      "El ImportJob no está listo para confirmar",
    );
  }

  const paymentMethodsSnap = await db
    .collection("families")
    .doc(familyId)
    .collection("paymentMethods")
    .get();
  const paymentMethodsById = new Map(
    paymentMethodsSnap.docs.map((doc) => [doc.id, String(doc.get("type") ?? "other")]),
  );

  const normalizedLines = linesRaw.map((raw) => {
    const amount = Number(raw?.amount ?? 0);
    const paymentMethodId = String(raw?.paymentMethodId ?? "").trim();
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError("invalid-argument", "Cada línea debe tener amount > 0");
    }
    if (!paymentMethodMethodsByIdHas(paymentMethodsById, paymentMethodId)) {
      throw new HttpsError(
        "invalid-argument",
        `Método de pago inválido: ${paymentMethodId || "vacío"}`,
      );
    }
    const paymentMethodType = paymentMethodsById.get(paymentMethodId) ?? "other";
    return {
      amount,
      categoryKey: String(raw?.categoryKey ?? "other").trim() || "other",
      occurredAtIso: normalizeIsoDate(String(raw?.occurredAtIso ?? "")),
      merchant: String(raw?.merchant ?? "").trim(),
      note: String(raw?.note ?? "").trim(),
      paymentMethodId,
      status: expenseStatusFromPaymentType(paymentMethodType),
    };
  });

  const expensesCol = db.collection("families").doc(familyId).collection("expenses");
  const batch = db.batch();
  for (const line of normalizedLines) {
    batch.set(expensesCol.doc(), {
      amount: line.amount,
      categoryKey: line.categoryKey,
      occurredAt: isoToTimestamp(line.occurredAtIso),
      merchant: line.merchant,
      note: line.note,
      paymentMethodId: line.paymentMethodId,
      status: line.status,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      importJobId,
    });
  }

  batch.update(jobRef, {
    status: "applied",
    appliedAt: FieldValue.serverTimestamp(),
    appliedBy: uid,
    appliedCount: normalizedLines.length,
    confirmedLines: normalizedLines,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await batch.commit();
  logger.info("confirmExpenseImport", {
    familyId,
    importJobId,
    appliedCount: normalizedLines.length,
  });
  return {
    importJobId,
    status: "applied",
    appliedCount: normalizedLines.length,
  };
});

function paymentMethodMethodsByIdHas(
  paymentMethodsById: Map<string, string>,
  paymentMethodId: string,
): boolean {
  return paymentMethodId.length > 0 && paymentMethodsById.has(paymentMethodId);
}
