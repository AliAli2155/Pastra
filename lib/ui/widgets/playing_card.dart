import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../theme.dart';
import 'suit_icon.dart';

/// A card that fills the space it is given (aspect ratio is up to the parent,
/// normally 1 : 1.42).
///
/// The face and the back are pictures made once ([CardArt]): a card that
/// flies, turns or lies slanted on the table is then one picture to draw,
/// not its letters, suit shapes and edges again in every frame (that is
/// what made dealing stutter on phones). Shadows are solid (no blur).
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
    this.flipDelay = Duration.zero,
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
  /// without its pattern.
  final bool simple;

  /// Gold glow: this table card is (about to be) captured.
  final bool highlighted;

  /// White glow: the human's selected card.
  final bool selected;

  /// When [faceUp] changes: how long the card waits before it turns over
  /// (a dealt card turns on its way, not while it still lies on the deck).
  final Duration flipDelay;

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
    final back = DecoratedBox(
      decoration: shadow,
      child: CardArt.picture(CardArt.back(backStyle ?? Look.back, simple: simple)),
    );
    final front = DecoratedBox(
      decoration: shadow,
      child: CardArt.picture(covered ? CardArt.blank() : CardArt.face(card, highlighted: highlighted)),
    );
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: w,
        height: h,
        child: _Flip(faceUp: faceUp, delay: flipDelay, front: front, back: back),
      ),
    );
  }
}

/// Turning a card over, drawn flat (a perspective turn is slow in a
/// browser): the old side narrows to its edge while the card lifts a little
/// and darkens, then the new side opens out of the edge.
class _Flip extends StatefulWidget {
  const _Flip({required this.faceUp, required this.delay, required this.front, required this.back});

  final bool faceUp;
  final Duration delay;
  final Widget front;
  final Widget back;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> with SingleTickerProviderStateMixin {
  static const Duration _turn = Duration(milliseconds: 280);

  /// Only made for a card that turns over (most never do).
  AnimationController? _c;

  /// The side shown before the turn.
  late bool _from = widget.faceUp;

  /// Part of the animation spent waiting ([_Flip.delay]).
  double _wait = 0;

  @override
  void didUpdateWidget(_Flip old) {
    super.didUpdateWidget(old);
    if (widget.faceUp == old.faceUp) return;
    final c = _c ??= AnimationController(vsync: this);
    // Turned again before the last turn ended: start from the side seen now.
    _from = c.isAnimating && _progress(c) < 0.5 ? _from : old.faceUp;
    final total = _turn + widget.delay;
    _wait = widget.delay.inMicroseconds / total.inMicroseconds;
    c.duration = total;
    c.forward(from: 0);
  }

  double _progress(AnimationController c) => _wait >= 1 ? 1 : ((c.value - _wait) / (1 - _wait)).clamp(0.0, 1.0);

  bool _sideAt(double t) => t < 0.5 ? _from : widget.faceUp;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _side(bool up) => up ? widget.front : widget.back;

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return _side(widget.faceUp);
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = c.isAnimating ? _progress(c) : 1.0;
        final child = _side(_sideAt(t));
        if (t <= 0 || t >= 1) return child;
        // 0 = lying flat, 1 = seen edge on.
        final turn = t < 0.5 ? t * 2 : (1 - t) * 2;
        final narrow = cos(turn * pi / 2);
        final lift = 1 + 0.07 * sin(turn * pi / 2);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(narrow * lift, lift, 1),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.passthrough,
            children: <Widget>[
              child,
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
}

/// The faces and backs of the cards as pictures, each made once and then
/// reused: drawing a picture costs the same however the card is turned,
/// slanted or scaled, while letters, suit shapes and edges drawn under such
/// a transform are worked out again in every frame (slow on phones and in
/// browsers).
class CardArt {
  CardArt._();

  static final Map<int, ui.Image> _images = <int, ui.Image>{};
  static double? _ratio;

  /// Pixels per point of a card [PlayingCardView.baseWidth] wide: about as
  /// sharp as the largest card on the screen.
  static double get ratio {
    final views = ui.PlatformDispatcher.instance.views;
    final dpr = views.isEmpty ? 2.0 : views.first.devicePixelRatio;
    return _ratio ??= (dpr * 0.9).clamp(1.5, 2.5).toDouble();
  }

  /// The face of [card] (with a gold edge when [highlighted]).
  static ui.Image face(int card, {bool highlighted = false}) => _image(
        card * 2 + (highlighted ? 1 : 0),
        (canvas, size) => paintCardFace(canvas, size, card, highlighted: highlighted),
      );

  /// A back in [style]; [simple] without its pattern.
  static ui.Image back(CardBackStyle style, {bool simple = false}) =>
      _image(1000 + style.index * 2 + (simple ? 1 : 0), CardBackPainter(style, simple).paint);

  /// A face-up card seen from the side of a pile: just the cream card.
  static ui.Image blank() => _image(2000, _paintBlank);

  static ui.Image _image(int key, void Function(Canvas canvas, Size size) paint) {
    return _images[key] ??= () {
      const size = Size(PlayingCardView.baseWidth, PlayingCardView.baseHeight);
      final r = ratio;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(r);
      paint(canvas, size);
      final picture = recorder.endRecording();
      final image = picture.toImageSync((size.width * r).ceil(), (size.height * r).ceil());
      picture.dispose();
      return image;
    }();
  }

  /// Shows [image] filling the space it is given.
  static Widget picture(ui.Image image) => RawImage(
        image: image,
        width: PlayingCardView.baseWidth,
        height: PlayingCardView.baseHeight,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );

  static void _paintBlank(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.08));
    canvas.drawRRect(card, Paint()..color = PastraColors.cream);
    canvas.drawDRRect(card, card.deflate(1), Paint()..color = const Color(0xFFD8D0BE));
  }
}

