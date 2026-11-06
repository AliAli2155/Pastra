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
    this.simple = false,
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

  /// Face down deep in a stack, where nobody can see it: the back is drawn
  /// without its pattern (much less to paint for a deck of 36 cards).
  final bool simple;

  /// Gold glow: this table card is (about to be) captured.
  final bool highlighted;

  /// White glow: the human's selected card.
  final bool selected;

  static final BorderRadius _radius = BorderRadius.circular(baseWidth * 0.08);

  @override
  Widget build(BuildContext context) {
    const w = baseWidth;
    const h = baseHeight;
    final glow = highlighted || selected;
    final glowColor = highlighted ? PastraColors.gold : Colors.white;
    // The shadow belongs to each side, so that a card being turned over
    // narrows together with its shadow.
    final shadow = BoxDecoration(
      borderRadius: _radius,
      boxShadow: <BoxShadow>[
        BoxShadow(color: Colors.black.withValues(alpha: 0.28), offset: const Offset(0, 3)),
        if (glow) BoxShadow(color: glowColor.withValues(alpha: 0.9), spreadRadius: 5),
        if (glow) BoxShadow(color: glowColor.withValues(alpha: 0.35), spreadRadius: 10),
      ],
    );
    final Widget content = !faceUp
        ? DecoratedBox(
            key: const ValueKey<String>('back'),
            decoration: shadow,
            child: RepaintBoundary(
              child: CardBack(width: w, height: h, style: backStyle ?? Look.back, simple: simple),
            ),
          )
        // Face and blank share one key, so covering a card (another one lands
        // on it) swaps the picture without a flip; only back <-> front flips.
        : DecoratedBox(
            key: const ValueKey<String>('front'),
            decoration: shadow,
            child: RepaintBoundary(
              child: covered
                  ? const _BlankCard(width: w, height: h)
                  : CardFace(card: card, width: w, height: h, highlighted: highlighted),
            ),
          );
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: w,
        height: h,
        // Turning a card over: a short flip around the vertical axis.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: _flip,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: <Widget>[...previous, if (current != null) current],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Turning a card over, drawn flat (a perspective turn is slow in a
/// browser): the old side narrows to its edge while the card lifts a little
/// and darkens, then the new side opens out of the edge. The old side does
/// the first half, the new side the second.
Widget _flip(Widget child, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final v = animation.value;
      // Hidden while the other side is still turning.
      if (v < 0.5) return const SizedBox.shrink();
      // 0 = lying flat, 1 = seen edge on.
      final turn = (1 - v) * 2;
      final narrow = cos(turn * pi / 2);
      final lift = 1 + 0.07 * sin(turn * pi / 2);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(narrow * lift, lift, 1),
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            child!,
            if (turn > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: PlayingCardView._radius,
                      color: Colors.black.withValues(alpha: 0.32 * turn),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    // A plain cream card with a fine edge (gold when it is about to be
    // captured) and a faint sheen towards the bottom.
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[PastraColors.cream, Color(0xFFF4EFE3)],
        ),
        borderRadius: BorderRadius.circular(w * 0.08),
        border: Border.all(
          color: highlighted ? PastraColors.gold : const Color(0xFFD8D0BE),
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
        borderRadius: BorderRadius.circular(width * 0.08),
        border: Border.all(color: const Color(0xFFD8D0BE), width: 1.0),
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
            fontSize: w * 0.23,
            height: 1.0,
            fontWeight: FontWeight.w700,
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

/// Original artwork for J / Q / K: a two-ended court card (readable from
/// both sides) with an art-deco portrait in each half — the king with a
/// crown and a beard, the queen with a tiara and long hair, the jack with a
/// plumed cap — on a deep panel in a gold frame, and the suit in a cream
/// medallion on the gold band between the two halves.
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

  /// The suit colour (red or black) of the medallion in the middle.
  final Color ink;

  static const Color gold = Color(0xFFE6B54A);
  static const Color goldLight = Color(0xFFF7E2B0);
  static const Color goldDark = Color(0xFF8A6212);
  static const Color skin = Color(0xFFF4E6CB);

  bool get _red => suit == Cards.diamonds || suit == Cards.hearts;

  /// Rubies on the red cards, turquoise on the black ones.
  Color get _jewel => _red ? const Color(0xFFE0574A) : const Color(0xFF5FD3C2);

  /// The robe: charcoal on the burgundy panel, emerald on the charcoal one.
  List<Color> get _robe =>
      _red ? const <Color>[Color(0xFF2A2E36), Color(0xFF111316)] : const <Color>[Color(0xFF16A07A), Color(0xFF064734)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final panel = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.08));
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _red
              ? const <Color>[Color(0xFF8A2A22), Color(0xFF5E1712), Color(0xFF8A2A22)]
              : const <Color>[Color(0xFF2E333B), Color(0xFF16181D), Color(0xFF2E333B)],
        ).createShader(Offset.zero & size),
    );

    // A faint gold lattice behind the portraits.
    final inner = panel.deflate(w * 0.06);
    canvas.save();
    canvas.clipRRect(inner);
    final lattice = Paint()
      ..color = gold.withValues(alpha: 0.08)
      ..strokeWidth = max(0.5, w * 0.008);
    final step = w * 0.16;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
      canvas.drawLine(Offset(x + h, 0), Offset(x, h), lattice);
    }

    // The portrait in the top half, the same turned round in the bottom one.
    final half = Rect.fromLTWH(0, 0, w, h / 2);
    canvas.save();
    canvas.clipRect(half);
    _portrait(canvas, half);
    canvas.restore();
    canvas.save();
    canvas.translate(w, h);
    canvas.rotate(pi);
    canvas.clipRect(half);
    _portrait(canvas, half);
    canvas.restore();
    canvas.restore();

    // Gold frame with a fine line inside it.
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.9, w * 0.035)
        ..color = gold,
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.5, w * 0.012)
        ..color = gold.withValues(alpha: 0.6),
    );

    // The gold band between the halves with the suit in a cream medallion.
    final c = Offset(w / 2, h / 2);
    final band = Paint()
      ..color = gold
      ..strokeWidth = max(0.8, w * 0.022);
    canvas.drawLine(Offset(inner.left, c.dy), Offset(inner.right, c.dy), band);
    final r = w * 0.16;
    canvas.drawCircle(c, r * 1.12, Paint()..color = goldDark);
    canvas.drawCircle(c, r, Paint()..color = PastraColors.cream);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.025)
        ..color = gold,
    );
    final s = r * 1.15;
    canvas.save();
    canvas.translate(c.dx - s / 2, c.dy - s / 2);
    SuitPainter(suit, ink).paint(canvas, Size(s, s));
    canvas.restore();
  }

  /// One half: a bust from the shoulders up, facing the viewer.
  void _portrait(Canvas canvas, Rect r) {
    final w = r.width;
    final hh = r.height;
    final cx = r.center.dx;
    final headY = r.top + hh * 0.5;
    final rx = w * 0.19;
    final ry = w * 0.235;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..color = goldDark
      ..strokeWidth = max(0.6, w * 0.014)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final goldFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFFF2C866), Color(0xFFD9A033)],
      ).createShader(r);
    final jewel = Paint()..color = _jewel;

    // Behind the head: the queen's long hair, the king's hair.
    if (rank == Cards.queen) {
      // Long hair that ends in a curl on each shoulder.
      final end = r.top + hh * 0.8;
      final hair = Path()
        ..moveTo(cx - rx * 0.9, end)
        ..quadraticBezierTo(cx - rx * 1.75, end + hh * 0.02, cx - rx * 1.55, headY + ry * 0.2)
        ..cubicTo(cx - rx * 1.7, headY - ry * 0.9, cx - rx * 1.2, headY - ry * 1.35, cx, headY - ry * 1.3)
        ..cubicTo(cx + rx * 1.2, headY - ry * 1.35, cx + rx * 1.7, headY - ry * 0.9, cx + rx * 1.55, headY + ry * 0.2)
        ..quadraticBezierTo(cx + rx * 1.75, end + hh * 0.02, cx + rx * 0.9, end)
        ..close();
      canvas.drawPath(hair, goldFill);
      canvas.drawPath(hair, outline);
    } else if (rank == Cards.king) {
      final hair = Path()
        ..moveTo(cx - rx * 1.25, headY + ry * 0.35)
        ..quadraticBezierTo(cx - rx * 1.35, headY - ry * 1.0, cx, headY - ry * 1.1)
        ..quadraticBezierTo(cx + rx * 1.35, headY - ry * 1.0, cx + rx * 1.25, headY + ry * 0.35)
        ..close();
      canvas.drawPath(hair, goldFill);
      canvas.drawPath(hair, outline);
    }

    // Shoulders and robe with a gold-trimmed neckline.
    final shoulderY = r.top + hh * 0.84;
    final robe = Path()
      ..moveTo(r.left + w * 0.1, r.bottom)
      ..quadraticBezierTo(r.left + w * 0.11, shoulderY - hh * 0.01, cx - rx * 0.8, shoulderY - hh * 0.03)
      ..lineTo(cx + rx * 0.8, shoulderY - hh * 0.03)
      ..quadraticBezierTo(r.right - w * 0.11, shoulderY - hh * 0.01, r.right - w * 0.1, r.bottom)
      ..close();
    canvas.drawPath(
      robe,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _robe,
        ).createShader(Rect.fromLTRB(r.left, shoulderY, r.right, r.bottom)),
    );
    canvas.drawPath(robe, outline..color = gold);
    outline.color = goldDark;

    // Neck.
    final neck = Rect.fromLTRB(cx - rx * 0.42, headY + ry * 0.6, cx + rx * 0.42, shoulderY);
    canvas.drawRect(neck, Paint()..color = skin);

    // V collar: gold for the king, cream lace for the queen, a ruff for the jack.
    final collar = Path()
      ..moveTo(cx - rx * 1.1, shoulderY - hh * 0.03)
      ..lineTo(cx, r.bottom)
      ..lineTo(cx + rx * 1.1, shoulderY - hh * 0.03)
      ..lineTo(cx + rx * 0.5, shoulderY - hh * 0.03)
      ..lineTo(cx, shoulderY + hh * 0.08)
      ..lineTo(cx - rx * 0.5, shoulderY - hh * 0.03)
      ..close();
    canvas.drawPath(collar, rank == Cards.queen ? (Paint()..color = goldLight) : goldFill);
    canvas.drawPath(collar, outline);
    if (rank == Cards.jack) {
      // Ruff: a row of small cream scallops under the chin.
      for (var i = -2; i <= 2; i++) {
        canvas.drawCircle(Offset(cx + i * rx * 0.36, shoulderY - hh * 0.04), rx * 0.2, Paint()..color = goldLight);
        canvas.drawCircle(Offset(cx + i * rx * 0.36, shoulderY - hh * 0.04), rx * 0.2, outline);
      }
    }
    if (rank == Cards.queen) {
      // Necklace of small jewels along the neckline.
      for (var i = -2; i <= 2; i++) {
        final t = i / 2;
        canvas.drawCircle(Offset(cx + t * rx * 0.9, shoulderY - hh * 0.06 + t * t * hh * 0.035), w * 0.022, jewel);
      }
    }

    // Face.
    final face = Rect.fromCenter(center: Offset(cx, headY), width: rx * 2, height: ry * 2);
    canvas.drawOval(face, Paint()..color = skin);
    // A touch of colour on the cheeks.
    for (final side in <double>[-1, 1]) {
      canvas.drawCircle(
        Offset(cx + side * rx * 0.55, headY + ry * 0.28),
        rx * 0.2,
        Paint()..color = const Color(0xFFE0574A).withValues(alpha: 0.22),
      );
    }
    canvas.drawOval(face, outline);
    final features = Paint()
      ..style = PaintingStyle.stroke
      ..color = goldDark
      ..strokeWidth = max(0.5, w * 0.012)
      ..strokeCap = StrokeCap.round;
    // Open eyes (a dot under a lid), brows and nose.
    for (final side in <double>[-1, 1]) {
      final ex = cx + side * rx * 0.4;
      final ey = headY - ry * 0.05;
      canvas.drawCircle(Offset(ex, ey), w * 0.018, Paint()..color = goldDark);
      canvas.drawArc(Rect.fromCenter(center: Offset(ex, ey + ry * 0.04), width: rx * 0.42, height: ry * 0.26), pi, pi, false, features);
      canvas.drawLine(Offset(ex - rx * 0.2, ey - ry * 0.3), Offset(ex + rx * 0.2, ey - ry * 0.34), features);
    }
    canvas.drawLine(Offset(cx, headY), Offset(cx - rx * 0.08, headY + ry * 0.3), features);

    switch (rank) {
      case Cards.king:
        // Beard and moustache.
        final beard = Path()
          ..moveTo(cx - rx * 0.98, headY + ry * 0.05)
          ..quadraticBezierTo(cx - rx * 0.95, headY + ry * 1.1, cx, headY + ry * 1.55)
          ..quadraticBezierTo(cx + rx * 0.95, headY + ry * 1.1, cx + rx * 0.98, headY + ry * 0.05)
          ..quadraticBezierTo(cx + rx * 0.5, headY + ry * 0.75, cx, headY + ry * 0.62)
          ..quadraticBezierTo(cx - rx * 0.5, headY + ry * 0.75, cx - rx * 0.98, headY + ry * 0.05)
          ..close();
        canvas.drawPath(beard, goldFill);
        canvas.drawPath(beard, outline);
        final moustache = Path()
          ..moveTo(cx - rx * 0.62, headY + ry * 0.52)
          ..quadraticBezierTo(cx - rx * 0.25, headY + ry * 0.3, cx, headY + ry * 0.45)
          ..quadraticBezierTo(cx + rx * 0.25, headY + ry * 0.3, cx + rx * 0.62, headY + ry * 0.52);
        canvas.drawPath(moustache, features..strokeWidth = max(0.7, w * 0.02));
        // Crown with three points and a jewel on each.
        final base = headY - ry * 0.72;
        final top = headY - ry * 1.75;
        final crown = Path()
          ..moveTo(cx - rx * 1.05, base)
          ..lineTo(cx - rx * 1.2, top + ry * 0.25)
          ..lineTo(cx - rx * 0.5, top + ry * 0.6)
          ..lineTo(cx, top)
          ..lineTo(cx + rx * 0.5, top + ry * 0.6)
          ..lineTo(cx + rx * 1.2, top + ry * 0.25)
          ..lineTo(cx + rx * 1.05, base)
          ..close();
        canvas.drawPath(crown, goldFill);
        canvas.drawPath(crown, outline);
        canvas.drawRect(Rect.fromLTRB(cx - rx * 1.05, base - ry * 0.22, cx + rx * 1.05, base), goldFill);
        canvas.drawRect(Rect.fromLTRB(cx - rx * 1.05, base - ry * 0.22, cx + rx * 1.05, base), outline);
        for (final p in <Offset>[Offset(cx - rx * 1.2, top + ry * 0.25), Offset(cx, top), Offset(cx + rx * 1.2, top + ry * 0.25)]) {
          canvas.drawCircle(p, w * 0.03, jewel);
        }
        canvas.drawCircle(Offset(cx, base - ry * 0.11), w * 0.025, jewel);
      case Cards.queen:
        // Lips, earrings and a tiara with a gem.
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, headY + ry * 0.5), width: rx * 0.45, height: ry * 0.22),
          0,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = _red ? const Color(0xFFB3261E) : goldDark
            ..strokeWidth = max(0.6, w * 0.016)
            ..strokeCap = StrokeCap.round,
        );
        for (final side in <double>[-1, 1]) {
          canvas.drawCircle(Offset(cx + side * rx * 1.02, headY + ry * 0.35), w * 0.022, jewel);
        }
        final base = headY - ry * 0.78;
        final tiara = Path()..moveTo(cx - rx * 0.95, base);
        const peaks = 5;
        for (var i = 0; i <= peaks * 2; i++) {
          final t = i / (peaks * 2);
          final arch = sin(t * pi);
          final up = i.isOdd ? ry * 0.22 : 0.0;
          tiara.lineTo(cx - rx * 0.95 + rx * 1.9 * t, base - ry * (0.15 + 0.45 * arch) - up);
        }
        tiara.close();
        canvas.drawPath(tiara, goldFill);
        canvas.drawPath(tiara, outline);
        final gem = Path()
          ..moveTo(cx, base - ry * 0.75)
          ..lineTo(cx + rx * 0.17, base - ry * 0.45)
          ..lineTo(cx, base - ry * 0.18)
          ..lineTo(cx - rx * 0.17, base - ry * 0.45)
          ..close();
        canvas.drawPath(gem, jewel);
      default:
        // A small smile, short hair and a plumed cap set at an angle.
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, headY + ry * 0.48), width: rx * 0.5, height: ry * 0.2),
          0,
          pi,
          false,
          features,
        );
        final hair = Path()
          ..moveTo(cx - rx * 1.02, headY + ry * 0.05)
          ..quadraticBezierTo(cx - rx * 1.05, headY - ry * 0.95, cx, headY - ry * 0.98)
          ..quadraticBezierTo(cx + rx * 1.05, headY - ry * 0.95, cx + rx * 1.02, headY + ry * 0.05)
          ..quadraticBezierTo(cx + rx * 0.8, headY - ry * 0.45, cx, headY - ry * 0.55)
          ..quadraticBezierTo(cx - rx * 0.8, headY - ry * 0.45, cx - rx * 1.02, headY + ry * 0.05)
          ..close();
        canvas.drawPath(hair, goldFill);
        canvas.drawPath(hair, outline);
        // Feather first, so the cap sits on its quill.
        final feather = Path()
          ..moveTo(cx + rx * 0.4, headY - ry * 0.95)
          ..cubicTo(cx + rx * 1.3, headY - ry * 1.85, cx + rx * 2.1, headY - ry * 1.5, cx + rx * 2.05, headY - ry * 0.6)
          ..cubicTo(cx + rx * 1.7, headY - ry * 1.25, cx + rx * 1.1, headY - ry * 1.2, cx + rx * 0.4, headY - ry * 0.95)
          ..close();
        canvas.drawPath(feather, jewel);
        canvas.drawPath(feather, outline);
        canvas.save();
        canvas.translate(cx, headY - ry * 0.95);
        canvas.rotate(-0.18);
        final cap = Rect.fromCenter(center: Offset.zero, width: rx * 2.5, height: ry * 0.95);
        canvas.drawOval(
          cap,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _robe,
            ).createShader(cap),
        );
        canvas.drawOval(cap, outline..color = gold);
        canvas.drawLine(Offset(-rx * 1.15, ry * 0.18), Offset(rx * 1.15, ry * 0.18), outline);
        canvas.restore();
        outline.color = goldDark;
    }
  }

  @override
  bool shouldRepaint(_CourtPainter old) => old.rank != rank || old.suit != suit || old.ink != ink;
}

