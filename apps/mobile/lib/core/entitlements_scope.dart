import 'package:craftr_mobile/core/entitlements_remote_config.dart';
import 'package:flutter/material.dart';

class MainShellEntitlementsScope extends InheritedWidget {
  const MainShellEntitlementsScope({
    required this.entitlements,
    required super.child,
    super.key,
  });

  final EntitlementsState entitlements;

  static EntitlementsState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MainShellEntitlementsScope>();
    return scope?.entitlements ??
        const EntitlementsState(allOn: false, iaAssistantEnabled: false);
  }

  @override
  bool updateShouldNotify(MainShellEntitlementsScope oldWidget) {
    return oldWidget.entitlements.allOn != entitlements.allOn ||
        oldWidget.entitlements.iaAssistantEnabled !=
            entitlements.iaAssistantEnabled;
  }
}
