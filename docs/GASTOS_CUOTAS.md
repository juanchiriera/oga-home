# Gastos en cuotas (planes y generación)

## Resumen funcional

Un **plan en cuotas** es un documento en `families/{familyId}/recurringTemplates` con `type: "installment"`. El job programado `generateRecurringExpenses` (Cloud Scheduler, zona `America/Argentina/Buenos_Aires`) crea **un gasto** en `expenses` en cada período calendario configurado, hasta completar `totalInstallments`. Cada gasto generado lleva `installmentIndex`, `installmentTotal`, `recurringTemplateId` y `recurringPeriodKey` (YYYY-MM del mes de imputación).

Los totales mensuales de la app móvil usan `occurredAt` del gasto; la función fija `occurredAt` al **mediodía civil** del día de generación (día 1 o último día del mes, según `generationDay`), de modo que el movimiento cae en el mes esperado.

## Campos del plan (plantilla)

| Campo | Uso |
|--------|-----|
| `active` | Si es `false`, no se generan más cuotas. |
| `amount` | Monto **por cuota** (positivo). |
| `categoryKey`, `paymentMethodId`, `merchant`, `note` | Igual que un gasto manual; la nota de cuota se concatena con «Cuota i/N». |
| `type` | `"installment"`. |
| `generationDay` | `"month_start"` (día 1) o `"month_end"` (último día del mes). |
| `totalInstallments` | Cantidad N de cuotas (≥ 1). |
| `currentInstallment` | Próxima cuota a generar (al crear el plan debe ser **1**). |
| `startPeriodKey` | Opcional, formato `YYYY-MM`: no se genera ninguna cuota en meses anteriores a este período (inclusive el mes indicado como primer mes con cuota posible). |
| `lastGeneratedPeriod` | Lo escribe el backend tras cada generación exitosa (YYYY-MM). |

## Reglas de negocio (v1)

1. **Periodicidad**: solo mensual alineada al calendario (`month_start` / `month_end`). No hay quincenas ni offsets por feriados.
2. **Redondeo**: en la app, si el usuario ingresa **monto total**, el monto por cuota es `round(total / N, 2 centavos)`; puede haber una diferencia de centavos respecto del total nominal (documentado en el formulario).
3. **Fin del plan**: tras generar la última cuota, el job pone `active: false` e incrementa `currentInstallment` por encima del total de forma consistente con la transacción existente.
4. **Cancelación manual**: cualquier miembro con permisos de escritura puede desactivar el plan (`active: false`) **solo si es el `createdBy` del documento** (reglas Firestore). No se borran gastos ya generados.
5. **Edición**: las reglas exigen mantener `createdBy`; cambiar categoría/monto de cuotas futuras implica actualizar la plantilla respetando las mismas restricciones. La UI móvil actual solo ofrece **alta** y **cancelar** del plan.

## Referencias de código

- Generación: `functions/src/scheduled/generateRecurringExpenses.ts`
- Reglas: `firestore.rules` → `recurringTemplates`
- Alta, listado y baja en app: `apps/mobile/lib/features/expenses/expenses_page.dart` (bottom sheet al FAB, tarjeta «Planes en cuotas»)
