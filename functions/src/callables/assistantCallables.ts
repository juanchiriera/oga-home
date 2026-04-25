import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";

import { geminiApiKey } from "./recipeCallables.js";

const region = "southamerica-east1";

const geminiModel = defineString("ASSISTANT_GEMINI_MODEL", {
  default: "gemini-2.0-flash",
});

const maxMessageChars = 8000;
const historyTurns = 20;

function requireAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  return request.auth.uid;
}

async function assertFamilyMember(
  db: admin.firestore.Firestore,
  familyId: string,
  uid: string,
): Promise<void> {
  const snap = await db
    .collection("families")
    .doc(familyId)
    .collection("members")
    .doc(uid)
    .get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "No sos miembro de esta familia");
  }
}

type FireMessage = {
  role: string;
  text: string;
};

function extractReplyText(body: unknown): string {
  const json = body as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  return String(text).trim();
}

async function callGeminiChat(params: {
  systemPrompt: string;
  prior: FireMessage[];
  userText: string;
}): Promise<string> {
  const key = geminiApiKey.value();
  const model = geminiModel.value();
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    model,
  )}:generateContent?key=${encodeURIComponent(key)}`;

  const contents: Array<{ role: string; parts: Array<{ text: string }> }> = [];
  for (const m of params.prior) {
    const role = m.role === "assistant" ? "model" : "user";
    contents.push({ role, parts: [{ text: m.text }] });
  }
  contents.push({ role: "user", parts: [{ text: params.userText }] });

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: params.systemPrompt }],
      },
      generationConfig: {
        temperature: 0.5,
        maxOutputTokens: 2048,
      },
      contents,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    logger.error("familyAssistantChat:gemini_error", {
      status: response.status,
      errorText: errorText.slice(0, 500),
    });
    throw new HttpsError(
      "internal",
      "No se pudo obtener respuesta del asistente",
      { status: response.status },
    );
  }

  const reply = extractReplyText(await response.json());
  if (!reply) {
    throw new HttpsError("internal", "El asistente no devolvió texto");
  }
  return reply;
}

/**
 * Persiste turno usuario+asistente en `families/{familyId}/assistantThreads/{threadId}/messages`
 * y devuelve la respuesta (respuesta completa en un único round-trip; streaming vía SSE/callable
 * queda como mejora futura).
 */
export const familyAssistantChat = onCall(
  { region, secrets: [geminiApiKey] },
  async (request) => {
    const uid = requireAuth(request);
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
    const historySnap = await messagesCol
      .orderBy("createdAt", "desc")
      .limit(historyTurns)
      .get();

    const prior: FireMessage[] = historySnap.docs
      .map((d) => {
        const data = d.data();
        return {
          role: String(data.role ?? ""),
          text: String(data.text ?? ""),
        };
      })
      .filter((m) => (m.role === "user" || m.role === "assistant") && m.text.length > 0)
      .reverse();

    const systemPrompt = [
      "Sos el asistente de CraftR, una app para familias en español rioplatense.",
      "Ayudás con hogar: gastos, despensa/stock, recetas, notas y organización.",
      "Sé conciso, amable y práctico. Si pedís datos que no tenés, sugerí qué puede cargar la familia en la app.",
      "No inventés datos financieros ni nombres de personas. No ejecutés acciones en la app: solo conversás (las herramientas vendrán después).",
    ].join(" ");

    const reply = await callGeminiChat({
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

    const title =
      text.length > 48 ? `${text.slice(0, 47)}…` : text;

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
