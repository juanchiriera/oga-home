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
import { ASSISTANT_AUTO_EXECUTE_TOOL_NAMES } from "./assistantServerPolicy.js";
import { assistantOpenAiTools } from "./assistantToolDeclarations.js";
import { executeAssistantTool, type ToolRouterContext } from "./assistantToolRouter.js";

const MAX_TOOL_ROUNDS = 6;
const SAFE_SILENT_AUTO_TOOLS = new Set<string>([...ASSISTANT_AUTO_EXECUTE_TOOL_NAMES]);

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
    return "Trazabilidad: sin herramientas | ok";
  }

  const blocked = toolNodes.filter((node) => node.status === "blocked");
  const chain = toolNodes
    .map((node) => {
      const mode = node.silent_auto_step ? "auto" : "manual";
      const outcome = node.result ?? node.status;
      return `${node.label}(${mode}:${outcome})`;
    })
    .join(" → ");

  const finalResult = blocked.length > 0
    ? `bloqueado:${blocked.length}`
    : "ok";

  return `Trazabilidad: ${chain} | ${finalResult}`;
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
    "Usá herramientas para datos reales; no inventes montos ni IDs.",
    "Flujos compuestos: encadená herramientas auto-ejecutables sin preguntar entre paso y paso.",
    "Tu mensaje visible al usuario: máximo 2 oraciones, tono conversacional; no listes nombres de herramientas ni pasos internos.",
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
    logger.info("assistantOpenRouterTools:planner_traceability", {
      familyId: params.toolCtx.familyId,
      conversationId: params.toolCtx.conversationId,
      plannerTraceability: buildPlannerTraceabilitySummary(planner),
    });
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
