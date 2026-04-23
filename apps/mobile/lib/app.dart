import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/core/entitlements_remote_config.dart';
import 'package:craftr_mobile/core/entitlements_scope.dart';
import 'package:craftr_mobile/router/app_router.dart';
import 'package:flutter/material.dart';

class CraftrApp extends StatelessWidget {
  const CraftrApp({required this.entitlementsRemoteConfig, super.key});

  final EntitlementsRemoteConfig entitlementsRemoteConfig;

  @override
  Widget build(BuildContext context) {
    final router = buildAppRouter();
    return ValueListenableBuilder<EntitlementsState>(
      valueListenable: entitlementsRemoteConfig.state,
      builder: (context, entitlements, child) {
        return MaterialApp.router(
          title: 'CraftR',
          theme: craftrLightTheme(),
          darkTheme: craftrDarkTheme(),
          themeMode: ThemeMode.system,
          routerConfig: router,
          builder: (context, child) {
            return MainShellEntitlementsScope(
              entitlements: entitlements,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
