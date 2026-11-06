import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'table_stage.dart';

/// A card on the table that glides to its new place instead of jumping
/// there. On a long way it rises a little (an arc, with a shadow growing
/// under it) and it turns to its new angle on the way. A dealt card can
/// leave a moment after the one before ([delay]).
///
/// [rect] is a place on the flat table. With a [geometry] the card is shown
/// where that place is seen on the screen: smaller further away and slanted
/// like the table under it (see [StageGeometry.slantAt]).
///
/// The [delay] is waited once for each [delayKey] (one deal, one capture):
/// when the place changes again later (a card rising under the mouse, a new
/// layout), the card goes on at once instead of stopping in the air.
///
/// It has to be a direct child of a [Stack] (it builds a [Positioned]).
class FlyCard extends StatefulWidget {
  const FlyCard({
    super.key,
    required this.rect,
    required this.angle,
    required this.duration,
    required this.child,
    this.delay = Duration.zero,
    this.delayKey,
    this.still = false,
    this.hop = true,
    this.geometry,
  });

  /// Where the card belongs.
  final Rect rect;

  /// Its angle in radians.
  final double angle;

  /// How long the move takes (after the [delay]).
  final Duration duration;
  final Duration delay;

  /// The move the [delay] belongs to (see the class description).
  final Object? delayKey;

  /// Follows [rect] at once, without gliding (a card held by a finger).
  final bool still;

  /// Rises on a long way (off in low graphics quality).
  final bool hop;

  /// How the table is seen; null: [rect] is already a place on the screen.
  final StageGeometry? geometry;

  final Widget child;

  @override
  State<FlyCard> createState() => _FlyCardState();
}

class _FlyCardState extends State<FlyCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late Rect _from = widget.rect;
  late Rect _to = widget.rect;
  late double _angleFrom = widget.angle;
  late double _angleTo = widget.angle;
  Curve _curve = Curves.easeOutCubic;

  /// The [FlyCard.delayKey] whose delay has been (or is being) waited. A new
  /// card lies where it belongs already.
  Object? _delayKey;

  /// Part of the running animation spent waiting.
  double _wait = 0;

  /// A short slide (a card rising under the mouse) takes at most this long.
  static const Duration _short = Duration(milliseconds: 130);

  /// How far the glide has come (0 = at [_from], 1 = at [_to]).
  double get _t => _curve.transform(_c.value.clamp(0.0, 1.0).toDouble());

  Rect get _rectNow => Rect.lerp(_from, _to, _t)!;

  double get _angleNow => _angleFrom + (_angleTo - _angleFrom) * _t;

  @override
  void initState() {
    super.initState();
    _delayKey = widget.delayKey;
  }

  @override
  void didUpdateWidget(FlyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final w = widget;
    final total = w.duration + w.delay;
    if (w.still || total <= Duration.zero) {
      _c.stop();
      _from = w.rect;
      _to = w.rect;
      _angleFrom = w.angle;
      _angleTo = w.angle;
      return;
    }
    if (w.rect == _to && w.angle == _angleTo) return;
    // The delay of a new move; for a later change only what is left of a
    // wait that is still running.
    final Duration wait;
    if (w.delayKey != _delayKey) {
      wait = w.delay;
      _delayKey = w.delayKey;
    } else if (_c.isAnimating && _c.value < _wait) {
      wait = (_c.duration ?? Duration.zero) * (_wait - _c.value);
    } else {
      wait = Duration.zero;
    }
    // The place changed: glide on from wherever the card is now.
    _from = _rectNow;
    _angleFrom = _angleNow;
    _to = w.rect;
    _angleTo = w.angle;
    var move = w.duration;
    if (wait == Duration.zero && (_to.center - _from.center).distance < _to.height * 0.15 && move > _short) {
      move = _short;
    }
    final run = move + wait;
    _wait = run > Duration.zero ? wait.inMicroseconds / run.inMicroseconds : 0;
    _curve = wait == Duration.zero ? Curves.easeOutCubic : Interval(_wait, 1, curve: Curves.easeOutCubic);
    _c.duration = run;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _t;
        final rect = Rect.lerp(_from, _to, t)!;
        final angle = _angleFrom + (_angleTo - _angleFrom) * t;
        // 0 on the ground, 1 at the top of the arc. Short moves (a card
        // sliding along its own hand) stay flat.
        var lift = 0.0;
        // A turn on the way (towards the side it flies to) and a little
        // bump when it lands: the card feels thrown, not slid.
        var spin = 0.0;
        var bump = 0.0;
        if (widget.hop && !widget.still && _c.isAnimating) {
          final way = _to.center - _from.center;
          final far = (way.distance / (_to.height * 2.2)).clamp(0.0, 1.0).toDouble();
          lift = math.sin(math.pi * t) * far;
          spin = math.sin(math.pi * t) * 0.14 * far * (way.dx >= 0 ? 1 : -1);
          if (far > 0.5 && t > 0.8) bump = math.sin(math.pi * (t - 0.8) / 0.2) * 0.05 * far;
        }
        final radius = BorderRadius.circular(rect.width * 0.09);
        // The place on the table (a flying card is a little higher), and
        // where it is seen on the screen.
        final place = rect.center - Offset(0, lift * rect.height * 0.45);
        final g = widget.geometry;
        final center = g == null ? place : g.project(place);
        // The same widgets whether the card flies or not, and on a flat or a
        // tilted table, so that a card that is being turned over keeps its
        // state. Each part is moved by one transform (fewer layers to put
        // together in every frame).
        final slant = g == null ? Matrix4.identity() : g.slantAt(place);
        final scale = 1 + 0.14 * lift + bump;
        final cardMatrix = slant.clone()
          ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
          ..rotateZ(angle + spin);
        return Positioned(
          left: center.dx - rect.width / 2,
          top: center.dy - rect.height / 2,
          width: rect.width,
          height: rect.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // The shadow on the table, further away the higher the card
              // (nothing while it lies on the table).
              Positioned.fill(
                child: lift <= 0
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: slant.clone()
                            ..translateByDouble(0, lift * rect.height * 0.22, 0, 1)
                            ..rotateZ(angle),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              color: Colors.black.withValues(alpha: 0.3 * lift),
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned.fill(
                child: Transform(alignment: Alignment.center, transform: cardMatrix, child: child),
              ),
            ],
          ),
        );
      },
    );
  }
}
