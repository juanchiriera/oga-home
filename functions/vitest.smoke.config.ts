import { defineConfig } from "vitest/config";

/** Ejecutar con: `OPENROUTER_API_KEY=sk-or-v1-... npm run test:smoke` */
export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.smoke.test.ts"],
    testTimeout: 45_000,
    hookTimeout: 15_000,
  },
});
