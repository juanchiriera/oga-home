import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData craftrLightTheme() {
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
  return _buildTheme(scheme);
}

ThemeData craftrDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9CD0CD),
    onPrimary: Color(0xFF003736),
    primaryContainer: Color(0xFF194E4D),
    onPrimaryContainer: Color(0xFFB8ECE9),
    secondary: Color(0xFFA1D2AA),
    onSecondary: Color(0xFF06391C),
    secondaryContainer: Color(0xFF225031),
    onSecondaryContainer: Color(0xFFBCEFC5),
    tertiary: Color(0xFFE8C08C),
    onTertiary: Color(0xFF442B00),
    tertiaryContainer: Color(0xFF5D4219),
    onTertiaryContainer: Color(0xFFFFDDB3),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF13140A),
    onSurface: Color(0xFFE4E4CC),
    onSurfaceVariant: Color(0xFFBFC8C7),
    outline: Color(0xFF899392),
    outlineVariant: Color(0xFF404848),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE4E4CC),
    onInverseSurface: Color(0xFF1B1D0E),
    inversePrimary: Color(0xFF0F4746),
    surfaceDim: Color(0xFF13140A),
    surfaceBright: Color(0xFF393A28),
    surfaceContainerLowest: Color(0xFF0E1006),
    surfaceContainerLow: Color(0xFF1B1D0E),
    surfaceContainer: Color(0xFF1F2112),
    surfaceContainerHigh: Color(0xFF292B1C),
    surfaceContainerHighest: Color(0xFF353626),
  );
  return _buildTheme(scheme);
}

ThemeData _buildTheme(ColorScheme scheme) {
  final textTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final scaffoldSurface = scheme.brightness == Brightness.dark
      ? scheme.surfaceDim
      : scheme.surface;

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldSurface,
    canvasColor: scaffoldSurface,
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      modalBackgroundColor: scheme.surfaceContainer,
      dragHandleColor: scheme.outline.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldSurface.withValues(alpha: 0.9),
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
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
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
      backgroundColor: scaffoldSurface.withValues(alpha: 0.82),
      shadowColor: scheme.shadow.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      height: 84,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
