import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oga/features/expenses/expense_lifecycle.dart';
import 'package:oga/features/expenses/expense_list_models.dart';
import 'package:oga/features/expenses/expenses_full_month_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('category filter shows only matching rows', (tester) async {
    final ts = Timestamp.fromDate(DateTime(2026, 5, 10));
    final entries = <ExpenseListEntry>[
      ExpenseListEntry(
        id: 'a',
        data: <String, dynamic>{
          'categoryKey': 'food',
          'amount': 100.0,
          'currency': 'ARS',
          'occurredAt': ts,
          'status': ExpenseLifecycle.confirmed,
        },
      ),
      ExpenseListEntry(
        id: 'b',
        data: <String, dynamic>{
          'categoryKey': 'transport',
          'amount': 50.0,
          'currency': 'ARS',
          'occurredAt': ts,
          'status': ExpenseLifecycle.confirmed,
        },
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ExpensesFullMonthListPage(
          monthLabel: 'mayo 2026',
          entries: entries,
          baseCurrency: 'ARS',
          paymentMethodsById: const {},
          onEdit: (_) async => null,
          onDelete: (_) async => false,
          onConfirmCard: (_) async => false,
        ),
      ),
    );

    final chips = find.byType(FilterChip);
    expect(chips, findsNWidgets(3));
    await tester.tap(chips.at(2));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('a')), findsNothing);
    expect(find.byKey(const ValueKey<String>('b')), findsOneWidget);
  });
}
