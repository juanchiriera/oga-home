import { beforeAll, describe, expect, it } from "vitest";

import {
  OPENROUTER_CHAT_COMPLETIONS_URL,
  buildOpenRouterHeaders,
  extractChatCompletionMessageText,
} from "./openRouterApi.js";

/**
 * Prueba de humo contra la API real de OpenRouter.
 *
 * No se commitea ninguna clave: usá variable de entorno.
 *
 *   OPENROUTER_API_KEY=sk-or-v1-... npm run test:smoke
 *
 * Opcional: `OPENROUTER_SMOKE_MODEL` (default `openai/gpt-4o-mini`).
 */
describe("OpenRouter API smoke (live)", () => {
  beforeAll(() => {
    if (!process.env.OPENROUTER_API_KEY?.trim()) {
      throw new Error(
        "OPENROUTER_API_KEY no está definida. Ej.: OPENROUTER_API_KEY=sk-or-... npm run test:smoke",
      );
    }
  });

  it("chat completions responde con JSON mode", async () => {
    const key = process.env.OPENROUTER_API_KEY!.trim();
    const model = process.env.OPENROUTER_SMOKE_MODEL?.trim() || "openai/gpt-4o-mini";

    const res = await fetch(OPENROUTER_CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: buildOpenRouterHeaders(key, { appTitle: "famil-ia-smoke" }),
      body: JSON.stringify({
        model,
        max_tokens: 48,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "user",
            content: 'Devolvé SOLO JSON con forma exacta: {"ping":"pong","n":1}',
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
