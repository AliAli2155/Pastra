import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';

/// The face-up cards under the deck (kapak altı) – one or several – all go to
/// the dealer with the last deal, and every hand stays the same size.
void main() {
  const rules = PastraRules();

  /// A new game whose deck has [faceUp] face-up cards under it (searched by
  /// seed), or null.
  GameState? gameWith(int players, int faceUp, {int dealer = 0}) {
    for (var seed = 0; seed < 20000; seed++) {
      final s = PastraEngine.newGame(rules: rules, numPlayers: players, seed: seed, firstDealer: dealer);
      if (s.exposed.length == faceUp) return s;
    }
    return null;
  }

  /// Plays nothing: empties the hands and deals again until the deck is
  /// gone, checking every deal. Returns the dealer's last hand.
  List<int> dealToTheEnd(GameState s) {
    final per = s.rules.cardsPerDeal;
    while (true) {
      for (final h in s.hands) {
        expect(h.length, per, reason: 'every hand the same size');
      }
      if (s.deck.isEmpty) return List<int>.of(s.hands[s.dealer]);
      for (final h in s.hands) {
        h.clear();
      }
      PastraEngine.dealHands(s);
    }
  }

  for (final players in <int>[2, 4]) {
    for (final faceUp in <int>[1, 2, 3]) {
      for (var dealer = 0; dealer < players; dealer++) {
        test('$faceUp face-up card(s) go to dealer $dealer of $players players', () {
          final s = gameWith(players, faceUp, dealer: dealer);
          if (s == null) {
            markTestSkipped('no deal with $faceUp face-up cards found');
            return;
          }
          final exposed = List<int>.of(s.exposed);
          final last = dealToTheEnd(s);
          expect(last, containsAll(exposed), reason: 'the dealer has every kapak altı card');
          // Nobody else got one.
          for (var seat = 0; seat < players; seat++) {
            if (seat == s.dealer) continue;
            expect(s.hands[seat].where(exposed.contains), isEmpty, reason: 'seat $seat');
          }
          // Every card of the deck was dealt exactly once, nothing lost.
          expect(s.deck, isEmpty);
        });
      }
    }
  }

  test('a deal without face-up cards is dealt one by one as before', () {
    final s = gameWith(2, 1)!;
    final top = List<int>.of(s.deck.reversed.take(12));
    for (final h in s.hands) {
      h.clear();
    }
    PastraEngine.dealHands(s);
    // The one after the dealer gets the 1st, 3rd, 5th … card off the deck.
    final starter = (s.dealer + 1) % 2;
    expect(s.hands[starter], <int>[for (var i = 0; i < 12; i += 2) top[i]]);
    expect(s.hands[s.dealer], <int>[for (var i = 1; i < 12; i += 2) top[i]]);
  });
}
