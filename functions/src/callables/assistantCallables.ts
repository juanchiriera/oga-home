import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";

import { openRouterApiKey } from "./recipeCallables.js";
import {
  assertFamilyMember,
  loadPriorMessages,
  maxMessageChars,
  requireCallAuth,
} from "./assistantCore.js";
import { runAssistantOpenRouterWithTools } from "./assistantOpenRouterTools.js";
import { ASSISTANT_TOOLS_VERSION } from "./assistantToolsVersion.js";

const region = "southamerica-east1";

const openRouterAssistantModel = defineString("OPENROUTER_ASSISTANT_MODEL", {
  default: "openai/gpt-4o-mini",
});

/**
 * Persiste turno usuario+asistente en `families/{familyId}/assistantThreads/{threadId}/messages`
 * (respuesta completa en un único round-trip). El cliente debería preferir
 * [familyAssistantChatStream] (chunks NDJSON + stream del proveedor).
 */
export const familyAssistantChat = onCall(
  { region, secrets: [openRouterApiKey] },
  async (request) => {
    const uid = requireCallAuth(request);
    const familyId = String(request.data?.familyId ?? "").trim();
    const rawThread = request.data?.threadId;
    const threadIdIn =
      rawThread != null && String(rawThread).trim() !== ""
        ? String(rawThread).trim()
        : "";
    const text = String(request.data?.message ?? request.data?.text ?? "").trim();
    const clientRequestIdRaw = request.data?.clientRequestId;
    const clientRequestId =
      clientRequestIdRaw != null && String(clientRequestIdRaw).trim() !== ""
        ? String(clientRequestIdRaw).trim()
        : undefined;

    if (!familyId) {
      throw new HttpsError("invalid-argument", "familyId es obligatorio");
    }
    if (!text) {
      throw new HttpsError("invalid-argument", "El mensaje no puede estar vacío");
    }
    if (text.length > maxMessageChars) {
      throw new HttpsError(
        "invalid-argument",
        `El mensaje supera ${maxMessageChars} caracteres`,
      );
    }

    const db = admin.firestore();
    await assertFamilyMember(db, familyId, uid);

    const threadsCol = db.collection("families").doc(familyId).collection("assistantThreads");

    let threadRef: admin.firestore.DocumentReference;
    let isNewThread = false;
    let threadId = threadIdIn;

    if (!threadId) {
      threadRef = threadsCol.doc();
      threadId = threadRef.id;
      isNewThread = true;
    } else {
      threadRef = threadsCol.doc(threadId);
      const tSnap = await threadRef.get();
      if (!tSnap.exists) {
        throw new HttpsError("not-found", "Conversación no encontrada");
      }
    }

    const messagesCol = threadRef.collection("messages");
    const prior = await loadPriorMessages(messagesCol);

    let reply: string;
    let toolPending: { tool: string; args: Record<string, unknown> } | undefined;
    try {
      const outcome = await runAssistantOpenRouterWithTools({
        apiKey: openRouterApiKey.value(),
        model: openRouterAssistantModel.value().trim(),
        prior,
        userText: text,
        toolCtx: {
          db,
          familyId,
          userId: uid,
          conversationId: threadId,
          clientRequestId,
        },
      });
      if (outcome.mode === "pending") {
        toolPending = { tool: outcome.tool, args: outcome.args };
        reply =
          "Te propongo una acción que pide confirmación. Revisá el resumen en la app y confirmá para aplicarla en tu hogar.";
      } else {
        reply = outcome.text;
      }
    } catch (e) {
      logger.error("familyAssistantChat:openrouter_tools", e);
      throw new HttpsError("internal", "No se pudo obtener respuesta del asistente");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();

    const userMsg = messagesCol.doc();
    batch.set(userMsg, {
      role: "user",
      text,
      createdAt: now,
      createdBy: uid,
    });

    const assistantMsg = messagesCol.doc();
    const assistantPayload: Record<string, unknown> = {
      role: "assistant",
      text: reply,
      createdAt: now,
      createdBy: "assistant",
    };
    if (toolPending != null) {
      assistantPayload.toolPending = toolPending;
    }
    batch.set(assistantMsg, assistantPayload);

    const title = text.length > 48 ? `${text.slice(0, 47)}…` : text;

    if (isNewThread) {
      batch.set(threadRef, {
        title,
        createdAt: now,
        updatedAt: now,
        createdBy: uid,
      });
    } else {
      batch.update(threadRef, {
        updatedAt: now,
      });
    }

    await batch.commit();

    logger.info("familyAssistantChat", {
      familyId,
      threadId,
      isNewThread,
      userChars: text.length,
      replyChars: reply.length,
    });

    return {
      threadId,
      replyText: reply,
      toolsVersion: ASSISTANT_TOOLS_VERSION,
      ...(toolPending != null ? { toolPending } : {}),
    };
  },
);
