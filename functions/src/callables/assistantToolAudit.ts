import { createHash } from "node:crypto";

import * as admin from "firebase-admin";

import { ASSISTANT_TOOLS_VERSION } from "./assistantToolsVersion.js";

export type AssistantAuditResult = "ok" | "rejected" | "error";

export function hashToolPayload(args: Record<string, unknown>): string {
  const normalized = stableStringify(args);
  return createHash("sha256").update(normalized).digest("hex");
}

function stableStringify(obj: unknown): string {
  if (obj === null || typeof obj !== "object") {
    return JSON.stringify(obj);
  }
  if (Array.isArray(obj)) {
    return `[${obj.map((x) => stableStringify(x)).join(",")}]`;
  }
  const keys = Object.keys(obj as Record<string, unknown>).sort();
  const parts = keys.map((k) => {
    return `${JSON.stringify(k)}:${stableStringify((obj as Record<string, unknown>)[k])}`;
  });
  return `{${parts.join(",")}}`;
}

/** Omite o acorta campos sensibles para guardar en auditoría. */
export function redactToolArgsForAudit(
  toolName: string,
  args: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = { ...args };
  const redactKeys = new Set([
    "note",
    "merchant",
    "content",
    "descripcion",
    "titulo",
    "url",
  ]);
  for (const k of Object.keys(out)) {
    if (redactKeys.has(k) && typeof out[k] === "string") {
      const s = out[k] as string;
      out[k] = s.length > 80 ? `${s.slice(0, 77)}…` : s;
    }
  }
  if (typeof out.amount === "number") {
    out.amount = "[number]";
  }
  if (toolName === "import_recipe_from_url" && typeof out.url === "string") {
    out.url = "[url]";
  }
  return out;
}

export async function appendAssistantActionLog(params: {
  db: admin.firestore.Firestore;
  familyId: string;
  userId: string;
  conversationId: string;
  toolName: string;
  clientRequestId: string | undefined;
  payloadHash: string;
  payloadRedacted: Record<string, unknown>;
  result: AssistantAuditResult;
  source?: string;
}): Promise<string> {
  const col = params.db
    .collection("families")
    .doc(params.familyId)
    .collection("assistantActionLog");
  const ref = col.doc();
  await ref.set({
    id: ref.id,
    familyId: params.familyId,
    userId: params.userId,
    conversationId: params.conversationId,
    toolName: params.toolName,
    clientRequestId: params.clientRequestId ?? null,
    payloadHash: params.payloadHash,
    payloadRedacted: params.payloadRedacted,
    result: params.result,
    source: params.source ?? "assistant_tool",
    toolsVersion: ASSISTANT_TOOLS_VERSION,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return ref.id;
}
