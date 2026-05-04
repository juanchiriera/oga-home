import { readFileSync } from "node:fs";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { Timestamp, doc, getDoc, setDoc } from "firebase/firestore";
import { afterAll, afterEach, beforeAll, describe, it } from "vitest";

const RULES_PATH = new URL("../../firestore.rules", import.meta.url);
const projectId = "demo-famil-ia-rules";

let testEnv: RulesTestEnvironment;

function memberPath(familyId: string, uid: string): string {
  return `families/${familyId}/members/${uid}`;
}

function invitePath(familyId: string, inviteId: string): string {
  return `families/${familyId}/invites/${inviteId}`;
}

function expensePath(familyId: string, expenseId: string): string {
  return `families/${familyId}/expenses/${expenseId}`;
}

function recurringTemplatePath(familyId: string, templateId: string): string {
  return `families/${familyId}/recurringTemplates/${templateId}`;
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(RULES_PATH, "utf8"),
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("firestore.rules · invitaciones", () => {
  it("permite leer invites a cualquier miembro de la familia", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, memberPath("famA", "ownerA")), { role: "owner" });
      await setDoc(doc(db, memberPath("famA", "memberA")), { role: "member" });
      await setDoc(doc(db, invitePath("famA", "inv1")), {
        token: "abc",
        status: "pending",
      });
    });

    const ownerDb = testEnv.authenticatedContext("ownerA").firestore();
    const memberDb = testEnv.authenticatedContext("memberA").firestore();
    const outsiderDb = testEnv.authenticatedContext("outsiderA").firestore();

    await assertSucceeds(getDoc(doc(ownerDb, invitePath("famA", "inv1"))));
    await assertSucceeds(getDoc(doc(memberDb, invitePath("famA", "inv1"))));
    await assertFails(getDoc(doc(outsiderDb, invitePath("famA", "inv1"))));
  });
});

describe("firestore.rules · gastos tarjeta", () => {
  it("acepta estado pending_card_cycle para miembro", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, memberPath("famB", "u1")), { role: "member" });
    });

    const userDb = testEnv.authenticatedContext("u1").firestore();
    await assertSucceeds(
      setDoc(doc(userDb, expensePath("famB", "exp-ok")), {
        amount: 4900,
        categoryKey: "shopping",
        occurredAt: Timestamp.now(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        createdBy: "u1",
        paymentMethodId: "pm-card",
        status: "pending_card_cycle",
        currency: "ARS",
      }),
    );
  });

  it("rechaza estado inválido y moneda fuera de contrato", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, memberPath("famC", "u2")), { role: "member" });
    });

    const userDb = testEnv.authenticatedContext("u2").firestore();
    await assertFails(
      setDoc(doc(userDb, expensePath("famC", "exp-bad-status")), {
        amount: 12,
        categoryKey: "food",
        occurredAt: Timestamp.now(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        createdBy: "u2",
        status: "processing",
        currency: "ARS",
      }),
    );

    await assertFails(
      setDoc(doc(userDb, expensePath("famC", "exp-bad-currency")), {
        amount: 12,
        categoryKey: "food",
        occurredAt: Timestamp.now(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        createdBy: "u2",
        status: "confirmed",
        currency: "CLP",
      }),
    );
  });
});

describe("firestore.rules · recurringTemplates cuotas", () => {
  it("permite crear plan installment con cuotas y startPeriodKey", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, memberPath("famD", "u3")), { role: "member" });
    });

    const userDb = testEnv.authenticatedContext("u3").firestore();
    await assertSucceeds(
      setDoc(doc(userDb, recurringTemplatePath("famD", "tpl-1")), {
        active: true,
        amount: 100.5,
        categoryKey: "shopping",
        type: "installment",
        generationDay: "month_start",
        totalInstallments: 6,
        currentInstallment: 1,
        startPeriodKey: "2026-05",
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        createdBy: "u3",
      }),
    );
  });

  it("rechaza installment sin totalInstallments/currentInstallment", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, memberPath("famE", "u4")), { role: "member" });
    });

    const userDb = testEnv.authenticatedContext("u4").firestore();
    await assertFails(
      setDoc(doc(userDb, recurringTemplatePath("famE", "tpl-bad")), {
        active: true,
        amount: 10,
        categoryKey: "food",
        type: "installment",
        generationDay: "month_end",
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        createdBy: "u4",
      }),
    );
  });

  it("rechaza startPeriodKey con formato inválido", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, memberPath("famF", "u5")), { role: "member" });
    });

    const userDb = testEnv.authenticatedContext("u5").firestore();
    await assertFails(
      setDoc(doc(userDb, recurringTemplatePath("famF", "tpl-bad2")), {
        active: true,
        amount: 10,
        categoryKey: "food",
        type: "installment",
        generationDay: "month_start",
        totalInstallments: 3,
        currentInstallment: 1,
        startPeriodKey: "05-2026",
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        createdBy: "u5",
      }),
    );
  });
});