/// The face of a card drawn as vectors (letters and suit shapes); used where
/// a card is shown on its own, still. Moving cards use [CardArt].
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
    return CustomPaint(size: Size(width, height), painter: _FacePainter(card, highlighted));
  }
}

class _FacePainter extends CustomPainter {
  const _FacePainter(this.card, this.highlighted);

  final int card;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) => paintCardFace(canvas, size, card, highlighted: highlighted);

  @override
  bool shouldRepaint(_FacePainter old) => old.card != card || old.highlighted != highlighted;
}

/// Pip positions (0..1 inside the centre box) for 2..10.
const Map<int, List<List<double>>> _pips = <int, List<List<double>>>{
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

/// Draws the face of [card] filling [size]: a cream card with a fine edge
/// (gold when [highlighted]), the rank and suit in two corners and the pips,
/// a large suit (ace) or the court artwork (J, Q, K) in the middle.
void paintCardFace(Canvas canvas, Size size, int card, {bool highlighted = false}) {
  final w = size.width;
  final h = size.height;
  final color = Cards.isRed(card) ? PastraColors.cardRed : PastraColors.cardBlack;
  final suit = Cards.suit(card);
  final rank = Cards.rank(card);

  final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.08));
  canvas.drawRRect(
    outer,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[PastraColors.cream, Color(0xFFF4EFE3)],
      ).createShader(Offset.zero & size),
  );
  final edge = highlighted ? max(1.5, w * 0.035) : 1.0;
  canvas.drawDRRect(
    outer,
    outer.deflate(edge),
    Paint()..color = highlighted ? PastraColors.gold : const Color(0xFFD8D0BE),
  );

  void suitAt(Offset topLeft, double s, {bool turned = false}) {
    canvas.save();
    canvas.translate(topLeft.dx, topLeft.dy);
    if (turned) {
      canvas.translate(s, s);
      canvas.rotate(pi);
    }
    SuitPainter(suit, color).paint(canvas, Size(s, s));
    canvas.restore();
  }

  // The corners: the rank over a small suit, top left and (turned round)
  // bottom right.
  final label = Cards.rankLabel(card);
  final text = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: appFont,
        fontFamilyFallback: appFontFallback,
        color: color,
        fontSize: w * 0.23,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: FontWeight.w700,
        letterSpacing: label.length > 1 ? -w * 0.02 : 0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final small = w * 0.15;
  final cornerWidth = max(text.width, small);
  for (final turned in <bool>[false, true]) {
    canvas.save();
    if (turned) {
      canvas.translate(w, h);
      canvas.rotate(pi);
    }
    final origin = Offset(w * 0.06, w * 0.05);
    text.paint(canvas, origin + Offset((cornerWidth - text.width) / 2, 0));
    suitAt(origin + Offset((cornerWidth - small) / 2, text.height + w * 0.015), small);
    canvas.restore();
  }
  text.dispose();

  // The middle.
  final box = Rect.fromLTRB(w * 0.22, h * 0.12, w - w * 0.22, h - h * 0.12);
  if (rank == Cards.ace || w < 40) {
    final big = rank == Cards.ace ? w * 0.42 : w * 0.34;
    suitAt(box.center - Offset(big / 2, big / 2), big);
  } else if (rank > 10) {
    canvas.save();
    canvas.translate(box.left, box.top);
    _CourtPainter(rank, suit, color).paint(canvas, box.size);
    canvas.restore();
  } else {
    final pip = rank >= 9 ? w * 0.17 : w * 0.19;
    for (final p in _pips[rank]!) {
      suitAt(
        box.topLeft + Offset(p[0] * (box.width - pip), p[1] * (box.height - pip)),
        pip,
        turned: p[1] > 0.5,
      );
    }
  }
}

