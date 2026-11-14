import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/ui/table_layout.dart';

/// The deck lies on the left of the dealer of the round (as the dealer sits)
/// and never on a hand, a pile or a seat.
void main() {
  // Where the deck must be for each dealer: (right half?, bottom half?).
  const expected = <int, Map<int, (bool, bool)>>{
    2: <int, (bool, bool)>{0: (false, true), 1: (true, false)},
    4: <int, (bool, bool)>{0: (false, true), 1: (true, true), 2: (true, false), 3: (false, false)},
  };

  for (final size in <Size>[const Size(844, 390), const Size(960, 540), const Size(1280, 720)]) {
    for (final players in <int>[2, 4]) {
      for (var dealer = 0; dealer < players; dealer++) {
        test('deck of dealer $dealer of $players at ${size.width.toInt()}x${size.height.toInt()}', () {
          final state = PastraEngine.newGame(
            rules: const PastraRules(),
            numPlayers: players,
            seed: 3 + dealer,
            firstDealer: dealer,
          );
          final layout = TableLayout.compute(
            size: size,
            state: state,
            selected: null,
            pending: null,
            highlighted: const <int>{},
            scale: TableLayout.scaleFor(size),
          );
          final c = layout.deckRect.center;
          final (right, bottom) = expected[players]![dealer]!;
          expect(c.dx > size.width / 2, right, reason: 'side');
          expect(c.dy > size.height / 2, bottom, reason: 'height');
          // On the cloth.
          expect(layout.deckArea.left, greaterThanOrEqualTo(0));
          expect(layout.deckArea.right, lessThanOrEqualTo(size.width));
          expect(layout.deckArea.top, greaterThanOrEqualTo(0));
          expect(layout.deckArea.bottom, lessThanOrEqualTo(size.height));
          // Clear of the other hands and the piles.
          // (The face-up card under the deck is turned in the top corners;
          // its box is bigger than the card, so the deck itself is checked.)
          for (final r in layout.seatRects.values) {
            expect(layout.deckRect.overlaps(r), isFalse, reason: 'seat $r');
          }
          for (final r in layout.pileRects) {
            expect(layout.deckRect.overlaps(r), isFalse, reason: 'pile $r');
          }
          // Clear of my hand.
          for (final card in state.hands[0]) {
            expect(layout.deckRect.overlaps(layout.cards[card]!.rect), isFalse, reason: 'hand');
          }
        });
      }
    }
  }
}
