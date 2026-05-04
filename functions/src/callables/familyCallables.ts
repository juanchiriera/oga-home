import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { randomBytes } from "node:crypto";

const region = "southamerica-east1";

function requireAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  return request.auth.uid;
}

async function assertEntitlement(familyId: string, key: string): Promise<void> {
  const billingDoc = await admin
    .firestore()
    .doc(`families/${familyId}/billing/entitlements`)
    .get();

  const enabled = billingDoc.get(`entitlements.${key}`) === true;
  if (!enabled) {
    throw new HttpsError(
      "permission-denied",
      `Entitlement ${key} requerido para esta operación`,
    );
  }
}

export const createFamily = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const name = String(request.data?.name ?? "").trim();
  const baseCurrency = String(request.data?.baseCurrency ?? "ARS").trim();
  if (name.length < 2) {
    throw new HttpsError("invalid-argument", "Nombre demasiado corto");
  }

  const db = admin.firestore();
  const familyRef = db.collection("families").doc();
  const batch = db.batch();
  batch.set(familyRef, {
    name,
    baseCurrency,
    settings: {
      stock: {
        include_low: false,
      },
    },
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(familyRef.collection("members").doc(uid), {
    role: "owner",
    joinedAt: FieldValue.serverTimestamp(),
  });
  batch.set(
    db.collection("users").doc(uid),
    { activeFamilyId: familyRef.id },
    { merge: true },
  );
  // Base para assertEntitlement (invites) antes del primer evento RevenueCat.
  batch.set(
    familyRef.collection("billing").doc("entitlements"),
    {
      familyId: familyRef.id,
      source: "bootstrap",
      entitlements: {
        invites: true,
      },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();
  logger.info("createFamily", { familyId: familyRef.id, uid });
  return { familyId: familyRef.id };
});

export const createFamilyInvite = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const familyId = String(request.data?.familyId ?? "").trim();
  if (!familyId) {
    throw new HttpsError("invalid-argument", "familyId requerido");
  }
  const db = admin.firestore();
  const memberSnap = await db
    .collection("families")
    .doc(familyId)
    .collection("members")
    .doc(uid)
    .get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "No pertenecés a este hogar");
  }
  await assertEntitlement(familyId, "invites");

  const token = randomBytes(24).toString("hex");
  const ttlDays = Number(request.data?.ttlDays ?? 7);
  const expires = Timestamp.fromMillis(
    Date.now() + ttlDays * 24 * 60 * 60 * 1000,
  );

  const inviteRef = db
    .collection("families")
    .doc(familyId)
    .collection("invites")
    .doc();

  await inviteRef.set({
    token,
    status: "pending",
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: expires,
  });

  return {
    inviteId: inviteRef.id,
    token,
    deepLink: `craftr://invite/${token}`,
    expiresAt: expires.toMillis(),
  };
});

export const acceptFamilyInvite = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const token = String(request.data?.token ?? "").trim();
  if (!token) {
    throw new HttpsError("invalid-argument", "token requerido");
  }

  const db = admin.firestore();
  const qs = await db
    .collectionGroup("invites")
    .where("token", "==", token)
    .limit(1)
    .get();
  if (qs.empty) {
    throw new HttpsError("not-found", "Invitación no encontrada");
  }
  const doc = qs.docs[0];
  const data = doc.data();
  if (data.status !== "pending") {
    throw new HttpsError("failed-precondition", "Invitación ya usada o revocada");
  }
  const exp = data.expiresAt as Timestamp | undefined;
  if (exp && exp.toMillis() < Date.now()) {
    throw new HttpsError("failed-precondition", "Invitación expirada");
  }

  const familyId = doc.ref.parent.parent?.id;
  if (!familyId) {
    throw new HttpsError("internal", "Ruta de invitación inválida");
  }
  await assertEntitlement(familyId, "invites");

  const batch = db.batch();
  batch.update(doc.ref, {
    status: "accepted",
    acceptedBy: uid,
    acceptedAt: FieldValue.serverTimestamp(),
  });
  batch.set(
    db.collection("families").doc(familyId).collection("members").doc(uid),
    {
      role: "member",
      joinedAt: FieldValue.serverTimestamp(),
    },
  );
  batch.set(
    db.collection("users").doc(uid),
    { activeFamilyId: familyId },
    { merge: true },
  );
  await batch.commit();
  return { familyId };
});

export const revokeFamilyInvite = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const familyId = String(request.data?.familyId ?? "").trim();
  const inviteId = String(request.data?.inviteId ?? "").trim();
  if (!familyId || !inviteId) {
    throw new HttpsError("invalid-argument", "familyId e inviteId requeridos");
  }
  const db = admin.firestore();
  const memberSnap = await db
    .collection("families")
    .doc(familyId)
    .collection("members")
    .doc(uid)
    .get();
  if (!memberSnap.exists) {
    throw new HttpsError("permission-denied", "No pertenecés a este hogar");
  }
  await assertEntitlement(familyId, "invites");

  const inviteRef = db
    .collection("families")
    .doc(familyId)
    .collection("invites")
    .doc(inviteId);
  const snap = await inviteRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Invitación inexistente");
  }
  await inviteRef.update({
    status: "revoked",
    revokedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

// TODO(E3-04): cuando se implementen nuevos callables de dominios pagos
// (p.ej. assistant, stock avanzado, importaciones), aplicar assertEntitlement
// con la key del módulo antes de mutaciones/compute costoso.
