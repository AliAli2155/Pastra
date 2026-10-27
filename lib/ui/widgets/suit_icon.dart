import 'package:flutter/material.dart';

import '../../engine/cards.dart';

/// Suit symbol drawn with paths, so it looks the same on every device (the
/// ♠♥♦♣ characters render as emoji on some phones).
class SuitIcon extends StatelessWidget {
  const SuitIcon({super.key, required this.suit, required this.size, required this.color});

  final int suit;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: SuitPainter(suit, color),
    );
  }
}

class SuitPainter extends CustomPainter {
  SuitPainter(this.suit, this.color);

  final int suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final w = size.width;
    final h = size.height;
    switch (suit) {
      case Cards.hearts:
        canvas.drawPath(heartPath(w, h), paint);
        break;
      case Cards.diamonds:
        canvas.drawPath(diamondPath(w, h), paint);
        break;
      case Cards.spades:
        canvas.drawPath(spadePath(w, h), paint);
        canvas.drawPath(stemPath(w, h), paint);
        break;
      default:
        drawClub(canvas, w, h, paint);
    }
  }

  static Path heartPath(double w, double h) {
    return Path()
      ..moveTo(0.5 * w, 0.96 * h)
      ..cubicTo(0.18 * w, 0.72 * h, 0.0, 0.52 * h, 0.0, 0.31 * h)
      ..cubicTo(0.0, 0.13 * h, 0.13 * w, 0.03 * h, 0.27 * w, 0.03 * h)
      ..cubicTo(0.38 * w, 0.03 * h, 0.46 * w, 0.09 * h, 0.5 * w, 0.19 * h)
      ..cubicTo(0.54 * w, 0.09 * h, 0.62 * w, 0.03 * h, 0.73 * w, 0.03 * h)
      ..cubicTo(0.87 * w, 0.03 * h, 1.0 * w, 0.13 * h, 1.0 * w, 0.31 * h)
      ..cubicTo(1.0 * w, 0.52 * h, 0.82 * w, 0.72 * h, 0.5 * w, 0.96 * h)
      ..close();
  }

  static Path diamondPath(double w, double h) {
    return Path()
      ..moveTo(0.5 * w, 0.02 * h)
      ..quadraticBezierTo(0.68 * w, 0.28 * h, 0.88 * w, 0.5 * h)
      ..quadraticBezierTo(0.68 * w, 0.72 * h, 0.5 * w, 0.98 * h)
      ..quadraticBezierTo(0.32 * w, 0.72 * h, 0.12 * w, 0.5 * h)
      ..quadraticBezierTo(0.32 * w, 0.28 * h, 0.5 * w, 0.02 * h)
      ..close();
  }

  static Path spadePath(double w, double h) {
    return Path()
      ..moveTo(0.5 * w, 0.02 * h)
      ..cubicTo(0.66 * w, 0.2 * h, 1.0 * w, 0.38 * h, 1.0 * w, 0.6 * h)
      ..cubicTo(1.0 * w, 0.76 * h, 0.87 * w, 0.84 * h, 0.74 * w, 0.84 * h)
      ..cubicTo(0.62 * w, 0.84 * h, 0.54 * w, 0.77 * h, 0.5 * w, 0.7 * h)
      ..cubicTo(0.46 * w, 0.77 * h, 0.38 * w, 0.84 * h, 0.26 * w, 0.84 * h)
      ..cubicTo(0.13 * w, 0.84 * h, 0.0, 0.76 * h, 0.0, 0.6 * h)
      ..cubicTo(0.0, 0.38 * h, 0.34 * w, 0.2 * h, 0.5 * w, 0.02 * h)
      ..close();
  }

  /// Stem shared by spades and clubs.
  static Path stemPath(double w, double h) {
    return Path()
      ..moveTo(0.455 * w, 0.5 * h)
      ..quadraticBezierTo(0.44 * w, 0.88 * h, 0.27 * w, 0.99 * h)
      ..lineTo(0.73 * w, 0.99 * h)
      ..quadraticBezierTo(0.56 * w, 0.88 * h, 0.545 * w, 0.5 * h)
      ..close();
  }

  static void drawClub(Canvas canvas, double w, double h, Paint paint) {
    final r = 0.215 * w;
    canvas.drawCircle(Offset(0.5 * w, 0.26 * h), r, paint);
    canvas.drawCircle(Offset(0.265 * w, 0.56 * h), r, paint);
    canvas.drawCircle(Offset(0.735 * w, 0.56 * h), r, paint);
    canvas.drawCircle(Offset(0.5 * w, 0.48 * h), r * 0.6, paint);
    canvas.drawPath(stemPath(w, h), paint);
  }

  @override
  bool shouldRepaint(SuitPainter oldDelegate) => oldDelegate.suit != suit || oldDelegate.color != color;
}
