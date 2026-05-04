import 'package:oga/features/expenses/expenses_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'muestra monto y moneda en la misma fila sin overflow en ancho chico',
    (tester) async {
      final amountController = TextEditingController(text: '123.45');
      addTearDown(amountController.dispose);
      var selectedCurrency = 'ARS';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return ExpenseAmountCurrencyRow(
                      availableWidth: 320,
                      amountController: amountController,
                      selectedCurrency: selectedCurrency,
                      baseCurrency: 'ARS',
                      onCurrencyChanged: (value) {
                        setState(() => selectedCurrency = value);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('expense-amount-currency-row')),
        findsOneWidget,
      );
      expect(find.text('Monto *'), findsOneWidget);
      expect(find.text('Moneda *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conserva cambio de moneda mediante callback', (tester) async {
    final amountController = TextEditingController();
    addTearDown(amountController.dispose);
    var selectedCurrency = 'ARS';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ExpenseAmountCurrencyRow(
                amountController: amountController,
                selectedCurrency: selectedCurrency,
                baseCurrency: 'ARS',
                onCurrencyChanged: (value) {
                  setState(() => selectedCurrency = value);
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();

    expect(selectedCurrency, 'USD');
  });
}
