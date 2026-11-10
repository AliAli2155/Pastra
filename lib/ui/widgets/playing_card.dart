import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Pictures used for some court cards instead of the drawn design (the
/// queens and kings for now). Loaded once at start-up ([load]); a card without a
/// picture, or one that could not be loaded, keeps the drawn design.
class CourtImages {
  CourtImages._();

  static final Map<int, String> _assets = <int, String>{
    Cards.make(Cards.clubs, Cards.queen): 'assets/cards/queen_clubs.webp',
    Cards.make(Cards.diamonds, Cards.queen): 'assets/cards/queen_diamonds.webp',
    Cards.make(Cards.hearts, Cards.queen): 'assets/cards/queen_hearts.webp',
    Cards.make(Cards.spades, Cards.queen): 'assets/cards/queen_spades.webp',
    Cards.make(Cards.clubs, Cards.king): 'assets/cards/king_clubs.webp',
    Cards.make(Cards.diamonds, Cards.king): 'assets/cards/king_diamonds.webp',
    Cards.make(Cards.hearts, Cards.king): 'assets/cards/king_hearts.webp',
    Cards.make(Cards.spades, Cards.king): 'assets/cards/king_spades.webp',
  };

  static final Map<int, ui.Image> _images = <int, ui.Image>{};

  /// The picture of [card], if it has one.
  static ui.Image? forCard(int card) => _images[card];

  /// Decodes every picture (call before the first card is drawn).
  static Future<void> load() async {
    await Future.wait(<Future<void>>[
      for (final e in _assets.entries)
        () async {
          try {
            final data = await rootBundle.load(e.value);
            final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
            _images[e.key] = (await codec.getNextFrame()).image;
          } catch (_) {
            // Keeps the drawn design.
          }
        }(),
    ]);
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
  final edge = highlighted ? max(1.5, w * 0.035) : 1.0;
  final edgePaint = Paint()..color = highlighted ? PastraColors.gold : const Color(0xFFD8D0BE);

  // A card with a picture (see CourtImages): the whole face is the picture,
  // its white turned into the cream of the other cards.
  final picture = CourtImages.forCard(card);
  if (picture != null) {
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawImageRect(
      picture,
      Rect.fromLTWH(0, 0, picture.width.toDouble(), picture.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = const ColorFilter.mode(PastraColors.cream, BlendMode.multiply),
    );
    canvas.restore();
    canvas.drawDRRect(outer, outer.deflate(edge), edgePaint);
    return;
  }

  canvas.drawRRect(
    outer,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[PastraColors.cream, Color(0xFFF4EFE3)],
      ).createShader(Offset.zero & size),
  );
  canvas.drawDRRect(outer, outer.deflate(edge), edgePaint);

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

/// J / Q / K: a charcoal panel split by an X into four triangles (the left
/// and right ones in a deep tint of the suit colour), gold diagonals, the
/// rank as a gold outlined serif letter at both ends (readable either way
/// up) and the suit in a gold-framed diamond where the diagonals cross.
/// Drawn in a 68 × 130 panel, scaled to the size it is given.
class _CourtPainter extends CustomPainter {
  _CourtPainter(this.rank, this.suit, this.ink);

  final int rank;
  final int suit;

  /// The suit colour (red or black).
  final Color ink;

  static const double _w = 68;
  static const double _h = 130;
  static const Color _charcoal = Color(0xFF1E2228);
  static const Color _slate = Color(0xFF2A2E36);
  static const Color _burgundy = Color(0xFF7A1F2A);
  static const Color _gold = Color(0xFFE6B54A);
  static const Color _goldLight = Color(0xFFF7E2B0);

  bool get _red => suit == Cards.diamonds || suit == Cards.hearts;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / _w, size.height / _h);
    final panel = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, _w, _h), const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(panel);
    canvas.drawRect(const Rect.fromLTWH(0, 0, _w, _h), Paint()..color = _charcoal);

    // The left and right triangles of the X.
    final side = Paint()..color = _red ? _burgundy : _slate;
    canvas.drawPath(Path()..addPolygon(const <Offset>[Offset(0, 0), Offset(34, 65), Offset(0, _h)], true), side);
    canvas.drawPath(Path()..addPolygon(const <Offset>[Offset(_w, 0), Offset(34, 65), Offset(_w, _h)], true), side);

    // Gold diagonals with a fine line beside each.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _gold.withValues(alpha: 0.9);
    canvas.drawLine(Offset.zero, const Offset(_w, _h), line);
    canvas.drawLine(const Offset(_w, 0), const Offset(0, _h), line);
    final fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.35
      ..color = _gold.withValues(alpha: 0.5);
    canvas.drawLine(const Offset(-4, 4), const Offset(64, 134), fine);
    canvas.drawLine(const Offset(72, 4), const Offset(4, 134), fine);

    // The letter at the top, and turned round at the bottom.
    _letter(canvas);
    canvas.save();
    canvas.translate(34, 65);
    canvas.rotate(pi);
    canvas.translate(-34, -65);
    _letter(canvas);
    canvas.restore();

    _diamond(canvas);
    canvas.restore();

    canvas.drawRRect(
      panel.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _gold,
    );
    canvas.restore();
  }

  /// The rank, outlined in gold, its cap height about 22 with its baseline
  /// at y = 34.
  void _letter(Canvas canvas) {
    final glyph = _glyphs[rank]!;
    const scale = 0.22;
    final bounds = glyph.getBounds();
    canvas.save();
    canvas.translate(34 - (bounds.left + bounds.right) / 2 * scale, 34 - 100 * scale);
    canvas.scale(scale);
    canvas.drawPath(
      glyph,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 / scale
        ..strokeJoin = StrokeJoin.miter
        ..color = _gold,
    );
    canvas.restore();
  }

  /// The suit in a gold-framed diamond where the diagonals cross.
  void _diamond(Canvas canvas) {
    const c = Offset(34, 65);
    const s = 10.0;
    Path rhombus(double r) => Path()
      ..addPolygon(<Offset>[c.translate(0, -r), c.translate(r, 0), c.translate(0, r), c.translate(-r, 0)], true);
    canvas.drawPath(rhombus(s), Paint()..color = _charcoal);
    canvas.drawPath(
      rhombus(s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _gold,
    );
    canvas.drawPath(
      rhombus(s - 3.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.45
        ..color = _gold,
    );
    const icon = s * 0.76;
    canvas.save();
    canvas.translate(c.dx - s * 0.38, c.dy - s * 0.36);
    SuitPainter(suit, _red ? const Color(0xFFF0785A) : _goldLight).paint(canvas, const Size(icon, icon));
    canvas.restore();
  }

  /// Serif capitals drawn as outlines (no serif font is bundled), cap height
  /// 100, baseline at y = 100.
  static final Map<int, Path> _glyphs = <int, Path>{
    Cards.king: Path()
      ..addPolygon(const <Offset>[
        Offset(0, 0),
        Offset(42, 0),
        Offset(42, 6),
        Offset(31, 6),
        Offset(31, 50),
        Offset(60, 6),
        Offset(54, 6),
        Offset(54, 0),
        Offset(88, 0),
        Offset(88, 6),
        Offset(78, 6),
        Offset(46, 42),
        Offset(82, 94),
        Offset(90, 94),
        Offset(90, 100),
        Offset(54, 100),
        Offset(54, 94),
        Offset(61, 94),
        Offset(36, 60),
        Offset(31, 65),
        Offset(31, 94),
        Offset(42, 94),
        Offset(42, 100),
        Offset(0, 100),
        Offset(0, 94),
        Offset(10, 94),
        Offset(10, 6),
        Offset(0, 6),
      ], true),
    Cards.queen: Path.combine(
      PathOperation.union,
      Path.combine(
        PathOperation.difference,
        Path()..addOval(const Rect.fromLTRB(0, 0, 92, 100)),
        Path()..addOval(const Rect.fromLTRB(20, 9, 72, 91)),
      ),
      Path()..addPolygon(const <Offset>[Offset(46, 86), Offset(62, 82), Offset(92, 114), Offset(74, 116)], true),
    ),
    Cards.jack: Path()
      ..moveTo(28, 0)
      ..lineTo(74, 0)
      ..lineTo(74, 6)
      ..lineTo(62, 6)
      ..lineTo(62, 70)
      ..cubicTo(62, 90, 50, 100, 32, 100)
      ..cubicTo(14, 100, 2, 92, 2, 80)
      ..cubicTo(2, 71, 8, 66, 15, 66)
      ..cubicTo(22, 66, 26, 71, 26, 77)
      ..cubicTo(26, 82, 30, 86, 35, 86)
      ..cubicTo(39, 86, 40, 80, 40, 72)
      ..lineTo(40, 6)
      ..lineTo(28, 6)
      ..close(),
  };

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
