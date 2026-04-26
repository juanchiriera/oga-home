import 'package:craftr_mobile/core/flavor.dart';
import 'package:craftr_mobile/core/entitlements_scope.dart';
import 'package:craftr_mobile/features/expenses/expenses_page.dart';
import 'package:craftr_mobile/features/assistant/family_assistant_page.dart';
import 'package:craftr_mobile/features/home/home_dashboard_page.dart';
import 'package:craftr_mobile/features/notes/shared_notes_page.dart';
import 'package:craftr_mobile/features/recipes/recipes_page.dart';
import 'package:craftr_mobile/features/stock/stock_list_page.dart';
import 'package:flutter/material.dart';

/// Navegación principal tipo “cozy” M3: barra inferior + asistente vía FAB
/// (hoja o panel flotante) para no saturar la [NavigationBar].
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = 0,
    this.openAssistantOnLaunch = false,
    this.assistantSeedMessage,
  });

  final int initialTab;
  final bool openAssistantOnLaunch;

  /// Texto inicial del compositor (p. ej. contexto E9-05 / §8.4).
  final String? assistantSeedMessage;

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
        return 0;
      case 'inicio':
      case 'home':
      default:
        return 0;
    }
  }

  /// `?tab=assistant` / `?tab=ia` / `?ia_open=1` abren el asistente (E9-05).
  static bool shouldOpenAssistantFromQuery(
    String? tab, {
    String? iaOpen,
  }) {
    final t = tab?.toLowerCase();
    if (t == 'assistant' || t == 'ia') {
      return true;
    }
    return iaOpen == '1';
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
    if (widget.openAssistantOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final ent = MainShellEntitlementsScope.of(context);
        if (ent.allOn || ent.iaAssistantEnabled) {
          _openAssistantPanel(
            context,
            seed: widget.assistantSeedMessage,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _index = widget.initialTab;
    }
    final wantOpen = widget.openAssistantOnLaunch;
    if (wantOpen &&
        (!oldWidget.openAssistantOnLaunch ||
            oldWidget.assistantSeedMessage != widget.assistantSeedMessage)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final ent = MainShellEntitlementsScope.of(context);
        if (ent.allOn || ent.iaAssistantEnabled) {
          _openAssistantPanel(
            context,
            seed: widget.assistantSeedMessage,
          );
        }
      });
    }
  }

  void _openAssistantPanel(BuildContext context, {String? seed}) {
    final h = MediaQuery.sizeOf(context).height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Center(
            child: Material(
              color: Theme.of(sheetContext).colorScheme.surface,
              elevation: 6,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: h * 0.92,
                  minHeight: h * 0.5,
                ),
                child: SizedBox(
                  height: h * 0.9,
                  child: FamilyAssistantPage(
                    onClose: () => Navigator.of(sheetContext).pop(),
                    initialComposerText: seed,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
    final selectedIndex = _index < 0 || _index >= pages.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      floatingActionButton: iaEnabled
          ? FloatingActionButton(
              onPressed: () => _openAssistantPanel(context, seed: null),
              tooltip: 'Asistente',
              child: const Icon(Icons.auto_awesome),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
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
        ],
      ),
    );
  }
}
