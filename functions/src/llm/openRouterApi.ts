/**
 * OpenRouter: API compatible con OpenAI Chat Completions.
 * @see https://openrouter.ai/docs/quickstart
 */
export const OPENROUTER_CHAT_COMPLETIONS_URL =
  "https://openrouter.ai/api/v1/chat/completions" as const;

export type LlmTextChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

/** @deprecated use LlmTextChatMessage; nombre histórico */
export type OpenAiTextChatMessage = LlmTextChatMessage;

/**
 * Cabeceras recomendadas por OpenRouter (Authorization + JSON).
 * `HTTP-Referer` y `X-OpenRouter-Title` son opcionales (atribución / rankings en openrouter.ai).
 */
export function buildOpenRouterHeaders(
  apiKey: string,
  opts?: { httpReferer?: string; appTitle?: string },
): Record<string, string> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${apiKey}`,
  };
  const ref = opts?.httpReferer?.trim();
  if (ref) {
    headers["HTTP-Referer"] = ref;
  }
  const title = opts?.appTitle?.trim();
  if (title) {
    headers["X-OpenRouter-Title"] = title;
  }
  return headers;
}

export function buildRecipeImportChatPayload(
  model: string,
  url: string,
  cleanedHtml: string,
  maxHtmlChars: number,
): {
  model: string;
  temperature: number;
  response_format: { type: "json_object" };
  messages: Array<{ role: "user"; content: string }>;
} {
  const promptHtml = cleanedHtml.slice(0, maxHtmlChars);
  const userContent =
    "Extrae una receta del HTML y devolvé SOLO JSON válido (sin markdown), con claves: " +
    "titulo, descripcion, ingredientes (array de strings), pasos (array de strings), " +
    "tiempoMin (int), porciones (int), tags (array de strings)." +
    `\nURL: ${url}\nHTML: ${promptHtml}`;
  return {
    model,
    temperature: 0.2,
    response_format: { type: "json_object" },
    messages: [{ role: "user", content: userContent }],
  };
}

export function buildAssistantChatPayload(
  model: string,
  messages: LlmTextChatMessage[],
): {
  model: string;
  temperature: number;
  max_tokens: number;
  messages: LlmTextChatMessage[];
} {
  return {
    model,
    temperature: 0.5,
    max_tokens: 2048,
    messages,
  };
}

export function buildAssistantStreamPayload(
  model: string,
  messages: LlmTextChatMessage[],
): {
  model: string;
  stream: true;
  temperature: number;
  max_tokens: number;
  messages: LlmTextChatMessage[];
} {
  return {
    model,
    stream: true,
    temperature: 0.5,
    max_tokens: 2048,
    messages,
  };
}

export function buildExpenseVisionChatPayload(
  model: string,
  prompt: string,
  dataUrl: string,
): {
  model: string;
  temperature: number;
  response_format: { type: "json_object" };
  messages: Array<{
    role: "user";
    content: Array<
      | { type: "text"; text: string }
      | { type: "image_url"; image_url: { url: string } }
    >;
  }>;
} {
  return {
    model,
    temperature: 0.2,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: dataUrl } },
        ],
      },
    ],
  };
}

export function buildExpenseCategoryChatPayload(
  model: string,
  prompt: string,
): {
  model: string;
  temperature: number;
  response_format: { type: "json_object" };
  messages: Array<{ role: "user"; content: string }>;
} {
  return {
    model,
    temperature: 0.2,
    response_format: { type: "json_object" },
    messages: [{ role: "user", content: prompt }],
  };
}

export function extractChatCompletionMessageText(body: unknown): string {
  const json = body as {
    choices?: Array<{ message?: { content?: string | null } }>;
  };
  const text = json.choices?.[0]?.message?.content ?? "";
  return String(text).trim();
}

/** Delta de contenido en stream SSE (formato OpenAI / OpenRouter). */
export function extractOpenAiStreamDelta(obj: unknown): string {
  const j = obj as {
    choices?: Array<{ delta?: { content?: string | null } }>;
  };
  const c = j.choices?.[0]?.delta?.content;
  return c != null ? String(c) : "";
}

/** Parsea líneas `data: {...}` del stream SSE. */
export function parseSseDataLines(buffer: string): { lines: string[]; rest: string } {
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
