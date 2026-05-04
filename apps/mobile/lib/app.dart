import 'package:oga/design_system/design_system.dart';
import 'package:oga/core/entitlements_remote_config.dart';
import 'package:oga/core/entitlements_scope.dart';
import 'package:oga/l10n/app_localizations.dart';
import 'package:oga/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: craftrLightTheme(),
          darkTheme: craftrDarkTheme(),
          themeMode: ThemeMode.system,
          locale: const Locale('es', 'AR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) {
            return MainShellEntitlementsScope(
              entitlements: entitlements,
              refreshEntitlements: entitlementsRemoteConfig.refresh,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
