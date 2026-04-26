import {
  FunctionCallingMode,
  GoogleGenerativeAI,
  type Content,
  type FunctionCall,
  type Part,
} from "@google/generative-ai";
import * as logger from "firebase-functions/logger";

import type { FireMessage } from "./assistantCore.js";
import { buildSystemPromptText } from "./assistantCore.js";
import { geminiHistoryFromPrior } from "./assistantToolAudit.js";
import { assistantFunctionDeclarations } from "./assistantToolDeclarations.js";
import { executeAssistantTool, type ToolRouterContext } from "./assistantToolRouter.js";

const MAX_TOOL_ROUNDS = 6;

function partsFromText(text: string): Part[] {
  return [{ text }];
}

function functionResponseParts(
  calls: FunctionCall[],
  ctx: ToolRouterContext,
): Promise<Part[]> {
  return Promise.all(
    calls.map(async (call) => {
      const name = call.name;
      const args = call.args as Record<string, unknown> | undefined;
      const { response } = await executeAssistantTool(ctx, name, args ?? {});
      return {
        functionResponse: {
          name,
          response,
        },
      };
    }),
  );
}

/**
 * Chat con Gemini + function calling. Devuelve texto final del asistente (sin streaming).
 */
export async function runAssistantGeminiWithTools(params: {
  apiKey: string;
  modelName: string;
  prior: FireMessage[];
  userText: string;
  toolCtx: ToolRouterContext;
}): Promise<string> {
  const genAI = new GoogleGenerativeAI(params.apiKey);
  const systemInstruction = [
    buildSystemPromptText(),
    "Tenés herramientas para leer y escribir datos del hogar (familia) del usuario.",
    "Usá herramientas cuando haga falta información real; no inventes montos ni IDs.",
    "Para acciones marcadas como pendientes de confirmación, el servidor puede rechazarlas: explicá que deben confirmarse en la app.",
  ].join(" ");

  const model = genAI.getGenerativeModel({
    model: params.modelName,
    systemInstruction,
    tools: [{ functionDeclarations: assistantFunctionDeclarations }],
    toolConfig: {
      functionCallingConfig: { mode: FunctionCallingMode.AUTO },
    },
  });

  const history: Content[] = geminiHistoryFromPrior(params.prior).map((h) => ({
    role: h.role,
    parts: h.parts,
  }));

  const chat = model.startChat({ history });

  let parts: Part[] = partsFromText(params.userText);
  let rounds = 0;

  for (;;) {
    rounds += 1;
    if (rounds > MAX_TOOL_ROUNDS) {
      logger.warn("assistantGemini:max_tool_rounds", { familyId: params.toolCtx.familyId });
      return "No pude completar la acción: demasiadas llamadas a herramientas. Probá de nuevo más simple.";
    }

    const result = await chat.sendMessage(parts);
    const response = result.response;
    const calls = response.functionCalls();
    if (calls && calls.length > 0) {
      parts = await functionResponseParts(calls, params.toolCtx);
      continue;
    }

    const text = response.text();
    const trimmed = text.trim();
    if (!trimmed) {
      return "No obtuve una respuesta clara del asistente.";
    }
    return trimmed;
  }
}

/**
 * Emite texto en trozos para NDJSON (tras resolver tools).
 */
export function* chunkTextForNdjson(text: string, chunkSize: number): Generator<string> {
  const n = Math.max(16, chunkSize);
  for (let i = 0; i < text.length; i += n) {
    yield text.slice(i, i + n);
  }
}
