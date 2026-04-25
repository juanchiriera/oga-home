import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineString } from "firebase-functions/params";

import { geminiApiKey } from "./recipeCallables.js";

const region = "southamerica-east1";

const geminiModel = defineString("EXPENSE_IMPORT_GEMINI_MODEL", {
  default: "gemini-2.5-flash",
});

/** Must match `kExpenseCategories` / import flow keys in the mobile app. */
const CLOSED_CATEGORY_KEYS: readonly string[] = [
  "housing",
  "food",
  "transport",
  "shopping",
  "utilities",
  "health",
  "education",
  "leisure",
  "other",
];

const KEY_LABELS: Record<string, string> = {
  housing: "Vivienda",
  food: "Comida",
  transport: "Transporte",
  shopping: "Compras",
  utilities: "Servicios (luz, gas, internet, etc.)",
  health: "Salud",
  education: "Educación",
  leisure: "Ocio / entretenimiento",
  other: "Otros",
};

const KEY_SET = new Set(CLOSED_CATEGORY_KEYS);

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

type GeminiSuggest = {
  categoryKey?: unknown;
  confidence?: unknown;
  suggestedNewCategoryName?: unknown;
};

function normalizeResult(raw: GeminiSuggest): {
  categoryKey: string | null;
  confidence: number;
  suggestedNewCategoryName: string | null;
} {
  const keyRaw = raw.categoryKey;
  const key =
    typeof keyRaw === "string" && KEY_SET.has(keyRaw.trim())
      ? keyRaw.trim()
      : null;

  let conf = Number(raw.confidence);
  if (!Number.isFinite(conf)) {
    conf = key ? 0.7 : 0;
  }
  conf = Math.min(1, Math.max(0, conf));

  const nameRaw = raw.suggestedNewCategoryName;
  const suggestedName =
    typeof nameRaw === "string" && nameRaw.trim().length > 0
      ? nameRaw.trim().slice(0, 120)
      : null;

  return {
    categoryKey: key,
    confidence: conf,
    suggestedNewCategoryName: suggestedName,
  };
}

/**
 * Sugiere una categoría del catálogo cerrado para un gasto manual.
 * Si no encaja en el catálogo, puede devolver `suggestedNewCategoryName` para que
 * el cliente pida confirmación (no crea categorías en Firestore).
 */
export const suggestManualExpenseCategory = onCall(
  { region, secrets: [geminiApiKey] },
  async (request) => {
    const uid = requireAuth(request);
    const familyId = String(request.data?.familyId ?? "").trim();
    const merchant = String(request.data?.merchant ?? "").trim();
    const note = String(request.data?.note ?? "").trim();
    const amountRaw = request.data?.amount;

    if (!familyId) {
      throw new HttpsError("invalid-argument", "familyId es obligatorio");
    }

    let amountLine = "";
    if (amountRaw !== undefined && amountRaw !== null && String(amountRaw).trim() !== "") {
      const n = Number(amountRaw);
      if (Number.isFinite(n) && n > 0) {
        amountLine = `Monto aproximado: ${n}.`;
      }
    }

    const contextBits = [merchant, note, amountLine].filter(Boolean);
    if (contextBits.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Indicá al menos comercio, nota o monto para sugerir categoría",
      );
    }

    const db = admin.firestore();
    await assertFamilyMember(db, familyId, uid);

    const catalogLines = CLOSED_CATEGORY_KEYS.map(
      (k) => `- "${k}" → ${KEY_LABELS[k] ?? k}`,
    ).join("\n");

    const prompt = [
      "Sos un asistente para categorizar gastos familiares en Argentina/Latam.",
      "Catálogo CERRADO de claves (elegí solo una de estas claves o null):",
      catalogLines,
      "",
      "Reglas:",
      "- Devolvé SOLO JSON válido, sin markdown.",
      '- Formato: {"categoryKey":string|null,"confidence":number,"suggestedNewCategoryName":string|null}',
      "- categoryKey debe ser exactamente una clave de la lista, o null si ninguna aplica bien.",
      "- confidence entre 0 y 1.",
      "- Si el gasto no encaja en ninguna categoría del catálogo (ej: algo muy específico), poner categoryKey en null y suggestedNewCategoryName con un nombre corto en español (2-4 palabras) que el usuario podría querer como categoría nueva. Si encaja, suggestedNewCategoryName en null.",
      "- No inventes claves fuera de la lista: si dudás entre varias, elegí la más razonable o null con suggestedNewCategoryName.",
      "",
      "Contexto del gasto:",
      merchant ? `Comercio: ${merchant}` : "Comercio: (no indicado)",
      note ? `Nota: ${note}` : "Nota: (no indicada)",
      amountLine || "Monto: (no indicado o no numérico)",
    ].join("\n");

    const endpoint =
      `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel.value()}:generateContent`;

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiApiKey.value(),
      },
      body: JSON.stringify({
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.2,
        },
        contents: [
          {
            role: "user",
            parts: [{ text: prompt }],
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("suggestManualExpenseCategory:gemini_error", {
        familyId,
        status: response.status,
        errorText: errorText.slice(0, 500),
      });
      throw new HttpsError(
        "internal",
        "No se pudo obtener sugerencia de categoría (IA)",
        { status: response.status },
      );
    }

    const json = (await response.json()) as {
      candidates?: Array<{
        content?: { parts?: Array<{ text?: string }> };
      }>;
    };
    const text = json.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    if (!text.trim()) {
      throw new HttpsError("internal", "La IA no devolvió contenido");
    }

    let parsed: GeminiSuggest;
    try {
      parsed = JSON.parse(text) as GeminiSuggest;
    } catch {
      logger.error("suggestManualExpenseCategory:json_parse", {
        familyId,
        snippet: text.slice(0, 200),
      });
      throw new HttpsError("internal", "Respuesta de IA inválida");
    }

    const out = normalizeResult(parsed);

    logger.info("suggestManualExpenseCategory", {
      familyId,
      categoryKey: out.categoryKey,
      confidence: out.confidence,
      hasNewName: Boolean(out.suggestedNewCategoryName),
    });

    return {
      categoryKey: out.categoryKey,
      confidence: out.confidence,
      suggestedNewCategoryName: out.suggestedNewCategoryName,
    };
  },
);
