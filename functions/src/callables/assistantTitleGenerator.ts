import * as logger from "firebase-functions/logger";

import {
  OPENROUTER_CHAT_COMPLETIONS_URL,
  buildAssistantChatPayload,
  extractChatCompletionMessageText,
} from "../llm/openRouterApi.js";
import { openRouterRequestHeaders } from "./recipeCallables.js";
import { sanitizeConversationTitleCandidate } from "./assistantCore.js";

const titleGenerationTimeoutMs = 8000;

export async function generateSemanticConversationTitle(params: {
  apiKey: string;
  model: string;
  firstUserMessage: string;
}): Promise<string | null> {
  const prompt =
    "Generá un título breve y conceptual para esta conversación. " +
    "Debe tener entre 2 y 6 palabras, sin comillas y sin punto final. " +
    "No copies literal el mensaje del usuario. Respondé solo el título.";

  const payload = buildAssistantChatPayload(params.model, [
    { role: "system", content: prompt },
    { role: "user", content: params.firstUserMessage },
  ]);

  try {
    const response = await fetch(OPENROUTER_CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: openRouterRequestHeaders(params.apiKey),
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(titleGenerationTimeoutMs),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.warn("assistantTitleGenerator:http_error", {
        status: response.status,
        errorText: errorText.slice(0, 250),
      });
      return null;
    }

    const body: unknown = await response.json();
    const rawTitle = extractChatCompletionMessageText(body);
    return sanitizeConversationTitleCandidate(rawTitle, params.firstUserMessage);
  } catch (error) {
    logger.warn("assistantTitleGenerator:request_failed", { error });
    return null;
  }
}
