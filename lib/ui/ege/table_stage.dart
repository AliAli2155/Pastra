import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../table_layout.dart';
import '../theme.dart';

/// How the table is seen on the screen.
///
/// The cards are laid out on a flat table ([size]). The table is then leaned
/// back like a real one seen from the player's seat: the near edge fills the
/// bottom of the screen and the far edge is smaller and higher. [TableStage]
/// draws it that way, and [project] tells where a point of the flat table
/// ends up (for name plates and messages, which are drawn flat on top).
///
/// In low graphics quality the table stays flat ([tilted] is false): it lies
/// inside the area with room for its rim at the top and the sides, and
/// [project] only moves a point by that room.
class StageGeometry {
  const StageGeometry._({
    required this.area,
    required this.size,
    required this.tilted,
    required double distance,
    required double inset,
  })  : _distance = distance,
        _inset = inset;

  /// The part of the screen the table is shown in.
  final Size area;

  /// The flat table the cards are laid out on. When [tilted] it is as wide
  /// as [area] and taller, because its far part is drawn smaller; a flat one
  /// is a little smaller than [area] (room for the rim).
  final Size size;

  /// False in low graphics quality.
  final bool tilted;

  final double _distance;

  /// Flat table: the room for the rim at the top and the sides.
  final double _inset;

  /// How far the table leans back, in radians.
  static const double lean = 0.42;

  /// Distance of the eye from the table, in table heights (smaller = a
  /// stronger perspective).
  static const double eye = 2.1;

  /// Fits the table into [area]: the bottom edge of the table is the bottom
  /// edge of the area, the far edge ends a little below the top (the rim of
  /// the table shows there).
  factory StageGeometry.fit(Size area, {bool tilted = true}) {
    if (!tilted || area.width < 200 || area.height < 140) {
      // The near edge goes on below the screen, as on the tilted table.
      final inset = flatInsetFor(area);
      return StageGeometry._(
        area: area,
        size: Size(math.max(0.0, area.width - 2 * inset), math.max(0.0, area.height - inset)),
        tilted: false,
        distance: 1,
        inset: inset,
      );
    }
    final far = farMarginFor(area);
    final target = area.height - far;
    final height = target * (1 + math.sin(lean) / eye) / math.cos(lean);
    return StageGeometry._(
      area: area,
      size: Size(area.width, height),
      tilted: true,
      distance: eye * height,
      inset: 0,
    );
  }

  /// Room above the far edge of the table.
  static double farMarginFor(Size area) => math.max(14.0, area.height * 0.04);

  /// Room for the rim around a flat table.
  static double flatInsetFor(Size area) => math.max(10.0, area.height * 0.03);

  /// Thickness of the rim around the cloth, on the flat table.
  double get rim => tilted ? math.max(12.0, size.height * 0.032) : _inset;

  /// The turn and the perspective, about the bottom centre of the table
  /// (nothing on a flat table).
  Matrix4 get matrix {
    if (!tilted) return Matrix4.identity();
    return Matrix4.identity()
      ..setEntry(3, 2, 1 / _distance)
      ..rotateX(-lean);
  }

  double _w(double y) => 1 - math.sin(lean) * (y - size.height) / _distance;

  /// Where the point [p] of the flat table is on the screen area.
  Offset project(Offset p) {
    if (!tilted) return p + Offset(_inset, _inset);
    final w = _w(p.dy);
    return Offset(
      area.width / 2 + (p.dx - size.width / 2) / w,
      area.height + math.cos(lean) * (p.dy - size.height) / w,
    );
  }

  /// The smallest rectangle on the screen that holds [r].
  Rect projectRect(Rect r) {
    if (!tilted) return r.shift(Offset(_inset, _inset));
    final a = project(r.topLeft);
    final b = project(r.topRight);
    final c = project(r.bottomLeft);
    final d = project(r.bottomRight);
    return Rect.fromLTRB(
      math.min(math.min(a.dx, b.dx), math.min(c.dx, d.dx)),
      math.min(math.min(a.dy, b.dy), math.min(c.dy, d.dy)),
      math.max(math.max(a.dx, b.dx), math.max(c.dx, d.dx)),
      math.max(math.max(a.dy, b.dy), math.max(c.dy, d.dy)),
    );
  }

  /// How large things are drawn at [p] compared with the flat table (1 at the
  /// near edge, smaller further away).
  double scaleAt(Offset p) => tilted ? 1 / _w(p.dy) : 1.0;

