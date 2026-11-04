import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';
import 'premium/premium.dart';

export 'palette.dart';

/// The app font: Outfit, with Manrope filling in Greek and Cyrillic.
const String appFont = 'Outfit';
const List<String> appFontFallback = <String>['Manrope'];

ThemeData buildPastraTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PastraColors.gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: PastraColors.gold,
    onPrimary: PastraColors.goldInk,
    secondary: PastraColors.teal,
    onSecondary: Colors.black,
    surface: PastraColors.nightMid,
    onSurface: PastraColors.text,
  );
  final rounded14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: appFont,
    fontFamilyFallback: appFontFallback,
    scaffoldBackgroundColor: PastraColors.night,
    // The same light transition on every platform: the new screen fades in
    // while it rises a little. No perspective and no snapshots, so it stays
    // smooth on phones and on the web.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _RiseTransitions(),
        TargetPlatform.iOS: _RiseTransitions(),
        TargetPlatform.macOS: _RiseTransitions(),
        TargetPlatform.windows: _RiseTransitions(),
        TargetPlatform.linux: _RiseTransitions(),
        TargetPlatform.fuchsia: _RiseTransitions(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xE6111316),
      shape: Border(bottom: BorderSide(color: PastraColors.edge)),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: PastraColors.text,
      titleTextStyle: TextStyle(
        fontFamily: appFont,
        fontFamilyFallback: appFontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: PastraColors.text,
      ),
      iconTheme: IconThemeData(color: PastraColors.text, size: 24),
    ),
    // Tabs: a gold pill behind the chosen one.
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(color: PastraColors.gold, borderRadius: BorderRadius.circular(10)),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerHeight: 0,
      labelColor: PastraColors.goldInk,
      unselectedLabelColor: PastraColors.text2,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      splashBorderRadius: BorderRadius.circular(10),
      overlayColor: WidgetStateProperty.all(Colors.white10),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PastraColors.gold,
        foregroundColor: PastraColors.goldInk,
        disabledBackgroundColor: Colors.white12,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        shape: rounded14,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PastraColors.text,
        backgroundColor: PastraColors.glass,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: rounded14,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: PastraColors.gold, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PastraColors.nightMid,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: PastraColors.edge),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: appFont,
        fontFamilyFallback: appFontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: PastraColors.text,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PastraColors.nightLight,
      contentTextStyle: const TextStyle(
        fontFamily: appFont,
        fontFamilyFallback: appFontFallback,
        color: PastraColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.45)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: PastraColors.nightLight, borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontFamily: appFont, fontFamilyFallback: appFontFallback, color: PastraColors.text, fontSize: 13),
      waitDuration: const Duration(milliseconds: 400),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? PastraColors.gold : PastraColors.text2,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? PastraColors.gold.withValues(alpha: 0.35) : Colors.white10,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.white24),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: PastraColors.gold,
      thumbColor: PastraColors.gold,
      inactiveTrackColor: Colors.white24,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: PastraColors.glass,
      selectedColor: PastraColors.gold,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(color: PastraColors.text, fontWeight: FontWeight.w600),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? PastraColors.gold : PastraColors.glass,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? PastraColors.goldInk : PastraColors.text,
        ),
        textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w700)),
        side: WidgetStateProperty.all(BorderSide(color: Colors.white.withValues(alpha: 0.14))),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PastraColors.glass,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PastraColors.gold, width: 1.6),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white30),
      radius: const Radius.circular(8),
    ),
  );
}