/// Card back: a lattice, a frame and a "Π" emblem in the chosen colours.
class CardBack extends StatelessWidget {
  const CardBack({
    super.key,
    required this.width,
    required this.height,
    this.style = CardBackStyle.aegean,
    this.simple = false,
  });

  final double width;
  final double height;
  final CardBackStyle style;

  /// Only the colours, no pattern (a card nobody can see).
  final bool simple;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, height), painter: CardBackPainter(style, simple));
  }
}

class CardBackPainter extends CustomPainter {
  const CardBackPainter([this.style = CardBackStyle.aegean, this.simple = false]);

  final CardBackStyle style;
  final bool simple;

  /// A dark card with a fine edge and a large "Π" in the accent colour, a
  /// faint lattice behind it.
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.08));
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[style.light, style.dark],
        ).createShader(outer.outerRect),
    );
    // The edge in the accent colour.
    canvas.drawRRect(
      outer.deflate(max(1.0, w * 0.018)),
      Paint()
        ..color = style.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, w * 0.03),
    );
    if (simple) return;
    final inner = outer.deflate(w * 0.1);
    canvas.save();
    canvas.clipRRect(inner);
    final line = Paint()
      ..color = style.accent.withValues(alpha: 0.07)
      ..strokeWidth = max(0.6, w * 0.01)
      ..style = PaintingStyle.stroke;
    final step = max(5.0, w * 0.16);
    for (var d = -h; d < w + h; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + h, h), line);
      canvas.drawLine(Offset(d + h, 0), Offset(d, h), line);
    }
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..color = style.accent.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, w * 0.01),
    );
    if (w >= 24) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Π',
          style: TextStyle(
            color: style.accent,
            fontSize: w * 0.42,
            fontWeight: FontWeight.w800,
            height: 1.0,
            fontFamily: 'Manrope',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w / 2, h / 2) - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(CardBackPainter oldDelegate) => oldDelegate.style != style || oldDelegate.simple != simple;
}
