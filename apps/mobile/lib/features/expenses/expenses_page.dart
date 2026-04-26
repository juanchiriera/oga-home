import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/features/assistant/assistant_entry_points.dart';
import 'package:craftr_mobile/features/expenses/expense_import_flow.dart';
import 'package:craftr_mobile/features/expenses/expense_lifecycle.dart';
import 'package:craftr_mobile/features/expenses/expense_money.dart';
import 'package:craftr_mobile/services/functions_region.dart';
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
            onPressed: () => launchExpenseImportFlow(context),
            icon: const Icon(Icons.document_scanner_outlined, size: 20),
            label: const Text('Escanear ticket'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
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
            return const Center(
              child: Text('Creá o elegí un hogar para registrar gastos.'),
            );
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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      familyId = userDoc.data()?['activeFamilyId'] as String?;
      if (familyId == null || familyId.isEmpty || !context.mounted) {
        return;
      }
    }

    final pmCol = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('paymentMethods');
    final familyDoc = await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .get();
    final baseCurrency = normalizeCurrency(
      familyDoc.data()?['baseCurrency'] as String?,
      fallback: 'ARS',
    );
    var methodsSnap = await pmCol.orderBy('name').get();
    while (methodsSnap.docs.isEmpty) {
      if (!context.mounted) {
        return;
      }
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Métodos de pago'),
          content: const Text(
            'Para registrar un gasto necesitás al menos un método (por ejemplo, Efectivo o tu tarjeta).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar método'),
            ),
          ],
        ),
      );
      if (add != true) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      await _upsertPaymentMethod(
        context: context,
        familyId: familyId,
        methodId: null,
      );
      if (!context.mounted) {
        return;
      }
      methodsSnap = await pmCol.orderBy('name').get();
    }

    if (!context.mounted) {
      return;
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
    var selectedCategory =
        (initialData?['categoryKey'] as String?) ??
        kExpenseCategories.first.key;
    var selectedDate =
        (initialData?['occurredAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    var selectedCurrency = normalizeCurrency(
      initialData?['currency'] as String?,
      fallback: baseCurrency,
    );

    final pmIds = methodsSnap.docs.map((d) => d.id).toSet();
    var selectedPaymentMethodId =
        (initialData?['paymentMethodId'] as String?) ?? '';
    if (selectedPaymentMethodId.isEmpty ||
        !pmIds.contains(selectedPaymentMethodId)) {
      selectedPaymentMethodId = _defaultPaymentMethodId(methodsSnap.docs)!;
    }
    var isSuggestingCategory = false;

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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Monto *'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('expense-currency-$selectedCurrency'),
                    initialValue: selectedCurrency,
                    decoration: InputDecoration(
                      labelText: 'Moneda *',
                      helperText: 'Moneda base familiar: $baseCurrency',
                    ),
                    items: kSupportedCurrencies
                        .map(
                          (currency) => DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => selectedCurrency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('expense-cat-$selectedCategory'),
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
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: isSuggestingCategory
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setLocal(() => isSuggestingCategory = true);
                              try {
                                final amount = double.tryParse(
                                  amountController.text.replaceAll(',', '.'),
                                );
                                final callable = craftrFunctions()
                                    .httpsCallable('suggestManualExpenseCategory');
                                final res =
                                    await callable.call<Map<String, dynamic>>(
                                  <String, dynamic>{
                                    'familyId': familyId,
                                    'merchant': merchantController.text.trim(),
                                    'note': noteController.text.trim(),
                                    if (amount != null && amount > 0)
                                      'amount': amount,
                                  },
                                );
                                final data = res.data;
                                if (!context.mounted) {
                                  return;
                                }
                                final ck = data['categoryKey'] as String?;
                                final suggestedName =
                                    data['suggestedNewCategoryName']
                                        as String?;
                                if (ck != null && ck.isNotEmpty) {
                                  setLocal(() => selectedCategory = ck);
                                  String? label;
                                  for (final c in kExpenseCategories) {
                                    if (c.key == ck) {
                                      label = c.label;
                                      break;
                                    }
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        label != null
                                            ? 'Categoría sugerida: $label'
                                            : 'Categoría sugerida',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (suggestedName != null &&
                                    suggestedName.trim().isNotEmpty) {
                                  final useOther = await showDialog<bool>(
                                    context: ctx,
                                    builder: (dCtx) => AlertDialog(
                                      title: const Text(
                                        'Categoría fuera del catálogo',
                                      ),
                                      content: Text(
                                        'La IA sugiere el nombre «$suggestedName» para este gasto. '
                                        'Las categorías personalizadas aún no están en la app. '
                                        '¿Querés usar «Otros» y agregar el texto a la nota, '
                                        'o elegir vos una categoría en el listado?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, false),
                                          child: const Text('Elegir en listado'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, true),
                                          child: const Text('Usar Otros + nota'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (useOther == true) {
                                    setLocal(() {
                                      selectedCategory = 'other';
                                      final n = noteController.text.trim();
                                      final add =
                                          'Sugerido: $suggestedName';
                                      noteController.text = n.isEmpty
                                          ? add
                                          : '$n — $add';
                                    });
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Categoría «Otros» con la sugerencia en la nota.',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No se pudo proponer una categoría. '
                                      'Añadí comercio o nota e intentá de nuevo, '
                                      'o elegí la categoría manualmente.',
                                    ),
                                  ),
                                );
                              } on FirebaseFunctionsException catch (e) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.message ??
                                            'Error al sugerir categoría',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setLocal(() {
                                    isSuggestingCategory = false;
                                  });
                                }
                              }
                            },
                      icon: isSuggestingCategory
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: Text(
                        isSuggestingCategory
                            ? 'Sugiriendo…'
                            : 'Sugerir categoría (IA)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'expense-pm-$selectedPaymentMethodId',
                    ),
                    initialValue: selectedPaymentMethodId,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago *',
                    ),
                    items: methodsSnap.docs.map((d) {
                      final m = d.data();
                      final t =
                          m['type'] as String? ?? PaymentMethodTypes.other;
                      final n = m['name'] as String? ?? '—';
                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Text('$n · ${PaymentMethodTypes.label(t)}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => selectedPaymentMethodId = value);
                      }
                    },
                  ),
                  Text(
                    'Con tarjeta de crédito el gasto queda pendiente de ciclo hasta que registres el cierre o pago.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Comercio (opcional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                    ),
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
    final methodDoc = methodsSnap.docs.firstWhere(
      (d) => d.id == selectedPaymentMethodId,
    );
    final mType =
        methodDoc.data()['type'] as String? ?? PaymentMethodTypes.other;
    var lifeStatus = ExpenseLifecycle.statusForPaymentMethodType(mType);
    if (expenseId != null &&
        selectedPaymentMethodId ==
            (initialData?['paymentMethodId'] as String?) &&
        (initialData?['status'] as String?) == ExpenseLifecycle.confirmed) {
      lifeStatus = ExpenseLifecycle.confirmed;
    }

    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      'amount': amount,
      'currency': selectedCurrency,
      'categoryKey': selectedCategory,
      'occurredAt': Timestamp.fromDate(
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
      ),
      'merchant': merchantController.text.trim(),
      'note': noteController.text.trim(),
      'updatedAt': now,
      'createdBy': uid,
      'paymentMethodId': selectedPaymentMethodId,
      'status': lifeStatus,
    };

    final collection = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('expenses');
    if (expenseId == null) {
      payload['createdAt'] = now;
      await collection.add(payload);
    } else {
      payload['fxRate'] = FieldValue.delete();
      payload['amountInBase'] = FieldValue.delete();
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

  String? _defaultPaymentMethodId(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return null;
    }
    for (final d in docs) {
      if ((d.data()['type'] as String?) == PaymentMethodTypes.cash) {
        return d.id;
      }
    }
    return docs.first.id;
  }

  Future<void> _upsertPaymentMethod({
    required BuildContext context,
    required String familyId,
    String? methodId,
    Map<String, dynamic>? initialData,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final nameController = TextEditingController(
      text: initialData?['name'] as String? ?? '',
    );
    final lastFourController = TextEditingController(
      text: initialData?['lastFour'] as String? ?? '',
    );
    var selectedType =
        (initialData?['type'] as String?) ?? PaymentMethodTypes.cash;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(
              methodId == null ? 'Nuevo método de pago' : 'Editar método',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      hintText: 'Ej. Visa hogar, Efectivo billetera',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('pm-type-$selectedType'),
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Tipo *'),
                    items: PaymentMethodTypes.values
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(PaymentMethodTypes.label(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setLocal(() => selectedType = value);
                      }
                    },
                  ),
                  if (selectedType == PaymentMethodTypes.creditCard) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastFourController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Últimos 4 dígitos (opcional)',
                        counterText: '',
                      ),
                    ),
                  ],
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

    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un nombre para el método.')),
      );
      return;
    }

    final lastFour = lastFourController.text.trim();
    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      'name': name,
      'type': selectedType,
      'updatedAt': now,
    };
    if (lastFour.isNotEmpty) {
      payload['lastFour'] = lastFour;
    }

    final col = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('paymentMethods');
    if (methodId == null) {
      payload['createdAt'] = now;
      payload['createdBy'] = uid;
      await col.add(payload);
    } else {
      if (lastFour.isEmpty) {
        payload['lastFour'] = FieldValue.delete();
      }
      await col.doc(methodId).update(payload);
    }
  }

  Future<void> _deletePaymentMethod(
    BuildContext context,
    String familyId,
    String methodId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar método'),
        content: const Text(
          'Los gastos que lo usaban seguirán mostrando el método por ID.',
        ),
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
        .collection('paymentMethods')
        .doc(methodId)
        .delete();
  }

  String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _effectivizeSingleCardExpense(
    BuildContext context,
    String familyId,
    String expenseId,
    String paymentMethodId,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha efectiva (impacto contable)',
    );
    if (picked == null || !context.mounted) {
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Efectivizar gasto'),
        content: Text(
          'Se marcará como confirmado con fecha efectiva ${_formatDate(picked)} '
          'según la regla de tarjeta del producto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) {
      return;
    }
    try {
      final callable = craftrFunctions().httpsCallable('registerCardPayment');
      final res = await callable.call<Map<String, dynamic>>({
        'familyId': familyId,
        'paymentMethodId': paymentMethodId,
        'effectiveDate': _isoDate(picked),
        'expenseIds': [expenseId],
      });
      final n = (res.data['affectedCount'] as num?)?.toInt() ?? 0;
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n > 0 ? 'Listo: $n gasto actualizado.' : 'No hubo cambios.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo efectivizar')),
      );
    }
  }

  Future<void> _registerCardCycleClose(
    BuildContext context,
    String familyId,
    String paymentMethodId,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha de cierre del resumen (incluye compras hasta ese día)',
    );
    if (picked == null || !context.mounted) {
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar cierre de resumen'),
        content: Text(
          'Los gastos pendientes de esta tarjeta con fecha de compra hasta '
          '${_formatDate(picked)} pasan a confirmados con esa fecha efectiva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) {
      return;
    }
    try {
      final callable = craftrFunctions().httpsCallable(
        'registerCardCycleClose',
      );
      final res = await callable.call<Map<String, dynamic>>({
        'familyId': familyId,
        'paymentMethodId': paymentMethodId,
        'closingDate': _isoDate(picked),
      });
      final n = (res.data['affectedCount'] as num?)?.toInt() ?? 0;
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cierre registrado: $n gastos efectivizados.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo registrar el cierre')),
      );
    }
  }

  Future<void> _registerCardPaymentAllPending(
    BuildContext context,
    String familyId,
    String paymentMethodId,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha en que considerás pagado el saldo pendiente',
    );
    if (picked == null || !context.mounted) {
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar pago de tarjeta'),
        content: Text(
          'Se efectivizarán todos los gastos pendientes de esta tarjeta '
          'con fecha efectiva ${_formatDate(picked)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) {
      return;
    }
    try {
      final callable = craftrFunctions().httpsCallable('registerCardPayment');
      final res = await callable.call<Map<String, dynamic>>({
        'familyId': familyId,
        'paymentMethodId': paymentMethodId,
        'effectiveDate': _isoDate(picked),
      });
      final n = (res.data['affectedCount'] as num?)?.toInt() ?? 0;
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pago registrado: $n gastos efectivizados.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo registrar el pago')),
      );
    }
  }
}

