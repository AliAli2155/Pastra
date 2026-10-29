import 'dart:math' as math;

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
  final rounded16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PastraColors.feltDark,
    // The same light fade-and-grow between screens on every platform. It is
    // cheap (no snapshots, no shadows), so it stays smooth on phones and on
    // the web.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _FadeScaleTransitions(),
        TargetPlatform.iOS: _FadeScaleTransitions(),
        TargetPlatform.macOS: _FadeScaleTransitions(),
        TargetPlatform.windows: _FadeScaleTransitions(),
        TargetPlatform.linux: _FadeScaleTransitions(),
        TargetPlatform.fuchsia: _FadeScaleTransitions(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xCC03170F),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
      iconTheme: IconThemeData(color: Colors.white, size: 26),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PastraColors.gold,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.white12,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        shape: rounded16,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: rounded16,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: PastraColors.gold, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PastraColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.35)),
      ),
      titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF0101814),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.5)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: const Color(0xF0101814), borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 13),
      waitDuration: const Duration(milliseconds: 400),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? PastraColors.gold : Colors.white70,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? PastraColors.gold.withValues(alpha: 0.4) : Colors.white12,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.white24),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: PastraColors.gold,
      thumbColor: PastraColors.gold,
      inactiveTrackColor: Colors.white24,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.black.withValues(alpha: 0.28),
      selectedColor: PastraColors.gold,
      side: const BorderSide(color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? PastraColors.gold : Colors.black.withValues(alpha: 0.25),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.black : Colors.white,
        ),
        textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700)),
        side: WidgetStateProperty.all(const BorderSide(color: Colors.white24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.25),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PastraColors.gold, width: 2),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white30),
      radius: const Radius.circular(8),
    ),
  );
}

class _FadeScaleTransitions extends PageTransitionsBuilder {
  const _FadeScaleTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween<double>(begin: 0.97, end: 1).animate(curved), child: child),
    );
  }
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

/// The table cloth behind every screen: the chosen colour, a fine woven
/// texture and a dark edge (vignette), like a real card table.
class Felt extends StatelessWidget {
  const Felt({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: feltDecoration,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(child: CustomPaint(painter: _FeltTexture(Look.table))),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _FeltTexture extends CustomPainter {
  _FeltTexture(this.table);

  final TableTheme table;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Fine fibres: short strokes in a fixed pseudo-random pattern.
    final light = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    final dark = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    var seed = 12345;
    double next() {
      seed = (seed * 48271) % 2147483647;
      return seed / 2147483647;
    }

    final count = (size.width * size.height / 900).clamp(200, 2600).toInt();
    for (var i = 0; i < count; i++) {
      final x = next() * size.width;
      final y = next() * size.height;
      final a = next() * math.pi;
      final l = 2 + next() * 3;
      final dx = l * math.cos(a);
      final dy = l * math.sin(a);
      canvas.drawLine(Offset(x, y), Offset(x + dx, y + dy), i.isEven ? light : dark);
    }
    // Dark edge.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.05,
          colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.38)],
          stops: const <double>[0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FeltTexture old) => old.table != table;
}

/// Text painted with a gold gradient (titles).
class GoldText extends StatelessWidget {
  const GoldText(this.text, {super.key, required this.size, this.weight = FontWeight.w900, this.letterSpacing = 1.0});

  final String text;
  final double size;
  final FontWeight weight;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: weight, letterSpacing: letterSpacing, height: 1.05);
    return Stack(
      children: <Widget>[
        // Soft shadow under the letters.
        Text(
          text,
          style: style.copyWith(
            color: Colors.transparent,
            shadows: <Shadow>[Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6))],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFFFF1C1), Color(0xFFF2C14E), Color(0xFFC08A1E)],
            stops: <double>[0.0, 0.55, 1.0],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
