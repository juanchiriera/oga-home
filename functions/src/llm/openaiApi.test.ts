import { describe, expect, it } from "vitest";

import {
  OPENAI_CHAT_COMPLETIONS_URL,
  buildAssistantChatPayload,
  buildAssistantStreamPayload,
  buildExpenseCategoryChatPayload,
  buildExpenseVisionChatPayload,
  buildRecipeImportChatPayload,
  extractChatCompletionMessageText,
  extractOpenAiStreamDelta,
  parseSseDataLines,
} from "./openaiApi.js";

describe("OPENAI_CHAT_COMPLETIONS_URL", () => {
  it("apunta al endpoint de Chat Completions v1", () => {
    expect(OPENAI_CHAT_COMPLETIONS_URL).toBe("https://api.openai.com/v1/chat/completions");
  });
});

describe("buildRecipeImportChatPayload", () => {
  it("usa json_object y recorta HTML al máximo indicado", () => {
    const html = "x".repeat(100);
    const p = buildRecipeImportChatPayload("gpt-4o-mini", "https://ejemplo.com/r", html, 20);
    expect(p.model).toBe("gpt-4o-mini");
    expect(p.temperature).toBe(0.2);
    expect(p.response_format).toEqual({ type: "json_object" });
    expect(p.messages).toHaveLength(1);
    expect(p.messages[0].role).toBe("user");
    expect(p.messages[0].content).toContain("https://ejemplo.com/r");
    expect(p.messages[0].content).toContain("x".repeat(20));
    expect(p.messages[0].content).not.toContain("x".repeat(21));
  });
});

describe("buildAssistantChatPayload", () => {
  it("incluye system y límites de salida", () => {
    const messages = [
      { role: "system" as const, content: "Sos un asistente." },
      { role: "user" as const, content: "Hola" },
    ];
    const p = buildAssistantChatPayload("gpt-4o-mini", messages);
    expect(p.stream).toBeUndefined();
    expect(p.max_tokens).toBe(2048);
    expect(p.temperature).toBe(0.5);
    expect(p.messages[0].role).toBe("system");
  });
});

describe("buildAssistantStreamPayload", () => {
  it("habilita stream", () => {
    const messages = [
      { role: "system" as const, content: "Sys" },
      { role: "user" as const, content: "Hi" },
    ];
    const p = buildAssistantStreamPayload("gpt-4o-mini", messages);
    expect(p.stream).toBe(true);
    expect(p.max_tokens).toBe(2048);
  });
});

describe("buildExpenseVisionChatPayload", () => {
  it("envía texto + image_url data URL", () => {
    const p = buildExpenseVisionChatPayload(
      "gpt-4o-mini",
      "Parseá el ticket",
      "data:image/png;base64,abcd",
    );
    expect(p.response_format).toEqual({ type: "json_object" });
    const content = p.messages[0].content;
    expect(content[0]).toEqual({ type: "text", text: "Parseá el ticket" });
    expect(content[1]).toEqual({
      type: "image_url",
      image_url: { url: "data:image/png;base64,abcd" },
    });
  });
});

describe("buildExpenseCategoryChatPayload", () => {
  it("es un único turno usuario con JSON mode", () => {
    const p = buildExpenseCategoryChatPayload("gpt-4o-mini", '{"foo":1}');
    expect(p.messages).toEqual([{ role: "user", content: '{"foo":1}' }]);
    expect(p.response_format.type).toBe("json_object");
  });
});

describe("extractChatCompletionMessageText", () => {
  it("lee choices[0].message.content", () => {
    expect(
      extractChatCompletionMessageText({
        choices: [{ message: { content: "  Hola  " } }],
      }),
    ).toBe("Hola");
  });

  it("devuelve cadena vacía si no hay contenido", () => {
    expect(extractChatCompletionMessageText({ choices: [{}] })).toBe("");
  });
});

describe("extractOpenAiStreamDelta", () => {
  it("concatena delta.content", () => {
    expect(
      extractOpenAiStreamDelta({
        choices: [{ delta: { content: "a" } }],
      }),
    ).toBe("a");
  });
});

describe("parseSseDataLines", () => {
  it("extrae JSON por línea data: y omite [DONE]", () => {
    const buf = 'data: {"x":1}\n\ndata: [DONE]\n';
    const { lines, rest } = parseSseDataLines(buf);
    expect(lines).toEqual(['{"x":1}']);
    expect(rest).toBe("");
  });

  it("deja línea incompleta en rest", () => {
    const { lines, rest } = parseSseDataLines('data: {"a');
    expect(lines).toEqual([]);
    expect(rest).toBe('data: {"a');
  });
});
