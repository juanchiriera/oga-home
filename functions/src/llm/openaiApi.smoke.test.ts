import { beforeAll, describe, expect, it } from "vitest";

import {
  OPENAI_CHAT_COMPLETIONS_URL,
  extractChatCompletionMessageText,
} from "./openaiApi.js";

/**
 * Prueba de humo contra la API real de OpenAI.
 *
 * No se commitea ninguna clave: usá variable de entorno.
 *
 *   OPENAI_API_KEY=sk-... npm run test:smoke
 *
 * Opcional: `OPENAI_SMOKE_MODEL` (default `gpt-4o-mini`).
 */
describe("OpenAI API smoke (live)", () => {
  beforeAll(() => {
    if (!process.env.OPENAI_API_KEY?.trim()) {
      throw new Error(
        "OPENAI_API_KEY no está definida. Ej.: OPENAI_API_KEY=sk-... npm run test:smoke",
      );
    }
  });

  it("chat completions responde con JSON mode", async () => {
    const key = process.env.OPENAI_API_KEY!.trim();
    const model = process.env.OPENAI_SMOKE_MODEL?.trim() || "gpt-4o-mini";

    const res = await fetch(OPENAI_CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model,
        max_tokens: 48,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "user",
            content:
              'Devolvé SOLO JSON con forma exacta: {"ping":"pong","n":1}',
          },
        ],
      }),
    });

    const errBody = res.ok ? "" : await res.text();
    expect(res.ok, `HTTP ${res.status}: ${errBody.slice(0, 500)}`).toBe(true);

    const body: unknown = await res.json();
    const text = extractChatCompletionMessageText(body);
    expect(text.length).toBeGreaterThan(0);

    const parsed = JSON.parse(text) as { ping?: string; n?: number };
    expect(parsed.ping).toBe("pong");
    expect(parsed.n).toBe(1);
  });
});
