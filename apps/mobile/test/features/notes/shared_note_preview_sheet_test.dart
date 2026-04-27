import 'package:craftr_mobile/features/notes/widgets/shared_note_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview sheet shows title, excerpt and open action', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showSharedNotePreviewSheet(
                    context,
                    title: 'Mi título',
                    content: 'Cuerpo en texto plano',
                    onOpenFullDetail: () => opened = true,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Mi título'), findsOneWidget);
    expect(find.text('Vista previa'), findsOneWidget);
    expect(find.text('Abrir detalle completo'), findsOneWidget);

    await tester.tap(find.text('Abrir detalle completo'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.text('Mi título'), findsNothing);
  });

  testWidgets('close icon dismisses sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showSharedNotePreviewSheet(
                    context,
                    title: 'T',
                    content: 'c',
                    onOpenFullDetail: () {},
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar vista previa'));
    await tester.pumpAndSettle();

    expect(find.text('T'), findsNothing);
  });
}
