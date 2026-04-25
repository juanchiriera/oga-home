import 'package:craftr_mobile/core/flavor.dart';
import 'package:craftr_mobile/core/entitlements_scope.dart';
import 'package:craftr_mobile/features/expenses/expenses_page.dart';
import 'package:craftr_mobile/features/assistant/family_assistant_page.dart';
import 'package:craftr_mobile/features/home/home_dashboard_page.dart';
import 'package:craftr_mobile/features/notes/shared_notes_page.dart';
import 'package:craftr_mobile/features/recipes/recipes_page.dart';
import 'package:craftr_mobile/features/stock/stock_list_page.dart';
import 'package:flutter/material.dart';

/// Navegación principal tipo “cozy” M3: barra inferior + secciones placeholder.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = 0});

  final int initialTab;

  static int tabFromQuery(String? tab) {
    switch (tab?.toLowerCase()) {
      case 'despensa':
      case 'stock':
        return 1;
      case 'gastos':
      case 'expenses':
        return 2;
      case 'recetas':
      case 'recipes':
        return 3;
      case 'notas':
      case 'notes':
        return 4;
      case 'ia':
      case 'assistant':
        return 5;
      case 'inicio':
      case 'home':
      default:
        return 0;
    }
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _index = widget.initialTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = MainShellEntitlementsScope.of(context);
    final iaEnabled =
        entitlements.allOn || entitlements.iaAssistantEnabled;
    final flavor = AppFlavor.fromEnvironment();
    final pages = <Widget>[
      HomeDashboardPage(flavor: flavor),
      const StockListPage(),
      const ExpensesPage(),
      const RecipesPage(),
      const SharedNotesPage(),
    ];
    if (iaEnabled) {
      pages.add(const FamilyAssistantPage());
    }
    final selectedIndex = _index < 0 || _index >= pages.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Gastos',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Recetas',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: 'Notas',
          ),
          if (iaEnabled)
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'IA',
            ),
        ],
      ),
    );
  }
}
