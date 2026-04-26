import * as logger from "firebase-functions/logger";

import {
  OPENROUTER_CHAT_COMPLETIONS_URL,
  buildAssistantToolsChatPayload,
  extractAssistantToolCompletion,
  type ChatMessageWithTools,
} from "../llm/openRouterApi.js";
import { openRouterRequestHeaders } from "./recipeCallables.js";
import type { FireMessage } from "./assistantCore.js";
import { buildSystemPromptText, openAiMessagesFromPriorAndUser } from "./assistantCore.js";
import { assistantOpenAiTools } from "./assistantToolDeclarations.js";
import { executeAssistantTool, type ToolRouterContext } from "./assistantToolRouter.js";

const MAX_TOOL_ROUNDS = 6;

/**
 * Chat con OpenRouter (API OpenAI-compatible) + tool calls. Devuelve texto final del asistente.
 */
export async function runAssistantOpenRouterWithTools(params: {
  apiKey: string;
  model: string;
  prior: FireMessage[];
  userText: string;
  toolCtx: ToolRouterContext;
}): Promise<string> {
  const systemContent = [
    buildSystemPromptText(),
    "Tenés herramientas para leer y escribir datos del hogar (familia) del usuario.",
    "Usá herramientas cuando haga falta información real; no inventes montos ni IDs.",
    "No pidas aprobación previa para create_expense cuando la intención sea válida y tengas datos mínimos.",
    "Si create_expense devuelve ok=true, respondé con confirmación de ejecución en pasado.",
    "Para acciones marcadas como pendientes de confirmación (excepto create_expense), el servidor puede rechazarlas: explicá que deben confirmarse en la app.",
  ].join(" ");

  const messages: ChatMessageWithTools[] = [
    { role: "system", content: systemContent },
    ...openAiMessagesFromPriorAndUser(params.prior, params.userText).map((m) => ({
      role: m.role,
      content: m.content,
    })),
  ];

  let rounds = 0;

  for (;;) {
    rounds += 1;
    if (rounds > MAX_TOOL_ROUNDS) {
      logger.warn("assistantOpenRouterTools:max_tool_rounds", {
        familyId: params.toolCtx.familyId,
      });
      return "No pude completar la acción: demasiadas llamadas a herramientas. Probá de nuevo más simple.";
    }

    const response = await fetch(OPENROUTER_CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: openRouterRequestHeaders(params.apiKey),
      body: JSON.stringify(
        buildAssistantToolsChatPayload(params.model, messages, assistantOpenAiTools),
      ),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("assistantOpenRouterTools:http_error", {
        status: response.status,
        errorText: errorText.slice(0, 500),
      });
      throw new Error(`OpenRouter error ${response.status}`);
    }

    const body: unknown = await response.json();
    const { content, tool_calls } = extractAssistantToolCompletion(body);

    if (tool_calls && tool_calls.length > 0) {
      messages.push({
        role: "assistant",
        content: content ?? null,
        tool_calls,
      });

      for (const tc of tool_calls) {
        const name = tc.function?.name ?? "";
        let args: Record<string, unknown> = {};
        const rawArgs = tc.function?.arguments ?? "{}";
        try {
          const parsed: unknown = JSON.parse(rawArgs);
          args = parsed && typeof parsed === "object" && !Array.isArray(parsed)
            ? (parsed as Record<string, unknown>)
            : {};
        } catch {
          logger.warn("assistantOpenRouterTools:bad_tool_args", { name, rawArgs: rawArgs.slice(0, 200) });
        }
        const { response: toolResponse } = await executeAssistantTool(params.toolCtx, name, args);
        messages.push({
          role: "tool",
          tool_call_id: tc.id,
          content: JSON.stringify(toolResponse),
        });
      }
      continue;
    }

    const text = (content ?? "").trim();
    if (!text) {
      return "No obtuve una respuesta clara del asistente.";
    }
    return text;
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
