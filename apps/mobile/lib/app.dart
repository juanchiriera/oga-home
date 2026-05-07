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
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: (locales, supported) {
            if (locales == null || locales.isEmpty) {
              return const Locale('es', 'AR');
            }
            for (final device in locales) {
              if (device.languageCode == 'en') {
                return const Locale('en', 'US');
              }
              if (device.languageCode == 'es') {
                return device.countryCode != null &&
                        device.countryCode!.isNotEmpty
                    ? device
                    : const Locale('es', 'AR');
              }
            }
            return const Locale('es', 'AR');
          },
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
