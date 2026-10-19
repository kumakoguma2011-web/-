
import 'package:flutter/material.dart';

class MichishirubeTheme {
  static const parchment = Color(0xFFF4EFE7);
  static const paper = Color(0xFFFBF8F3);
  static const panel = Color(0xFFEAE3D8);
  static const ink = Color(0xFF342F2A);
  static const muted = Color(0xFF756C62);
  static const accent = Color(0xFF8A5A44);
  static const accentDark = Color(0xFF684333);
  static const sage = Color(0xFF6F7F68);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: paper,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      secondary: sage,
      surface: paper,
      onSurface: ink,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: parchment,
      canvasColor: parchment,
      appBarTheme: const AppBarTheme(
        backgroundColor: parchment,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2D9CD)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: Color(0xFF9B9186)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9CFC2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9CFC2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFEDE6DB),
        side: const BorderSide(color: Color(0xFFDDD2C4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFFF0EAE1),
        indicatorColor: Color(0xFFDCCABD),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE0D7CC)),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: accentDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
    );
  }
}
