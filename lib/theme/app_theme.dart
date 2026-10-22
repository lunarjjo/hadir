/// Tema Material 3 — terang & gelap dari satu benih warna indigo.
library;

import 'package:flutter/material.dart';

class AppTheme {
  static const Color seedColor = Color(0xFF3F51B5);

  static ThemeData light() =>
      _build(ColorScheme.fromSeed(seedColor: seedColor));

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      );

  static ThemeData _build(ColorScheme cs) => ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        inputDecorationTheme: InputDecorationTheme(
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: cs.brightness == Brightness.light
              ? const Color(0x0A000000)
              : const Color(0x14FFFFFF),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 48),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      );
}
