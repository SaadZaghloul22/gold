import 'package:flutter/material.dart';

/// Visual identity: warm gold on deep charcoal at night, on ivory by day.
class GoldColors {
  static const gold = Color(0xFFD4A537);
  static const goldDeep = Color(0xFFA67C1B);
  static const goldPale = Color(0xFFF3E2B0);
  static const ivory = Color(0xFFFAF6EC);
  static const ink = Color(0xFF231E14);
  static const night = Color(0xFF14120E);
  static const nightSurface = Color(0xFF1E1B15);
  static const nightHigh = Color(0xFF2A261D);
  static const nightInk = Color(0xFFF1EBDD);
  static const up = Color(0xFF1E9E61);
  static const down = Color(0xFFD64545);
  static const silver = Color(0xFF9AA4AE);
}

class GoldTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: GoldColors.gold, brightness: Brightness.light).copyWith(
      primary: GoldColors.goldDeep,
      onPrimary: Colors.white,
      secondary: GoldColors.gold,
      onSecondary: GoldColors.ink,
      surface: Colors.white,
      onSurface: GoldColors.ink,
      surfaceContainerHighest: const Color(0xFFF0E9D8),
      surfaceContainerHigh: const Color(0xFFF4EEE0),
      surfaceContainer: const Color(0xFFF6F1E5),
      surfaceContainerLow: const Color(0xFFFCFAF4),
      outlineVariant: const Color(0xFFE6DCC4),
    );
    return _base(scheme, GoldColors.ivory);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: GoldColors.gold, brightness: Brightness.dark).copyWith(
      primary: GoldColors.gold,
      onPrimary: const Color(0xFF2A1F00),
      secondary: GoldColors.goldPale,
      onSecondary: GoldColors.ink,
      surface: GoldColors.nightSurface,
      onSurface: GoldColors.nightInk,
      surfaceContainerHighest: const Color(0xFF332E23),
      surfaceContainerHigh: GoldColors.nightHigh,
      surfaceContainer: const Color(0xFF242018),
      surfaceContainerLow: const Color(0xFF1A1813),
      outlineVariant: const Color(0xFF3A3427),
    );
    return _base(scheme, GoldColors.night);
  }

  static ThemeData _base(ColorScheme scheme, Color bg) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['NotoColorEmoji'],
    );
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: .18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
