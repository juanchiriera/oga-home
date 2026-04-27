import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for semantics/layout when a dialog (similar shape to
/// gasto puntual) closes over a scrollable list and the host rebuilds on the
/// next frame — mirrors the `_deferUntilAfterRouteTransitionFrames` pattern
/// in [expenses_page.dart].
void main() {
  testWidgets(
    'ListView + Material dialog close then endOfFrame then setState — no crash',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _ScaffoldWithExpenseLikeDialog()));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _ScaffoldWithExpenseLikeDialog extends StatefulWidget {
  const _ScaffoldWithExpenseLikeDialog();

  @override
  State<_ScaffoldWithExpenseLikeDialog> createState() =>
      _ScaffoldWithExpenseLikeDialogState();
}

class _ScaffoldWithExpenseLikeDialogState extends State<_ScaffoldWithExpenseLikeDialog> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (var i = 0; i < 6; i++)
            Material(
              child: ListTile(title: Text('Line $i')),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Nuevo gasto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(initialValue: '10'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: 'food',
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: const [
                        DropdownMenuItem(value: 'food', child: Text('Comida')),
                        DropdownMenuItem(value: 'other', child: Text('Otros')),
                      ],
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );
          if (!context.mounted) {
            return;
          }
          await WidgetsBinding.instance.endOfFrame;
          if (!context.mounted) {
            return;
          }
          setState(() {});
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar gasto'),
      ),
    );
  }
}
