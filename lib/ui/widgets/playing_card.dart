import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../theme.dart';
import 'suit_icon.dart';

/// A card that fills the space it is given (aspect ratio is up to the parent,
/// normally 1 : 1.42).
///
/// For smooth animations the card is always drawn at one fixed size and
/// scaled to fit: a card that moves or grows only re-composites its cached
/// picture instead of being rebuilt and repainted every frame. Shadows are
/// solid (no blur), which is much cheaper on phones and in browsers.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    required this.card,
    required this.faceUp,
    this.highlighted = false,
    this.selected = false,
    this.covered = false,
    this.backStyle,
  });

  static const double baseWidth = 120;

  /// Back design; null = the one chosen in the settings ([Look.back]).
  final CardBackStyle? backStyle;
  static const double baseHeight = baseWidth * 1.42;

  final int card;
  final bool faceUp;

  /// Face up but under other cards: drawn as a blank card.
  final bool covered;

  /// Gold glow: this table card is (about to be) captured.
  final bool highlighted;

  /// White glow: the human's selected card.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const w = baseWidth;
    const h = baseHeight;
    final radius = BorderRadius.circular(w * 0.09);
    final glow = highlighted || selected;
    final glowColor = highlighted ? PastraColors.gold : Colors.white;
    final Widget content = !faceUp
        ? CardBack(key: const ValueKey<String>('back'), width: w, height: h, style: backStyle ?? Look.back)
        // Face and blank share one key, so covering a card (another one lands
        // on it) swaps the picture without a flip; only back <-> front flips.
        : KeyedSubtree(
            key: const ValueKey<String>('front'),
            child: covered
                ? const _BlankCard(width: w, height: h)
                : CardFace(
                    card: card,
                    width: w,
                    height: h,
                    highlighted: highlighted,
                  ),
          );
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: w,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: <BoxShadow>[
              BoxShadow(color: Colors.black.withValues(alpha: 0.28), offset: const Offset(0, 3)),
              if (glow) BoxShadow(color: glowColor.withValues(alpha: 0.9), spreadRadius: 5),
              if (glow) BoxShadow(color: glowColor.withValues(alpha: 0.35), spreadRadius: 10),
            ],
          ),
          child: RepaintBoundary(
            // Turning a card over: a short flip around the vertical axis.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: _flip,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: <Widget>[...previous, if (current != null) current],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The old side turns away (first half), the new side turns in (second half).
Widget _flip(Widget child, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final v = animation.value;
      // Hidden while the other side is still turning.
      if (v < 0.5) return const SizedBox.shrink();
      final angle = (1 - v) * pi;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle),
        child: child,
      );
    },
  );
}

class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.highlighted = false,
  });

  final int card;
  final double width;
  final double height;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = height;
    final color = Cards.isRed(card) ? PastraColors.cardRed : PastraColors.cardBlack;
    final suit = Cards.suit(card);
    final label = Cards.rankLabel(card);
    final corner = _Corner(label: label, suit: suit, color: color, cardWidth: w);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFDF7), PastraColors.cream, Color(0xFFF3EBDA)],
        ),
        borderRadius: BorderRadius.circular(w * 0.09),
        border: Border.all(
          color: highlighted ? PastraColors.gold : PastraColors.cardEdge,
          width: highlighted ? max(1.5, w * 0.035) : 1.0,
        ),
      ),
      child: Stack(
        children: <Widget>[
          // A fine frame line inside the edge, like printed cards.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(w * 0.035),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.06),
                  border: Border.all(color: color.withValues(alpha: 0.12), width: max(0.6, w * 0.008)),
                ),
              ),
            ),
          ),
          Positioned(left: w * 0.06, top: w * 0.05, child: corner),
          Positioned(
            right: w * 0.06,
            bottom: w * 0.05,
            child: Transform.rotate(angle: pi, child: corner),
          ),
          Positioned(
            left: w * 0.22,
            right: w * 0.22,
            top: h * 0.12,
            bottom: h * 0.12,
            child: _CardCenter(card: card, color: color, cardWidth: w),
          ),
        ],
      ),
    );
  }
}

