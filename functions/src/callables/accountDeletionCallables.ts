import * as admin from "firebase-admin";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const region = "southamerica-east1";

function requireAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  return request.auth.uid;
}

const EMAIL_RE =
  /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

/**
 * Removes the caller's Firestore profile and family memberships (or whole families when sole member).
 * Intended to run immediately before Firebase Auth `delete()` from the client after reauthentication.
 */
export const purgeAccountData = onCall({ region }, async (request) => {
  const uid = requireAuth(request);
  const db = admin.firestore();

  const memberSnaps = await db
    .collectionGroup("members")
    .where(FieldPath.documentId(), "==", uid)
    .get();

  for (const memberDoc of memberSnaps.docs) {
    const familyRef = memberDoc.ref.parent.parent;
    if (!familyRef) {
      logger.warn("purgeAccountData: missing family ref", {
        path: memberDoc.ref.path,
      });
      continue;
    }

    const membersSnap = await familyRef.collection("members").get();
    const memberRole = String(memberDoc.data().role ?? "");

    if (membersSnap.size <= 1) {
      await db.recursiveDelete(familyRef);
      logger.info("purgeAccountData: deleted family (sole member)", {
        familyId: familyRef.id,
        uid,
      });
      continue;
    }

    const batch = db.batch();

    if (memberRole === "owner") {
      const others = membersSnap.docs
        .filter((d) => d.id !== uid)
        .sort((a, b) => a.id.localeCompare(b.id));
      if (others.length === 0) {
        await db.recursiveDelete(familyRef);
        logger.info("purgeAccountData: deleted family (no successor)", {
          familyId: familyRef.id,
          uid,
        });
        continue;
      }
      const successor = others[0];
      batch.update(successor.ref, { role: "owner" });
      batch.update(familyRef, { createdBy: successor.id });
    }

    batch.delete(memberDoc.ref);
    await batch.commit();
    logger.info("purgeAccountData: removed membership", {
      familyId: familyRef.id,
      uid,
    });
  }

  await db
    .collection("users")
    .doc(uid)
    .delete()
    .catch(() => undefined);

  return { ok: true };
});

/**
 * Web-accessible path for users without the app: queues a deletion/privacy request (manual follow-up).
 * Callable must stay callable without App Check (static Hosting page).
 */
export const submitAccountDeletionRequest = onCall(
  { region, enforceAppCheck: false },
  async (request) => {
    const email = String(request.data?.email ?? "").trim().toLowerCase();
    if (!EMAIL_RE.test(email) || email.length > 320) {
      throw new HttpsError("invalid-argument", "Email inválido");
    }
    const note = String(request.data?.note ?? "").trim().slice(0, 2000);

    await admin.firestore().collection("accountDeletionRequests").add({
      email,
      note,
      source: "web",
      createdAt: FieldValue.serverTimestamp(),
    });

    return { ok: true };
  },
);
