import 'package:cloud_functions/cloud_functions.dart';
import 'package:craftr_mobile/services/functions_region.dart';
import 'package:flutter/material.dart';

/// Bottom sheet alineado a sheets del resto de la app (§8.1) — diff + confirmar/cancelar.
Future<bool> showAssistantToolConfirmSheet({
  required BuildContext context,
  required String tool,
  required List<String> diffLines,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmar acción',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El asistente propone una acción sensible. Revisá el detalle y '
                'confirmá solo si coincide con lo que querés.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.38,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      diffLines.join('\n'),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}

/// Aplica la herramienta pendiente tras confirmación (servidor o callables existentes).
Future<void> applyAssistantPendingTool({
  required String familyId,
  required String? threadId,
  required String tool,
  required Map<String, dynamic> args,
}) async {
  final fn = craftrFunctions();
  if (tool == 'register_card_cycle_close') {
    final pm = args['payment_method_id'] as String?;
    final closing = args['closing_date'] as String?;
    if (pm == null || pm.isEmpty || closing == null || closing.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Faltan datos de cierre de tarjeta',
      );
    }
    await fn.httpsCallable('registerCardCycleClose').call<Map<String, dynamic>>({
      'familyId': familyId,
      'paymentMethodId': pm,
      'closingDate': closing,
    });
    return;
  }
  if (tool == 'register_card_payment') {
    final pm = args['payment_method_id'] as String?;
    final eff = args['effective_date'] as String?;
    if (pm == null || pm.isEmpty || eff == null || eff.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Faltan datos de pago de tarjeta',
      );
    }
    final body = <String, dynamic>{
      'familyId': familyId,
      'paymentMethodId': pm,
      'effectiveDate': eff,
    };
    final ex = args['expense_ids'];
    if (ex is List && ex.isNotEmpty) {
      body['expenseIds'] = ex.map((e) => e.toString()).toList();
    }
    await fn.httpsCallable('registerCardPayment').call<Map<String, dynamic>>(body);
    return;
  }
  if (tool == 'start_receipt_import') {
    throw FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'Abrí Gastos y usá el import de ticket o escanear comprobante.',
    );
  }
  await fn.httpsCallable('assistantApplyPendingTool').call<Map<String, dynamic>>({
    'familyId': familyId,
    'conversationId': threadId ?? '',
    'tool': tool,
    'args': args,
  });
}
