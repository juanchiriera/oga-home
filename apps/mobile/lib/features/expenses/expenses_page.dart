import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/expenses/expense_categories.dart';
import 'package:oga/features/expenses/expense_import_flow.dart';
import 'package:oga/features/expenses/expense_lifecycle.dart';
import 'package:oga/features/expenses/expense_list_models.dart';
import 'package:oga/features/expenses/expense_month_list_tile.dart';
import 'package:oga/features/expenses/expense_month_window.dart';
import 'package:oga/features/expenses/expense_money.dart';
import 'package:oga/features/expenses/expenses_full_month_list_page.dart';
import 'package:oga/features/profile/account_preferences.dart';
import 'package:oga/services/functions_region.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Lets the current frame finish layout and semantics after a route or sheet
/// closes, before Firestore streams rebuild large scrollables. Avoids rare
/// `!semantics.parentDataDirty` crashes when a dialog returns and listeners
/// update the tree in the same frame (e.g. gasto puntual → Guardar).
Future<void> _deferUntilAfterRouteTransitionFrames() async {
  await WidgetsBinding.instance.endOfFrame;
}

List<String> accountExpenseCurrenciesFromUserData(
  Map<String, dynamic>? userData,
  Locale locale, {
  String? includeCurrency,
}) {
  final rawCurrencyCodes = userData?['currencyCodes'];
  final configuredCurrencies = rawCurrencyCodes is Iterable
      ? rawCurrencyCodes
      : defaultCurrenciesForLocale(locale);
  return normalizeAccountCurrencies([
    ...configuredCurrencies,
    ?includeCurrency,
  ], fallbackLocale: locale);
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, this.isActive = true});

  /// When false, the page is built but not the visible tab ([IndexedStack] in
  /// [MainShell]). Used to avoid refetching/listeners tied to "being on Gastos".
  final bool isActive;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  int _expensesReloadToken = 0;
  final GlobalKey<_ExpensesContentState> _expensesContentKey =
      GlobalKey<_ExpensesContentState>();

  void _requestExpensesReload() {
    setState(() => _expensesReloadToken++);
  }

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
      body: SanctuaryScrollUnderAppBarFade(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
            final familyId =
                userSnap.data?.data()?['activeFamilyId'] as String?;
            if (familyId == null || familyId.isEmpty) {
              return const Center(
                child: Text('Creá o elegí un hogar para registrar gastos.'),
              );
            }
            return _ExpensesContent(
              key: _expensesContentKey,
              familyId: familyId,
              isActive: widget.isActive,
              expensesReloadToken: _expensesReloadToken,
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 72 + MediaQuery.paddingOf(context).bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _pickExpenseCreationFlow(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar gasto'),
        ),
      ),
    );
  }

  Future<void> _pickExpenseCreationFlow(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Gasto puntual'),
              onTap: () => Navigator.pop(ctx, 'single'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month_outlined),
              title: const Text('Plan en cuotas'),
              subtitle: const Text(
                'Se genera un gasto por mes hasta completar las cuotas',
              ),
              onTap: () => Navigator.pop(ctx, 'installment'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (choice == 'installment') {
      await _deferUntilAfterRouteTransitionFrames();
      if (!context.mounted) {
        return;
      }
      await _createInstallmentPlan(context: context);
    } else if (choice == 'single') {
      await _deferUntilAfterRouteTransitionFrames();
      if (!context.mounted) {
        return;
      }
      final created = await _upsertExpense(context: context);
      if (created != null && context.mounted) {
        _expensesContentKey.currentState?.applyUpsertEntry(created);
      }
    }
  }

  Future<void> _createInstallmentPlan({required BuildContext context}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    var familyId = '';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    familyId = userDoc.data()?['activeFamilyId'] as String? ?? '';
    if (familyId.isEmpty || !context.mounted) {
      return;
    }
    final lastUsedPaymentMethodId =
        userDoc.data()?['lastUsedPaymentMethodId'] as String?;
    final userData = userDoc.data();

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
    var methodDocs = _orderedPaymentMethodDocs(await pmCol.get());
    while (methodDocs.isEmpty) {
      if (!context.mounted) {
        return;
      }
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Métodos de pago'),
          content: const Text(
            'Para un plan en cuotas necesitás al menos un método de pago.',
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
      methodDocs = _orderedPaymentMethodDocs(await pmCol.get());
    }

    if (!context.mounted) {
      return;
    }

    final installmentsController = TextEditingController(text: '12');
    final amountController = TextEditingController();
    final merchantController = TextEditingController();
    final noteController = TextEditingController();
    var useTotalAmount = false;
    var selectedCategory = kExpenseCategories.first.key;
    var generationDay = 'month_start';
    var firstMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final availableCurrencies = accountExpenseCurrenciesFromUserData(
      userData,
      Localizations.localeOf(context),
    );
    var selectedCurrency = availableCurrencies.first;
    final pmIds = methodDocs.map((d) => d.id).toSet();
    var selectedPaymentMethodId = _defaultPaymentMethodId(
      methodDocs,
      preferredId: lastUsedPaymentMethodId,
    )!;

    double round2(double x) => (x * 100).round() / 100;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Plan en cuotas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'El sistema cargará un gasto por mes en la fecha de cargo '
                    '(inicio o fin de mes). Los totales del mes usan esa fecha.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: installmentsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad de cuotas *',
                      hintText: 'Ej. 12',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Monto por cuota'),
                      ),
                      ButtonSegment(value: true, label: Text('Monto total')),
                    ],
                    selected: {useTotalAmount},
                    onSelectionChanged: (Set<bool> s) {
                      if (s.isEmpty) {
                        return;
                      }
                      setLocal(() => useTotalAmount = s.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: useTotalAmount
                          ? 'Monto total *'
                          : 'Monto por cuota *',
                      helperText: 'Moneda del hogar: $baseCurrency',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('inst-currency-$selectedCurrency'),
                    initialValue: selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Moneda *'),
                    items: availableCurrencies
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
                  if (useTotalAmount)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'El monto por cuota se reparte en partes iguales '
                        'redondeando a 2 decimales; puede haber diferencia de '
                        'centavos con el total.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('inst-cat-$selectedCategory'),
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
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => selectedCategory = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('inst-pm-$selectedPaymentMethodId'),
                    initialValue: selectedPaymentMethodId,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago *',
                    ),
                    items: methodDocs.map((d) {
                      final m = d.data();
                      final t =
                          m['type'] as String? ?? PaymentMethodTypes.other;
                      final n = m['name'] as String? ?? '—';
                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Text('$n · ${PaymentMethodTypes.label(t)}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null && pmIds.contains(v)) {
                        setLocal(() => selectedPaymentMethodId = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('inst-gen-$generationDay'),
                    initialValue: generationDay,
                    decoration: const InputDecoration(
                      labelText: 'Día de cargo cada mes *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'month_start',
                        child: Text('Primer día hábil del mes (día 1)'),
                      ),
                      DropdownMenuItem(
                        value: 'month_end',
                        child: Text('Último día del mes'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => generationDay = v);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Primer mes con cuota *'),
                    subtitle: Text(_formatDate(firstMonth)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: firstMonth,
                        firstDate: DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          1,
                        ),
                        lastDate: DateTime(2100),
                        helpText: 'Mes del primer cargo programado',
                      );
                      if (picked != null) {
                        setLocal(
                          () => firstMonth = DateTime(
                            picked.year,
                            picked.month,
                            1,
                          ),
                        );
                      }
                    },
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
                child: const Text('Crear plan'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !context.mounted) {
      return;
    }
    await _deferUntilAfterRouteTransitionFrames();
    if (!context.mounted) {
      return;
    }

    final nRaw = int.tryParse(installmentsController.text.trim());
    if (nRaw == null || nRaw < 2 || nRaw > 240) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indicá entre 2 y 240 cuotas.')),
      );
      return;
    }
    final n = nRaw;

    final rawAmount = parseMoneyInput(
      amountController.text,
      Localizations.localeOf(context),
    );
    if (rawAmount == null || rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un monto válido mayor a 0.')),
      );
      return;
    }

    final perCuota = useTotalAmount ? round2(rawAmount / n) : round2(rawAmount);
    if (perCuota <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto por cuota no es válido.')),
      );
      return;
    }

    final startPeriodKey =
        '${firstMonth.year.toString().padLeft(4, '0')}-'
        '${firstMonth.month.toString().padLeft(2, '0')}';

    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      'active': true,
      'amount': perCuota,
      'currency': selectedCurrency,
      'categoryKey': selectedCategory,
      'type': 'installment',
      'generationDay': generationDay,
      'totalInstallments': n,
      'currentInstallment': 1,
      'startPeriodKey': startPeriodKey,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': uid,
      'paymentMethodId': selectedPaymentMethodId,
    };
    final mer = merchantController.text.trim();
    if (mer.isNotEmpty) {
      payload['merchant'] = mer;
    }
    final nt = noteController.text.trim();
    if (nt.isNotEmpty) {
      payload['note'] = nt;
    }

    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('recurringTemplates')
        .add(payload);
    await _rememberLastUsedPaymentMethod(uid, selectedPaymentMethodId);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Plan creado. Los gastos se generan automáticamente en cada mes.',
        ),
      ),
    );
  }

  Future<ExpenseListEntry?> _upsertExpense({
    required BuildContext context,
    String? familyId,
    String? expenseId,
    Map<String, dynamic>? initialData,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return null;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data();
    if (familyId == null || familyId.isEmpty) {
      familyId = userData?['activeFamilyId'] as String?;
      if (familyId == null || familyId.isEmpty || !context.mounted) {
        return null;
      }
    }
    final lastUsedPaymentMethodId =
        userData?['lastUsedPaymentMethodId'] as String?;

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
    var methodDocs = _orderedPaymentMethodDocs(await pmCol.get());
    while (methodDocs.isEmpty) {
      if (!context.mounted) {
        return null;
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
        return null;
      }
      if (!context.mounted) {
        return null;
      }
      await _upsertPaymentMethod(
        context: context,
        familyId: familyId,
        methodId: null,
      );
      if (!context.mounted) {
        return null;
      }
      methodDocs = _orderedPaymentMethodDocs(await pmCol.get());
    }

    if (!context.mounted) {
      return null;
    }

    final amountController = TextEditingController(
      text: () {
        final initialAmt = (initialData?['amount'] as num?)?.toDouble();
        if (initialAmt == null || initialAmt <= 0) {
          return '';
        }
        return formatLocalizedAmount(
          initialAmt,
          Localizations.localeOf(context),
        );
      }(),
    );
    final merchantController = TextEditingController(
      text: initialData?['merchant'] as String? ?? '',
    );
    final noteController = TextEditingController(
      text: initialData?['note'] as String? ?? '',
    );
    final amountFocusNode = FocusNode();
    final merchantFocusNode = FocusNode();
    final noteFocusNode = FocusNode();
    var selectedCategory =
        (initialData?['categoryKey'] as String?) ??
        kExpenseCategories.first.key;
    var selectedDate =
        (initialData?['occurredAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final initialCurrency = initialData?['currency'] as String?;
    final availableCurrencies = accountExpenseCurrenciesFromUserData(
      userData,
      Localizations.localeOf(context),
      includeCurrency: initialCurrency,
    );
    var selectedCurrency = normalizeCurrency(
      initialCurrency,
      fallback: availableCurrencies.first,
    );

    final pmIds = methodDocs.map((d) => d.id).toSet();
    var selectedPaymentMethodId =
        (initialData?['paymentMethodId'] as String?) ?? '';
    if (selectedPaymentMethodId.isEmpty ||
        !pmIds.contains(selectedPaymentMethodId)) {
      selectedPaymentMethodId = _defaultPaymentMethodId(
        methodDocs,
        preferredId: lastUsedPaymentMethodId,
      )!;
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
                  ExpenseAmountCurrencyRow(
                    // AlertDialog measures content with IntrinsicWidth; do not use
                    // LayoutBuilder inside the row. Approximate dialog content width.
                    availableWidth: (MediaQuery.sizeOf(ctx).width - 80).clamp(
                      0.0,
                      560.0,
                    ),
                    amountController: amountController,
                    amountFocusNode: amountFocusNode,
                    amountTextInputAction: TextInputAction.next,
                    onAmountSubmitted: (_) =>
                        FocusScope.of(ctx).requestFocus(merchantFocusNode),
                    selectedCurrency: selectedCurrency,
                    baseCurrency: baseCurrency,
                    availableCurrencies: availableCurrencies,
                    onCurrencyChanged: (value) {
                      setLocal(() => selectedCurrency = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: merchantController,
                    focusNode: merchantFocusNode,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(ctx).requestFocus(noteFocusNode),
                    onTapOutside: (_) => FocusScope.of(ctx).unfocus(),
                    decoration: const InputDecoration(
                      labelText: 'Comercio (opcional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    focusNode: noteFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
                    onTapOutside: (_) => FocusScope.of(ctx).unfocus(),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                    ),
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
                                final amount = parseMoneyInput(
                                  amountController.text,
                                  Localizations.localeOf(context),
                                );
                                final callable = craftrFunctions()
                                    .httpsCallable(
                                      'suggestManualExpenseCategory',
                                    );
                                final res = await callable
                                    .call<Map<String, dynamic>>(
                                      <String, dynamic>{
                                        'familyId': familyId,
                                        'merchant': merchantController.text
                                            .trim(),
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
                                    data['suggestedNewCategoryName'] as String?;
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
                                          child: const Text(
                                            'Elegir en listado',
                                          ),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, true),
                                          child: const Text(
                                            'Usar Otros + nota',
                                          ),
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
                                      final add = 'Sugerido: $suggestedName';
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                    items: methodDocs.map((d) {
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
    amountFocusNode.dispose();
    merchantFocusNode.dispose();
    noteFocusNode.dispose();

    if (ok != true || !context.mounted) {
      return null;
    }
    await _deferUntilAfterRouteTransitionFrames();
    if (!context.mounted) {
      return null;
    }

    final amount = parseMoneyInput(
      amountController.text,
      Localizations.localeOf(context),
    );
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido mayor a 0.')),
      );
      return null;
    }
    final methodDoc = methodDocs.firstWhere(
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

    final fsNow = FieldValue.serverTimestamp();
    final occurredTs = Timestamp.fromDate(
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    );
    final payload = <String, dynamic>{
      'amount': amount,
      'currency': selectedCurrency,
      'categoryKey': selectedCategory,
      'occurredAt': occurredTs,
      'merchant': merchantController.text.trim(),
      'note': noteController.text.trim(),
      'updatedAt': fsNow,
      'createdBy': uid,
      'paymentMethodId': selectedPaymentMethodId,
      'status': lifeStatus,
    };

    final collection = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('expenses');
    final listNow = Timestamp.now();
    if (expenseId == null) {
      payload['createdAt'] = fsNow;
      final ref = await collection.add(payload);
      await _rememberLastUsedPaymentMethod(uid, selectedPaymentMethodId);
      return ExpenseListEntry(
        id: ref.id,
        data: <String, dynamic>{
          'amount': amount,
          'currency': selectedCurrency,
          'categoryKey': selectedCategory,
          'occurredAt': occurredTs,
          'merchant': merchantController.text.trim(),
          'note': noteController.text.trim(),
          'updatedAt': listNow,
          'createdAt': listNow,
          'createdBy': uid,
          'paymentMethodId': selectedPaymentMethodId,
          'status': lifeStatus,
        },
      );
    }
    payload['fxRate'] = FieldValue.delete();
    payload['amountInBase'] = FieldValue.delete();
    await collection.doc(expenseId).update(payload);
    await _rememberLastUsedPaymentMethod(uid, selectedPaymentMethodId);
    final merged = Map<String, dynamic>.from(initialData ?? {});
    merged
      ..['amount'] = amount
      ..['currency'] = selectedCurrency
      ..['categoryKey'] = selectedCategory
      ..['occurredAt'] = occurredTs
      ..['merchant'] = merchantController.text.trim()
      ..['note'] = noteController.text.trim()
      ..['updatedAt'] = listNow
      ..['paymentMethodId'] = selectedPaymentMethodId
      ..['status'] = lifeStatus
      ..remove('fxRate')
      ..remove('amountInBase');
    return ExpenseListEntry(id: expenseId, data: merged);
  }

  Future<bool> _deleteExpense(
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
      return false;
    }
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
    return true;
  }

  /// Devuelve el id del método de pago a usar por defecto.
  ///
  /// Trello #98: priorizamos el último método usado por el usuario si sigue
  /// disponible. Si no, mantenemos el comportamiento previo: preferimos el
  /// primer "efectivo" y, en último caso, el primero de la lista ordenada.
  String? _defaultPaymentMethodId(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    String? preferredId,
  }) {
    if (docs.isEmpty) {
      return null;
    }
    if (preferredId != null && preferredId.isNotEmpty) {
      for (final d in docs) {
        if (d.id == preferredId) {
          return d.id;
        }
      }
    }
    for (final d in docs) {
      if ((d.data()['type'] as String?) == PaymentMethodTypes.cash) {
        return d.id;
      }
    }
    return docs.first.id;
  }

  /// Aplica el orden de presentación de Trello #98: efectivo/débito/banco
  /// arriba, tarjetas de crédito al final, desempate alfabético por nombre.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _orderedPaymentMethodDocs(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return sortPaymentMethods<QueryDocumentSnapshot<Map<String, dynamic>>>(
      snap.docs,
      typeOf: (d) => d.data()['type'] as String? ?? PaymentMethodTypes.other,
      nameOf: (d) => d.data()['name'] as String? ?? '',
    );
  }

  /// Persiste el último método de pago usado en `users/{uid}` para que la
  /// próxima carga lo proponga por defecto (Trello #98).
  Future<void> _rememberLastUsedPaymentMethod(
    String uid,
    String paymentMethodId,
  ) async {
    if (paymentMethodId.isEmpty) {
      return;
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      <String, dynamic>{'lastUsedPaymentMethodId': paymentMethodId},
      SetOptions(merge: true),
    );
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
    await _deferUntilAfterRouteTransitionFrames();
    if (!context.mounted) {
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

  Future<bool> _effectivizeSingleCardExpense(
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
      return false;
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
      return false;
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
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n > 0 ? 'Listo: $n gasto actualizado.' : 'No hubo cambios.',
          ),
        ),
      );
      if (n > 0) {
        return true;
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo efectivizar')),
      );
      return false;
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
      if (n > 0) {
        _requestExpensesReload();
      }
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
      if (n > 0) {
        _requestExpensesReload();
      }
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

class _ExpensesContent extends StatefulWidget {
  const _ExpensesContent({
    super.key,
    required this.familyId,
    required this.isActive,
    required this.expensesReloadToken,
  });

  final String familyId;
  final bool isActive;
  final int expensesReloadToken;

  @override
  State<_ExpensesContent> createState() => _ExpensesContentState();
}

class _ExpensesContentState extends State<_ExpensesContent> {
  late DateTime _now;
  DateTime? _selectedMonthStart;
  Timer? _ticker;

  List<ExpenseListEntry> _expenseEntries = const [];
  bool _expensesLoading = false;
  Object? _expensesError;
  int _expenseLoadGen = 0;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      final next = DateTime.now();
      if (_selectedMonthStart == null &&
          (_now.year != next.year || _now.month != next.month)) {
        setState(() => _now = next);
      } else {
        _now = next;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isActive) {
        unawaited(_loadExpensesIfActive());
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ExpensesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.familyId != oldWidget.familyId) {
      _expenseLoadGen++;
      _expenseEntries = const [];
    }
    if (widget.isActive &&
        (!oldWidget.isActive ||
            widget.expensesReloadToken != oldWidget.expensesReloadToken ||
            widget.familyId != oldWidget.familyId)) {
      unawaited(_loadExpensesIfActive());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadExpensesIfActive() async {
    if (!widget.isActive || !mounted) {
      return;
    }
    final gen = ++_expenseLoadGen;
    final familyId = widget.familyId;
    final viewed = _viewedMonthStart;
    final monthWindow = expenseMonthWindowForMonth(viewed.year, viewed.month);
    final q = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('expenses')
        .where(
          'occurredAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            monthWindow.startInclusive,
          ),
        )
        .where(
          'occurredAt',
          isLessThan: Timestamp.fromDate(monthWindow.endExclusive),
        )
        .orderBy('occurredAt', descending: true);

    final showBlockingSpinner = _expenseEntries.isEmpty;
    if (showBlockingSpinner) {
      setState(() {
        _expensesLoading = true;
        _expensesError = null;
      });
    }
    try {
      final snap = await q.get();
      if (!mounted || gen != _expenseLoadGen) {
        return;
      }
      setState(() {
        _expenseEntries = snap.docs.map(ExpenseListEntry.fromQueryDoc).toList();
        _expensesLoading = false;
        _expensesError = null;
      });
    } catch (e) {
      if (!mounted || gen != _expenseLoadGen) {
        return;
      }
      setState(() {
        _expensesLoading = false;
        _expensesError = e;
      });
    }
  }

  /// Removes one row locally after a successful delete (no full refetch).
  void applyExpenseDeleted(String id) {
    if (!mounted) {
      return;
    }
    setState(() {
      _expenseEntries = [
        for (final e in _expenseEntries)
          if (e.id != id) e,
      ];
    });
  }

  /// Inserts or replaces one row and keeps [occurredAt] descending order.
  void applyUpsertEntry(ExpenseListEntry entry) {
    if (!mounted) {
      return;
    }
    final monthWindow = expenseMonthWindowForMonth(
      _viewedMonthStart.year,
      _viewedMonthStart.month,
    );
    final od = entry.occurredAt;
    final inMonth = od != null && monthWindow.contains(od);
    setState(() {
      final without = <ExpenseListEntry>[
        for (final e in _expenseEntries)
          if (e.id != entry.id) e,
      ];
      if (!inMonth) {
        _expenseEntries = without;
        return;
      }
      without.add(entry);
      without.sort((a, b) {
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
      _expenseEntries = without;
    });
  }

  DateTime get _currentMonthStart => DateTime(_now.year, _now.month, 1);

  DateTime get _viewedMonthStart => _selectedMonthStart ?? _currentMonthStart;

  bool get _isViewingCurrentMonth =>
      _viewedMonthStart.year == _currentMonthStart.year &&
      _viewedMonthStart.month == _currentMonthStart.month;

  void _shiftViewedMonth(int delta) {
    setState(() {
      final base = _viewedMonthStart;
      final moved = DateTime(base.year, base.month + delta, 1);
      _selectedMonthStart = _sameMonth(moved, _currentMonthStart)
          ? null
          : moved;
    });
    if (widget.isActive) {
      unawaited(_loadExpensesIfActive());
    }
  }

  Future<void> _pickViewedMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewedMonthStart,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Elegí el mes a consultar',
    );
    if (picked == null || !mounted) {
      return;
    }
    final normalized = DateTime(picked.year, picked.month, 1);
    setState(() {
      _selectedMonthStart = _sameMonth(normalized, _currentMonthStart)
          ? null
          : normalized;
    });
    if (widget.isActive) {
      unawaited(_loadExpensesIfActive());
    }
  }

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  String _monthLabel(DateTime monthStart) {
    const names = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${names[monthStart.month - 1]} ${monthStart.year}';
  }

  @override
  Widget build(BuildContext context) {
    final familyId = widget.familyId;
    final viewedMonthStart = _viewedMonthStart;
    final monthWindow = expenseMonthWindowForMonth(
      viewedMonthStart.year,
      viewedMonthStart.month,
    );
    final familyRef = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId);
    final pmQuery = familyRef.collection('paymentMethods');

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
                sortPaymentMethods<QueryDocumentSnapshot<Map<String, dynamic>>>(
                  pmSnap.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                  typeOf: (d) =>
                      d.data()['type'] as String? ?? PaymentMethodTypes.other,
                  nameOf: (d) => d.data()['name'] as String? ?? '',
                );
            final pmById = <String, Map<String, dynamic>>{
              for (final d in pmDocs) d.id: d.data(),
            };

            if (_expensesLoading && _expenseEntries.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_expensesError != null && _expenseEntries.isEmpty) {
              return _ErrorState(
                onRetry: () => unawaited(_loadExpensesIfActive()),
                message: 'No se pudieron cargar los gastos.',
              );
            }

            final monthlyEntries = _expenseEntries.where((e) {
              final occurredAt = e.occurredAt;
              return monthWindow.contains(occurredAt);
            }).toList();

            final visibleExpenseDocs = monthlyEntries
                .where(
                  (e) =>
                      (e.data['status'] as String?) !=
                      ExpenseLifecycle.cancelled,
                )
                .toList(growable: false);

            final monthlyEffectiveByCurrency = <String, double>{};
            final monthlyPendingByCurrency = <String, double>{};
            final byCategoryCurrency = <String, Map<String, double>>{};
            for (final e in monthlyEntries) {
              final data = e.data;
              if ((data['status'] as String?) == ExpenseLifecycle.cancelled) {
                continue;
              }
              final amount = expenseAmount(data);
              final currency = expenseCurrency(data, fallback: baseCurrency);
              final categoryKey = data['categoryKey'] as String? ?? 'other';
              final categoryTotals = byCategoryCurrency.putIfAbsent(
                categoryKey,
                () => <String, double>{},
              );
              categoryTotals[currency] =
                  (categoryTotals[currency] ?? 0) + amount;
              if (ExpenseLifecycle.countsTowardEffectiveMonthly(data)) {
                monthlyEffectiveByCurrency[currency] =
                    (monthlyEffectiveByCurrency[currency] ?? 0) + amount;
              } else if ((data['status'] as String?) ==
                  ExpenseLifecycle.pendingCardCycle) {
                monthlyPendingByCurrency[currency] =
                    (monthlyPendingByCurrency[currency] ?? 0) + amount;
              }
            }

            final scheme = Theme.of(context).colorScheme;
            final state = context.findAncestorStateOfType<_ExpensesPageState>();

            return RefreshIndicator(
              onRefresh: () async {
                await _loadExpensesIfActive();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.paddingOf(context).top +
                      kSanctuaryAppBarToolbarHeight +
                      8,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        onPressed: () => _shiftViewedMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickViewedMonth(context),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(_monthLabel(viewedMonthStart)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        onPressed: _isViewingCurrentMonth
                            ? null
                            : () => _shiftViewedMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  if (!_isViewingCurrentMonth)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton(
                        onPressed: () {
                          setState(() => _selectedMonthStart = null);
                          if (widget.isActive) {
                            unawaited(_loadExpensesIfActive());
                          }
                        },
                        child: const Text('Volver al mes actual'),
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
                          'Gasto reconocido de ${_monthLabel(viewedMonthStart)}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: scheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (monthlyEffectiveByCurrency.isEmpty)
                          Text(
                            'Sin movimientos en ${_monthLabel(viewedMonthStart)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          )
                        else
                          ...formatTotalsByCurrency(
                            monthlyEffectiveByCurrency,
                            Localizations.localeOf(context),
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
                            Localizations.localeOf(context),
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
                          'Suma movimientos del mes elegido que ya impactan como débito/efectivo.',
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
                                          Localizations.localeOf(context),
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
                                                } else if (action == 'delete') {
                                                  await state
                                                      ._deletePaymentMethod(
                                                        context,
                                                        familyId,
                                                        d.id,
                                                      );
                                                }
                                              },
                                              itemBuilder: (context) => const [
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
                                              onPressed: () =>
                                                  state._registerCardCycleClose(
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
                  const SizedBox(height: 14),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: familyRef
                        .collection('recurringTemplates')
                        .where('type', isEqualTo: 'installment')
                        .limit(24)
                        .snapshots(),
                    builder: (context, tplSnap) {
                      if (tplSnap.hasError) {
                        return const SizedBox.shrink();
                      }
                      final tplDocs = tplSnap.data?.docs ?? [];
                      if (tplDocs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      return CozyCard(
                        color: scheme.surfaceContainer,
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Planes en cuotas',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            ...tplDocs.map((doc) {
                              final t = doc.data();
                              final active = t['active'] as bool? ?? false;
                              final amount =
                                  (t['amount'] as num?)?.toDouble() ?? 0;
                              final total = t['totalInstallments'] as int?;
                              final cur = t['currentInstallment'] as int?;
                              final gen = t['generationDay'] as String? ?? '';
                              final merchant = t['merchant'] as String?;
                              final note = t['note'] as String?;
                              final createdBy = t['createdBy'] as String? ?? '';
                              final title =
                                  (merchant != null &&
                                      merchant.trim().isNotEmpty)
                                  ? merchant.trim()
                                  : (note != null && note.trim().isNotEmpty
                                        ? note.trim()
                                        : 'Plan en cuotas');
                              final cargo = gen == 'month_end'
                                  ? 'Fin de mes'
                                  : 'Día 1';
                              final progress = (total != null && cur != null)
                                  ? 'Cuota $cur de $total'
                                  : '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(14),
                                  child: ListTile(
                                    title: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (progress.isNotEmpty) progress,
                                        '${formatMoney(amount, baseCurrency, Localizations.localeOf(context))} · $cargo',
                                        if (!active) 'Inactivo',
                                      ].join('\n'),
                                    ),
                                    trailing:
                                        active &&
                                            uid != null &&
                                            uid == createdBy
                                        ? TextButton(
                                            onPressed: () async {
                                              final go = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                    'Cancelar plan',
                                                  ),
                                                  content: const Text(
                                                    'No se borran los gastos ya generados; '
                                                    'solo se detienen las cuotas futuras.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Volver',
                                                      ),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Detener plan',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (go != true ||
                                                  !context.mounted) {
                                                return;
                                              }
                                              try {
                                                await doc.reference.update({
                                                  'active': false,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                });
                                                if (!context.mounted) {
                                                  return;
                                                }
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Plan detenido.',
                                                    ),
                                                  ),
                                                );
                                              } catch (_) {
                                                if (!context.mounted) {
                                                  return;
                                                }
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'No se pudo actualizar '
                                                      '(¿fuiste quien creó el plan?).',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text('Detener'),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Movimientos de ${_monthLabel(viewedMonthStart)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (visibleExpenseDocs.isEmpty) ...[
                    Icon(
                      Icons.payments_outlined,
                      size: 40,
                      color: scheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aún no hay gastos en ${_monthLabel(viewedMonthStart)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Usá «Agregar gasto» para registrar el primero del período.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    if (_expensesLoading && monthlyEntries.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ...visibleExpenseDocs.take(10).map((row) {
                      final data = row.data;
                      final pending =
                          (data['status'] as String?) ==
                          ExpenseLifecycle.pendingCardCycle;
                      final locale = Localizations.localeOf(context);
                      final pmForTile = <String, Map<String, dynamic>>{
                        for (final e in pmById.entries)
                          e.key: Map<String, dynamic>.from(e.value),
                      };
                      return ExpenseMonthListTile(
                        key: ValueKey<String>(row.id),
                        entry: row,
                        baseCurrency: baseCurrency,
                        pmById: pmForTile,
                        locale: locale,
                        onTap: state == null
                            ? null
                            : () async {
                                final updated = await state._upsertExpense(
                                  context: context,
                                  familyId: familyId,
                                  expenseId: row.id,
                                  initialData: data,
                                );
                                if (!context.mounted || updated == null) {
                                  return;
                                }
                                applyUpsertEntry(updated);
                              },
                        trailing: state == null
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    final updated = await state._upsertExpense(
                                      context: context,
                                      familyId: familyId,
                                      expenseId: row.id,
                                      initialData: data,
                                    );
                                    if (!context.mounted || updated == null) {
                                      return;
                                    }
                                    applyUpsertEntry(updated);
                                  } else if (action == 'delete') {
                                    final ok = await state._deleteExpense(
                                      context,
                                      familyId,
                                      row.id,
                                    );
                                    if (!context.mounted || !ok) {
                                      return;
                                    }
                                    applyExpenseDeleted(row.id);
                                  } else if (action == 'confirm') {
                                    final pm =
                                        data['paymentMethodId'] as String?;
                                    if (pm != null && pm.isNotEmpty) {
                                      final ok = await state
                                          ._effectivizeSingleCardExpense(
                                            context,
                                            familyId,
                                            row.id,
                                            pm,
                                          );
                                      if (!context.mounted || !ok) {
                                        return;
                                      }
                                      applyUpsertEntry(
                                        row.copyWithData(<String, dynamic>{
                                          'status': ExpenseLifecycle.confirmed,
                                        }),
                                      );
                                    }
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
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                      );
                    }),
                    if (visibleExpenseDocs.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: () async {
                              final pmCopy = <String, Map<String, dynamic>>{
                                for (final e in pmById.entries)
                                  e.key: Map<String, dynamic>.from(e.value),
                              };
                              final entries = List<ExpenseListEntry>.from(
                                visibleExpenseDocs,
                              );
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (ctx) => ExpensesFullMonthListPage(
                                    monthLabel: _monthLabel(
                                      viewedMonthStart,
                                    ),
                                    entries: entries,
                                    baseCurrency: baseCurrency,
                                    paymentMethodsById: pmCopy,
                                    onEdit: (e) {
                                      if (state == null) {
                                        return Future<ExpenseListEntry?>.value(
                                          null,
                                        );
                                      }
                                      return state._upsertExpense(
                                        context: ctx,
                                        familyId: familyId,
                                        expenseId: e.id,
                                        initialData: e.data,
                                      );
                                    },
                                    onDelete: (e) async {
                                      if (state == null) {
                                        return false;
                                      }
                                      final ok = await state._deleteExpense(
                                        ctx,
                                        familyId,
                                        e.id,
                                      );
                                      if (ok) {
                                        applyExpenseDeleted(e.id);
                                      }
                                      return ok;
                                    },
                                    onConfirmCard: (e) async {
                                      if (state == null) {
                                        return false;
                                      }
                                      final pm =
                                          e.data['paymentMethodId']
                                              as String?;
                                      if (pm == null || pm.isEmpty) {
                                        return false;
                                      }
                                      final ok = await state
                                          ._effectivizeSingleCardExpense(
                                            ctx,
                                            familyId,
                                            e.id,
                                            pm,
                                          );
                                      if (ok) {
                                        applyUpsertEntry(
                                          e.copyWithData(<String, dynamic>{
                                            'status':
                                                ExpenseLifecycle.confirmed,
                                          }),
                                        );
                                      }
                                      return ok;
                                    },
                                  ),
                                ),
                              );
                            },
                            child: const Text('Ver lista completa'),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
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
          MediaQuery.paddingOf(context).top +
              kSanctuaryAppBarToolbarHeight +
              24,
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

class ExpenseAmountCurrencyRow extends StatelessWidget {
  const ExpenseAmountCurrencyRow({
    super.key,
    this.availableWidth,
    required this.amountController,
    this.amountFocusNode,
    this.amountTextInputAction,
    this.onAmountSubmitted,
    required this.selectedCurrency,
    required this.baseCurrency,
    required this.availableCurrencies,
    required this.onCurrencyChanged,
  });

  /// When set (e.g. inside [AlertDialog]), used for responsive flex ratios.
  /// Avoids [LayoutBuilder], which cannot answer intrinsic sizing that dialogs
  /// use to size their content.
  final double? availableWidth;

  final TextEditingController amountController;
  final FocusNode? amountFocusNode;
  final TextInputAction? amountTextInputAction;
  final ValueChanged<String>? onAmountSubmitted;
  final String selectedCurrency;
  final String baseCurrency;
  final List<String> availableCurrencies;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final width = availableWidth ?? MediaQuery.sizeOf(context).width;
    final isCompact = width < 360;
    final amountFlex = isCompact ? 3 : 5;
    final currencyFlex = isCompact ? 2 : 3;
    return Row(
      key: const Key('expense-amount-currency-row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: amountFlex,
          child: TextField(
            controller: amountController,
            focusNode: amountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: amountTextInputAction,
            onSubmitted: onAmountSubmitted,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(labelText: 'Monto *'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: currencyFlex,
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>('expense-currency-$selectedCurrency'),
            initialValue: selectedCurrency,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Moneda *',
              helperText: 'Base: $baseCurrency',
            ),
            items: availableCurrencies
                .map(
                  (currency) => DropdownMenuItem<String>(
                    value: currency,
                    child: Text(currency, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onCurrencyChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }
}
