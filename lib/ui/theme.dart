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

/// Table cloth colours (light centre → dark edge).
enum TableTheme {
  green(Color(0xFF138152), Color(0xFF0A5A39), Color(0xFF052E1E)),
  blue(Color(0xFF2468B5), Color(0xFF15427A), Color(0xFF0A2142)),
  red(Color(0xFFA3303F), Color(0xFF6E1A27), Color(0xFF3A0C14)),
  wood(Color(0xFFA0703F), Color(0xFF6B4423), Color(0xFF34200F)),
  purple(Color(0xFF7448AA), Color(0xFF452870), Color(0xFF22123A)),
  night(Color(0xFF3E4656), Color(0xFF242A35), Color(0xFF101318));

  const TableTheme(this.light, this.mid, this.dark);

  final Color light;
  final Color mid;
  final Color dark;

  BoxDecoration get decoration => BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.15,
          colors: <Color>[light, mid, dark],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
      );
}

/// Card back colours (gradient + accent for frame and emblem).
enum CardBackStyle {
  aegean(Color(0xFF0D3B8C), Color(0xFF1E6FD0), Colors.white),
  red(Color(0xFF7A1020), Color(0xFFC62838), Colors.white),
  green(Color(0xFF0B4D2C), Color(0xFF1E8A50), Colors.white),
  black(Color(0xFF15161A), Color(0xFF3A3D45), PastraColors.gold),
  purple(Color(0xFF3B1B6E), Color(0xFF7A4BC2), Colors.white),
  gold(Color(0xFF6B4E0E), Color(0xFFD4A43A), Color(0xFFFFF6DA));

  const CardBackStyle(this.dark, this.light, this.accent);

  final Color dark;
  final Color light;
  final Color accent;
}

/// The look chosen in the settings. Kept here (set by AppSettings) so card
/// and background widgets can read it without extra plumbing.
class Look {
  Look._();

  static TableTheme table = TableTheme.green;
  static CardBackStyle back = CardBackStyle.aegean;
}

/// Card-table background in the chosen colour.
BoxDecoration get feltDecoration => Look.table.decoration;
