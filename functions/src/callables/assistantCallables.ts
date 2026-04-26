import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";

import {
  OPENAI_CHAT_COMPLETIONS_URL,
  buildAssistantChatPayload,
  extractChatCompletionMessageText,
} from "../llm/openaiApi.js";
import { openaiApiKey } from "./recipeCallables.js";
import {
  assertFamilyMember,
  buildSystemPromptText,
  loadPriorMessages,
  maxMessageChars,
  openAiMessagesFromPriorAndUser,
  requireCallAuth,
} from "./assistantCore.js";
import type { FireMessage } from "./assistantCore.js";

const region = "southamerica-east1";

const openaiAssistantModel = defineString("OPENAI_ASSISTANT_MODEL", {
  default: "gpt-4o-mini",
});

async function callOpenAiChat(params: {
  systemPrompt: string;
  prior: FireMessage[];
  userText: string;
}): Promise<string> {
  const key = openaiApiKey.value();
  const model = openaiAssistantModel.value().trim();
  const messages = [
    { role: "system" as const, content: params.systemPrompt },
    ...openAiMessagesFromPriorAndUser(params.prior, params.userText),
  ];

  const response = await fetch(OPENAI_CHAT_COMPLETIONS_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify(buildAssistantChatPayload(model, messages)),
  });

  if (!response.ok) {
    const errorText = await response.text();
    logger.error("familyAssistantChat:openai_error", {
      status: response.status,
      errorText: errorText.slice(0, 500),
    });
    throw new HttpsError(
      "internal",
      "No se pudo obtener respuesta del asistente",
      { status: response.status },
    );
  }

  const reply = extractChatCompletionMessageText(await response.json());
  if (!reply) {
    throw new HttpsError("internal", "El asistente no devolvió texto");
  }
  return reply;
}

/**
 * Persiste turno usuario+asistente en `families/{familyId}/assistantThreads/{threadId}/messages`
 * (respuesta completa en un único round-trip). El cliente debería preferir
 * [familyAssistantChatStream] (chunks NDJSON + stream OpenAI).
 */
export const familyAssistantChat = onCall(
  { region, secrets: [openaiApiKey] },
  async (request) => {
    const uid = requireCallAuth(request);
    const familyId = String(request.data?.familyId ?? "").trim();
    const rawThread = request.data?.threadId;
    const threadIdIn =
      rawThread != null && String(rawThread).trim() !== ""
        ? String(rawThread).trim()
        : "";
    const text = String(request.data?.message ?? request.data?.text ?? "").trim();

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
    const systemPrompt = buildSystemPromptText();
    const reply = await callOpenAiChat({
      systemPrompt,
      prior,
      userText: text,
    });

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
    };
  },
);
