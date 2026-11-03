import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fx/fx.dart';
import '../palette.dart';
import 'painters.dart';

/// The look of a stone tablet: dark navy, a gold hairline and a soft shadow.
BoxDecoration tabletDecoration({double radius = 20, bool glow = false}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xF01A2F63), Color(0xF00B1634)],
    ),
    border: Border.all(color: PastraColors.gold.withValues(alpha: glow ? 0.8 : 0.4), width: 1.2),
    boxShadow: <BoxShadow>[
      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8)),
      if (glow) BoxShadow(color: PastraColors.gold.withValues(alpha: 0.25), blurRadius: 22),
    ],
  );
}

/// A small plate (name plates, counters, short messages on the table): navy
/// with a gold hairline. With [glow] the edge is brighter and a gold light
/// shines around the plate.
BoxDecoration plateDecoration({double radius = 12, bool glow = false, double edge = 0.4}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xF01A2F63), Color(0xF00B1634)],
    ),
    border: Border.all(color: PastraColors.gold.withValues(alpha: glow ? 0.9 : edge), width: glow ? 1.5 : 1),
    boxShadow: <BoxShadow>[
      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
      if (glow) BoxShadow(color: PastraColors.gold.withValues(alpha: 0.4), blurRadius: 14),
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
    if (!brackets) return box;
    return CustomPaint(
      foregroundPainter: CornerBracketsPainter(color: PastraColors.gold.withValues(alpha: 0.5)),
      child: box,
    );
  }
}

/// A Greek key band (a thin decoration between sections).
class MeanderBand extends StatelessWidget {
  const MeanderBand({super.key, this.height = 12, this.opacity = 0.55});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: MeanderPainter(
          color: PastraColors.gold.withValues(alpha: opacity),
          stroke: math.max(1.0, height / 9),
        ),
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
/// quality).
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({super.key, required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));

  @override
  void initState() {
    super.initState();
    Fx.low.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (Fx.low.value) {
      _time.stop();
    } else if (!_time.isAnimating) {
      _time.repeat();
    }
  }

  @override
  void dispose() {
    Fx.low.removeListener(_sync);
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

/// A raised button with a visible lower edge that sinks when pressed. Gold
/// for the main action, dark blue ("lapis") for the others.
class BevelButton extends StatefulWidget {
  const BevelButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56,
    this.radius = 16,
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
  final bool shimmer;
  final bool autofocus;
  final double fontSize;
  final EdgeInsets padding;

  @override
  State<BevelButton> createState() => _BevelButtonState();
}

class _BevelButtonState extends State<BevelButton> {
  static const double _edge = 5;

  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final gold = widget.gold;
    final r = BorderRadius.circular(widget.radius);
    final fg = gold ? const Color(0xFF2A1A00) : Colors.white;
    final faceColors = gold
        ? const <Color>[PastraColors.goldLight, PastraColors.gold, Color(0xFFD9A234)]
        : const <Color>[Color(0xFF26407F), Color(0xFF162B60), Color(0xFF0F2048)];
    final edgeColor = gold ? PastraColors.goldDeep : const Color(0xFF050D24);
    final top = _down ? _edge - 1 : (_hover && enabled ? -1.0 : 0.0);
    final button = SizedBox(
      height: widget.height + _edge,
      child: Stack(
        children: <Widget>[
          // The lower edge: the thickness of the button.
          Positioned(
            left: 0,
            right: 0,
            top: _edge,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                color: edgeColor,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Colors.black.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 8)),
                ],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: top,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: faceColors,
                  stops: const <double>[0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: (gold ? PastraColors.goldLight : PastraColors.gold).withValues(alpha: gold ? 0.9 : 0.45),
                  width: 1.2,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: r,
                  autofocus: widget.autofocus,
                  onTap: widget.onPressed,
                  onHighlightChanged: (v) => setState(() => _down = v),
                  onHover: (v) => setState(() => _hover = v),
                  child: Stack(
                    children: <Widget>[
                      if (widget.shimmer && enabled) Positioned.fill(child: ShimmerSweep(borderRadius: r)),
                      // The light along the upper edge.
                      Positioned(
                        left: widget.radius,
                        right: widget.radius,
                        top: 2,
                        height: 1.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: Colors.white.withValues(alpha: gold ? 0.55 : 0.2),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: widget.padding,
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: fg, fontSize: widget.fontSize, fontWeight: FontWeight.w800),
                            child: IconTheme.merge(data: IconThemeData(color: fg), child: widget.child),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return enabled ? button : Opacity(opacity: 0.45, child: button);
  }
}
