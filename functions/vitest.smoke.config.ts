import { defineConfig } from "vitest/config";

/** Ejecutar con: `OPENAI_API_KEY=sk-... npm run test:smoke` */
export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.smoke.test.ts"],
    testTimeout: 45_000,
    hookTimeout: 15_000,
  },
});
