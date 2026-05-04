import 'package:oga/design_system/sanctuary_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<SanctuaryBottomDestination> sampleDestinations() {
    return const [
      SanctuaryBottomDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Inicio',
      ),
      SanctuaryBottomDestination(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: 'Gastos',
      ),
      SanctuaryBottomDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Perfil',
      ),
    ];
  }

  testWidgets('uses minimum 48dp touch target for each destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: SanctuaryBottomNav(
            currentIndex: 0,
            onSelect: (_) {},
            destinations: sampleDestinations(),
          ),
        ),
      ),
    );

    final constrainedBoxes = tester.widgetList<ConstrainedBox>(
      find.byType(ConstrainedBox),
    );

    final touchTargets = constrainedBoxes
        .map((box) => box.constraints)
        .where((constraints) => constraints.minHeight >= 48)
        .toList(growable: false);

    expect(touchTargets.length, greaterThanOrEqualTo(3));
    for (final constraints in touchTargets.take(3)) {
      expect(constraints.minHeight, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('exposes button semantics and selected state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: SanctuaryBottomNav(
            currentIndex: 1,
            onSelect: (_) {},
            destinations: sampleDestinations(),
          ),
        ),
      ),
    );

    final semanticsWidgets = tester.widgetList<Semantics>(
      find.byType(Semantics),
    );

    expect(
      semanticsWidgets.any(
        (widget) =>
            widget.properties.label == 'Gastos' &&
            widget.properties.button == true &&
            widget.properties.selected == true,
      ),
      isTrue,
    );
    expect(
      semanticsWidgets.any(
        (widget) =>
            widget.properties.label == 'Inicio' &&
            widget.properties.button == true &&
            widget.properties.selected != true,
      ),
      isTrue,
    );
  });

  testWidgets('fab inset uses safe area when keyboard is closed', (
    tester,
  ) async {
    late double inset;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 12),
            viewInsets: EdgeInsets.zero,
          ),
          child: Builder(
            builder: (context) {
              inset = sanctuaryFabBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(inset, 84);
  });

  testWidgets('fab inset rises above keyboard when it is open', (tester) async {
    late double inset;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 12),
            viewInsets: EdgeInsets.only(bottom: 240),
          ),
          child: Builder(
            builder: (context) {
              inset = sanctuaryFabBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(inset, 312);
  });
}
