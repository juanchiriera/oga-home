import 'package:flutter/material.dart';

ThemeData craftrLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B4F3A),
      brightness: Brightness.light,
    ),
  );
}

ThemeData craftrDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD4A574),
      brightness: Brightness.dark,
    ),
  );
}
