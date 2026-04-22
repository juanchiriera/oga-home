import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/router/app_router.dart';
import 'package:flutter/material.dart';

class CraftrApp extends StatelessWidget {
  const CraftrApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildAppRouter();
    return MaterialApp.router(
      title: 'CraftR',
      theme: craftrLightTheme(),
      darkTheme: craftrDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