/// Original artwork for J / Q / K: a two-ended court card (readable from
/// both sides) with an art-deco portrait in each half — the king with a
/// crown and a beard, the queen with a tiara and long hair, the jack with a
/// plumed cap — on a deep panel in a gold frame, and the suit in a cream
/// medallion on the gold band between the two halves.
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
    _pattern(canvas, inner.outerRect, w, h);
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

  /// The faint pattern inside the frame (see [BackPattern]).
  void _pattern(Canvas canvas, Rect r, double w, double h) {
    final faint = style.accent.withValues(alpha: 0.07);
    final line = Paint()
      ..color = faint
      ..strokeWidth = max(0.6, w * 0.01)
      ..style = PaintingStyle.stroke;
    final step = max(5.0, w * 0.16);
    switch (style.pattern) {
      case BackPattern.lattice:
        for (var d = -h; d < w + h; d += step) {
          canvas.drawLine(Offset(d, 0), Offset(d + h, h), line);
          canvas.drawLine(Offset(d + h, 0), Offset(d, h), line);
        }
      case BackPattern.dots:
        final dot = Paint()..color = style.accent.withValues(alpha: 0.12);
        final gap = w * 0.11;
        var row = 0;
        for (var y = r.top; y < r.bottom + gap; y += gap * 0.87, row++) {
          for (var x = r.left + (row.isOdd ? gap / 2 : 0); x < r.right + gap; x += gap) {
            canvas.drawCircle(Offset(x, y), w * 0.018, dot);
          }
        }
      case BackPattern.stripes:
        line
          ..strokeWidth = w * 0.035
          ..color = style.accent.withValues(alpha: 0.06);
        for (var d = -h; d < w + h; d += w * 0.12) {
          canvas.drawLine(Offset(d, 0), Offset(d + h * 0.6, h), line);
        }
      case BackPattern.rays:
        final c = r.center;
        final ray = Paint()..color = style.accent.withValues(alpha: 0.08);
        const n = 18;
        final far = r.longestSide;
        for (var i = 0; i < n; i++) {
          final a = i * 2 * pi / n;
          final b = a + pi / n * 0.55;
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy)
              ..lineTo(c.dx + cos(a) * far, c.dy + sin(a) * far)
              ..lineTo(c.dx + cos(b) * far, c.dy + sin(b) * far)
              ..close(),
            ray,
          );
        }
      case BackPattern.waves:
        line.color = style.accent.withValues(alpha: 0.1);
        final g = w * 0.1;
        for (var y = r.top; y < r.bottom + g; y += g) {
          final path = Path()..moveTo(r.left - g, y);
          for (var x = r.left - g; x < r.right + g; x += g * 2) {
            path.quadraticBezierTo(x + g / 2, y - g * 0.45, x + g, y);
            path.quadraticBezierTo(x + g * 1.5, y + g * 0.45, x + g * 2, y);
          }
          canvas.drawPath(path, line);
        }
      case BackPattern.meander:
        // A Greek key band along the top and the bottom of the frame.
        final u = r.width / 6;
        final key = Paint()
          ..color = style.accent.withValues(alpha: 0.3)
          ..strokeWidth = max(0.8, w * 0.014)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.miter;
        void band(double top, bool flip) {
          final s = u / 4;
          for (var i = 0; i < 6; i++) {
            final x0 = r.left + i * u;
            Offset p(double gx, double gy) => Offset(x0 + gx * s, flip ? top - gy * s : top + gy * s);
            canvas.drawPath(
              Path()..addPolygon(<Offset>[p(0, 4), p(0, 0), p(3, 0), p(3, 3), p(1, 3), p(1, 1), p(2, 1), p(2, 2)], false),
              key,
            );
            canvas.drawLine(p(0, 4), p(4, 4), key);
          }
        }
        band(r.top + w * 0.04, false);
        band(r.bottom - w * 0.04, true);
        canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), line);
    }
  }

  @override
  bool shouldRepaint(CardBackPainter oldDelegate) => oldDelegate.style != style || oldDelegate.simple != simple;
}
