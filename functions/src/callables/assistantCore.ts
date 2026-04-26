import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

export const maxMessageChars = 8000;
export const historyTurns = 20;

export function requireCallAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  return request.auth.uid;
}

export async function assertFamilyMember(
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

export type FireMessage = {
  role: string;
  text: string;
};

export async function loadPriorMessages(
  messagesCol: admin.firestore.CollectionReference,
): Promise<FireMessage[]> {
  const historySnap = await messagesCol
    .orderBy("createdAt", "desc")
    .limit(historyTurns)
    .get();

  return historySnap.docs
    .map((d) => {
      const data = d.data();
      return {
        role: String(data.role ?? ""),
        text: String(data.text ?? ""),
      };
    })
    .filter(
      (m) =>
        (m.role === "user" || m.role === "assistant") && m.text.length > 0,
    )
    .reverse();
}

export function buildSystemPromptText(): string {
  return [
    "Sos el asistente de CraftR, una app para familias en español rioplatense.",
    "Ayudás con hogar: gastos, despensa/stock, recetas, notas y organización.",
    "Sé conciso, amable y práctico. Si pedís datos que no tenés, sugerí qué puede cargar la familia en la app.",
    "No inventés datos financieros ni nombres de personas.",
    "Podés usar herramientas para leer y, cuando corresponda, modificar datos del hogar del usuario.",
    "Para create_expense, si la intención es clara y hay datos mínimos válidos, ejecutá sin pedir aprobación adicional.",
    "Si faltan datos críticos no inferibles para create_expense, pedí solo esos campos mínimos.",
    "Tras un create_expense exitoso, confirmá en el chat que ya quedó cargado.",
    "Algunas acciones sensibles distintas de create_expense se confirman en la app: si una herramienta devuelve rejected o pending_confirmation, explicá el siguiente paso en la UI.",
  ].join(" ");
}

function stripDiacritics(value: string): string {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function normalizeForComparison(value: string): string {
  return stripDiacritics(value).toLowerCase().replace(/[^a-z0-9]+/g, "");
}

/**
 * Fallback de título de conversación cuando no hay resumen semántico válido.
 * Formato: dd/mm/yyyy hh:mm
 */
export function formatConversationFallbackTitle(date: Date): string {
  const pad2 = (n: number) => String(n).padStart(2, "0");
  const day = pad2(date.getDate());
  const month = pad2(date.getMonth() + 1);
  const year = String(date.getFullYear());
  const hour = pad2(date.getHours());
  const minute = pad2(date.getMinutes());
  return `${day}/${month}/${year} ${hour}:${minute}`;
}

/**
 * Acepta/rechaza un título generado por IA para evitar usar eco literal del mensaje.
 */
export function sanitizeConversationTitleCandidate(
  candidate: string | null | undefined,
  firstUserMessage: string,
): string | null {
  const cleaned = String(candidate ?? "")
    .trim()
    .replace(/^["'`]+|["'`]+$/g, "")
    .replace(/\s+/g, " ")
    .trim();

  if (cleaned.length < 3) {
    return null;
  }

  const trimmed = cleaned.length > 80 ? cleaned.slice(0, 80).trim() : cleaned;
  const normalizedTitle = normalizeForComparison(trimmed);
  const normalizedFirstMessage = normalizeForComparison(firstUserMessage);

  if (!normalizedTitle) {
    return null;
  }

  // Evita título que sea básicamente el primer mensaje del usuario.
  if (
    normalizedTitle === normalizedFirstMessage ||
    (normalizedFirstMessage.startsWith(normalizedTitle) &&
      normalizedTitle.length >= Math.floor(normalizedFirstMessage.length * 0.8))
  ) {
    return null;
  }

  return trimmed;
}

export function contentsFromPriorAndUser(
  prior: FireMessage[],
  userText: string,
): Array<{ role: string; parts: Array<{ text: string }> }> {
  const contents: Array<{ role: string; parts: Array<{ text: string }> }> = [];
  for (const m of prior) {
    const role = m.role === "assistant" ? "model" : "user";
    contents.push({ role, parts: [{ text: m.text }] });
  }
  contents.push({ role: "user", parts: [{ text: userText }] });
  return contents;
}

/** Construye turnos de chat para el LLM (`user` / `assistant`), p. ej. hacia OpenRouter. */
export function openAiMessagesFromPriorAndUser(
  prior: FireMessage[],
  userText: string,
): Array<{ role: "user" | "assistant"; content: string }> {
  const messages: Array<{ role: "user" | "assistant"; content: string }> = [];
  for (const m of prior) {
    const role = m.role === "assistant" ? "assistant" : "user";
    messages.push({ role, content: m.text });
  }
  messages.push({ role: "user", content: userText });
  return messages;
}
