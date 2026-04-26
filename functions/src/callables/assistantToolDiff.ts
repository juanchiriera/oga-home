/**
 * Líneas legibles para bottom sheet (§8.1) — resumen de args antes de aplicar.
 */
export function buildToolDiffLines(
  tool: string,
  args: Record<string, unknown>,
): string[] {
  const lines: string[] = [`Herramienta: ${tool}`];
  for (const [k, v] of Object.entries(args)) {
    let s: string;
    if (v === null || v === undefined) {
      s = "—";
    } else if (typeof v === "object") {
      s = JSON.stringify(v);
    } else {
      s = String(v);
    }
    if (s.length > 200) {
      s = `${s.slice(0, 197)}…`;
    }
    lines.push(`• ${k}: ${s}`);
  }
  if (lines.length === 1) {
    lines.push("• (sin parámetros adicionales)");
  }
  return lines;
}
