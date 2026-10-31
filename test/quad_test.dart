import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/cards.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';

void main() {
  test('four of a kind voids the deal; the same dealer deals again', () {
    final rules = PastraRules.pileDefaults;
    final aces = <int>[for (var s = 0; s < 4; s++) Cards.make(s, Cards.ace)];
    final others = <int>[
      for (var c = 0; c < Cards.deckSize; c++)
        if (!aces.contains(c)) c,
    ];
    // Seat 0 (left of dealer 1) gets every other card, starting with the
    // last card of the deck: make those four aces.
    final dealOrder = <int>[];
    var a = 0;
    var o = 0;
    for (var i = 0; i < 8; i++) {
      dealOrder.add(i.isEven ? aces[a++] : others[o++]);
    }
    final deck = <int>[...others.sublist(o), ...dealOrder.reversed];
    final s = GameState(rules: rules, numPlayers: 2, seed: 7, dealer: 1, deck: deck);

    PastraEngine.dealHands(s);

    expect(s.quads, isNotEmpty);
    expect(s.quads.first.seat, 0);
    expect(s.quads.first.cards.length, rules.cardsPerDeal);
    expect(s.quads.first.cards.where((c) => Cards.rank(c) == Cards.ace).length, 4);
    for (final h in s.hands) {
      expect(h.length, rules.cardsPerDeal);
      expect(PastraEngine.hasFourOfAKind(h), isFalse);
    }
    expect(s.dealNumber, 1);
    expect(<int>{...s.deck, ...s.hands.expand((h) => h)}.length, Cards.deckSize);
  });

  test('a normal hand is not a four of a kind', () {
    expect(PastraEngine.hasFourOfAKind(<int>[0, 1, 2, 3]), isFalse);
    expect(PastraEngine.hasFourOfAKind(<int>[0, 13, 26, 39]), isTrue);
    expect(PastraEngine.hasFourOfAKind(<int>[0, 13, 26, 1, 14]), isFalse);
  });

  test('later deals of a round keep four of a kind (no redeal)', () {
    final rules = PastraRules.pileDefaults;
    final aces = <int>[for (var s = 0; s < 4; s++) Cards.make(s, Cards.ace)];
    final others = <int>[
      for (var c = 0; c < Cards.deckSize; c++)
        if (!aces.contains(c)) c,
    ];
    final dealOrder = <int>[];
    var a = 0;
    var o = 0;
    for (var i = 0; i < 8; i++) {
      dealOrder.add(i.isEven ? aces[a++] : others[o++]);
    }
    final deck = <int>[...others.sublist(o), ...dealOrder.reversed];
    final s = GameState(rules: rules, numPlayers: 2, seed: 7, dealer: 1, deck: deck, dealNumber: 1);

    PastraEngine.dealHands(s);

    expect(s.quads, isEmpty);
    expect(PastraEngine.hasFourOfAKind(s.hands[0]), isTrue);
    expect(s.dealNumber, 2);
  });
}
