import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineSecret, defineString } from "firebase-functions/params";

import {
  OPENROUTER_CHAT_COMPLETIONS_URL,
  buildOpenRouterHeaders,
  buildRecipeImportChatPayload,
  extractChatCompletionMessageText,
} from "../llm/openRouterApi.js";

const region = "southamerica-east1";
const fetchTimeoutMs = 8000;
const maxHtmlBytes = 800_000;
const maxHtmlCharsForPrompt = 20_000;

export const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");
const openRouterRecipeModel = defineString("OPENROUTER_RECIPE_IMPORT_MODEL", {
  default: "openai/gpt-4o-mini",
});
const openRouterHttpReferer = defineString("OPENROUTER_HTTP_REFERER", {
  default: "",
});
const openRouterAppTitle = defineString("OPENROUTER_APP_TITLE", {
  default: "Famil-IA",
});

/** Cabeceras para `fetch` a OpenRouter (incluye atribución opcional). */
export function openRouterRequestHeaders(apiKey: string): Record<string, string> {
  return buildOpenRouterHeaders(apiKey, {
    httpReferer: openRouterHttpReferer.value().trim() || undefined,
    appTitle: openRouterAppTitle.value().trim() || "Famil-IA",
  });
}

type RecipeImportDraft = {
  titulo: string;
  descripcion: string;
  ingredientes: string[];
  pasos: string[];
  tiempoMin: number;
  porciones: number;
  tags: string[];
  sourceUrl: string;
};

function requireAuth(request: { auth?: { uid: string } | null }): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  return request.auth.uid;
}

function normalizeUrl(raw: unknown): string {
  const value = String(raw ?? "").trim();
  if (!value) {
    throw new HttpsError("invalid-argument", "URL requerida");
  }
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new HttpsError("invalid-argument", "URL inválida");
  }
  if (parsed.protocol !== "https:") {
    throw new HttpsError("invalid-argument", "Solo se admiten URLs https");
  }
  return parsed.toString();
}

async function assertFamilyMember(
  db: admin.firestore.Firestore,
  familyId: string,
  uid: string,
): Promise<void> {
  if (!familyId) {
    throw new HttpsError("invalid-argument", "familyId requerido");
  }
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

async function assertRecipeImportEntitlement(
  db: admin.firestore.Firestore,
  familyId: string,
): Promise<void> {
  const billingDoc = await db
    .collection("families")
    .doc(familyId)
    .collection("billing")
    .doc("entitlements")
    .get();
  const value = billingDoc.get("entitlements.recipe_url_import");
  if (value === false) {
    throw new HttpsError(
      "permission-denied",
      "Tu plan no tiene habilitada la importación de recetas por URL",
    );
  }
}

function cleanHtml(raw: string): string {
  return raw
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function fetchHtml(url: string): Promise<{ html: string; fetchedBytes: number }> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), fetchTimeoutMs);
  try {
    const res = await fetch(url, {
      method: "GET",
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "User-Agent": "famil-ia-recipe-import/1.0",
        "Accept": "text/html,application/xhtml+xml",
      },
    });
    if (!res.ok) {
      throw new HttpsError("failed-precondition", `No se pudo leer la URL (${res.status})`);
    }
    const reader = res.body?.getReader();
    if (!reader) {
      throw new HttpsError("failed-precondition", "Respuesta sin contenido");
    }
    const chunks: Uint8Array[] = [];
    let totalBytes = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      if (value) {
        totalBytes += value.byteLength;
        if (totalBytes > maxHtmlBytes) {
          throw new HttpsError("resource-exhausted", "La página excede el tamaño permitido");
        }
        chunks.push(value);
      }
    }
    const merged = Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)));
    const html = merged.toString("utf8");
    return { html: cleanHtml(html), fetchedBytes: totalBytes };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    if ((error as { name?: string }).name === "AbortError") {
      throw new HttpsError("deadline-exceeded", "Timeout al intentar leer la URL");
    }
    throw new HttpsError("internal", "Falló la lectura de la URL");
  } finally {
    clearTimeout(timeout);
  }
}

function toStringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => String(item ?? "").trim())
    .filter((item) => item.length > 0)
    .slice(0, 80);
}

function toPositiveInt(value: unknown, fallback: number): number {
  const n = Number(value);
  if (Number.isFinite(n) && n > 0) {
    return Math.round(n);
  }
  return fallback;
}

function parseJsonFromModelText(text: string): unknown {
  let t = text.trim();
  const fence = /^```(?:json)?\s*([\s\S]*?)```$/m.exec(t);
  if (fence) {
    t = fence[1].trim();
  }
  return JSON.parse(t);
}

function normalizeDraft(raw: unknown, sourceUrl: string): RecipeImportDraft {
  const map = raw && typeof raw === "object" ? (raw as Record<string, unknown>) : {};
  const ingredientes = toStringList(map.ingredientes);
  const pasos = toStringList(map.pasos);
  return {
    titulo: String(map.titulo ?? "").trim(),
    descripcion: String(map.descripcion ?? "").trim(),
    ingredientes,
    pasos,
    tiempoMin: toPositiveInt(map.tiempoMin, 15),
    porciones: toPositiveInt(map.porciones, 2),
    tags: toStringList(map.tags).slice(0, 12),
    sourceUrl,
  };
}

async function callOpenRouterForRecipeDraft(
  url: string,
  html: string,
): Promise<RecipeImportDraft> {
  const key = openRouterApiKey.value();
  const model = openRouterRecipeModel.value().trim();
  const payload = buildRecipeImportChatPayload(
    model,
    url,
    html,
    maxHtmlCharsForPrompt,
  );

  const response = await fetch(OPENROUTER_CHAT_COMPLETIONS_URL, {
    method: "POST",
    headers: openRouterRequestHeaders(key),
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    logger.error("importRecipeFromUrl:openrouter_http_error", {
      status: response.status,
      model,
      errorText: errorText.slice(0, 800),
    });
    throw new HttpsError("internal", "No se pudo procesar la receta con el proveedor de IA", {
      status: response.status,
    });
  }

  const body = (await response.json()) as {
    choices?: Array<{ finish_reason?: string; message?: { content?: string | null } }>;
  };
  const text = extractChatCompletionMessageText(body);
  if (!text) {
    const finishReason = body.choices?.[0]?.finish_reason;
    logger.warn("importRecipeFromUrl:openrouter_empty_choice", { finishReason });
    throw new HttpsError("failed-precondition", "No se obtuvo contenido parseable");
  }
  let parsed: unknown;
  try {
    parsed = parseJsonFromModelText(text);
  } catch {
    logger.error("importRecipeFromUrl:openrouter_json_parse", {
      snippet: text.slice(0, 240),
    });
    throw new HttpsError("failed-precondition", "La respuesta de IA no fue JSON válido");
  }
  return normalizeDraft(parsed, url);
}

export const importRecipeFromUrl = onCall(
  { region, secrets: [openRouterApiKey] },
  async (request) => {
    const uid = requireAuth(request);
    const familyId = String(request.data?.familyId ?? "").trim();
    const sourceUrl = normalizeUrl(request.data?.url);

    const db = admin.firestore();
    await assertFamilyMember(db, familyId, uid);
    await assertRecipeImportEntitlement(db, familyId);

    const { html, fetchedBytes } = await fetchHtml(sourceUrl);
    const draft = await callOpenRouterForRecipeDraft(sourceUrl, html);
    logger.info("importRecipeFromUrl", {
      familyId,
      uid,
      sourceUrl,
      fetchedBytes,
      ingredientes: draft.ingredientes.length,
      pasos: draft.pasos.length,
    });
    return {
      draft,
      legalDisclaimer:
        "Verificá copyright y términos del sitio origen. La receta importada puede requerir edición.",
      meta: {
        sourceUrl,
        fetchedBytes,
      },
    };
  },
);
