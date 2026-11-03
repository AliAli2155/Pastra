import 'package:flutter/material.dart';

/// A Greek key (meander) band: hooks standing on a running line.
class MeanderPainter extends CustomPainter {
  const MeanderPainter({required this.color, this.stroke = 1.6});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height;
    final a = h / 4;
    final period = a * 6;
    final path = Path();
    for (var x = 0.0; x < size.width; x += period) {
      path
        ..moveTo(x, h)
        ..lineTo(x, 0)
        ..lineTo(x + a * 4, 0)
        ..lineTo(x + a * 4, a * 3)
        ..lineTo(x + a * 2, a * 3)
        ..lineTo(x + a * 2, a * 1.5)
        ..lineTo(x + a * 3, a * 1.5)
        ..moveTo(x + a * 4, h)
        ..lineTo(x + period, h);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(MeanderPainter old) => old.color != color || old.stroke != stroke;
}

/// Four corner brackets, like the corners of an inscribed stone tablet.
class CornerBracketsPainter extends CustomPainter {
  const CornerBracketsPainter({required this.color, this.inset = 5, this.length = 10, this.stroke = 1.4});

  final Color color;
  final double inset;
  final double length;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide < (inset + length) * 2) return;
    final l = inset;
    final t = inset;
    final r = size.width - inset;
    final b = size.height - inset;
    final path = Path()
      ..moveTo(l, t + length)
      ..lineTo(l, t)
      ..lineTo(l + length, t)
      ..moveTo(r - length, t)
      ..lineTo(r, t)
      ..lineTo(r, t + length)
      ..moveTo(r, b - length)
      ..lineTo(r, b)
      ..lineTo(r - length, b)
      ..moveTo(l + length, b)
      ..lineTo(l, b)
      ..lineTo(l, b - length);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(CornerBracketsPainter old) => old.color != color || old.inset != inset || old.length != length;
}

/// A light band that sweeps over a button once while [time] runs from 0 to
/// 1 (nothing at 0 and 1).
class SweepPainter extends CustomPainter {
  SweepPainter(this.time) : super(repaint: time);

  final Animation<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final p = time.value;
    if (p <= 0 || p >= 1 || size.isEmpty) return;
    final bw = size.width * 0.2;
    final skew = size.height * 0.5;
    final x = -bw - skew + (size.width + bw * 2 + skew) * p;
    final band = Path()
      ..moveTo(x, 0)
      ..lineTo(x + bw, 0)
      ..lineTo(x + bw - skew, size.height)
      ..lineTo(x - skew, size.height)
      ..close();
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(x - skew, 0, bw + skew, size.height)),
    );
  }

  @override
  bool shouldRepaint(SweepPainter old) => old.time != time;
}
