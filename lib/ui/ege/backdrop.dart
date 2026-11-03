import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../fx/fx.dart';
import '../palette.dart';

/// The night sky and the sea behind every menu screen: stars that twinkle,
/// a harvest moon with its glitter on the water, slow waves in perspective
/// and (on the home screen) lantern sparks rising. In low quality it is one
/// still picture.
class AegeanBackdrop extends StatefulWidget {
  const AegeanBackdrop({super.key, required this.child, this.ambient = false});

  final Widget child;

  /// Lantern sparks rising (home screen).
  final bool ambient;

  @override
  State<AegeanBackdrop> createState() => _AegeanBackdropState();
}

class _AegeanBackdropState extends State<AegeanBackdrop> with SingleTickerProviderStateMixin {
  /// Time of the picture from 0 to 1 (one round takes a minute). It is
  /// updated about 30 times a second, which is smooth enough for slow stars
  /// and waves and half the work of a full 60.
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    Fx.low.addListener(_sync);
    _sync();
  }

  void _onTick(Duration elapsed) {
    if ((elapsed - _last).inMilliseconds < 33) return;
    _last = elapsed;
    _clock.value = (elapsed.inMilliseconds / 60000.0) % 1.0;
  }

  void _sync() {
    if (Fx.low.value) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    Fx.low.removeListener(_sync);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: ValueListenableBuilder<bool>(
                valueListenable: Fx.low,
                builder: (context, low, _) => CustomPaint(
                  painter: _SkyPainter(_clock, ambient: widget.ambient && !low),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Star {
  const _Star(this.x, this.y, this.r, this.phase);

  final double x;
  final double y;
  final double r;
  final double phase;
}

class _Spark {
  const _Spark(this.x, this.speed, this.phase, this.size);

  final double x;
  final double speed;
  final double phase;
  final double size;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.time, {required this.ambient}) : super(repaint: time);

  final ValueNotifier<double> time;
  final bool ambient;

  static final List<_Star> _stars = _makeStars();
  static final List<_Spark> _sparks = _makeSparks();

  static List<_Star> _makeStars() {
    final rng = math.Random(11);
    return List<_Star>.generate(
      72,
      (_) => _Star(rng.nextDouble(), rng.nextDouble() * 0.58, 0.5 + rng.nextDouble() * 1.3, rng.nextDouble()),
    );
  }

  static List<_Spark> _makeSparks() {
    final rng = math.Random(29);
    return List<_Spark>.generate(
      18,
      (_) => _Spark(rng.nextDouble(), 0.5 + rng.nextDouble(), rng.nextDouble(), 1.0 + rng.nextDouble() * 1.8),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final t = time.value;
    final horizon = h * 0.6;

    // Sky, horizon and sea.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF030614),
            Color(0xFF0A1636),
            Color(0xFF1A3F80),
            Color(0xFF0E3270),
            Color(0xFF071B40),
            Color(0xFF040C20),
          ],
          stops: <double>[0.0, 0.34, 0.6, 0.6, 0.78, 1.0],
        ).createShader(rect),
    );

    // A soft glow where the sky meets the sea.
    final glowRect = Rect.fromLTWH(0, horizon - h * 0.14, w, h * 0.14);
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            PastraColors.seaLight.withValues(alpha: 0.0),
            PastraColors.seaLight.withValues(alpha: 0.2),
          ],
        ).createShader(glowRect),
    );

    // Stars.
    final starPaint = Paint();
    for (final s in _stars) {
      final twinkle = 0.6 + 0.4 * math.sin((t * 12 + s.phase) * math.pi * 2);
      final base = 0.35 + 0.4 * ((s.r - 0.5) / 1.3);
      starPaint.color = Colors.white.withValues(alpha: (twinkle * base).clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(Offset(s.x * w, s.y * h), s.r, starPaint);
    }

    // The moon and its glow.
    final moon = Offset(w * 0.84, h * 0.2);
    final mr = math.min(w, h) * 0.055;
    final glowCircle = Rect.fromCircle(center: moon, radius: mr * 5);
    canvas.drawCircle(
      moon,
      mr * 5,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            PastraColors.goldLight.withValues(alpha: 0.26),
            PastraColors.goldLight.withValues(alpha: 0.0),
          ],
        ).createShader(glowCircle),
    );
    canvas.drawCircle(moon, mr, Paint()..color = const Color(0xFFFFF3D2));

    // Glitter of the moon on the water.
    final sea = h - horizon;
    final glitter = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var j = 0; j < 12; j++) {
      final f = (j + 1) / 12;
      final y = horizon + sea * f * f * 0.85;
      final half = mr * (0.5 + f * 4) * (0.55 + 0.45 * math.sin((t * 20 + j * 0.7) * math.pi * 2));
      glitter.color = PastraColors.goldLight.withValues(alpha: 0.42 * (1 - f * 0.8));
      canvas.drawLine(Offset(moon.dx - half, y), Offset(moon.dx + half, y), glitter);
    }

    // Waves in perspective: close together at the horizon, wider apart near
    // the viewer.
    final line = Paint()..style = PaintingStyle.stroke;
    const lines = 9;
    for (var i = 0; i < lines; i++) {
      final f = (i + 1) / lines;
      final y0 = horizon + sea * f * f;
      final amp = 1.5 + 5 * f;
      final length = 40 + 130 * f;
      final shift = t * math.pi * 2 * 5 * (i.isEven ? 1 : -1);
      final path = Path()..moveTo(0, y0 + amp * math.sin(shift));
      for (var x = 14.0; x <= w + 14; x += 14) {
        path.lineTo(x, y0 + amp * math.sin(x / length * math.pi * 2 + shift));
      }
      line
        ..strokeWidth = 1 + f * 1.6
        ..color = PastraColors.foam.withValues(alpha: 0.04 + 0.1 * f);
      canvas.drawPath(path, line);
    }

    // Lantern sparks rising.
    if (ambient) {
      final spark = Paint();
      for (final s in _sparks) {
        final p = (t * s.speed * 6 + s.phase) % 1.0;
        final x = s.x * w + math.sin(t * 40 + s.phase * 9) * 14;
        final y = h * (1.0 - p);
        final fade = math.sin(p * math.pi);
        spark.color = PastraColors.lantern.withValues(alpha: 0.55 * fade);
        canvas.drawCircle(Offset(x, y), s.size, spark);
        spark.color = PastraColors.lantern.withValues(alpha: 0.12 * fade);
        canvas.drawCircle(Offset(x, y), s.size * 3.2, spark);
      }
    }

    // Dark edges.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.1,
          colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.5)],
          stops: const <double>[0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.ambient != ambient;
}