/// A face-up card seen from the side of a pile: just the cream card.
class _BlankCard extends StatelessWidget {
  const _BlankCard({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PastraColors.cream,
        borderRadius: BorderRadius.circular(width * 0.09),
        border: Border.all(color: PastraColors.cardEdge, width: 1.0),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.label, required this.suit, required this.color, required this.cardWidth});

  final String label;
  final int suit;
  final Color color;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final w = cardWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: w * 0.22,
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: label.length > 1 ? -w * 0.02 : 0,
          ),
        ),
        SizedBox(height: w * 0.015),
        SuitIcon(suit: suit, size: w * 0.15, color: color),
      ],
    );
  }
}

class _CardCenter extends StatelessWidget {
  const _CardCenter({required this.card, required this.color, required this.cardWidth});

  final int card;
  final Color color;
  final double cardWidth;

  /// Pip positions (0..1 inside the centre box) for 2..10.
  static const Map<int, List<List<double>>> pips = <int, List<List<double>>>{
    2: [[0.5, 0.0], [0.5, 1.0]],
    3: [[0.5, 0.0], [0.5, 0.5], [0.5, 1.0]],
    4: [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]],
    5: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.5], [0.0, 1.0], [1.0, 1.0]],
    6: [[0.0, 0.0], [1.0, 0.0], [0.0, 0.5], [1.0, 0.5], [0.0, 1.0], [1.0, 1.0]],
    7: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.25], [0.0, 0.5], [1.0, 0.5], [0.0, 1.0], [1.0, 1.0]],
    8: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.25], [0.0, 0.5], [1.0, 0.5], [0.5, 0.75], [0.0, 1.0], [1.0, 1.0]],
    9: [[0.0, 0.0], [1.0, 0.0], [0.0, 0.333], [1.0, 0.333], [0.5, 0.5], [0.0, 0.667], [1.0, 0.667], [0.0, 1.0], [1.0, 1.0]],
    10: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.167], [0.0, 0.333], [1.0, 0.333], [0.0, 0.667], [1.0, 0.667], [0.5, 0.833], [0.0, 1.0], [1.0, 1.0]],
  };

  @override
  Widget build(BuildContext context) {
    final rank = Cards.rank(card);
    final suit = Cards.suit(card);
    final w = cardWidth;
    if (rank == Cards.ace || w < 40) {
      final big = rank == Cards.ace ? w * 0.42 : w * 0.34;
      return Center(child: SuitIcon(suit: suit, size: big, color: color));
    }
    if (rank > 10) return _FaceCardArt(card: card, color: color, cardWidth: w);
    final layout = pips[rank]!;
    final pip = rank >= 9 ? w * 0.17 : w * 0.19;
    return LayoutBuilder(builder: (context, box) {
      final bw = box.maxWidth;
      final bh = box.maxHeight;
      return Stack(
        children: <Widget>[
          for (final p in layout)
            Positioned(
              left: p[0] * (bw - pip),
              top: p[1] * (bh - pip),
              width: pip,
              height: pip,
              child: p[1] > 0.5
                  ? Transform.rotate(angle: pi, child: SuitIcon(suit: suit, size: pip, color: color))
                  : SuitIcon(suit: suit, size: pip, color: color),
            ),
        ],
      );
    });
  }
}

/// Original artwork for J / Q / K: a framed, two-ended panel (like real
/// court cards, readable from both sides) with an emblem in each half (a
/// crown for the king, a tiara for the queen, a plumed cap for the jack)
/// and the letter in a medallion in the middle.
class _FaceCardArt extends StatelessWidget {
  const _FaceCardArt({required this.card, required this.color, required this.cardWidth});

  final int card;
  final Color color;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CourtPainter(Cards.rank(card), Cards.suit(card), color),
      child: const SizedBox.expand(),
    );
  }
}

class _CourtPainter extends CustomPainter {
  _CourtPainter(this.rank, this.suit, this.ink);

  final int rank;
  final int suit;
  final Color ink;

