import 'package:flutter/material.dart';

class PastraColors {
  PastraColors._();

  static const Color feltDark = Color(0xFF052E1E);
  static const Color felt = Color(0xFF0A5A39);
  static const Color feltLight = Color(0xFF138152);
  static const Color gold = Color(0xFFF2C14E);
  static const Color cream = Color(0xFFFFFBF2);
  static const Color cardEdge = Color(0xFFB9B2A4);
  static const Color cardRed = Color(0xFFC62828);
  static const Color cardBlack = Color(0xFF1B1B1F);
  static const Color navy = Color(0xFF0D3B8C);
  static const Color aegean = Color(0xFF1E6FD0);
  static const Color panel = Color(0xF0102A1F);
}

ThemeData buildPastraTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PastraColors.felt,
    brightness: Brightness.dark,
  ).copyWith(
    primary: PastraColors.gold,
    onPrimary: Colors.black,
    secondary: PastraColors.gold,
    onSecondary: Colors.black,
    surface: const Color(0xFF0E2A1F),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PastraColors.feltDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PastraColors.gold,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

/// Green card-table background.
const BoxDecoration feltDecoration = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, -0.15),
    radius: 1.15,
    colors: [PastraColors.feltLight, PastraColors.felt, PastraColors.feltDark],
    stops: [0.0, 0.55, 1.0],
  ),
);