  /// How a small thing lying at [p] looks on the screen, about its own
  /// centre: narrower and shorter further away, and slanted like the sides
  /// of the table. Cards are drawn with this instead of through the
  /// perspective itself: at their size it looks the same, and it is much
  /// cheaper to draw (above all in a browser). Nothing on a flat table.
  Matrix4 slantAt(Offset p) {
    if (!tilted) return Matrix4.identity();
    final w = _w(p.dy);
    final sx = 1 / w;
    final sy = math.cos(lean) / (w * w);
    final k = (p.dx - size.width / 2) * math.sin(lean) / (_distance * w * w);
    // Columns: where (1, 0) and (0, 1) of the table end up.
    return Matrix4(sx, 0, 0, 0, k, sy, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
  }
}

/// Shows its child (the flat table with all its cards) leaned back as
/// described by [geometry]. Touches are turned back by the same amount, so
/// cards can be tapped and dragged where they are seen.
class TableStage extends StatelessWidget {
  const TableStage({super.key, required this.geometry, required this.child});

  final StageGeometry geometry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = geometry;
    // The same widgets for a flat and a tilted table: when the graphics
    // quality changes during a game, the cards keep their state and glide
    // to their new places. A flat table hangs from the bottom centre too,
    // which leaves the room for its rim at the top and the sides.
    return OverflowBox(
      alignment: Alignment.bottomCenter,
      minWidth: g.size.width,
      maxWidth: g.size.width,
      minHeight: g.size.height,
      maxHeight: g.size.height,
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: g.matrix,
        child: SizedBox(width: g.size.width, height: g.size.height, child: child),
      ),
    );
  }
}

/// The table itself: a wooden rim with a gold edge around the cloth in the
/// colour the player chose, lit from the middle and darker towards the rim.
/// It is drawn on the flat table and may go beyond its edges (the rim).
class StageFeltPainter extends CustomPainter {
  const StageFeltPainter({required this.table, required this.rim});

  final TableTheme table;
  final double rim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final short = math.min(w, h);
    final felt = RRect.fromLTRBR(0, 0, w, h, Radius.circular(short * TableLayout.cornerFactor));
    final outer = felt.inflate(rim);

    // A gold edge around the rim.
    canvas.drawRRect(outer.inflate(2.5), Paint()..color = PastraColors.gold);
    // The wooden rim, lighter on the far side.
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF6E4C27), PastraColors.wood, PastraColors.woodDark],
          stops: <double>[0.0, 0.35, 1.0],
        ).createShader(outer.outerRect),
    );
    // A fine light along the top of the wood.
    canvas.drawRRect(
      outer.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    // The cloth, lit from the middle.
    canvas.drawRRect(
      felt,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: (w * 0.6) / short,
          colors: <Color>[table.light, table.mid, table.dark],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(felt.outerRect),
    );

    canvas.save();
    canvas.clipRRect(felt);
    // The cloth falls into the dark towards the edges.
    canvas.drawRect(
      felt.outerRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: (w * 0.62) / short,
          colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.32)],
          stops: const <double>[0.6, 1.0],
        ).createShader(felt.outerRect),
    );
    // A soft shadow just inside the rim, as if the cloth lay a little lower.
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        felt.deflate(i * 2.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.black.withValues(alpha: 0.2 - i * 0.045),
      );
    }
    canvas.restore();

    // A gold hairline where the cloth meets the rim.
    canvas.drawRRect(
      felt.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = PastraColors.gold.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(StageFeltPainter old) => old.table != table || old.rim != rim;
}

/// The playing area in the middle of the table: only a faint gold ring with
/// a "Π" in it. While a card is dragged over it, a soft light and a gold
/// edge show where it can be dropped.
class TableZonePainter extends CustomPainter {
  const TableZonePainter({required this.highlight});

  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    if (highlight) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(26));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.0)],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rrect.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = PastraColors.gold.withValues(alpha: 0.75),
      );
    }
    // The "Π" emblem in the middle of the cloth.
    final c = rect.center;
    final er = math.min(rect.height, rect.width) * 0.32;
    canvas.drawCircle(
      c,
      er,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = PastraColors.gold.withValues(alpha: 0.2),
    );
    final emblem = TextPainter(
      text: TextSpan(
        text: 'Π',
        style: TextStyle(
          color: PastraColors.gold.withValues(alpha: 0.12),
          fontSize: er * 1.0,
          fontWeight: FontWeight.w800,
          height: 1,
          fontFamily: 'Manrope',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emblem.paint(canvas, c - Offset(emblem.width / 2, emblem.height / 2));
    emblem.dispose();
  }

  @override
  bool shouldRepaint(TableZonePainter old) => old.highlight != highlight;
}
