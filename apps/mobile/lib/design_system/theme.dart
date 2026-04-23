import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData craftrLightTheme() {
  final textTheme = GoogleFonts.plusJakartaSansTextTheme();
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0F4746),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF2C5F5D),
    onPrimaryContainer: Color(0xFFA3D7D4),
    secondary: Color(0xFF3A6847),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFBCEFC5),
    onSecondaryContainer: Color(0xFF406E4D),
    tertiary: Color(0xFF553B12),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF6F5227),
    onTertiaryContainer: Color(0xFFEFC792),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFFBFBE2),
    onSurface: Color(0xFF1B1D0E),
    onSurfaceVariant: Color(0xFF404848),
    outline: Color(0xFF707978),
    outlineVariant: Color(0xFFBFC8C7),
    shadow: Color(0xFF1B1D0E),
    scrim: Color(0xFF1B1D0E),
    inverseSurface: Color(0xFF303221),
    onInverseSurface: Color(0xFFF2F2D9),
    inversePrimary: Color(0xFF9CD0CD),
    surfaceDim: Color(0xFFDBDCC3),
    surfaceBright: Color(0xFFFBFBE2),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F5DC),
    surfaceContainer: Color(0xFFEFEFD7),
    surfaceContainerHigh: Color(0xFFEAEAD1),
    surfaceContainerHighest: Color(0xFFE4E4CC),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface.withValues(alpha: 0.9),
      foregroundColor: scheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: scheme.primaryContainer, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      selectedColor: scheme.primary,
      backgroundColor: scheme.surfaceContainer,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary,
      backgroundColor: scheme.surface.withValues(alpha: 0.85),
      height: 84,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

ThemeData craftrDarkTheme() {
  final base = craftrLightTheme();
  final scheme = base.colorScheme.copyWith(
    brightness: Brightness.dark,
    surface: const Color(0xFF1B1D0E),
    onSurface: const Color(0xFFF2F2D9),
    surfaceContainerLowest: const Color(0xFF101109),
    surfaceContainerLow: const Color(0xFF202218),
    surfaceContainer: const Color(0xFF292B20),
    surfaceContainerHigh: const Color(0xFF323429),
    surfaceContainerHighest: const Color(0xFF3A3D31),
    onSurfaceVariant: const Color(0xFFD0D4C4),
    outline: const Color(0xFF96A09D),
    outlineVariant: const Color(0xFF5D6665),
  );
  return base.copyWith(colorScheme: scheme, brightness: Brightness.dark);
}