class _ExpensesContent extends StatelessWidget {
  const _ExpensesContent({required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context) {
    final familyRef = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId);
    final pmQuery = familyRef.collection('paymentMethods').orderBy('name');
    final expensesQuery = familyRef
        .collection('expenses')
        .orderBy('occurredAt', descending: true);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: familyRef.snapshots(),
      builder: (context, familySnap) {
        final baseCurrency = normalizeCurrency(
          familySnap.data?.data()?['baseCurrency'] as String?,
          fallback: 'ARS',
        );
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: pmQuery.snapshots(),
          builder: (context, pmSnap) {
            if (pmSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (pmSnap.hasError) {
              return _ErrorState(
                onRetry: () {},
                message: 'No se pudieron cargar los métodos de pago.',
              );
            }

            final pmDocs =
                pmSnap.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final pmById = <String, Map<String, dynamic>>{
              for (final d in pmDocs) d.id: d.data(),
            };

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

                final monthStart = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  1,
                );
                final monthlyEffectiveByCurrency = <String, double>{};
                final monthlyPendingByCurrency = <String, double>{};
                final byCategoryCurrency = <String, Map<String, double>>{};
                for (final doc in docs) {
                  final data = doc.data();
                  if ((data['status'] as String?) ==
                      ExpenseLifecycle.cancelled) {
                    continue;
                  }
                  final amount = expenseAmount(data);
                  final currency = expenseCurrency(
                    data,
                    fallback: baseCurrency,
                  );
                  final categoryKey = data['categoryKey'] as String? ?? 'other';
                  final occurredAt = (data['occurredAt'] as Timestamp?)
                      ?.toDate();
                  final categoryTotals = byCategoryCurrency.putIfAbsent(
                    categoryKey,
                    () => <String, double>{},
                  );
                  categoryTotals[currency] =
                      (categoryTotals[currency] ?? 0) + amount;
                  if (occurredAt != null && !occurredAt.isBefore(monthStart)) {
                    if (ExpenseLifecycle.countsTowardEffectiveMonthly(data)) {
                      monthlyEffectiveByCurrency[currency] =
                          (monthlyEffectiveByCurrency[currency] ?? 0) + amount;
                    } else if ((data['status'] as String?) ==
                        ExpenseLifecycle.pendingCardCycle) {
                      monthlyPendingByCurrency[currency] =
                          (monthlyPendingByCurrency[currency] ?? 0) + amount;
                    }
                  }
                }

                final scheme = Theme.of(context).colorScheme;
                final state = context
                    .findAncestorStateOfType<_ExpensesPageState>();

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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
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
                            'Gasto reconocido del mes',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: scheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (monthlyEffectiveByCurrency.isEmpty)
                            Text(
                              'Sin movimientos del mes',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            )
                          else
                            ...formatTotalsByCurrency(
                              monthlyEffectiveByCurrency,
                            ).map(
                              (line) => Text(
                                line,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          if (monthlyPendingByCurrency.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Pendiente en tarjeta (aún no en resumen):',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                            ...formatTotalsByCurrency(
                              monthlyPendingByCurrency,
                            ).map(
                              (line) => Text(
                                line,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Suma movimientos del mes que ya impactan como débito/efectivo.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (byCategoryCurrency.isEmpty)
                            Text(
                              'Sin datos aún.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            )
                          else
                            ...kExpenseCategories
                                .where(
                                  (c) => byCategoryCurrency.containsKey(c.key),
                                )
                                .map((c) {
                                  final accent = expenseCategoryAccent(
                                    scheme,
                                    c.colorIndex,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Icon(c.icon, color: accent, size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(c.label)),
                                        Text(
                                          formatTotalsByCurrency(
                                            byCategoryCurrency[c.key] ??
                                                const <String, double>{},
                                          ).join(' · '),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Métodos de pago',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: scheme.primary,
                                      ),
                                ),
                              ),
                              if (state != null)
                                TextButton.icon(
                                  onPressed: () => state._upsertPaymentMethod(
                                    context: context,
                                    familyId: familyId,
                                    methodId: null,
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text('Agregar'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (pmDocs.isEmpty)
                            Text(
                              'Todavía no cargaste métodos. Agregá uno para asignarlo a cada gasto.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            )
                          else
                            ...pmDocs.map((d) {
                              final m = d.data();
                              final t =
                                  m['type'] as String? ??
                                  PaymentMethodTypes.other;
                              final n = m['name'] as String? ?? '—';
                              final lastFour = m['lastFour'] as String?;
                              final isCard = t == PaymentMethodTypes.creditCard;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: isCard
                                      ? scheme.primaryContainer.withValues(
                                          alpha: 0.35,
                                        )
                                      : scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 4,
                                            ),
                                        leading: Icon(
                                          isCard
                                              ? Icons.credit_card_rounded
                                              : Icons.payments_outlined,
                                          color: scheme.primary,
                                        ),
                                        title: Text(
                                          n,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          [
                                            PaymentMethodTypes.label(t),
                                            if (isCard &&
                                                lastFour != null &&
                                                lastFour.isNotEmpty)
                                              '· ****$lastFour',
                                          ].join(' '),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        trailing: state == null
                                            ? null
                                            : PopupMenuButton<String>(
                                                onSelected: (action) async {
                                                  if (action == 'edit') {
                                                    await state
                                                        ._upsertPaymentMethod(
                                                          context: context,
                                                          familyId: familyId,
                                                          methodId: d.id,
                                                          initialData: m,
                                                        );
                                                  } else if (action ==
                                                      'delete') {
                                                    await state
                                                        ._deletePaymentMethod(
                                                          context,
                                                          familyId,
                                                          d.id,
                                                        );
                                                  }
                                                },
                                                itemBuilder: (context) =>
                                                    const [
                                                      PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text('Editar'),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text('Eliminar'),
                                                      ),
                                                    ],
                                              ),
                                      ),
                                      if (isCard && state != null)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            0,
                                            8,
                                            8,
                                          ),
                                          child: Wrap(
                                            spacing: 4,
                                            runSpacing: 0,
                                            children: [
                                              TextButton(
                                                onPressed: () => state
                                                    ._registerCardCycleClose(
                                                      context,
                                                      familyId,
                                                      d.id,
                                                    ),
                                                child: const Text(
                                                  'Cierre de resumen',
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => state
                                                    ._registerCardPaymentAllPending(
                                                      context,
                                                      familyId,
                                                      d.id,
                                                    ),
                                                child: const Text(
                                                  'Pago (todos los pendientes)',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
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
                    if (docs.isEmpty) ...[
                      Icon(
                        Icons.payments_outlined,
                        size: 40,
                        color: scheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aún no hay movimientos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Usá «Agregar gasto» para registrar el primero.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          navigateToAssistant(
                            context,
                            tab: 'gastos',
                            seedMessage:
                                'Todavía no registré gastos: ¿cómo empiezo a usar el módulo y qué me conviene anotar primero?',
                          );
                        },
                        icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                        label: const Text('Preguntar al asistente'),
                      ),
                    ] else
                      ...docs
                          .where(
                            (d) =>
                                (d.data()['status'] as String?) !=
                                ExpenseLifecycle.cancelled,
                          )
                          .take(20)
                          .map((doc) {
                            final data = doc.data();
                            final amount =
                                (data['amount'] as num?)?.toDouble() ?? 0;
                            final currency = normalizeCurrency(
                              data['currency'] as String?,
                              fallback: baseCurrency,
                            );
                            final categoryKey =
                                data['categoryKey'] as String? ?? 'other';
                            final category = kExpenseCategories.firstWhere(
                              (c) => c.key == categoryKey,
                              orElse: () => kExpenseCategories.last,
                            );
                            final accent = expenseCategoryAccent(
                              scheme,
                              category.colorIndex,
                            );
                            final merchant = data['merchant'] as String?;
                            final note = data['note'] as String?;
                            final occurredAt =
                                (data['occurredAt'] as Timestamp?)?.toDate();
                            final st = data['status'] as String?;
                            final pending =
                                st == ExpenseLifecycle.pendingCardCycle;
                            final pmId = data['paymentMethodId'] as String?;
                            String pmLine = '';
                            if (pmId != null && pmById.containsKey(pmId)) {
                              final pm = pmById[pmId]!;
                              final pn = pm['name'] as String? ?? '—';
                              final pt = PaymentMethodTypes.label(
                                pm['type'] as String? ??
                                    PaymentMethodTypes.other,
                              );
                              pmLine = '\n$pn ($pt)';
                            } else if (pmId != null) {
                              pmLine = '\nMétodo desconocido';
                            }

                            final sub = StringBuffer()
                              ..write(
                                '${category.label} • ${_formatDate(occurredAt ?? DateTime.now())}',
                              )
                              ..write(' • ${formatMoney(amount, currency)}')
                              ..write(pending ? ' • Pendiente tarjeta' : '')
                              ..write(pmLine);
                            if (note != null && note.trim().isNotEmpty) {
                              sub.write('\n${note.trim()}');
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CozyCard(
                                color: scheme.surfaceContainerLowest,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: accent.withValues(
                                      alpha: 0.14,
                                    ),
                                    child: Icon(category.icon, color: accent),
                                  ),
                                  title: Text(
                                    merchant != null &&
                                            merchant.trim().isNotEmpty
                                        ? merchant.trim()
                                        : category.label,
                                  ),
                                  subtitle: Text(sub.toString()),
                                  isThreeLine:
                                      sub.toString().split('\n').length >= 3,
                                  trailing: state == null
                                      ? null
                                      : PopupMenuButton<String>(
                                          onSelected: (action) async {
                                            if (action == 'edit') {
                                              await state._upsertExpense(
                                                context: context,
                                                familyId: familyId,
                                                expenseId: doc.id,
                                                initialData: data,
                                              );
                                            } else if (action == 'delete') {
                                              await state._deleteExpense(
                                                context,
                                                familyId,
                                                doc.id,
                                              );
                                            } else if (action == 'confirm') {
                                              final pm =
                                                  data['paymentMethodId']
                                                      as String?;
                                              if (pm != null && pm.isNotEmpty) {
                                                await state
                                                    ._effectivizeSingleCardExpense(
                                                      context,
                                                      familyId,
                                                      doc.id,
                                                      pm,
                                                    );
                                              }
                                            } else if (action == 'assistant') {
                                              final merchantStr =
                                                  (data['merchant'] as String? ??
                                                          '')
                                                      .trim();
                                              final cat = category.label;
                                              final amt = formatMoney(
                                                amount,
                                                currency,
                                              );
                                              final when = _formatDate(
                                                occurredAt ?? DateTime.now(),
                                              );
                                              navigateToAssistant(
                                                context,
                                                tab: 'gastos',
                                                seedMessage: merchantStr
                                                        .isNotEmpty
                                                    ? 'Quiero hablar de este gasto: $merchantStr, $cat, $amt, fecha $when.'
                                                    : 'Quiero hablar de este gasto: $cat, $amt, fecha $when.',
                                              );
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Editar'),
                                            ),
                                            if (pending)
                                              const PopupMenuItem(
                                                value: 'confirm',
                                                child: Text(
                                                  'Efectivizar (fecha de pago)',
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'assistant',
                                              child: Text(
                                                'Preguntar al asistente',
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                  onTap: () async {
                                    if (state != null) {
                                      await state._upsertExpense(
                                        context: context,
                                        familyId: familyId,
                                        expenseId: doc.id,
                                        initialData: data,
                                      );
                                    }
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            );
                          }),
                  ],
                );
              },
            );
          },
        );
      },
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
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 24,
          24,
          24,
        ),
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
