import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fx/fx.dart';
import '../palette.dart';
import '../premium/premium.dart';
import 'painters.dart';

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

/// Turns its child in 3D towards the pointer (the mouse on a computer, a
/// finger that drags on a phone). With [idleSway] it also rocks gently by
/// itself, unless the graphics quality is low.
class Tilt3D extends StatefulWidget {
  const Tilt3D({
    super.key,
    required this.child,
    this.maxAngle = 0.2,
    this.idleSway = 0,
    this.borderRadius,
    this.glare = false,
    this.enabled = true,
  });

  final Widget child;

  /// Largest turn in radians (with the pointer at an edge).
  final double maxAngle;

  /// Gentle rocking when nobody points at it: 0 = none, 1 = as far as the
  /// pointer at an edge.
  final double idleSway;

  /// Corners of the glare (when [glare] is on).
  final BorderRadius? borderRadius;

  /// A light streak that slides over the surface while it turns.
  final bool glare;
  final bool enabled;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  /// Pointer position from -1 to 1 around the centre; null = nobody.
  Offset? _pointer;

  @override
  void initState() {
    super.initState();
    Fx.low.addListener(_sync);
    _sync();
  }

  void _sync() {
    final run = widget.enabled && widget.idleSway > 0 && !Fx.low.value;
    if (run && !_idle.isAnimating) {
      _idle.repeat();
    } else if (!run && _idle.isAnimating) {
      _idle.stop();
    }
  }

  @override
  void didUpdateWidget(Tilt3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    Fx.low.removeListener(_sync);
    _idle.dispose();
    super.dispose();
  }

  void _point(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _pointer = Offset(
        (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0).toDouble(),
        (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0).toDouble(),
      );
    });
  }

  void _release() {
    if (_pointer != null) setState(() => _pointer = null);
  }

  Offset _target() {
    final p = _pointer;
    if (p != null) return p;
    if (widget.idleSway > 0 && !Fx.low.value) {
      final a = _idle.value * math.pi * 2;
      return Offset(math.sin(a) * widget.idleSway, math.cos(a) * widget.idleSway * 0.6);
    }
    return Offset.zero;
  }

  Widget _turned(Offset t, Widget child) {
    Widget content = child;
    if (widget.glare) {
      content = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment(-1.6 - t.dx * 1.5, -1.6 - t.dy * 1.5),
                    end: Alignment(0.4 - t.dx * 1.5, 0.4 - t.dy * 1.5),
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(-t.dy * widget.maxAngle)
        ..rotateY(t.dx * widget.maxAngle),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return MouseRegion(
      onHover: (e) => _point(e.localPosition),
      onExit: (_) => _release(),
      child: Listener(
        onPointerMove: (e) => _point(e.localPosition),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedBuilder(
          animation: _idle,
          builder: (context, _) => TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(end: _target()),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, t, child) => _turned(t, child!),
            child: widget.child,
          ),
        ),
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

/// A light band that sweeps over its parent now and then (not in low
/// quality). Between two sweeps nothing moves, so nothing has to be drawn.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({super.key, required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  /// Waits for the next sweep.
  Timer? _rest;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    Fx.low.addListener(_sync);
    _sync();
  }

  void _sync() {
    _rest?.cancel();
    _rest = null;
    _time.stop();
    _time.value = 0;
    // The first sweep comes a moment after the button appears.
    if (!Fx.low.value) _rest = Timer(const Duration(milliseconds: 1400), _sweep);
  }

  void _sweep() {
    _rest = null;
    if (_disposed || Fx.low.value) return;
    _time.forward(from: 0).whenComplete(() {
      if (_disposed || Fx.low.value || _rest != null) return;
      _rest = Timer(const Duration(milliseconds: 5600), _sweep);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    Fx.low.removeListener(_sync);
    _rest?.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: CustomPaint(painter: SweepPainter(_time)),
      ),
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
