import 'package:oga/features/recipes/recipes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders only the import URL button with accessibility metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportRecipeFromUrlButton(onPressed: () {}),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text(ImportRecipeFromUrlButton.buttonText), findsOneWidget);
    expect(find.text('Importar desde la web'), findsNothing);
    expect(
      find.byTooltip(ImportRecipeFromUrlButton.accessibilityLabel),
      findsOneWidget,
    );

    final semanticsWidgets = tester.widgetList<Semantics>(
      find.byType(Semantics),
    );
    expect(
      semanticsWidgets.any(
        (widget) =>
            widget.properties.label ==
                ImportRecipeFromUrlButton.accessibilityLabel &&
            widget.properties.button == true,
      ),
      isTrue,
    );
  });
}
