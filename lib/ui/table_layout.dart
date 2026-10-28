import 'dart:math';

import 'package:flutter/widgets.dart';

import '../engine/game_state.dart';
import '../engine/pastra_engine.dart';
import '../game/game_controller.dart';

/// Where seats sit on screen. Seat 0 (the local player) is at the bottom and
/// play goes anticlockwise: bottom → right → top → left.
enum SeatSide { bottom, right, top, left }

/// Where one card is drawn.
class CardPlacement {
  final Rect rect;
  final bool faceUp;
  final int z;
  final double angle;
  final bool highlighted;
  final bool selected;
  final bool interactive;

  /// Face up but hidden under other cards of the pile: drawn blank, so its
  /// corner never gives it away.
  final bool covered;

  const CardPlacement({
    required this.rect,
    required this.faceUp,
    required this.z,
    this.angle = 0,
    this.highlighted = false,
    this.selected = false,
    this.interactive = false,
    this.covered = false,
  });
}

/// Pure geometry for the landscape table: computes the rectangle of every
/// card for a given size and game state. Every card always has a place
/// (deck, hand, table or pile), so a change of place animates.
///
/// ```
///  [deck+kapak altı]          [top seat][its pile]
///  [left][its pile]        [ pile / table ]        [its pile][right]
///                              [ info ]
///                        [ my hand (big) ][our pile]
///
/// A team's captured cards lie in front of the team member who captured
/// first in the round.
/// ```
class TableLayout {
  TableLayout._({
    required this.cards,
    required this.deckRect,
    required this.pileRects,
    required this.seatRects,
    required this.seatSides,
    required this.infoRect,
    required this.tableRect,
    required this.handCardWidth,
    required this.handTop,
    required this.dropLine,
    required this.playCenter,
    required this.smallCardWidth,
  });

  final Map<int, CardPlacement> cards;
  final Rect deckRect;

  /// Captured-cards pile per team (0 = our team).
  final List<Rect> pileRects;

  /// Area of each other seat's hand (labels are drawn next to it).
  final Map<int, Rect> seatRects;
  final Map<int, SeatSide> seatSides;

  /// Line above the hand for hints / status.
  final Rect infoRect;
  final Rect tableRect;
  final double handCardWidth;
  final double handTop;

  /// A dragged hand card whose centre is above this line is played.
  final double dropLine;

  /// Middle of the pile / table cards.
  final Offset playCenter;

  /// Width of the small cards (other hands, deck, piles).
  final double smallCardWidth;

  static const double cardRatio = 1.42;
  static const double margin = 8;

  /// Opening cards side by side: each starts this far (in card widths) to
  /// the right of the previous one.
  static const double spreadStep = 0.8;

  static SeatSide sideOf(int seat, int numPlayers) {
    if (seat == 0) return SeatSide.bottom;
    if (numPlayers == 2) return SeatSide.top;
    if (seat == 1) return SeatSide.right;
    if (seat == 2) return SeatSide.top;
    return SeatSide.left;
  }