class _RiseTransitions extends PageTransitionsBuilder {
  const _RiseTransitions();

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
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

/// Table cloth colours (light centre → dark edge).
enum TableTheme {
  green(Color(0xFF16A07A), Color(0xFF0D7356), Color(0xFF064734)),
  blue(Color(0xFF2468B5), Color(0xFF15427A), Color(0xFF0A2142)),
  red(Color(0xFFA3303F), Color(0xFF6E1A27), Color(0xFF3A0C14)),
  wood(Color(0xFFA0703F), Color(0xFF6B4423), Color(0xFF34200F)),
  purple(Color(0xFF7448AA), Color(0xFF452870), Color(0xFF22123A)),
  night(Color(0xFF3E4656), Color(0xFF242A35), Color(0xFF101318)),
  olive(Color(0xFF7C8A3A), Color(0xFF4E5A22), Color(0xFF232A0D)),
  // Store tables (bought with chips or diamonds, see Economy.items).
  ocean(Color(0xFF14A3A0), Color(0xFF0B6B72), Color(0xFF04323A)),
  royal(Color(0xFF3446A8), Color(0xFF1C2466), Color(0xFF0A0D2E)),
  sunset(Color(0xFFD9733A), Color(0xFF9C3446), Color(0xFF3E1230)),
  aurora(Color(0xFF2FB38A), Color(0xFF2A5FA8), Color(0xFF1A1440)),
  rose(Color(0xFFC0587A), Color(0xFF7A2848), Color(0xFF2E0C1C));

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
  // The first back ("aegean" by its old name) is the charcoal and gold one.
  aegean(Color(0xFF15171B), Color(0xFF262A31), PastraColors.gold),
  red(Color(0xFF7A1020), Color(0xFFC62838), Colors.white),
  green(Color(0xFF0B4D2C), Color(0xFF1E8A50), Colors.white),
  black(Color(0xFF0B0B0D), Color(0xFF2A2A2E), Color(0xFFC9D0D8)),
  purple(Color(0xFF3B1B6E), Color(0xFF7A4BC2), Colors.white),
  gold(Color(0xFF6B4E0E), Color(0xFFD4A43A), Color(0xFFFFF6DA)),
  meander(Color(0xFF0D47A1), Color(0xFF42A5F5), Colors.white),
  // Store card backs.
  emerald(Color(0xFF053D2E), Color(0xFF12A374), PastraColors.gold),
  ruby(Color(0xFF4A0618), Color(0xFFD01E4A), PastraColors.gold),
  diamond(Color(0xFF0B4A6E), Color(0xFF7FD8F5), Colors.white),
  copper(Color(0xFF4A2410), Color(0xFFC46A2E), Color(0xFFFFE0B2)),
  galaxy(Color(0xFF140A36), Color(0xFF6A3FD0), Color(0xFFE6D7FF));

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

/// The background of the menu screens: the still charcoal gradient of
/// [PremiumBackdrop]. [ambient] and [animated] are kept for the callers;
/// the background never moves.
class Felt extends StatelessWidget {
  const Felt({super.key, required this.child, this.ambient = false, this.animated = true});

  final Widget child;
  final bool ambient;
  final bool animated;

  @override
  Widget build(BuildContext context) => PremiumBackdrop(child: child);
}

/// The table cloth of the game screen: the chosen colour, a fine woven
/// texture and a dark edge (vignette), like a real card table.
class TableFelt extends StatelessWidget {
  const TableFelt({super.key, required this.child});

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

/// Text painted with a gold gradient (titles). With [depth] the letters
/// get a thickness, like engraved gold lettering.
class GoldText extends StatelessWidget {
  const GoldText(
    this.text, {
    super.key,
    required this.size,
    this.weight = FontWeight.w900,
    this.letterSpacing = 1.0,
    this.depth = 0,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final double letterSpacing;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: weight, letterSpacing: letterSpacing, height: 1.05);
    return Stack(
      children: <Widget>[
        // Soft shadow under the letters.
        ExcludeSemantics(
          child: Text(
            text,
            style: style.copyWith(
              color: Colors.transparent,
              shadows: <Shadow>[Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6))],
            ),
          ),
        ),
        // The thickness: copies of the text below it, darker the lower.
        for (var i = depth; i >= 1; i--)
          ExcludeSemantics(
            child: Transform.translate(
              offset: Offset(0, i.toDouble()),
              child: Text(
                text,
                style: style.copyWith(color: Color.lerp(PastraColors.goldDeep, const Color(0xFF4A2F06), i / depth)),
              ),
            ),
          ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF7E2B0), Color(0xFFE6B54A), Color(0xFFB8862B)],
            stops: <double>[0.0, 0.55, 1.0],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
