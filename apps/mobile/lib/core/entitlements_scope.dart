import 'package:oga/core/entitlements_remote_config.dart';
import 'package:flutter/material.dart';

class MainShellEntitlementsScope extends InheritedWidget {
  const MainShellEntitlementsScope({
    required this.entitlements,
    required this.refreshEntitlements,
    required super.child,
    super.key,
  });

  final EntitlementsState entitlements;
  final Future<void> Function() refreshEntitlements;

  static EntitlementsState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MainShellEntitlementsScope>();
    return scope?.entitlements ??
        const EntitlementsState(allOn: false, iaAssistantEnabled: false);
  }

  static Future<void> refresh(BuildContext context) async {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MainShellEntitlementsScope>();
    if (scope == null) {
      return;
    }
    await scope.refreshEntitlements();
  }

  @override
  bool updateShouldNotify(MainShellEntitlementsScope oldWidget) {
    return oldWidget.entitlements.allOn != entitlements.allOn ||
        oldWidget.entitlements.iaAssistantEnabled !=
            entitlements.iaAssistantEnabled ||
        oldWidget.refreshEntitlements != refreshEntitlements;
  }
}
