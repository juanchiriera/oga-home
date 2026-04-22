import 'package:flutter/material.dart';

ThemeData craftrLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6B4F3A),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.secondaryContainer,
      backgroundColor: scheme.surfaceContainerLow,
    ),
  );
}

ThemeData craftrDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFD4A574),
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.secondaryContainer,
      backgroundColor: scheme.surfaceContainerLow,
    ),
  );
}
