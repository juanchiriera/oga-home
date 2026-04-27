import 'package:craftr_mobile/features/stock/stock_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHarness({
    required Future<void> Function() onTap,
    required Future<void> Function() onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StockItemTile(
          name: 'Leche',
          level: StockLevel.out,
          onTap: onTap,
          onDelete: onDelete,
        ),
      ),
    );
  }

  testWidgets('tap simple abre edición', (tester) async {
    var editCalls = 0;
    var deleteCalls = 0;
    await tester.pumpWidget(
      buildHarness(
        onTap: () async => editCalls++,
        onDelete: () async => deleteCalls++,
      ),
    );

    await tester.tap(find.byKey(const Key('stock-item-tile')));
    await tester.pumpAndSettle();

    expect(editCalls, 1);
    expect(deleteCalls, 0);
  });

  testWidgets('acción editar desde menú no dispara delete', (tester) async {
    var editCalls = 0;
    var deleteCalls = 0;
    await tester.pumpWidget(
      buildHarness(
        onTap: () async => editCalls++,
        onDelete: () async => deleteCalls++,
      ),
    );

    await tester.tap(find.byKey(const Key('stock-item-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(editCalls, 1);
    expect(deleteCalls, 0);
  });

  testWidgets('acción eliminar es explícita desde menú', (tester) async {
    var editCalls = 0;
    var deleteCalls = 0;
    await tester.pumpWidget(
      buildHarness(
        onTap: () async => editCalls++,
        onDelete: () async => deleteCalls++,
      ),
    );

    await tester.tap(find.byKey(const Key('stock-item-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(editCalls, 0);
    expect(deleteCalls, 1);
  });
}
