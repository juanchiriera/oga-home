import 'package:oga/features/expenses/expense_categories.dart';
import 'package:oga/features/expenses/expense_lifecycle.dart';
import 'package:oga/features/expenses/expense_list_models.dart';
import 'package:oga/features/expenses/expense_month_list_tile.dart';
import 'package:flutter/material.dart';

/// Full in-memory list for the selected month, with category filter.
class ExpensesFullMonthListPage extends StatefulWidget {
  const ExpensesFullMonthListPage({
    super.key,
    required this.monthLabel,
    required this.entries,
    required this.baseCurrency,
    required this.paymentMethodsById,
    required this.onEdit,
    required this.onDelete,
    required this.onConfirmCard,
  });

  final String monthLabel;
  final List<ExpenseListEntry> entries;
  final String baseCurrency;
  final Map<String, Map<String, dynamic>> paymentMethodsById;

  final Future<ExpenseListEntry?> Function(ExpenseListEntry entry) onEdit;
  final Future<bool> Function(ExpenseListEntry entry) onDelete;
  final Future<bool> Function(ExpenseListEntry entry) onConfirmCard;

  @override
  State<ExpensesFullMonthListPage> createState() =>
      _ExpensesFullMonthListPageState();
}

class _ExpensesFullMonthListPageState extends State<ExpensesFullMonthListPage> {
  String? _categoryFilter;
  late List<ExpenseListEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List<ExpenseListEntry>.from(widget.entries);
  }

  void _sortEntriesDesc() {
    _entries.sort((a, b) {
      final da = a.occurredAt;
      final db = b.occurredAt;
      if (da == null && db == null) {
        return a.id.compareTo(b.id);
      }
      if (da == null) {
        return 1;
      }
      if (db == null) {
        return -1;
      }
      final c = db.compareTo(da);
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });
  }

  void _applyUpsert(ExpenseListEntry updated) {
    _entries.removeWhere((e) => e.id == updated.id);
    _entries.add(updated);
    _sortEntriesDesc();
  }

  List<ExpenseListEntry> get _visibleEntries {
    if (_categoryFilter == null) {
      return _entries;
    }
    return _entries
        .where(
          (e) =>
              (e.data['categoryKey'] as String? ?? 'other') == _categoryFilter,
        )
        .toList(growable: false);
  }

  Set<String> get _categoryKeysInList =>
      _entries.map((e) => e.data['categoryKey'] as String? ?? 'other').toSet();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final visible = _visibleEntries;

    return Scaffold(
      appBar: AppBar(title: Text('Todos los gastos · ${widget.monthLabel}')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todas'),
                  selected: _categoryFilter == null,
                  onSelected: (_) => setState(() => _categoryFilter = null),
                ),
                ...kExpenseCategories
                    .where((c) => _categoryKeysInList.contains(c.key))
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(c.label),
                          selected: _categoryFilter == c.key,
                          onSelected: (selected) {
                            setState(() {
                              _categoryFilter = selected ? c.key : null;
                            });
                          },
                        ),
                      ),
                    ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      _categoryFilter == null
                          ? 'Sin movimientos'
                          : 'Sin gastos en esta categoría',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final e = visible[index];
                      final data = e.data;
                      final pending =
                          (data['status'] as String?) ==
                          ExpenseLifecycle.pendingCardCycle;
                      final pmId = data['paymentMethodId'] as String?;

                      return ExpenseMonthListTile(
                        key: ValueKey<String>(e.id),
                        entry: e,
                        baseCurrency: widget.baseCurrency,
                        pmById: widget.paymentMethodsById,
                        locale: locale,
                        onTap: () async {
                          final updated = await widget.onEdit(e);
                          if (!mounted || updated == null) {
                            return;
                          }
                          setState(() => _applyUpsert(updated));
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'edit') {
                              final updated = await widget.onEdit(e);
                              if (!mounted || updated == null) {
                                return;
                              }
                              setState(() => _applyUpsert(updated));
                            } else if (action == 'delete') {
                              final ok = await widget.onDelete(e);
                              if (!mounted || !ok) {
                                return;
                              }
                              setState(() {
                                _entries.removeWhere((x) => x.id == e.id);
                              });
                            } else if (action == 'confirm') {
                              final ok = await widget.onConfirmCard(e);
                              if (!mounted || !ok) {
                                return;
                              }
                              setState(() {
                                final i = _entries.indexWhere((x) => x.id == e.id);
                                if (i >= 0) {
                                  _entries[i] = _entries[i].copyWithData(
                                    <String, dynamic>{
                                      'status': ExpenseLifecycle.confirmed,
                                    },
                                  );
                                }
                              });
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            if (pending && pmId != null && pmId.isNotEmpty)
                              const PopupMenuItem(
                                value: 'confirm',
                                child: Text('Efectivizar (fecha de pago)'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
