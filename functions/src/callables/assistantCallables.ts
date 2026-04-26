import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";

import { openRouterApiKey } from "./recipeCallables.js";
import {
  assertFamilyMember,
  formatConversationFallbackTitle,
  loadPriorMessages,
  maxMessageChars,
  requireCallAuth,
} from "./assistantCore.js";
import { runAssistantOpenRouterWithTools } from "./assistantOpenRouterTools.js";
import { generateSemanticConversationTitle } from "./assistantTitleGenerator.js";
import { ASSISTANT_TOOLS_VERSION } from "./assistantToolsVersion.js";

const region = "southamerica-east1";

const openRouterAssistantModel = defineString("OPENROUTER_ASSISTANT_MODEL", {
  default: "openai/gpt-4o-mini",
});
const openRouterAssistantTitleModel = defineString("OPENROUTER_ASSISTANT_TITLE_MODEL", {
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
    const threadCreateCauseRaw = request.data?.threadCreateCause;
    const threadCreateCause =
      threadCreateCauseRaw != null &&
      String(threadCreateCauseRaw).trim() !== ""
        ? String(threadCreateCauseRaw).trim()
        : "implicit_missing_thread_id";

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
    let shouldBackfillTitle = false;

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
      const title = tSnap.data()?.title;
      shouldBackfillTitle = typeof title !== "string" || title.trim() === "" ||
        title.trim().toLowerCase() === "nueva conversación";
    }

    const messagesCol = threadRef.collection("messages");
    const prior = await loadPriorMessages(messagesCol);

    let reply: string;
    try {
      reply = await runAssistantOpenRouterWithTools({
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
    batch.set(assistantMsg, {
      role: "assistant",
      text: reply,
      createdAt: now,
      createdBy: "assistant",
    });

    let conversationTitle = "";
    if (isNewThread) {
      const semanticTitle = await generateSemanticConversationTitle({
        apiKey: openRouterApiKey.value(),
        model: openRouterAssistantTitleModel.value().trim(),
        firstUserMessage: text,
      });
      conversationTitle = semanticTitle ?? formatConversationFallbackTitle(new Date());
    }

    if (isNewThread) {
      batch.set(threadRef, {
        title: conversationTitle,
        conversationTitle,
        createdAt: now,
        updatedAt: now,
        createdBy: uid,
        createdCause: threadCreateCause,
      });
    } else {
      batch.update(threadRef, {
        updatedAt: now,
        ...(shouldBackfillTitle ? { title: formatConversationFallbackTitle(new Date()) } : {}),
      });
    }

    await batch.commit();

    logger.info("familyAssistantChat", {
      familyId,
      threadId,
      isNewThread,
      threadCreateCause: isNewThread ? threadCreateCause : "existing_thread",
      userChars: text.length,
      replyChars: reply.length,
    });

    return {
      threadId,
      replyText: reply,
      toolsVersion: ASSISTANT_TOOLS_VERSION,
    };
  },
);

export const renameAssistantThreadTitle = onCall(
  { region },
  async (request) => {
    const uid = requireCallAuth(request);
    const familyId = String(request.data?.familyId ?? "").trim();
    const threadId = String(request.data?.threadId ?? "").trim();
    const conversationTitle = String(request.data?.conversationTitle ?? "")
      .trim()
      .replace(/\s+/g, " ");

    if (!familyId) {
      throw new HttpsError("invalid-argument", "familyId es obligatorio");
    }
    if (!threadId) {
      throw new HttpsError("invalid-argument", "threadId es obligatorio");
    }
    if (conversationTitle.length < 3 || conversationTitle.length > 80) {
      throw new HttpsError(
        "invalid-argument",
        "El título debe tener entre 3 y 80 caracteres",
      );
    }

    const db = admin.firestore();
    await assertFamilyMember(db, familyId, uid);

    const threadRef = db
      .collection("families")
      .doc(familyId)
      .collection("assistantThreads")
      .doc(threadId);
    const threadSnap = await threadRef.get();
    if (!threadSnap.exists) {
      throw new HttpsError("not-found", "Conversación no encontrada");
    }

    await threadRef.update({
      title: conversationTitle,
      conversationTitle,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true };
  },
);
