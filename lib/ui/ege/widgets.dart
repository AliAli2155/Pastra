import 'package:flutter/material.dart';

import '../palette.dart';
import '../premium/premium.dart';

/// A charcoal panel with a hairline edge (the premium look); [glow] gives
/// it a gold edge and a faint gold light.
BoxDecoration tabletDecoration({double radius = 20, bool glow = false}) =>
    panelDecoration(radius: radius, highlight: glow);

/// A small plate (name plates, counters, short messages on the table): dark
/// glass with a hairline. With [glow] the edge turns gold and a gold light
/// shines around the plate.
BoxDecoration plateDecoration({double radius = 12, bool glow = false, double edge = 0.4}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: const Color(0xD114161A),
    border: Border.all(
      color: glow ? PastraColors.gold.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.12 + edge * 0.1),
      width: glow ? 1.5 : 1,
    ),
    boxShadow: <BoxShadow>[
      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
      if (glow) BoxShadow(color: PastraColors.gold.withValues(alpha: 0.35), blurRadius: 14),
    ],
  );
}

/// A panel in the look of an inscribed tablet (with gold corner brackets).
class Tablet extends StatelessWidget {
  const Tablet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.glow = false,
    this.brackets = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;
  final bool brackets;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: tabletDecoration(radius: radius, glow: glow),
      child: Padding(padding: padding, child: child),
    );
    // [brackets] is kept for the callers; the premium look has no corner
    // ornaments.
    return box;
  }
}

/// A Greek key band (a thin decoration between sections).
class MeanderBand extends StatelessWidget {
  const MeanderBand({super.key, this.height = 12, this.opacity = 0.55});

  final double height;
  final double opacity;

  /// The premium look has no Greek key: the band only keeps its place (a
  /// hairline in the middle).
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: Container(height: 1, color: Colors.white.withValues(alpha: opacity * 0.15)),
      ),
    );
  }
}

/// Comes in once like a card dealt onto the table: it turns up from the
/// table, slides a little and fades in, [order] steps after the first one.
class DealIn extends StatelessWidget {
  const DealIn({super.key, required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (0.11 * order).clamp(0.0, 0.7).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + 90 * order),
      builder: (context, t, child) {
        final p = Curves.easeOutCubic.transform(((t - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble());
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - p)),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX((1 - p) * 0.9),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// A button of the premium look: gold with dark text for the main action,
/// glass for the others. (The name is from the older raised design.)
class BevelButton extends StatelessWidget {
  const BevelButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56,
    this.radius = 14,
    this.gold = true,
    this.shimmer = false,
    this.autofocus = false,
    this.fontSize = 19,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double radius;
  final bool gold;

  /// Kept for the callers: the premium buttons do not shimmer.
  final bool shimmer;
  final bool autofocus;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final fg = gold ? PastraColors.goldInk : PastraColors.text;
    return SizedBox(
      height: height,
      child: Pressable(
        onTap: onPressed,
        radius: r,
        autofocus: autofocus,
        decoration: gold
            ? BoxDecoration(
                gradient: goldGradient,
                borderRadius: r,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: PastraColors.goldBottom.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 8)),
                ],
              )
            : glassDecoration(radius: radius),
        child: Center(
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w800),
              child: IconTheme.merge(data: IconThemeData(color: fg), child: child),
            ),
          ),
        ),
      ),
    );
  }
}
