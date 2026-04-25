import * as admin from "firebase-admin";
import { HttpsError, onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";
import { geminiApiKey } from "./recipeCallables.js";
import {
  assertFamilyMember,
  buildSystemPromptText,
  contentsFromPriorAndUser,
  loadPriorMessages,
  maxMessageChars,
} from "./assistantCore.js";
import type { FireMessage } from "./assistantCore.js";

const region = "southamerica-east1";

const geminiModel = defineString("ASSISTANT_GEMINI_MODEL", {
  default: "gemini-2.0-flash",
});

type NdEvent =
  | { type: "meta"; threadId: string }
  | { type: "delta"; text: string }
  | { type: "done" }
  | { type: "error"; message: string };

function writeNd(res: { write: (s: string) => boolean }, ev: NdEvent) {
  res.write(`${JSON.stringify(ev)}\n`);
}

function extractStreamDelta(obj: unknown): string {
  const j = obj as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };
  const parts = j.candidates?.[0]?.content?.parts;
  if (!parts?.length) {
    return "";
  }
  return parts.map((p) => p.text ?? "").join("");
}

/** Parsea líneas `data: {...}` del stream SSE de Gemini. */
function parseSseDataLines(buffer: string): { lines: string[]; rest: string } {
  const lines: string[] = [];
  const parts = buffer.split("\n");
  const rest = parts.pop() ?? "";
  for (const raw of parts) {
    const line = raw.replace(/\r$/, "");
    if (line.startsWith("data: ")) {
      const payload = line.slice(6).trim();
      if (payload && payload !== "[DONE]") {
        lines.push(payload);
      }
    }
  }
  return { lines, rest };
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
 * Cuerpo JSON: { familyId, threadId?, message | text }.
 * Respuesta: `application/x-ndjson` con chunks: meta → delta* → done | error.
 */
export const familyAssistantChatStream = onRequest(
  {
    region,
    secrets: [geminiApiKey],
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

    let body: { familyId?: string; threadId?: string; message?: string; text?: string };
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
    }

    const messagesCol = threadRef.collection("messages");
    const prior: FireMessage[] = await loadPriorMessages(messagesCol);
    const systemPrompt = buildSystemPromptText();
    const contents = contentsFromPriorAndUser(prior, text);

    const key = geminiApiKey.value();
    const model = geminiModel.value();
    const streamUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
      model,
    )}:streamGenerateContent?key=${encodeURIComponent(key)}&alt=sse`;

    res.setHeader("Content-Type", "application/x-ndjson; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-transform");
    res.setHeader("X-Accel-Buffering", "no");
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
    const title = text.length > 48 ? `${text.slice(0, 47)}…` : text;

    try {
      await userMsg.set(userWrite);
      if (isNewThread) {
        await threadRef.set({
          title,
          createdAt: now,
          updatedAt: now,
          createdBy: uid,
        });
      } else {
        await threadRef.update({ updatedAt: now });
      }
    } catch (e) {
      logger.error("familyAssistantChatStream:write_user", e);
      writeNd(res, { type: "error", message: "No se pudo guardar el mensaje" });
      res.end();
      return;
    }

    const gRes = await fetch(streamUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemPrompt }] },
        generationConfig: { temperature: 0.5, maxOutputTokens: 2048 },
        contents,
      }),
    });

    if (!gRes.ok) {
      const errTxt = await gRes.text();
      logger.error("familyAssistantChatStream:gemini_http", {
        status: gRes.status,
        errTxt: errTxt.slice(0, 500),
      });
      writeNd(res, {
        type: "error",
        message: "No se pudo obtener respuesta del asistente",
      });
      res.end();
      return;
    }

    if (!gRes.body) {
      writeNd(res, { type: "error", message: "Respuesta vacía del asistente" });
      res.end();
      return;
    }

    const reader = gRes.body.getReader();
    const dec = new TextDecoder();
    let carry = "";
    let fullText = "";

    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) {
          break;
        }
        carry += dec.decode(value, { stream: true });
        const { lines, rest } = parseSseDataLines(carry);
        carry = rest;
        for (const dataLine of lines) {
          let parsed: unknown;
          try {
            parsed = JSON.parse(dataLine);
          } catch {
            continue;
          }
          const piece = extractStreamDelta(parsed);
          if (piece) {
            fullText += piece;
            writeNd(res, { type: "delta", text: piece });
          }
        }
      }
      if (carry.length > 0) {
        const tail = carry.replace(/\r$/, "");
        if (tail.startsWith("data: ")) {
          const payload = tail.slice(6).trim();
          if (payload && payload !== "[DONE]") {
            try {
              const parsed: unknown = JSON.parse(payload);
              const piece = extractStreamDelta(parsed);
              if (piece) {
                fullText += piece;
                writeNd(res, { type: "delta", text: piece });
              }
            } catch {
              // ignore
            }
          }
        }
      }
    } catch (e) {
      logger.error("familyAssistantChatStream:read_gemini", e);
      writeNd(res, { type: "error", message: "Error al leer la respuesta" });
      res.end();
      return;
    }

    const reply = fullText.trim();
    if (!reply) {
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
      userChars: text.length,
      replyChars: reply.length,
    });

    writeNd(res, { type: "done" });
    res.end();
  },
);
