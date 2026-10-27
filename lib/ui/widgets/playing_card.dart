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
  });

  static const double baseWidth = 120;
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
        ? const CardBack(key: ValueKey<String>('back'), width: w, height: h)
        : covered
            ? const _BlankCard(key: ValueKey<String>('blank'), width: w, height: h)
            : CardFace(
                key: const ValueKey<String>('face'),
                card: card,
                width: w,
                height: h,
                highlighted: highlighted,
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
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
        color: PastraColors.cream,
        borderRadius: BorderRadius.circular(w * 0.09),
        border: Border.all(
          color: highlighted ? PastraColors.gold : PastraColors.cardEdge,
          width: highlighted ? max(1.5, w * 0.035) : 1.0,
        ),
      ),
      child: Stack(
        children: <Widget>[
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
  const _BlankCard({super.key, required this.width, required this.height});

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
            fontSize: w * 0.2,
            height: 1.0,
            fontWeight: FontWeight.w800,
            letterSpacing: label.length > 1 ? -w * 0.02 : 0,
          ),
        ),
        SizedBox(height: w * 0.015),
        SuitIcon(suit: suit, size: w * 0.14, color: color),
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

/// Simple, original artwork for J / Q / K: a framed panel with the letter.
class _FaceCardArt extends StatelessWidget {
  const _FaceCardArt({required this.card, required this.color, required this.cardWidth});

  final int card;
  final Color color;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final w = cardWidth;
    final tint = Cards.isRed(card) ? const Color(0xFFFCE4E0) : const Color(0xFFE3E8F4);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[tint, Colors.white, tint],
        ),
        border: Border.all(color: color.withValues(alpha: 0.55), width: max(1.0, w * 0.018)),
        borderRadius: BorderRadius.circular(w * 0.05),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            Cards.rankLabel(card),
            style: TextStyle(
              color: color,
              fontSize: w * 0.34,
              height: 1.0,
              fontWeight: FontWeight.w900,
              fontFamily: 'serif',
            ),
          ),
          SizedBox(height: w * 0.03),
          SuitIcon(suit: Cards.suit(card), size: w * 0.17, color: color),
        ],
      ),
    );
  }
}

/// Card back: Aegean blue with a lattice, a white frame and a "Π" emblem.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, height), painter: const CardBackPainter());
  }
}

class CardBackPainter extends CustomPainter {
  const CardBackPainter();

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
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[PastraColors.navy, PastraColors.aegean],
        ).createShader(inner.outerRect),
    );
    canvas.save();
    canvas.clipRRect(inner);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
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
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.02),
    );
    if (w >= 28) {
      final center = Offset(w / 2, h / 2);
      final r = w * 0.2;
      canvas.drawCircle(center, r, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        r * 0.8,
        Paint()
          ..color = PastraColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, w * 0.018),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'Π',
          style: TextStyle(color: PastraColors.navy, fontSize: r * 1.05, fontWeight: FontWeight.w800, height: 1.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(CardBackPainter oldDelegate) => false;
}