  static const Color gold = Color(0xFFD4A43A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final red = suit == Cards.diamonds || suit == Cards.hearts;
    final tint = red ? const Color(0xFFFBE3DE) : const Color(0xFFE2E8F5);
    final frame = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.08));
    // Panel: the tint at both ends, white in the middle.
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[tint, Colors.white, tint],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.025)
        ..color = ink.withValues(alpha: 0.6),
    );
    // The diagonal line that splits the two ends.
    canvas.drawLine(
      Offset(w * 0.1, h * 0.62),
      Offset(w * 0.9, h * 0.38),
      Paint()
        ..color = ink.withValues(alpha: 0.18)
        ..strokeWidth = max(0.6, w * 0.012),
    );
    // Emblem at the top, the same turned round at the bottom.
    final emblem = Rect.fromCenter(center: Offset(w / 2, h * 0.19), width: w * 0.78, height: h * 0.28);
    _emblem(canvas, emblem);
    canvas.save();
    canvas.translate(w, h);
    canvas.rotate(pi);
    _emblem(canvas, emblem);
    canvas.restore();
    // Medallion with the letter.
    final c = Offset(w / 2, h / 2);
    final r = min(w, h) * 0.22;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.03)
        ..color = gold,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: Cards.rankLabel(Cards.make(suit, rank)),
        style: TextStyle(color: ink, fontSize: r * 1.25, fontWeight: FontWeight.w900, fontFamily: 'serif', height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  void _emblem(Canvas canvas, Rect r) {
    final fill = Paint()..color = gold;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, r.width * 0.035)
      ..strokeJoin = StrokeJoin.round;
    final jewel = Paint()..color = ink;
    switch (rank) {
      case Cards.king:
        // Crown: three points on a band, a jewel on each point.
        final base = r.top + r.height * 0.78;
        final path = Path()
          ..moveTo(r.left + r.width * 0.12, base)
          ..lineTo(r.left + r.width * 0.06, r.top + r.height * 0.22)
          ..lineTo(r.left + r.width * 0.32, r.top + r.height * 0.5)
          ..lineTo(r.center.dx, r.top + r.height * 0.08)
          ..lineTo(r.right - r.width * 0.32, r.top + r.height * 0.5)
          ..lineTo(r.right - r.width * 0.06, r.top + r.height * 0.22)
          ..lineTo(r.right - r.width * 0.12, base)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, line);
        final band = Rect.fromLTRB(r.left + r.width * 0.12, base, r.right - r.width * 0.12, base + r.height * 0.16);
        canvas.drawRect(band, fill);
        canvas.drawRect(band, line);
        for (final x in <double>[0.06, 0.5, 0.94]) {
          final y = x == 0.5 ? r.top + r.height * 0.08 : r.top + r.height * 0.22;
          canvas.drawCircle(Offset(r.left + r.width * x, y), r.width * 0.05, jewel);
        }
      case Cards.queen:
        // Tiara: an arch with five small points and a gem in the middle.
        final base = r.top + r.height * 0.82;
        final path = Path()..moveTo(r.left + r.width * 0.1, base);
        const peaks = 5;
        for (var i = 0; i <= peaks * 2; i++) {
          final t = i / (peaks * 2);
          final x = r.left + r.width * (0.1 + 0.8 * t);
          final arch = sin(t * pi);
          final up = i.isOdd ? r.height * 0.14 : 0.0;
          path.lineTo(x, base - r.height * (0.25 + 0.4 * arch) - up);
        }
        path
          ..lineTo(r.right - r.width * 0.1, base)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, line);
        final gem = Path()
          ..moveTo(r.center.dx, r.top + r.height * 0.18)
          ..lineTo(r.center.dx + r.width * 0.09, r.top + r.height * 0.42)
          ..lineTo(r.center.dx, r.top + r.height * 0.62)
          ..lineTo(r.center.dx - r.width * 0.09, r.top + r.height * 0.42)
          ..close();
        canvas.drawPath(gem, jewel);
      default:
        // Jack: a cap with a long feather.
        final cap = Rect.fromLTRB(r.left + r.width * 0.2, r.top + r.height * 0.3, r.right - r.width * 0.2, r.bottom + r.height * 0.3);
        final capPath = Path()
          ..addArc(cap, pi, pi)
          ..close();
        canvas.drawPath(capPath, fill);
        canvas.drawPath(capPath, line);
        final band = Rect.fromLTRB(r.left + r.width * 0.16, r.top + r.height * 0.74, r.right - r.width * 0.16, r.top + r.height * 0.92);
        canvas.drawRRect(RRect.fromRectAndRadius(band, Radius.circular(r.height * 0.05)), jewel);
        final feather = Path()
          ..moveTo(r.center.dx + r.width * 0.05, r.top + r.height * 0.4)
          ..quadraticBezierTo(r.right + r.width * 0.05, r.top - r.height * 0.1, r.right - r.width * 0.02, r.top + r.height * 0.05)
          ..quadraticBezierTo(r.right - r.width * 0.2, r.top + r.height * 0.12, r.center.dx + r.width * 0.05, r.top + r.height * 0.4)
          ..close();
        canvas.drawPath(feather, Paint()..color = ink.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_CourtPainter old) => old.rank != rank || old.suit != suit || old.ink != ink;
}

