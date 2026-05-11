import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

const region = "southamerica-east1";
const scheduleTz = "America/Argentina/Buenos_Aires";

export type GenerationDay = "month_start" | "month_end";
export type RecurringType = "fixed_monthly" | "installment";

export interface RecurringTemplateData {
  active: boolean;
  amount: number;
  categoryKey: string;
  currency?: string | null;
  paymentMethodId?: string;
  type: RecurringType;
  generationDay: GenerationDay;
  totalInstallments?: number | null;
  currentInstallment?: number | null;
  /** Primer período YYYY-MM en el que puede generarse una cuota (inclusive). */
  startPeriodKey?: string | null;
  merchant?: string | null;
  note?: string | null;
  lastGeneratedPeriod?: string | null;
  createdBy: string;
}

/** `periodKey` y `startPeriodKey` en formato YYYY-MM; el orden léxico coincide con el cronológico. */
export function shouldDeferPeriodForStartKey(
  periodKey: string,
  startPeriodKey: string | null | undefined,
): boolean {
  if (startPeriodKey == null) {
    return false;
  }
  const s = String(startPeriodKey).trim();
  if (!/^\d{4}-\d{2}$/.test(s)) {
    return false;
  }
  return periodKey < s;
}

function calendarPartsInTz(now: Date, timeZone: string): { y: number; m: number; d: number } {
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = fmt.formatToParts(now);
  const y = Number(parts.find((p) => p.type === "year")?.value ?? 0);
  const m = Number(parts.find((p) => p.type === "month")?.value ?? 0);
  const d = Number(parts.find((p) => p.type === "day")?.value ?? 0);
  return { y, m, d };
}

function lastDayOfMonth(y: number, m: number): number {
  return new Date(y, m, 0).getDate();
}

function periodKey(y: number, m: number): string {
  return `${y}-${String(m).padStart(2, "0")}`;
}

function isGenerationCalendarDay(
  y: number,
  m: number,
  d: number,
  generationDay: GenerationDay,
): boolean {
  if (generationDay === "month_start") {
    return d === 1;
  }
  return d === lastDayOfMonth(y, m);
}

/** Mediodía (12:00) hora civil ART (UTC-3 sin DST) → 15:00 UTC. */
function occurredAtNoonArt(y: number, m: number, d: number): Timestamp {
  return Timestamp.fromMillis(Date.UTC(y, m - 1, d, 15, 0, 0));
}

function buildInstallmentNote(
  base: string | null | undefined,
  index: number,
  total: number | null | undefined,
): string | undefined {
  const suffix = `Cuota ${index}${total != null ? `/${total}` : ""}`;
  if (base && base.trim()) {
    return `${base.trim()} · ${suffix}`;
  }
  return suffix;
}

async function processTemplate(
  db: admin.firestore.Firestore,
  familyId: string,
  templateId: string,
  templateRef: admin.firestore.DocumentReference,
  now: Date,
): Promise<boolean> {
  const { y, m, d } = calendarPartsInTz(now, scheduleTz);
  const key = periodKey(y, m);

  const snap = await templateRef.get();
  if (!snap.exists) {
    return false;
  }
  const raw = snap.data() as RecurringTemplateData;
  if (!raw?.active || typeof raw.amount !== "number" || raw.amount <= 0) {
    return false;
  }
  if (raw.type !== "fixed_monthly" && raw.type !== "installment") {
    return false;
  }
  if (raw.generationDay !== "month_start" && raw.generationDay !== "month_end") {
    return false;
  }
  if (typeof raw.categoryKey !== "string" || !raw.categoryKey) {
    return false;
  }
  if (typeof raw.createdBy !== "string" || !raw.createdBy) {
    return false;
  }

  if (shouldDeferPeriodForStartKey(key, raw.startPeriodKey)) {
    return false;
  }

  if (!isGenerationCalendarDay(y, m, d, raw.generationDay)) {
    return false;
  }

  if (raw.type === "installment") {
    const total = raw.totalInstallments;
    const current = raw.currentInstallment ?? 1;
    if (total == null || total < 1 || current > total) {
      return false;
    }
  }

  let generated = false;
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(templateRef);
    if (!fresh.exists) {
      return;
    }
    const t = fresh.data() as RecurringTemplateData;
    if (!t.active || t.lastGeneratedPeriod === key) {
      return;
    }
    if (shouldDeferPeriodForStartKey(key, t.startPeriodKey)) {
      return;
    }
    if (!isGenerationCalendarDay(y, m, d, t.generationDay)) {
      return;
    }
    if (t.type === "installment") {
      const total = t.totalInstallments;
      const current = t.currentInstallment ?? 1;
      if (total == null || total < 1 || current > total) {
        return;
      }
    }

    const expensesCol = db.collection("families").doc(familyId).collection("expenses");
    const expenseRef = expensesCol.doc();
    const ts = Timestamp.now();
    const occurredAt = occurredAtNoonArt(y, m, d);

    let installmentIndex: number | undefined;
    let installmentTotal: number | undefined;
    if (t.type === "installment") {
      installmentIndex = t.currentInstallment ?? 1;
      installmentTotal = t.totalInstallments ?? undefined;
    }

    const note =
      t.type === "installment" && installmentIndex != null
        ? buildInstallmentNote(t.note ?? undefined, installmentIndex, installmentTotal)
        : t.note ?? undefined;

    const expensePayload: Record<string, unknown> = {
      amount: t.amount,
      categoryKey: t.categoryKey,
      occurredAt,
      createdAt: ts,
      updatedAt: ts,
      createdBy: t.createdBy,
      status: "confirmed",
      recurringTemplateId: templateId,
      recurringPeriodKey: key,
    };
    if (t.currency) {
      expensePayload.currency = t.currency;
    }
    if (t.paymentMethodId) {
      expensePayload.paymentMethodId = t.paymentMethodId;
    }
    if (t.merchant) {
      expensePayload.merchant = t.merchant;
    }
    if (note) {
      expensePayload.note = note;
    }
    if (installmentIndex != null) {
      expensePayload.installmentIndex = installmentIndex;
    }
    if (installmentTotal != null) {
      expensePayload.installmentTotal = installmentTotal;
    }

    tx.set(expenseRef, expensePayload);

    const updates: Record<string, unknown> = {
      lastGeneratedPeriod: key,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (t.type === "installment") {
      const next = (t.currentInstallment ?? 1) + 1;
      const total = t.totalInstallments ?? 0;
      updates.currentInstallment = next;
      if (next > total) {
        updates.active = false;
      }
    }
    tx.update(templateRef, updates);
    generated = true;
  });

  if (generated) {
    logger.info("recurring expense generated", { familyId, templateId, period: key });
  }
  return generated;
}

export const generateRecurringExpenses = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: scheduleTz,
    region,
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    const db = admin.firestore();
    const familiesSnap = await db.collection("families").select().get();
    let templatesSeen = 0;
    let generatedCount = 0;

    for (const fam of familiesSnap.docs) {
      const familyId = fam.id;
      const templatesSnap = await db
        .collection("families")
        .doc(familyId)
        .collection("recurringTemplates")
        .where("active", "==", true)
        .get();

      for (const doc of templatesSnap.docs) {
        templatesSeen++;
        const ok = await processTemplate(db, familyId, doc.id, doc.ref, new Date());
        if (ok) {
          generatedCount++;
        }
      }
    }

    logger.info("generateRecurringExpenses finished", {
      families: familiesSnap.size,
      templatesSeen,
      generatedCount,
    });
  },
);
