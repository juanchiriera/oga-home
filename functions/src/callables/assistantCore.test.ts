import { describe, expect, it } from "vitest";

import { openAiMessagesFromPriorAndUser } from "./assistantCore.js";

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
