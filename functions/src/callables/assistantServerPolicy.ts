/**
 * Herramientas que el backend ejecuta sin `pending_confirmation`.
 * Mantener alineado con `dispatchTool` en assistantToolRouter.ts.
 */
export const ASSISTANT_AUTO_EXECUTE_TOOL_NAMES = [
  "list_expenses",
  "list_categories",
  "list_stock_items",
  "list_recipes",
  "get_recipe",
  "list_notes",
  "create_expense",
  "create_stock_item",
  "update_stock_status",
  "create_note",
  "create_family_link",
  "create_recipe",
  "import_recipe_from_url",
] as const;
