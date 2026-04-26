import * as admin from "firebase-admin";
import { HttpsError, onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";
import { openRouterApiKey } from "./recipeCallables.js";
import {
  assertFamilyMember,
  formatConversationFallbackTitle,
  loadPriorMessages,
  maxMessageChars,
} from "./assistantCore.js";
import type { FireMessage } from "./assistantCore.js";
import { chunkTextForNdjson, runAssistantOpenRouterWithTools } from "./assistantOpenRouterTools.js";
import { generateSemanticConversationTitle } from "./assistantTitleGenerator.js";
import { ASSISTANT_TOOLS_VERSION } from "./assistantToolsVersion.js";

const region = "southamerica-east1";

const openRouterAssistantModel = defineString("OPENROUTER_ASSISTANT_MODEL", {
  default: "openai/gpt-4o-mini",
});
const openRouterAssistantTitleModel = defineString("OPENROUTER_ASSISTANT_TITLE_MODEL", {
  default: "openai/gpt-4o-mini",
});

type NdEvent =
  | { type: "meta"; threadId: string }
  | { type: "delta"; text: string }
  | { type: "done" }
  | { type: "error"; message: string };

function writeNd(res: { write: (s: string) => boolean }, ev: NdEvent) {
  res.write(`${JSON.stringify(ev)}\n`);
}

function sendJsonError(
  res: { status: (c: number) => void; setHeader: (a: string, b: string) => void; send: (b: string) => void },
  code: number,
  message: string,
) {
  res.status(code);
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.send(JSON.stringify({ error: message }));
}

/**
 * HTTP POST, Auth: `Authorization: Bearer <Firebase idToken>`.
 * Cuerpo JSON: { familyId, threadId?, message | text, clientRequestId? }.
 * Cabeceras opcionales: `X-Client-Request-Id` (idempotencia en herramientas mutantes).
 * Respuesta: `application/x-ndjson` con chunks: meta → delta* → done | error.
 * Cabecera `tools_version`: catálogo §8.2 (actualmente 1). Modelo vía OpenRouter con tools.
 */
export const familyAssistantChatStream = onRequest(
  {
    region,
    secrets: [openRouterApiKey],
    cors: true,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).end();
      return;
    }
    if (req.method !== "POST") {
      sendJsonError(res, 405, "Method not allowed");
      return;
    }

    const authHeader = req.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      sendJsonError(res, 401, "Falta Authorization Bearer");
      return;
    }
    const idToken = authHeader.slice(7).trim();
    let uid: string;
    try {
      const t = await admin.auth().verifyIdToken(idToken);
      uid = t.uid;
    } catch (e) {
      logger.warn("familyAssistantChatStream:invalid_token", e);
      sendJsonError(res, 401, "Token inválido o expirado");
      return;
    }

    let body: {
      familyId?: string;
      threadId?: string;
      message?: string;
      text?: string;
      clientRequestId?: string;
      threadCreateCause?: string;
    };
    try {
      if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
        body = req.body;
      } else {
        const raw = Buffer.isBuffer(req.body) ? req.body.toString("utf8") : String(req.body ?? "{}");
        body = raw ? (JSON.parse(raw) as typeof body) : {};
      }
    } catch {
      sendJsonError(res, 400, "JSON inválido");
      return;
    }

    const familyId = String(body.familyId ?? "").trim();
    const threadIdIn =
      body.threadId != null && String(body.threadId).trim() !== ""
        ? String(body.threadId).trim()
        : "";
    const text = String(body.message ?? body.text ?? "").trim();
    const headerCri = String(req.get("X-Client-Request-Id") ?? "").trim();
    const bodyCri =
      body.clientRequestId != null ? String(body.clientRequestId).trim() : "";
    const clientRequestId = headerCri || bodyCri || undefined;
    const threadCreateCause =
      body.threadCreateCause != null &&
      String(body.threadCreateCause).trim() !== ""
        ? String(body.threadCreateCause).trim()
        : "implicit_missing_thread_id";

    if (!familyId) {
      sendJsonError(res, 400, "familyId es obligatorio");
      return;
    }
    if (!text) {
      sendJsonError(res, 400, "El mensaje no puede estar vacío");
      return;
    }
    if (text.length > maxMessageChars) {
      sendJsonError(
        res,
        400,
        `El mensaje supera ${maxMessageChars} caracteres`,
      );
      return;
    }

    const db = admin.firestore();
    try {
      await assertFamilyMember(db, familyId, uid);
    } catch (e) {
      if (e instanceof HttpsError && e.code === "permission-denied") {
        sendJsonError(res, 403, e.message);
        return;
      }
      logger.error("familyAssistantChatStream:assert_family", e);
      sendJsonError(res, 500, "Error al validar el hogar");
      return;
    }

    const threadsCol = db
      .collection("families")
      .doc(familyId)
      .collection("assistantThreads");

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
        sendJsonError(res, 404, "Conversación no encontrada");
        return;
      }
      const title = tSnap.data()?.title;
      shouldBackfillTitle = typeof title !== "string" || title.trim() === "" ||
        title.trim().toLowerCase() === "nueva conversación";
    }

    const messagesCol = threadRef.collection("messages");
    const prior: FireMessage[] = await loadPriorMessages(messagesCol);

    res.setHeader("Content-Type", "application/x-ndjson; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-transform");
    res.setHeader("X-Accel-Buffering", "no");
    res.setHeader("tools_version", String(ASSISTANT_TOOLS_VERSION));
    if (clientRequestId) {
      res.setHeader("X-Client-Request-Id", clientRequestId);
    }
    res.status(200);
    writeNd(res, { type: "meta", threadId });

    const now = admin.firestore.FieldValue.serverTimestamp();
    const userMsg = messagesCol.doc();
    const userWrite = {
      role: "user" as const,
      text,
      createdAt: now,
      createdBy: uid,
    };
    let conversationTitle = "";
    if (isNewThread) {
      const semanticTitle = await generateSemanticConversationTitle({
        apiKey: openRouterApiKey.value(),
        model: openRouterAssistantTitleModel.value().trim(),
        firstUserMessage: text,
      });
      conversationTitle = semanticTitle ?? formatConversationFallbackTitle(new Date());
    }

    try {
      await userMsg.set(userWrite);
      if (isNewThread) {
        await threadRef.set({
          title: conversationTitle,
          conversationTitle,
          createdAt: now,
          updatedAt: now,
          createdBy: uid,
          createdCause: threadCreateCause,
        });
      } else {
        await threadRef.update({
          updatedAt: now,
          ...(shouldBackfillTitle ? { title: formatConversationFallbackTitle(new Date()) } : {}),
        });
      }
    } catch (e) {
      logger.error("familyAssistantChatStream:write_user", e);
      writeNd(res, { type: "error", message: "No se pudo guardar el mensaje" });
      res.end();
      return;
    }

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
      logger.error("familyAssistantChatStream:openrouter_tools", e);
      writeNd(res, { type: "error", message: "No se pudo obtener respuesta del asistente" });
      res.end();
      return;
    }
    for (const piece of chunkTextForNdjson(reply, 48)) {
      writeNd(res, { type: "delta", text: piece });
    }

    if (!reply.trim()) {
      writeNd(res, { type: "error", message: "El asistente no devolvió texto" });
      res.end();
      return;
    }

    const now2 = admin.firestore.FieldValue.serverTimestamp();
    const assistantMsg = messagesCol.doc();
    try {
      await assistantMsg.set({
        role: "assistant",
        text: reply,
        createdAt: now2,
        createdBy: "assistant",
      });
      await threadRef.update({ updatedAt: now2 });
    } catch (e) {
      logger.error("familyAssistantChatStream:write_assistant", e);
      writeNd(res, {
        type: "error",
        message: "Respuesta recibida pero no se pudo guardar",
      });
      res.end();
      return;
    }

    logger.info("familyAssistantChatStream:ok", {
      familyId,
      threadId,
      isNewThread,
      threadCreateCause: isNewThread ? threadCreateCause : "existing_thread",
      userChars: text.length,
      replyChars: reply.length,
      provider: "openrouter",
    });

    writeNd(res, { type: "done" });
    res.end();
  },
);