/// Card back: a lattice, a frame and a "Π" emblem in the chosen colours.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width, required this.height, this.style = CardBackStyle.aegean});

  final double width;
  final double height;
  final CardBackStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, height), painter: CardBackPainter(style));
  }
}

class CardBackPainter extends CustomPainter {
  const CardBackPainter([this.style = CardBackStyle.aegean]);

  final CardBackStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.09));
    canvas.drawRRect(outer, Paint()..color = Colors.white);
    final inner = outer.deflate(w * 0.055);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[style.dark, style.light],
        ).createShader(inner.outerRect),
    );
    canvas.save();
    canvas.clipRRect(inner);
    final line = Paint()
      ..color = style.accent.withValues(alpha: 0.16)
      ..strokeWidth = max(0.7, w * 0.012)
      ..style = PaintingStyle.stroke;
    final step = max(4.0, w * 0.14);
    for (var d = -h; d < w + h; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + h, h), line);
      canvas.drawLine(Offset(d + h, 0), Offset(d, h), line);
    }
    canvas.restore();
    canvas.drawRRect(
      inner.deflate(w * 0.045),
      Paint()
        ..color = style.accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.02),
    );
    // A Greek key (meander) band at the top and the bottom.
    if (w >= 40) {
      final band = inner.deflate(w * 0.045).outerRect;
      final unit = w * 0.1;
      final key = Paint()
        ..color = style.accent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, w * 0.012)
        ..strokeJoin = StrokeJoin.miter;
      for (final top in <bool>[true, false]) {
        final y0 = top ? band.top + w * 0.035 : band.bottom - w * 0.035 - unit;
        final count = ((band.width - w * 0.08) / unit).floor();
        final x0 = band.center.dx - count * unit / 2;
        for (var i = 0; i < count; i++) {
          final x = x0 + i * unit;
          final u = unit;
          final path = Path()
            ..moveTo(x, y0 + u)
            ..lineTo(x, y0)
            ..lineTo(x + u * 0.8, y0)
            ..lineTo(x + u * 0.8, y0 + u * 0.6)
            ..lineTo(x + u * 0.35, y0 + u * 0.6)
            ..lineTo(x + u * 0.35, y0 + u * 0.3)
            ..moveTo(x, y0 + u)
            ..lineTo(x + u, y0 + u);
          canvas.drawPath(path, key);
        }
      }
    }
    if (w >= 28) {
      final center = Offset(w / 2, h / 2);
      final r = w * 0.2;
      canvas.drawCircle(center, r, Paint()..color = style.accent);
      canvas.drawCircle(
        center,
        r * 0.8,
        Paint()
          ..color = style.dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, w * 0.018),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'Π',
          style: TextStyle(color: style.dark, fontSize: r * 1.05, fontWeight: FontWeight.w800, height: 1.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(CardBackPainter oldDelegate) => oldDelegate.style != style;
}