  static TableLayout compute({
    required Size size,
    required GameState state,
    required int? selected,
    required PendingPlay? pending,
    required Set<int> highlighted,
    int? tableShown,
    int? landing,
  }) {
    final w = size.width;
    final h = size.height;
    final placements = <int, CardPlacement>{};
    final teamGame = state.numPlayers == 4;
    final pendingCard = pending?.card;

    // ---- the local player's hand: big cards at the bottom
    final slots = max(state.rules.cardsPerDeal, state.hands[0].length);
    final spacing = slots > 4 ? 0.74 : 1.06;
    var hh = min(170.0, max(60.0, h * 0.31));
    var hw = hh / cardRatio;
    final handSpan = 1 + (slots - 1) * spacing;
    final maxHandW = w * 0.56;
    if (hw * handSpan > maxHandW) {
      hw = maxHandW / handSpan;
      hh = hw * cardRatio;
    }
    final handTop = h - hh - 6;
    final raise = hh * 0.12;

    // ---- small cards: other hands, deck, piles
    final sh = min(90.0, max(36.0, h * 0.17));
    final sw = sh / cardRatio;
    const topY = 4.0;
    const labelH = 18.0;
    final topRowBottom = topY + sh + labelH;
    // Side hands lie sideways (card tops point to the middle), so they are sh wide.
    final sideW = teamGame ? sh + 10 : 0.0;

    // ---- hint line just above the hand
    final infoBottom = handTop - raise - 2;
    final infoTop = infoBottom - 22;
    final infoRect = Rect.fromLTRB(w * 0.18, infoTop, w * 0.82, infoBottom);

    final tableRect = Rect.fromLTRB(
      margin + sideW,
      topRowBottom + 2,
      w - margin - sideW,
      max(topRowBottom + 2 + sh, infoTop - 4),
    );
    // Deck in the top-left corner, the face-up bottom card (kapak altı)
    // sticking out under it.
    // The whole block (deck + kapak altı) is turned by [deckTilt], so the kapak
    // altı cards stick out towards the bottom-right corner. The deck keeps
    // clear of the screen edges after the turn.
    const deckTilt = pi / 4;
    final deckReach = (sw + sh) / 2 * 0.72;
    final deckRect = Rect.fromCenter(
      center: Offset(margin + deckReach, topY + max(deckReach, sh / 2)),
      width: sw,
      height: sh,
    );

    // Captured cards: in front of the player who captured first for the team.
    final fullHandW = hw * handSpan;
    final topHandW = sw + (slots - 1) * sw * 0.55;
    Rect pileRectFor(int seat) => switch (sideOf(seat, state.numPlayers)) {
          SeatSide.bottom =>
            Rect.fromLTWH(min((w + fullHandW) / 2 + 16, w - margin - sw * 1.8), h - sh - 10, sw, sh),
          SeatSide.top => Rect.fromLTWH(min((w + topHandW) / 2 + 16, w - margin - sw * 1.8), topY, sw, sh),
          SeatSide.left => Rect.fromLTWH(tableRect.left + 2, tableRect.center.dy - sh / 2, sw, sh),
          SeatSide.right => Rect.fromLTWH(tableRect.right - sw - 2, tableRect.center.dy - sh / 2, sw, sh),
        };

    final pileSeats = <int>[
      for (var t = 0; t < 2; t++) state.pileSeat[t] >= 0 ? state.pileSeat[t] : t,
    ];
    final pileRects = <Rect>[pileRectFor(pileSeats[0]), pileRectFor(pileSeats[1])];
    // Table cards stay clear of the side piles, centred.
    final sideGap = teamGame ? 1.9 * sw + 10 : 4.0;
    final contentRect = Rect.fromLTRB(
      tableRect.left + sideGap,
      tableRect.top,
      max(tableRect.left + sideGap + sw, tableRect.right - sideGap),
      tableRect.bottom,
    );

    // ---- deck. The face-up cards under it ("kapak altı": the bottom card and
    // every jack that was put there at the opening) lie side by side, all
    // visible, the one nearest to the deck on top.
    var faceUpUnder = 0;
    while (faceUpUnder < state.deck.length && state.exposed.contains(state.deck[faceUpUnder])) {
      faceUpUnder++;
    }
    for (var i = 0; i < state.deck.length; i++) {
      final c = state.deck[i];
      if (i < faceUpUnder) {
        placements[c] = CardPlacement(
          rect: Rect.fromCenter(
            // The first one sticks out under the tilted deck, further ones
            // follow to the right.
            center: deckRect.center + Offset(cos(deckTilt), sin(deckTilt)) * (sw * 0.62) + Offset(i * sw * 0.85, 0),
            width: sw,
            height: sh,
          ),
          faceUp: true,
          z: -1 - i,
          // Turned with the deck: the card's top points to the bottom-right.
          angle: pi / 2 + deckTilt,
        );
        continue;
      }
      final o = (i ~/ 4) * 0.6;
      placements[c] = CardPlacement(
        rect: deckRect.shift(Offset(-o, -o)),
        faceUp: false,
        z: i,
        angle: deckTilt,
      );
    }

    // ---- piles (pastra cards stick out crosswise, face up)
    for (var t = 0; t < 2; t++) {
      final pile = state.piles[t];
      final pastras = state.pastraCards[t];
      final r = pileRects[t];
      // Pastra cards stick out towards the middle of the table.
      final dir = sideOf(pileSeats[t], state.numPlayers) == SeatSide.right ? -1.0 : 1.0;
      var k = 0;
      for (var i = 0; i < pile.length; i++) {
        final c = pile[i];
        if (pastras.contains(c)) {
          final cx = r.center.dx + dir * (sw * 0.45 + k * 4);
          placements[c] = CardPlacement(
            rect: Rect.fromCenter(center: Offset(cx, r.center.dy + k * 2), width: sw, height: sh),
            faceUp: true,
            z: 160 + k,
            angle: pi / 2,
          );
          k++;
        } else {
          final o = (i ~/ 4) * 0.5;
          placements[c] = CardPlacement(rect: r.shift(Offset(-o, -o)), faceUp: false, z: 100 + i);
        }
      }
    }

    final table = state.table;
    final count = table.length;
    final double tw;
    final double th;
    final tableRects = <int, Rect>{};

    if (state.rules.isPile) {
      // ---- one pile in the middle: only the top card shows its face.
      // Before the first card of a round is played the opening cards lie
      // side by side, slightly overlapping: the rightmost is the top card.
      final spread = PastraEngine.isOpeningPosition(state);
      final pileW = min(hw, max(30.0, (contentRect.height - 4) / cardRatio));
      tw = spread ? min(pileW, contentRect.width / (1 + (count - 1) * spreadStep)) : pileW;
      th = tw * cardRatio;
      final pileRect = Rect.fromCenter(center: contentRect.center, width: tw, height: th);
      final spreadLeft = contentRect.center.dx - (tw + (count - 1) * tw * spreadStep) / 2;
      final shown = min(tableShown ?? count, count);
      // While a card is landing, the one below keeps its face until covered.
      final faceFrom =
          landing != null && shown >= 2 && table[shown - 1] == landing ? shown - 2 : shown - 1;
      for (var i = 0; i < count; i++) {
        final c = table[i];
        if (i >= shown) {
          // Opening card still waiting on the deck.
          placements[c] = CardPlacement(rect: deckRect, faceUp: false, z: 90 - i, angle: deckTilt);
          continue;
        }
        final rect = spread
            ? Rect.fromLTWH(spreadLeft + i * tw * spreadStep, pileRect.top, tw, th)
            : pileRect.shift(_jitter(c, tw));
        tableRects[c] = rect;
        placements[c] = CardPlacement(
          rect: rect,
          faceUp: true,
          covered: !spread && i < faceFrom,
          z: 200 + i,
          angle: spread ? 0 : _tilt(c),
          highlighted: i == shown - 1 && highlighted.contains(c),
        );
      }
    } else {
      // ---- table grid
      var w0 = min(hw * 0.9, 90.0);
      var gap = w0 * 0.12;
      var cols = 1;
      var rows = 0;
      while (true) {
        final cardH = w0 * cardRatio;
        gap = w0 * 0.12;
        cols = max(1, ((contentRect.width + gap) / (w0 + gap)).floor());
        rows = count == 0 ? 0 : (count / cols).ceil();
        final needed = rows * cardH + max(0, rows - 1) * gap;
        if (needed <= contentRect.height || w0 <= 24) break;
        w0 *= 0.92;
      }
      tw = w0;
      th = tw * cardRatio;
      final gridH = rows * th + max(0, rows - 1) * gap;
      final gridTop = contentRect.top + max(0.0, (contentRect.height - gridH) / 2);
      for (var i = 0; i < count; i++) {
        final row = i ~/ cols;
        final col = i % cols;
        final inRow = min(cols, count - row * cols);
        final rowW = inRow * tw + (inRow - 1) * gap;
        final left = contentRect.center.dx - rowW / 2 + col * (tw + gap);
        final rect = Rect.fromLTWH(left, gridTop + row * (th + gap), tw, th);
        tableRects[table[i]] = rect;
        placements[table[i]] = CardPlacement(
          rect: rect,
          faceUp: true,
          z: 200 + i,
          highlighted: highlighted.contains(table[i]),
        );
      }
    }

    // ---- the card being played onto the cards it captures
    if (pending != null) {
      Rect? target;
      if (pending.captured.isNotEmpty) {
        target = state.rules.isPile ? tableRects[table.last] : tableRects[pending.captured.first];
      }
      final base = target ?? Rect.fromCenter(center: contentRect.center, width: tw, height: th);
      placements[pending.card] = CardPlacement(
        rect: Rect.fromLTWH(base.left + tw * 0.22, base.top + tw * 0.22, tw, th),
        faceUp: true,
        z: 500,
        selected: true,
      );
    }

    // ---- the local player's hand
    final myHand = state.hands[0].where((c) => c != pendingCard).toList();
    if (myHand.isNotEmpty) {
      final step = hw * spacing;
      final total = hw + (myHand.length - 1) * step;
      final left0 = (w - total) / 2;
      for (var i = 0; i < myHand.length; i++) {
        final c = myHand[i];
        final isSel = c == selected;
        placements[c] = CardPlacement(
          rect: Rect.fromLTWH(left0 + i * step, handTop - (isSel ? raise : 0), hw, hh),
          faceUp: true,
          z: isSel ? 480 : 400 + i,
          selected: isSel,
          interactive: true,
        );
      }
    }

    // ---- other seats (always face down, the kapak altı too once dealt)
    final seatRects = <int, Rect>{};
    final seatSides = <int, SeatSide>{};
    for (var seat = 1; seat < state.numPlayers; seat++) {
      final side = sideOf(seat, state.numPlayers);
      seatSides[seat] = side;
      final hand = state.hands[seat].where((c) => c != pendingCard).toList();
      final n = max(1, hand.length);
      if (side == SeatSide.top) {
        final step = sw * 0.55;
        final total = sw + (n - 1) * step;
        final left0 = (w - total) / 2;
        seatRects[seat] = Rect.fromLTWH(left0, topY, total, sh);
        for (var i = 0; i < hand.length; i++) {
          placements[hand[i]] = CardPlacement(
            rect: Rect.fromLTWH(left0 + i * step, topY, sw, sh),
            faceUp: false,
            z: 300 + seat * 10 + i,
          );
        }
      } else {
        // Cards lie sideways: the top of each card points to the middle of the
        // table, away from its owner. Rects are unrotated (sw x sh) and turned
        // around their centre, so the visual box is sh wide and sw tall.
        final step = n <= 1 ? 0.0 : min(sw * 0.55, max(3.0, (tableRect.height - sw) / (n - 1)));
        final total = sw + (n - 1) * step;
        final top0 = tableRect.center.dy - total / 2;
        final cx = side == SeatSide.right ? w - margin - sh / 2 : margin + sh / 2;
        seatRects[seat] = Rect.fromLTWH(cx - sh / 2, top0, sh, total);
        final angle = side == SeatSide.right ? -pi / 2 : pi / 2;
        for (var i = 0; i < hand.length; i++) {
          placements[hand[i]] = CardPlacement(
            rect: Rect.fromCenter(center: Offset(cx, top0 + sw / 2 + i * step), width: sw, height: sh),
            faceUp: false,
            z: 300 + seat * 10 + i,
            angle: angle,
          );
        }
      }
    }

    return TableLayout._(
      cards: placements,
      deckRect: deckRect,
      pileRects: pileRects,
      seatRects: seatRects,
      seatSides: seatSides,
      infoRect: infoRect,
      tableRect: tableRect,
      handCardWidth: hw,
      handTop: handTop,
      dropLine: handTop - hh * 0.25,
      playCenter: contentRect.center,
      smallCardWidth: sw,
    );
  }

  /// Small, stable offset of a pile card (from its id), so the pile looks
  /// hand-made.
  static Offset _jitter(int card, double cardWidth) {
    final dx = ((card * 37) % 7 - 3) * cardWidth * 0.012;
    final dy = ((card * 53) % 7 - 3) * cardWidth * 0.012;
    return Offset(dx, dy);
  }

  static double _tilt(int card) => ((card * 29) % 9 - 4) * 0.018;
}
