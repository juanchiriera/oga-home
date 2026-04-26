import { createHash } from "node:crypto";

import * as admin from "firebase-admin";

import { ASSISTANT_TOOLS_VERSION } from "./assistantToolsVersion.js";

export function idempotencyDocId(clientRequestId: string, toolName: string): string {
  const h = createHash("sha256")
    .update(`${clientRequestId}\0${toolName}`, "utf8")
    .digest("hex");
  return h.slice(0, 40);
}

export async function readIdempotentToolResult(
  db: admin.firestore.Firestore,
  familyId: string,
  clientRequestId: string,
  toolName: string,
): Promise<Record<string, unknown> | null> {
  const id = idempotencyDocId(clientRequestId, toolName);
  const ref = db
    .collection("families")
    .doc(familyId)
    .collection("assistantToolIdempotency")
    .doc(id);
  const snap = await ref.get();
  if (!snap.exists) {
    return null;
  }
  const data = snap.data();
  const stored = data?.toolResponse;
  if (stored && typeof stored === "object") {
    return stored as Record<string, unknown>;
  }
  return null;
}

export async function writeIdempotentToolResult(
  db: admin.firestore.Firestore,
  familyId: string,
  clientRequestId: string,
  toolName: string,
  toolResponse: Record<string, unknown>,
): Promise<void> {
  const id = idempotencyDocId(clientRequestId, toolName);
  const ref = db
    .collection("families")
    .doc(familyId)
    .collection("assistantToolIdempotency")
    .doc(id);
  await ref.set({
    clientRequestId,
    toolName,
    toolsVersion: ASSISTANT_TOOLS_VERSION,
    toolResponse,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/** Herramientas que persisten en Firestore o efectos costosos repetibles con el mismo id de cliente. */
export function toolUsesIdempotencyStore(toolName: string): boolean {
  return (
    toolName === "create_expense" ||
    toolName === "create_stock_item" ||
    toolName === "update_stock_status" ||
    toolName === "create_note" ||
    toolName === "create_family_link" ||
    toolName === "create_recipe" ||
    toolName === "import_recipe_from_url"
  );
}
