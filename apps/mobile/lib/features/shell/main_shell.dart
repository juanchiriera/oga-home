import 'package:oga/core/flavor.dart';
import 'package:oga/core/entitlements_scope.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/expenses/expenses_page.dart';
import 'package:oga/features/assistant/family_assistant_page.dart';
import 'package:oga/features/home/home_dashboard_page.dart';
import 'package:oga/features/notes/shared_notes_page.dart';
import 'package:oga/features/recipes/recipes_page.dart';
import 'package:oga/features/stock/stock_list_page.dart';
import 'package:oga/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Navegación principal tipo “cozy” M3: barra inferior + asistente vía FAB
/// (hoja o panel flotante) para no saturar la [NavigationBar].
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = 0,
    this.openAssistantOnLaunch = false,
  });

  final int initialTab;
  final bool openAssistantOnLaunch;

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

  /// `?tab=assistant` o `?tab=ia` abre el asistente en un panel (junto con [openAssistantOnLaunch]).
  static bool shouldOpenAssistantFromQuery(String? tab) {
    final t = tab?.toLowerCase();
    return t == 'assistant' || t == 'ia';
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class MainShellController extends InheritedWidget {
  const MainShellController({
    super.key,
    required this.selectTab,
    required super.child,
  });

  final void Function(int index) selectTab;

  static MainShellController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellController>();
  }

  @override
  bool updateShouldNotify(MainShellController oldWidget) => false;
}

class _MainShellState extends State<MainShell> {
  late int _index;
  final List<int> _tabHistory = <int>[];

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
          _openAssistantPanel(context);
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
  }

  void _openAssistantPanel(BuildContext context) {
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectTab(int nextIndex) {
    if (nextIndex == _index) {
      return;
    }
    setState(() {
      _tabHistory.add(_index);
      _index = nextIndex;
    });
  }

  Future<bool> _onWillPop() async {
    if (_tabHistory.isNotEmpty) {
      setState(() {
        _index = _tabHistory.removeLast();
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entitlements = MainShellEntitlementsScope.of(context);
    final iaEnabled = entitlements.allOn || entitlements.iaAssistantEnabled;
    final flavor = AppFlavor.fromEnvironment();
    final pages = <Widget>[
      HomeDashboardPage(flavor: flavor),
      const StockListPage(),
      const ExpensesPage(),
      const RecipesPage(),
      const SharedNotesPage(),
    ];
    final selectedIndex = _index < 0 || _index >= pages.length ? 0 : _index;

    return MainShellController(
      selectTab: _selectTab,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(index: selectedIndex, children: pages),
              const SanctuaryNavBarScrollFade(),
            ],
          ),
          floatingActionButton: iaEnabled
              ? FloatingActionButton(
                  onPressed: () => _openAssistantPanel(context),
                  tooltip: l10n.assistantTooltip,
                  child: const Icon(Icons.auto_awesome),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: _selectTab,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: l10n.navHome,
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: l10n.navStock,
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: l10n.navExpenses,
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu_outlined),
                selectedIcon: Icon(Icons.restaurant_menu),
                label: l10n.navRecipes,
              ),
              NavigationDestination(
                icon: Icon(Icons.note_alt_outlined),
                selectedIcon: Icon(Icons.note_alt),
                label: l10n.navNotes,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
