/** URL de Chat Completions usada por todas las integraciones OpenAI del backend. */
export const OPENAI_CHAT_COMPLETIONS_URL =
  "https://api.openai.com/v1/chat/completions" as const;

export type OpenAiTextChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

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
  messages: OpenAiTextChatMessage[],
): {
  model: string;
  temperature: number;
  max_tokens: number;
  messages: OpenAiTextChatMessage[];
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
  messages: OpenAiTextChatMessage[],
): {
  model: string;
  stream: true;
  temperature: number;
  max_tokens: number;
  messages: OpenAiTextChatMessage[];
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

export function extractOpenAiStreamDelta(obj: unknown): string {
  const j = obj as {
    choices?: Array<{ delta?: { content?: string | null } }>;
  };
  const c = j.choices?.[0]?.delta?.content;
  return c != null ? String(c) : "";
}

/** Parsea líneas `data: {...}` del stream SSE de OpenAI. */
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
