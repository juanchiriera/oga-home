import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/expenses/expense_categories.dart';
import 'package:oga/features/expenses/expense_lifecycle.dart';
import 'package:oga/features/expenses/expense_list_models.dart';
import 'package:oga/features/expenses/expense_money.dart';
import 'package:flutter/material.dart';

/// One expense row for month lists (preview and full list).
class ExpenseMonthListTile extends StatelessWidget {
  const ExpenseMonthListTile({
    super.key,
    required this.entry,
    required this.baseCurrency,
    required this.pmById,
    required this.locale,
    this.trailing,
    this.onTap,
  });

  final ExpenseListEntry entry;
  final String baseCurrency;
  final Map<String, Map<String, dynamic>> pmById;
  final Locale locale;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final data = entry.data;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final currency = normalizeCurrency(
      data['currency'] as String?,
      fallback: baseCurrency,
    );
    final categoryKey = data['categoryKey'] as String? ?? 'other';
    final category = kExpenseCategories.firstWhere(
      (c) => c.key == categoryKey,
      orElse: () => kExpenseCategories.last,
    );
    final accent = expenseCategoryAccent(scheme, category.colorIndex);
    final merchant = data['merchant'] as String?;
    final note = data['note'] as String?;
    final occurredAt = entry.occurredAt ?? DateTime.now();
    final st = data['status'] as String?;
    final pending = st == ExpenseLifecycle.pendingCardCycle;
    final pmId = data['paymentMethodId'] as String?;
    String? pmShort;
    if (pmId != null && pmById.containsKey(pmId)) {
      final pm = pmById[pmId]!;
      final pn = pm['name'] as String? ?? '—';
      final pt = PaymentMethodTypes.label(
        pm['type'] as String? ?? PaymentMethodTypes.other,
      );
      pmShort = '$pn · $pt';
    } else if (pmId != null) {
      pmShort = 'Método desconocido';
    }

    final titleText = merchant != null && merchant.trim().isNotEmpty
        ? merchant.trim()
        : category.label;

    final iIdx = data['installmentIndex'] as int?;
    final iTot = data['installmentTotal'] as int?;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CozyCard(
          color: scheme.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: accent.withValues(alpha: 0.14),
                          child: Icon(category.icon, color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      titleText,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatMoney(amount, currency, locale),
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    label: Text(
                                      category.label,
                                      style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    side: BorderSide(
                                      color: accent.withValues(alpha: 0.45),
                                    ),
                                    backgroundColor: accent.withValues(
                                      alpha: 0.12,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  if (pending)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      label: Text(
                                        'Pendiente tarjeta',
                                        style: textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      side: BorderSide(
                                        color: scheme.tertiary.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      backgroundColor: scheme.tertiaryContainer
                                          .withValues(alpha: 0.35),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  if (iIdx != null && iTot != null)
                                    Text(
                                      'Cuota $iIdx/$iTot',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatExpenseListDate(occurredAt),
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (pmShort != null)
                                Text(
                                  pmShort,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              if (note != null && note.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    note.trim(),
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
