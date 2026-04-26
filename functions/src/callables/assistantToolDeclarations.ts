/** Catálogo §8.2 — nombres en snake_case; `tools_version` global 1 (cabecera HTTP). Formato OpenAI / OpenRouter. */

export type AssistantOpenAiTool = {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
};

const str = (description: string): Record<string, unknown> => ({
  type: "string",
  description,
});

const optStr = (description: string): Record<string, unknown> => ({
  type: "string",
  description,
  nullable: true,
});

export const assistantOpenAiTools: AssistantOpenAiTool[] = [
  {
    type: "function",
    function: {
      name: "list_expenses",
      description:
        "Lista gastos del hogar con filtros opcionales por fecha, categoría, estado y moneda.",
      parameters: {
        type: "object",
        properties: {
          date_from: optStr("Fecha inclusive inicio YYYY-MM-DD (opcional)"),
          date_to: optStr("Fecha inclusive fin YYYY-MM-DD (opcional)"),
          category_key: optStr("Clave de categoría (p. ej. food, transport)"),
          status: optStr("confirmed | pending_card_cycle | cancelled"),
          currency: optStr("ARS | USD | EUR"),
          limit: {
            type: "integer",
            description: "Máximo de documentos (default 40, max 80)",
            nullable: true,
          },
        },
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "create_expense",
      description: "Alta de gasto (requiere confirmación en UI; no se aplica en servidor v1).",
      parameters: {
        type: "object",
        properties: {
          amount: { type: "number", description: "Monto positivo" },
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
  },
  {
    type: "function",
    function: {
      name: "update_expense",
      description: "Actualizar gasto (v1: requiere confirmación; rechazado en servidor).",
      parameters: {
        type: "object",
        properties: {
          expense_id: str("ID del gasto"),
          amount: { type: "number", nullable: true },
          category_key: optStr("Nueva categoría"),
          payment_method_id: optStr("Nuevo método de pago"),
          merchant: optStr("Comercio"),
          note: optStr("Nota"),
          occurred_at: optStr("YYYY-MM-DD"),
        },
        required: ["expense_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "delete_expense",
      description: "Eliminar gasto (alto riesgo; v1 rechazado pendiente confirmación UI).",
      parameters: {
        type: "object",
        properties: { expense_id: str("ID del gasto") },
        required: ["expense_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "list_categories",
      description: "Lista categorías de gasto conocidas (incluye flag system).",
      parameters: {
        type: "object",
        properties: {},
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_new_category",
      description: "Propone categoría nueva (v1: solo tras confirmación explícita en UI).",
      parameters: {
        type: "object",
        properties: {
          label: str("Nombre visible"),
          key: optStr("Clave sugerida snake_case"),
        },
        required: ["label"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "register_card_cycle_close",
      description: "Efectiviza cierre de ciclo de tarjeta (v1: rechazado; usar pantalla dedicada).",
      parameters: {
        type: "object",
        properties: {
          payment_method_id: str("ID método tarjeta crédito"),
          closing_date: str("YYYY-MM-DD"),
        },
        required: ["payment_method_id", "closing_date"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "register_card_payment",
      description: "Registra pago de tarjeta (v1: rechazado; usar pantalla dedicada).",
      parameters: {
        type: "object",
        properties: {
          payment_method_id: str("ID método tarjeta crédito"),
          effective_date: str("YYYY-MM-DD"),
          expense_ids: {
            type: "array",
            items: { type: "string" },
            description: "Opcional: IDs específicos; si vacío, todos los pendientes del método",
            nullable: true,
          },
        },
        required: ["payment_method_id", "effective_date"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "list_stock_items",
      description: "Lista ítems de despensa/stock, filtro opcional por estado (hay, low, out).",
      parameters: {
        type: "object",
        properties: {
          state: optStr("hay | low | out"),
          limit: { type: "integer", nullable: true },
        },
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "create_stock_item",
      description: "Crea ítem de stock con nombre y estado inicial.",
      parameters: {
        type: "object",
        properties: {
          name: str("Nombre del producto"),
          state: str("hay | low | out"),
        },
        required: ["name", "state"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "update_stock_status",
      description: "Actualiza el estado de un ítem de stock existente.",
      parameters: {
        type: "object",
        properties: {
          item_id: str("ID del ítem"),
          state: str("hay | low | out"),
        },
        required: ["item_id", "state"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "archive_stock_item",
      description: "Archivar/eliminar ítem (v1: rechazado pendiente confirmación).",
      parameters: {
        type: "object",
        properties: { item_id: str("ID del ítem") },
        required: ["item_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "list_recipes",
      description: "Lista recetas del hogar (título y metadatos breves).",
      parameters: {
        type: "object",
        properties: {
          limit: { type: "integer", nullable: true },
        },
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_recipe",
      description: "Obtiene una receta por ID.",
      parameters: {
        type: "object",
        properties: { recipe_id: str("ID receta") },
        required: ["recipe_id"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "create_recipe",
      description: "Crea receta con ingredientes y pasos (idempotente con client_request_id).",
      parameters: {
        type: "object",
        properties: {
          titulo: str("Título"),
          descripcion: str("Descripción"),
          ingredientes: { type: "array", items: { type: "string" } },
          pasos: { type: "array", items: { type: "string" } },
          tiempo_min: { type: "integer", description: "Minutos" },
          porciones: { type: "integer" },
          favorita: { type: "boolean", nullable: true },
          tags: {
            type: "array",
            items: { type: "string" },
            nullable: true,
          },
        },
        required: ["titulo", "descripcion", "ingredientes", "pasos", "tiempo_min", "porciones"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "import_recipe_from_url",
      description:
        "Obtiene borrador de receta desde URL https (preview; no persiste hasta confirmación en UI).",
      parameters: {
        type: "object",
        properties: { url: str("URL https") },
        required: ["url"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "list_notes",
      description: "Lista notas compartidas del hogar.",
      parameters: {
        type: "object",
        properties: {
          limit: { type: "integer", nullable: true },
        },
        required: [],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "create_note",
      description: "Crea nota compartida con título y contenido.",
      parameters: {
        type: "object",
        properties: {
          title: str("Título"),
          content: str("Contenido"),
        },
        required: ["title", "content"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "create_family_link",
      description: "Crea enlace útil (URL https, título y nota opcionales).",
      parameters: {
        type: "object",
        properties: {
          url: str("URL https"),
          title: optStr("Título corto"),
          note: optStr("Nota"),
        },
        required: ["url"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "start_receipt_import",
      description: "Inicia import de ticket (v1: rechazado; flujo requiere UI de confirmación).",
      parameters: {
        type: "object",
        properties: {
          hint: optStr("Texto libre opcional"),
        },
        required: [],
      },
    },
  },
];
