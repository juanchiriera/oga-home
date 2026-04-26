import type { FunctionDeclaration } from "@google/generative-ai";
import { SchemaType } from "@google/generative-ai";

const str = (description: string): { type: SchemaType.STRING; description: string } => ({
  type: SchemaType.STRING,
  description,
});

const optStr = (description: string): { type: SchemaType.STRING; description: string; nullable: true } => ({
  type: SchemaType.STRING,
  description,
  nullable: true,
});

/** Catálogo §8.2 — nombres en snake_case, `tools_version` global 1 (cabecera HTTP). */
export const assistantFunctionDeclarations: FunctionDeclaration[] = [
  {
    name: "list_expenses",
    description:
      "Lista gastos del hogar con filtros opcionales por fecha, categoría, estado y moneda.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        date_from: optStr("Fecha inclusive inicio YYYY-MM-DD (opcional)"),
        date_to: optStr("Fecha inclusive fin YYYY-MM-DD (opcional)"),
        category_key: optStr("Clave de categoría (p. ej. food, transport)"),
        status: optStr("confirmed | pending_card_cycle | cancelled"),
        currency: optStr("ARS | USD | EUR"),
        limit: {
          type: SchemaType.INTEGER,
          description: "Máximo de documentos (default 40, max 80)",
          nullable: true,
        },
      },
      required: [],
    },
  },
  {
    name: "create_expense",
    description: "Alta de gasto (requiere confirmación en UI; no se aplica en servidor v1).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        amount: { type: SchemaType.NUMBER, description: "Monto positivo" },
        currency: str("ARS | USD | EUR"),
        category_key: str("Clave de categoría"),
        occurred_at: str("YYYY-MM-DD"),
        payment_method_id: optStr("ID método de pago"),
        merchant: optStr("Comercio"),
        note: optStr("Nota"),
      },
      required: ["amount", "currency", "category_key", "occurred_at"],
    },
  },
  {
    name: "update_expense",
    description: "Actualizar gasto (v1: requiere confirmación; rechazado en servidor).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        expense_id: str("ID del gasto"),
        amount: { type: SchemaType.NUMBER, nullable: true },
        category_key: optStr("Nueva categoría"),
        payment_method_id: optStr("Nuevo método de pago"),
        merchant: optStr("Comercio"),
        note: optStr("Nota"),
        occurred_at: optStr("YYYY-MM-DD"),
      },
      required: ["expense_id"],
    },
  },
  {
    name: "delete_expense",
    description: "Eliminar gasto (alto riesgo; v1 rechazado pendiente confirmación UI).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: { expense_id: str("ID del gasto") },
      required: ["expense_id"],
    },
  },
  {
    name: "list_categories",
    description: "Lista categorías de gasto conocidas (incluye flag system).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {},
      required: [],
    },
  },
  {
    name: "propose_new_category",
    description: "Propone categoría nueva (v1: solo tras confirmación explícita en UI).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        label: str("Nombre visible"),
        key: optStr("Clave sugerida snake_case"),
      },
      required: ["label"],
    },
  },
  {
    name: "register_card_cycle_close",
    description: "Efectiviza cierre de ciclo de tarjeta (v1: rechazado; usar pantalla dedicada).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        payment_method_id: str("ID método tarjeta crédito"),
        closing_date: str("YYYY-MM-DD"),
      },
      required: ["payment_method_id", "closing_date"],
    },
  },
  {
    name: "register_card_payment",
    description: "Registra pago de tarjeta (v1: rechazado; usar pantalla dedicada).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        payment_method_id: str("ID método tarjeta crédito"),
        effective_date: str("YYYY-MM-DD"),
        expense_ids: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Opcional: IDs específicos; si vacío, todos los pendientes del método",
          nullable: true,
        },
      },
      required: ["payment_method_id", "effective_date"],
    },
  },
  {
    name: "list_stock_items",
    description: "Lista ítems de despensa/stock, filtro opcional por estado (hay, low, out).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        state: optStr("hay | low | out"),
        limit: { type: SchemaType.INTEGER, nullable: true },
      },
      required: [],
    },
  },
  {
    name: "create_stock_item",
    description: "Crea ítem de stock con nombre y estado inicial.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        name: str("Nombre del producto"),
        state: str("hay | low | out"),
      },
      required: ["name", "state"],
    },
  },
  {
    name: "update_stock_status",
    description: "Actualiza el estado de un ítem de stock existente.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        item_id: str("ID del ítem"),
        state: str("hay | low | out"),
      },
      required: ["item_id", "state"],
    },
  },
  {
    name: "archive_stock_item",
    description: "Archivar/eliminar ítem (v1: rechazado pendiente confirmación).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: { item_id: str("ID del ítem") },
      required: ["item_id"],
    },
  },
  {
    name: "list_recipes",
    description: "Lista recetas del hogar (título y metadatos breves).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        limit: { type: SchemaType.INTEGER, nullable: true },
      },
      required: [],
    },
  },
  {
    name: "get_recipe",
    description: "Obtiene una receta por ID.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: { recipe_id: str("ID receta") },
      required: ["recipe_id"],
    },
  },
  {
    name: "create_recipe",
    description: "Crea receta con ingredientes y pasos (idempotente con client_request_id).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        titulo: str("Título"),
        descripcion: str("Descripción"),
        ingredientes: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
        pasos: { type: SchemaType.ARRAY, items: { type: SchemaType.STRING } },
        tiempo_min: { type: SchemaType.INTEGER, description: "Minutos" },
        porciones: { type: SchemaType.INTEGER },
        favorita: { type: SchemaType.BOOLEAN, nullable: true },
        tags: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          nullable: true,
        },
      },
      required: ["titulo", "descripcion", "ingredientes", "pasos", "tiempo_min", "porciones"],
    },
  },
  {
    name: "import_recipe_from_url",
    description:
      "Obtiene borrador de receta desde URL https (preview; no persiste hasta confirmación en UI).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: { url: str("URL https") },
      required: ["url"],
    },
  },
  {
    name: "list_notes",
    description: "Lista notas compartidas del hogar.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        limit: { type: SchemaType.INTEGER, nullable: true },
      },
      required: [],
    },
  },
  {
    name: "create_note",
    description: "Crea nota compartida con título y contenido.",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        title: str("Título"),
        content: str("Contenido"),
      },
      required: ["title", "content"],
    },
  },
  {
    name: "create_family_link",
    description: "Crea enlace útil (URL https, título y nota opcionales).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        url: str("URL https"),
        title: optStr("Título corto"),
        note: optStr("Nota"),
      },
      required: ["url"],
    },
  },
  {
    name: "start_receipt_import",
    description: "Inicia import de ticket (v1: rechazado; flujo requiere UI de confirmación).",
    parameters: {
      type: SchemaType.OBJECT,
      properties: {
        hint: optStr("Texto libre opcional"),
      },
      required: [],
    },
  },
];
