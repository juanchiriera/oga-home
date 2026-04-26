import { describe, expect, it } from "vitest";

import {
  formatConversationFallbackTitle,
  openAiMessagesFromPriorAndUser,
  sanitizeConversationTitleCandidate,
} from "./assistantCore.js";

describe("openAiMessagesFromPriorAndUser", () => {
  it("mapea assistant del historial a role assistant", () => {
    const msgs = openAiMessagesFromPriorAndUser(
      [
        { role: "user", text: "A" },
        { role: "assistant", text: "B" },
      ],
      "C",
    );
    expect(msgs).toEqual([
      { role: "user", content: "A" },
      { role: "assistant", content: "B" },
      { role: "user", content: "C" },
    ]);
  });

  it("trata roles desconocidos como user", () => {
    const msgs = openAiMessagesFromPriorAndUser([{ role: "system", text: "X" }], "Y");
    expect(msgs[0].role).toBe("user");
  });
});

describe("conversation titles", () => {
  it("usa fallback dd/mm/yyyy hh:mm", () => {
    const title = formatConversationFallbackTitle(new Date(2026, 3, 26, 18, 7));
    expect(title).toBe("26/04/2026 18:07");
  });

  it("descarta título que repite el primer mensaje", () => {
    const title = sanitizeConversationTitleCandidate(
      "Necesito ideas para una cena rápida",
      "Necesito ideas para una cena rápida",
    );
    expect(title).toBeNull();
  });

  it("acepta título conceptual breve", () => {
    const title = sanitizeConversationTitleCandidate(
      "Ideas de cena rápida",
      "Necesito ideas para una cena rápida",
    );
    expect(title).toBe("Ideas de cena rápida");
  });
});
