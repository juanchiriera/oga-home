import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.colorIndex,
  });

  final String key;
  final String label;
  final IconData icon;
  /// Index into [expenseCategoryAccent] for on-palette tints.
  final int colorIndex;
}

const kExpenseCategories = <ExpenseCategory>[
  ExpenseCategory(
    key: 'housing',
    label: 'Vivienda',
    icon: Icons.home_work_outlined,
    colorIndex: 0,
  ),
  ExpenseCategory(
    key: 'food',
    label: 'Comida',
    icon: Icons.restaurant_outlined,
    colorIndex: 1,
  ),
  ExpenseCategory(
    key: 'transport',
    label: 'Transporte',
    icon: Icons.directions_car_outlined,
    colorIndex: 2,
  ),
  ExpenseCategory(
    key: 'shopping',
    label: 'Compras',
    icon: Icons.shopping_bag_outlined,
    colorIndex: 3,
  ),
  ExpenseCategory(
    key: 'utilities',
    label: 'Servicios',
    icon: Icons.lightbulb_outline,
    colorIndex: 4,
  ),
  ExpenseCategory(
    key: 'health',
    label: 'Salud',
    icon: Icons.local_hospital_outlined,
    colorIndex: 5,
  ),
  ExpenseCategory(
    key: 'education',
    label: 'Educación',
    icon: Icons.school_outlined,
    colorIndex: 6,
  ),
  ExpenseCategory(
    key: 'leisure',
    label: 'Ocio',
    icon: Icons.sports_esports_outlined,
    colorIndex: 7,
  ),
  ExpenseCategory(
    key: 'other',
    label: 'Otros',
    icon: Icons.category_outlined,
    colorIndex: 8,
  ),
];

Color expenseCategoryAccent(ColorScheme scheme, int index) {
  final tones = <Color>[
    scheme.primary,
    scheme.secondary,
    scheme.tertiary,
    scheme.primaryContainer,
    scheme.secondaryContainer,
    scheme.tertiaryContainer,
    scheme.error,
    scheme.onSurfaceVariant,
    scheme.outline,
  ];
  return tones[index % tones.length];
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        actions: [
          TextButton.icon(
            onPressed: () => _showScanReceiptPlaceholder(context),
            icon: const Icon(Icons.document_scanner_outlined, size: 20),
            label: const Text('Escanear ticket'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnap.hasError) {
            return _ErrorState(
              onRetry: () => setState(() {}),
              message: 'No se pudo cargar el hogar activo.',
            );
          }
          final familyId = userSnap.data?.data()?['activeFamilyId'] as String?;
          if (familyId == null || familyId.isEmpty) {
            return const Center(child: Text('Creá o elegí un hogar para registrar gastos.'));
          }
          return _ExpensesContent(familyId: familyId);
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 72 + MediaQuery.paddingOf(context).bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _upsertExpense(context: context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar gasto'),
        ),
      ),
    );
  }

  Future<void> _upsertExpense({
    required BuildContext context,
    String? familyId,
    String? expenseId,
    Map<String, dynamic>? initialData,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    if (familyId == null || familyId.isEmpty) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      familyId = userDoc.data()?['activeFamilyId'] as String?;
      if (familyId == null || familyId.isEmpty || !context.mounted) {
        return;
      }
    }

    final amountController = TextEditingController(
      text: initialData?['amount']?.toString() ?? '',
    );
    final merchantController = TextEditingController(
      text: initialData?['merchant'] as String? ?? '',
    );
    final noteController = TextEditingController(
      text: initialData?['note'] as String? ?? '',
    );

    var selectedCategory = (initialData?['categoryKey'] as String?) ?? kExpenseCategories.first.key;
    var selectedDate = (initialData?['occurredAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(expenseId == null ? 'Nuevo gasto' : 'Editar gasto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto *'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoría *'),
                    items: kExpenseCategories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.key,
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha *'),
                    subtitle: Text(_formatDate(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setLocal(() => selectedDate = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: merchantController,
                    decoration: const InputDecoration(labelText: 'Comercio (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Nota (opcional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !context.mounted) {
      return;
    }

    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido mayor a 0.')),
      );
      return;
    }

    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      'amount': amount,
      'categoryKey': selectedCategory,
      'occurredAt': Timestamp.fromDate(DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      )),
      'merchant': merchantController.text.trim(),
      'note': noteController.text.trim(),
      'updatedAt': now,
      'createdBy': uid,
    };

    final collection = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('expenses');
    if (expenseId == null) {
      payload['createdAt'] = now;
      await collection.add(payload);
    } else {
      await collection.doc(expenseId).update(payload);
    }
  }

  Future<void> _deleteExpense(
    BuildContext context,
    String familyId,
    String expenseId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  void _showScanReceiptPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escanear ticket: próximamente.')),
    );
  }
}

