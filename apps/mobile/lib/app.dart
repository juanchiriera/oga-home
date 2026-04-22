import 'package:craftr_mobile/core/flavor.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/features/bootstrap/bootstrap_page.dart';
import 'package:flutter/material.dart';

class CraftrApp extends StatelessWidget {
  const CraftrApp({super.key});

  @override
  Widget build(BuildContext context) {
    final flavor = AppFlavor.fromEnvironment();
    return MaterialApp(
      title: flavor.displayName,
      theme: craftrLightTheme(),
      darkTheme: craftrDarkTheme(),
      themeMode: ThemeMode.system,
      home: BootstrapPage(flavor: flavor),
    );
  }
}
