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
const SAFE_SILENT_AUTO_TOOLS = new Set<string>([
  "list_expenses",
  "list_categories",
  "list_stock_items",
  "list_recipes",
  "get_recipe",
  "list_notes",
  "create_stock_item",
  "update_stock_status",
  "create_note",
  "create_family_link",
  "create_recipe",
  "import_recipe_from_url",
]);

type PlannerNodeType = "goal" | "substep" | "tool";
type PlannerNodeStatus = "planned" | "done" | "blocked";

type PlannerNode = {
  id: string;
  type: PlannerNodeType;
  status: PlannerNodeStatus;
  label: string;
  dependsOn: string[];
  silent_auto_step?: boolean;
  result?: string;
};

export type AssistantTaskPlanner = {
  goal: string;
  nodes: PlannerNode[];
  privateState: {
    lastNodeId: string;
    substepCount: number;
    toolCount: number;
  };
};

type ToolExecutionClassification = {
  blocking: boolean;
  status: "done" | "blocked";
  result: string;
};

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

export function classifyAssistantToolExecution(
  toolName: string,
  toolResponse: Record<string, unknown>,
): ToolExecutionClassification {
  const ok = toolResponse.ok === true;
  const rejected = toolResponse.rejected === true;
  const pendingConfirmation = toolResponse.pending_confirmation === true;
  const reason = String(toolResponse.reason ?? "").trim();
  const error = String(toolResponse.error ?? "").trim();
  const code = String(toolResponse.code ?? "").trim();

  if (ok) {
    return { blocking: false, status: "done", result: `ok:${toolName}` };
  }

  if (pendingConfirmation || rejected) {
    const detail = reason || "requires_user_intervention";
    return { blocking: true, status: "blocked", result: `blocked:${detail}` };
  }

  if (error) {
    const detail = code ? `${code}:${error}` : error;
    return { blocking: true, status: "blocked", result: `error:${detail}` };
  }

  return {
    blocking: true,
    status: "blocked",
    result: `error:${toolName}_unknown_tool_failure`,
  };
}

export function createAssistantTaskPlanner(goal: string): AssistantTaskPlanner {
  const goalText = goal.trim() || "Resolver solicitud del usuario";
  const goalId = "goal_1";
  return {
    goal: goalText,
    nodes: [{
      id: goalId,
      type: "goal",
      status: "planned",
      label: goalText,
      dependsOn: [],
    }],
    privateState: {
      lastNodeId: goalId,
      substepCount: 0,
      toolCount: 0,
    },
  };
}

export function registerPlannerToolExecution(
  planner: AssistantTaskPlanner,
  toolName: string,
  toolResponse: Record<string, unknown>,
): ToolExecutionClassification {
  const classification = classifyAssistantToolExecution(toolName, toolResponse);
  planner.privateState.substepCount += 1;
  const substepId = `substep_${planner.privateState.substepCount}`;
  planner.nodes.push({
    id: substepId,
    type: "substep",
    status: classification.status,
    label: `Resolver paso intermedio para ${toolName}`,
    dependsOn: [planner.privateState.lastNodeId],
  });

  planner.privateState.toolCount += 1;
  const toolId = `tool_${planner.privateState.toolCount}`;
  planner.nodes.push({
    id: toolId,
    type: "tool",
    status: classification.status,
    label: toolName,
    dependsOn: [substepId],
    silent_auto_step: SAFE_SILENT_AUTO_TOOLS.has(toolName) && !classification.blocking,
    result: classification.result,
  });
  planner.privateState.lastNodeId = toolId;

  return classification;
}

export function buildPlannerTraceabilitySummary(planner: AssistantTaskPlanner): string {
  const toolNodes = planner.nodes.filter((node) => node.type === "tool");
  if (toolNodes.length === 0) {
    return "Trazabilidad breve:\n- Objetivo: sin cambios de datos; solo respuesta directa.\n- Resultado: completado sin herramientas.";
  }

  const blocked = toolNodes.filter((node) => node.status === "blocked");
  const lines = toolNodes.map((node, index) => {
    const mode = node.silent_auto_step ? "silent_auto_step" : "user_intervention";
    const outcome = node.result ?? node.status;
    return `- Paso ${index + 1}: ${node.label} (${mode}) -> ${outcome}`;
  });

  const finalResult = blocked.length > 0
    ? `bloqueado (${blocked.length} paso(s) requieren intervención del usuario)`
    : "completado automáticamente";

  return [
    "Trazabilidad breve:",
    `- Objetivo: ${planner.goal}`,
    ...lines,
    `- Resultado: ${finalResult}.`,
  ].join("\n");
}

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
    "Si la solicitud requiere flujo compuesto, ejecutá automáticamente pasos intermedios seguros sin pedir confirmación.",
    "Pedí intervención del usuario solo cuando haya bloqueo real: permisos, conflicto o datos críticos faltantes.",
    "Al finalizar, devolvé respuesta con trazabilidad breve de acciones y resultado.",
  ].join(" ");

  const messages: ChatMessageWithTools[] = [
    { role: "system", content: systemContent },
    ...openAiMessagesFromPriorAndUser(params.prior, params.userText).map((m) => ({
      role: m.role,
      content: m.content,
    })),
  ];

  let rounds = 0;
  const planner = createAssistantTaskPlanner(params.userText);

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
        const normalizedToolResponse = asRecord(toolResponse);
        const classification = registerPlannerToolExecution(planner, name, normalizedToolResponse);
        messages.push({
          role: "tool",
          tool_call_id: tc.id,
          content: JSON.stringify(normalizedToolResponse),
        });
        if (classification.blocking) {
          messages.push({
            role: "system",
            content:
              `La ejecución de ${name} quedó bloqueada (${classification.result}). ` +
              "No pidas confirmaciones innecesarias; pedí intervención solo para destrabar este punto.",
          });
        }
      }
      continue;
    }

    const text = (content ?? "").trim();
    if (!text) {
      return "No obtuve una respuesta clara del asistente.";
    }
    return `${text}\n\n${buildPlannerTraceabilitySummary(planner)}`;
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
