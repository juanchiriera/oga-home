import 'package:oga/design_system/design_system.dart';
import 'package:oga/core/auth_session_gate.dart';
import 'package:oga/core/entitlements_remote_config.dart';
import 'package:oga/core/entitlements_scope.dart';
import 'package:oga/features/profile/account_preferences.dart';
import 'package:oga/l10n/app_localizations.dart';
import 'package:oga/router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

class CraftrApp extends StatefulWidget {
  const CraftrApp({
    required this.entitlementsRemoteConfig,
    required this.authSessionGate,
    super.key,
  });

  final EntitlementsRemoteConfig entitlementsRemoteConfig;
  final AuthSessionGate authSessionGate;

  @override
  State<CraftrApp> createState() => _CraftrAppState();
}

class _CraftrAppState extends State<CraftrApp> {
  late final GoRouter _router = buildAppRouter(
    sessionGate: widget.authSessionGate,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntitlementsState>(
      valueListenable: widget.entitlementsRemoteConfig.state,
      builder: (context, entitlements, child) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, authSnapshot) {
            final user = authSnapshot.data;
            if (user == null) {
              return _LocalizedMaterialApp(
                router: _router,
                entitlements: entitlements,
                refreshEntitlements: widget.entitlementsRemoteConfig.refresh,
              );
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                final preferredLocale =
                    userSnapshot.data?.data()?['preferredLocale'] as String?;
                return _LocalizedMaterialApp(
                  router: _router,
                  locale: preferredLocale == null
                      ? null
                      : accountLocaleFromCode(preferredLocale),
                  entitlements: entitlements,
                  refreshEntitlements: widget.entitlementsRemoteConfig.refresh,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LocalizedMaterialApp extends StatelessWidget {
  const _LocalizedMaterialApp({
    required this.router,
    required this.entitlements,
    required this.refreshEntitlements,
    this.locale,
  });

  final RouterConfig<Object> router;
  final EntitlementsState entitlements;
  final Future<void> Function() refreshEntitlements;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: craftrLightTheme(),
      darkTheme: craftrDarkTheme(),
      themeMode: ThemeMode.system,
      locale: locale,
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
            return device.countryCode != null && device.countryCode!.isNotEmpty
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
          refreshEntitlements: refreshEntitlements,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