class _ExpensesContent extends StatelessWidget {
  const _ExpensesContent({required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context) {
    final expensesQuery = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('expenses')
        .orderBy('occurredAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: expensesQuery.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _ErrorState(
            onRetry: () {},
            message: 'No se pudieron cargar los gastos.',
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState();
        }

        final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
        var monthlyTotal = 0.0;
        final byCategory = <String, double>{};
        for (final doc in docs) {
          final data = doc.data();
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          final categoryKey = data['categoryKey'] as String? ?? 'other';
          final occurredAt = (data['occurredAt'] as Timestamp?)?.toDate();
          byCategory[categoryKey] = (byCategory[categoryKey] ?? 0) + amount;
          if (occurredAt != null && !occurredAt.isBefore(monthStart)) {
            monthlyTotal += amount;
          }
        }

        final scheme = Theme.of(context).colorScheme;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
            24,
            sanctuaryScrollBottomPadding(context),
          ),
          children: [
            Text(
              'Gastos y finanzas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Seguí el ritmo del mes y registrá cada movimiento.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            CozyCard(
              color: scheme.surfaceContainerLow,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gasto mensual',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${monthlyTotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Movimientos del mes actual',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CozyCard(
              color: scheme.surfaceContainer,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por categoría',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...kExpenseCategories
                      .where((c) => (byCategory[c.key] ?? 0) > 0)
                      .map(
                        (c) {
                          final accent = expenseCategoryAccent(scheme, c.colorIndex);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(c.icon, color: accent, size: 22),
                                const SizedBox(width: 10),
                                Expanded(child: Text(c.label)),
                                Text(
                                  '\$${(byCategory[c.key] ?? 0).toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Movimientos recientes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...docs.take(20).map(
              (doc) {
                final data = doc.data();
                final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                final categoryKey = data['categoryKey'] as String? ?? 'other';
                final category = kExpenseCategories.firstWhere(
                  (c) => c.key == categoryKey,
                  orElse: () => kExpenseCategories.last,
                );
                final accent = expenseCategoryAccent(scheme, category.colorIndex);
                final merchant = data['merchant'] as String?;
                final note = data['note'] as String?;
                final occurredAt = (data['occurredAt'] as Timestamp?)?.toDate();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CozyCard(
                    color: scheme.surfaceContainerLowest,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                      backgroundColor: accent.withValues(alpha: 0.14),
                        child: Icon(category.icon, color: accent),
                      ),
                      title: Text(
                      merchant != null && merchant.trim().isNotEmpty
                          ? merchant.trim()
                          : category.label,
                      ),
                      subtitle: Text(
                      '${category.label} • ${_formatDate(occurredAt ?? DateTime.now())}'
                      ' • \$${amount.toStringAsFixed(2)}'
                        '${note != null && note.trim().isNotEmpty ? '\n${note.trim()}' : ''}',
                      ),
                      isThreeLine: note != null && note.trim().isNotEmpty,
                      trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        final state = context.findAncestorStateOfType<_ExpensesPageState>();
                        if (state == null) {
                          return;
                        }
                        if (action == 'edit') {
                          await state._upsertExpense(
                            context: context,
                            familyId: familyId,
                            expenseId: doc.id,
                            initialData: data,
                          );
                        } else if (action == 'delete') {
                          await state._deleteExpense(context, familyId, doc.id);
                        }
                      },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                      onTap: () async {
                      final state = context.findAncestorStateOfType<_ExpensesPageState>();
                      if (state != null) {
                        await state._upsertExpense(
                          context: context,
                          familyId: familyId,
                          expenseId: doc.id,
                          initialData: data,
                        );
                      }
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('Aún no hay movimientos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Usá “Agregar gasto” para registrar el primer movimiento.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString();
  return '$dd/$mm/$yyyy';
}
