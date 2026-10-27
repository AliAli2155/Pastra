import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/cards.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';

int card(int suit, int rank) => Cards.make(suit, rank);

const int clubs = Cards.clubs;
const int diamonds = Cards.diamonds;
const int hearts = Cards.hearts;
const int spades = Cards.spades;

Set<int> capture(List<int> table, int played) => PastraEngine.sumCapture(table, played).toSet();

const PastraRules sums = PastraRules.sumsDefaults;
const PastraRules pile = PastraRules.pileDefaults;

/// A fresh game where the current player holds [hand] and the table is [table].
GameState position({
  required List<int> table,
  required List<int> hand,
  PastraRules rules = sums,
  bool emptyDeck = false,
}) {
  final s = PastraEngine.newGame(rules: rules, numPlayers: 2, seed: 7);
  s.table = List<int>.of(table);
  s.hands = <List<int>>[<int>[], <int>[]];
  s.hands[s.current] = List<int>.of(hand);
  if (emptyDeck) s.deck = <int>[];
  return s;
}

void expectAllCards(GameState s) {
  final all = <int>[
    ...s.deck,
    ...s.table,
    for (final h in s.hands) ...h,
    for (final p in s.piles) ...p,
  ];
  expect(all.length, Cards.deckSize);
  expect(all.toSet().length, Cards.deckSize);
}

/// Plays a whole game with bots and checks invariants along the way.
GameState playGame({
  required int players,
  required int perDeal,
  required List<AiLevel> levels,
  required int seed,
  PastraRules? rules,
}) {
  final r = (rules ?? sums).copyWith(cardsPerDeal: perDeal);
  final s = PastraEngine.newGame(rules: r, numPlayers: players, seed: seed);
  final rng = Random(seed);
  var rounds = 0;
  expectGoodOpening(s);
  while (s.phase != GamePhase.gameOver) {
    if (s.phase == GamePhase.roundOver) {
      PastraEngine.startNextRound(s);
      expectGoodOpening(s);
      continue;
    }
    final c = PastraAI.chooseCard(s, levels[s.current], rng);
    expect(s.hands[s.current], contains(c));
    PastraEngine.applyMove(s, c);
    expectAllCards(s);
    if (PastraEngine.roundCardsExhausted(s)) {
      PastraEngine.collectLeftovers(s);
      expect(s.piles[0].length + s.piles[1].length, Cards.deckSize);
      final res = PastraEngine.scoreRound(s);
      final base = res.teams[0].total +
          res.teams[1].total -
          res.teams[0].pastraPoints -
          res.teams[1].pastraPoints;
      final tie = res.teams[0].cards == res.teams[1].cards;
      if (r.isPile) {
        expect(base, tie ? 22 : 25, reason: '25 points per round (22 on a 26-26 tie)');
      } else {
        expect(base, tie ? 13 : 16, reason: '16 points per round (13 on a 26-26 tie)');
      }
      rounds++;
      expect(rounds, lessThan(200));
    } else if (PastraEngine.needsDeal(s)) {
      PastraEngine.dealHands(s);
    }
  }
  return s;
}

void expectGoodOpening(GameState s) {
  expect(s.table, hasLength(PastraEngine.tableCardsAtStart));
  if (s.rules.isPile) {
    expect(Cards.isJack(s.table.last), isFalse, reason: 'no jack on top of the opening cards');
    expect(s.exposed, isNotEmpty);
    expect(s.exposed.last, s.deck.first, reason: 'the kapak altı is the bottom card of the deck');
    for (final c in s.exposed) {
      expect(s.deck, contains(c));
    }
  } else {
    expect(s.table.any(Cards.isJack), isFalse, reason: 'no jack on the opening table');
  }
}

void main() {
  group('cards', () {
    test('special cards', () {
      expect(Cards.twoOfClubs, card(clubs, 2));
      expect(Cards.tenOfDiamonds, card(diamonds, 10));
      expect(Cards.points(Cards.twoOfClubs), 2);
      expect(Cards.points(Cards.tenOfDiamonds), 3);
      expect(Cards.points(card(hearts, Cards.ace)), 1);
      expect(Cards.points(card(spades, Cards.jack)), 1);
      expect(Cards.points(card(spades, 10)), 0);
      var total = 0;
      for (var c = 0; c < Cards.deckSize; c++) {
        total += Cards.points(c);
      }
      expect(total, 13, reason: '4 aces + 4 jacks + 2 + 3');
    });

    test('pile game card points', () {
      expect(Cards.xeriPoints(Cards.tenOfDiamonds), 2);
      expect(Cards.xeriPoints(Cards.twoOfClubs), 1);
      expect(Cards.xeriPoints(card(spades, Cards.king)), 1);
      expect(Cards.xeriPoints(card(spades, 10)), 1);
      expect(Cards.xeriPoints(card(spades, 9)), 0);
      var total = 0;
      for (var c = 0; c < Cards.deckSize; c++) {
        total += pile.pointsOf(c);
      }
      expect(total, 22, reason: '20 for A K Q J 10 + 1 for 10♦ + 1 for 2♣');
    });
  });

  group('captures', () {
    test('nothing to take on an empty table', () {
      expect(capture(<int>[], card(hearts, 5)), isEmpty);
    });

    test('equal card', () {
      expect(capture(<int>[card(hearts, 5), card(spades, 9)], card(clubs, 5)), <int>{card(hearts, 5)});
    });

    test('sum of two numerals', () {
      expect(
        capture(<int>[card(hearts, 3), card(spades, 5), card(diamonds, 12)], card(clubs, 8)),
        <int>{card(hearts, 3), card(spades, 5)},
      );
    });

    test('several groups at once: 8, 5+3 and 6+A+A', () {
      final table = <int>[
        card(hearts, 8),
        card(spades, 5),
        card(diamonds, 3),
        card(clubs, 6),
        card(hearts, 1),
        card(spades, 1),
      ];
      expect(capture(table, card(clubs, 8)), table.toSet());
    });

    test('queens and kings only take their own rank', () {
      expect(capture(<int>[card(hearts, 12), card(spades, 2)], card(clubs, 13)), isEmpty);
      expect(
        capture(<int>[card(hearts, 12), card(spades, 12), card(diamonds, 2)], card(clubs, 12)),
        <int>{card(hearts, 12), card(spades, 12)},
      );
      expect(capture(<int>[card(hearts, 12)], card(clubs, 10)), isEmpty, reason: 'faces are never added');
    });

    test('jack takes the whole table', () {
      final table = <int>[card(hearts, 12), card(spades, 2), card(diamonds, 13)];
      expect(capture(table, card(clubs, Cards.jack)), table.toSet());
    });

    test('largest capture wins when groups overlap', () {
      // 6 = 2+4 or 1+2+3: taking 1+2+3 takes more cards.
      final table = <int>[card(hearts, 1), card(hearts, 2), card(hearts, 3), card(hearts, 4)];
      expect(capture(table, card(clubs, 6)), <int>{card(hearts, 1), card(hearts, 2), card(hearts, 3)});
    });

    test('ties are broken by points (2 of clubs preferred)', () {
      final table = <int>[card(hearts, 2), Cards.twoOfClubs, card(spades, 3)];
      expect(capture(table, card(diamonds, 5)), <int>{Cards.twoOfClubs, card(spades, 3)});
    });
  });

  group('pile game', () {
    test('same rank as the top card takes the whole pile', () {
      final table = <int>[card(hearts, 3), card(spades, 9), card(diamonds, 7)];
      expect(PastraEngine.captureFor(pile, table, card(clubs, 7)), table);
      expect(PastraEngine.captureFor(pile, table, card(clubs, 9)), isEmpty, reason: 'only the top card counts');
      expect(PastraEngine.captureFor(pile, table, card(clubs, 10)), isEmpty, reason: 'no sums');
      expect(PastraEngine.captureFor(pile, table, card(clubs, Cards.jack)), table);
      expect(PastraEngine.captureFor(pile, <int>[], card(clubs, Cards.jack)), isEmpty);
    });

    test('taking a lone card is a pastra, a bigger pile is not', () {
      var s = position(table: <int>[card(hearts, 7)], hand: <int>[card(clubs, 7), card(clubs, 2)], rules: pile);
      expect(PastraEngine.applyMove(s, card(clubs, 7)).pastraPoints, 10);
      s = position(
        table: <int>[card(hearts, 2), card(hearts, 7)],
        hand: <int>[card(clubs, 7), card(clubs, 2)],
        rules: pile,
      );
      final pv = PastraEngine.applyMove(s, card(clubs, 7));
      expect(pv.captured, hasLength(2));
      expect(pv.isPastra, isFalse);
      expect(s.table, isEmpty);
    });

    test('jack on a lone jack scores 20, on another lone card nothing', () {
      var s = position(
        table: <int>[card(hearts, Cards.jack)],
        hand: <int>[card(clubs, Cards.jack), card(clubs, 2)],
        rules: pile,
      );
      expect(PastraEngine.applyMove(s, card(clubs, Cards.jack)).pastraPoints, 20);
      s = position(
        table: <int>[card(hearts, 5)],
        hand: <int>[card(clubs, Cards.jack), card(clubs, 2)],
        rules: pile,
      );
      final pv = PastraEngine.applyMove(s, card(clubs, Cards.jack));
      expect(pv.isCapture, isTrue);
      expect(pv.isPastra, isFalse);
      s = position(
        table: <int>[card(hearts, 5)],
        hand: <int>[card(clubs, Cards.jack), card(clubs, 2)],
        rules: pile.copyWith(jackSweepIsPastra: true),
      );
      expect(PastraEngine.applyMove(s, card(clubs, Cards.jack)).pastraPoints, 10);
    });

    test('the kapak altı goes to the dealer with the last deal', () {
      for (final players in <int>[2, 4]) {
        for (var seed = 1; seed <= 30; seed++) {
          final s = PastraEngine.newGame(rules: pile, numPlayers: players, seed: seed);
          final bottom = s.deck.first;
          final rng = Random(seed);
          while (s.deck.isNotEmpty) {
            if (PastraEngine.needsDeal(s)) {
              PastraEngine.dealHands(s);
            } else {
              PastraEngine.applyMove(s, PastraAI.chooseCard(s, AiLevel.medium, rng));
            }
          }
          expect(s.hands[s.dealer], contains(bottom));
          expect(PastraEngine.unseenFor(s, (s.dealer + 1) % players), isNot(contains(bottom)),
              reason: 'everybody knows where the kapak altı is');
        }
      }
    });

    test('a jack never opens on top: it goes under the deck', () {
      var jacksUnder = 0;
      for (var seed = 1; seed <= 300; seed++) {
        final s = PastraEngine.newGame(rules: pile, numPlayers: 2, seed: seed);
        expect(Cards.isJack(s.table.last), isFalse);
        if (s.exposed.length > 1) {
          jacksUnder++;
          expect(Cards.isJack(s.deck.first), isTrue);
        }
      }
      expect(jacksUnder, greaterThan(0));
    });

    test('captured cards belong in front of the first capturer of the team', () {
      for (var seed = 1; seed <= 20; seed++) {
        final s = PastraEngine.newGame(rules: pile, numPlayers: 4, seed: seed);
        final rng = Random(seed);
        final first = <int>[-1, -1];
        while (!PastraEngine.roundCardsExhausted(s)) {
          if (PastraEngine.needsDeal(s)) {
            PastraEngine.dealHands(s);
            continue;
          }
          final seat = s.current;
          final pv = PastraEngine.applyMove(s, PastraAI.chooseCard(s, AiLevel.medium, rng));
          final team = GameState.teamOf(seat);
          if (pv.isCapture && first[team] < 0) first[team] = seat;
          for (var t = 0; t < 2; t++) {
            expect(s.pileSeat[t], first[t]);
          }
        }
      }
    });

    test('the last card of the round is not a pastra', () {
      final s = position(table: <int>[card(hearts, 7)], hand: <int>[card(clubs, 7)], rules: pile, emptyDeck: true);
      final pv = PastraEngine.applyMove(s, card(clubs, 7));
      expect(pv.isCapture, isTrue);
      expect(pv.isPastra, isFalse);
    });

    test('the opening position lasts until the first card is played', () {
      for (var seed = 1; seed <= 20; seed++) {
        final s = PastraEngine.newGame(rules: pile, numPlayers: 2, seed: seed);
        expect(PastraEngine.isOpeningPosition(s), isTrue);
        PastraEngine.applyMove(s, s.hands[s.current].first);
        expect(PastraEngine.isOpeningPosition(s), isFalse);
      }
    });

    test('a card that takes nothing goes on top', () {
      final s = position(table: <int>[card(hearts, 9)], hand: <int>[card(clubs, 4), card(clubs, 2)], rules: pile);
      expect(PastraEngine.applyMove(s, card(clubs, 4)).isCapture, isFalse);
      expect(s.table.last, card(clubs, 4));
    });

    test('a round is worth 25 points plus pastras', () {
      final s = PastraEngine.newGame(rules: pile, numPlayers: 2, seed: 3);
      s.hands = <List<int>>[<int>[], <int>[]];
      s.deck = <int>[];
      s.table = <int>[];
      s.piles = <List<int>>[
        List<int>.generate(27, (i) => i),
        List<int>.generate(25, (i) => 27 + i),
      ];
      s.pastraCards = <List<int>>[<int>[5], <int>[]];
      s.pastraPoints = <int>[10, 0];
      final r = PastraEngine.computeRoundResult(s);
      expect(r.teams[0].mostCards, isTrue);
      expect(r.teams[0].honours + r.teams[1].honours, 20);
      expect(r.teams[0].total + r.teams[1].total, 25 + 10);
    });

    test('old rules without a variant load as the sum game', () {
      final old = <String, dynamic>{'targetScore': 101, 'cardsPerDeal': 4, 'jackOnJackPoints': 10};
      final r = PastraRules.fromJson(old);
      expect(r.variant, GameVariant.sums);
      expect(PastraRules.fromJson(pile.toJson()).variant, GameVariant.pile);
      expect(PastraRules.fromJson(pile.toJson()).jackOnJackPoints, 20);
    });
  });

  group('pastra', () {
    test('taking the last card is a pastra', () {
      final s = position(table: <int>[card(hearts, 7)], hand: <int>[card(clubs, 7), card(clubs, 2)]);
      final seat = s.current;
      final pv = PastraEngine.applyMove(s, card(clubs, 7));
      expect(pv.isPastra, isTrue);
      expect(pv.pastraPoints, 10);
      expect(s.pastraPoints[GameState.teamOf(seat)], 10);
      expect(s.table, isEmpty);
    });

    test('a sum that clears the table is a pastra', () {
      final s = position(
        table: <int>[card(hearts, 3), card(spades, 4)],
        hand: <int>[card(clubs, 7), card(clubs, 2)],
      );
      expect(PastraEngine.applyMove(s, card(clubs, 7)).isPastra, isTrue);
    });

    test('a jack sweep is not a pastra by default', () {
      final s = position(
        table: <int>[card(hearts, 7), card(spades, 2)],
        hand: <int>[card(clubs, Cards.jack), card(clubs, 2)],
      );
      final pv = PastraEngine.applyMove(s, card(clubs, Cards.jack));
      expect(pv.captured.length, 2);
      expect(pv.isPastra, isFalse);
    });

    test('jack sweep can count as pastra (setting)', () {
      final s = position(
        table: <int>[card(hearts, 7), card(spades, 2)],
        hand: <int>[card(clubs, Cards.jack), card(clubs, 2)],
        rules: sums.copyWith(jackSweepIsPastra: true),
      );
      expect(PastraEngine.applyMove(s, card(clubs, Cards.jack)).pastraPoints, 10);
    });

    test('jack on a lone jack uses its own setting', () {
      for (final points in sums.jackOnJackOptions) {
        final s = position(
          table: <int>[card(hearts, Cards.jack)],
          hand: <int>[card(clubs, Cards.jack), card(clubs, 2)],
          rules: sums.copyWith(jackOnJackPoints: points),
        );
        expect(PastraEngine.applyMove(s, card(clubs, Cards.jack)).pastraPoints, points);
      }
    });

    test('no pastra with the last card when disabled', () {
      final s = position(
        table: <int>[card(hearts, 7)],
        hand: <int>[card(clubs, 7)],
        rules: sums.copyWith(pastraOnLastCard: false),
        emptyDeck: true,
      );
      final pv = PastraEngine.applyMove(s, card(clubs, 7));
      expect(pv.captured, hasLength(1));
      expect(pv.isPastra, isFalse);
    });

    test('a card that takes nothing stays on the table', () {
      final s = position(table: <int>[card(hearts, 9)], hand: <int>[card(clubs, 4), card(clubs, 2)]);
      final pv = PastraEngine.applyMove(s, card(clubs, 4));
      expect(pv.isCapture, isFalse);
      expect(s.table, <int>[card(hearts, 9), card(clubs, 4)]);
    });
  });

  group('dealing', () {
    for (final base in <PastraRules>[pile, sums]) {
      for (final players in <int>[2, 4]) {
        for (final perDeal in PastraRules.dealOptions) {
          test('${base.variant.name}, $players players, $perDeal cards: the deck divides evenly', () {
            for (var seed = 1; seed <= 40; seed++) {
              final s = PastraEngine.newGame(
                rules: base.copyWith(cardsPerDeal: perDeal),
                numPlayers: players,
                seed: seed,
              );
              expectGoodOpening(s);
              for (final h in s.hands) {
                expect(h, hasLength(perDeal));
              }
              expect(s.deck.length % (players * perDeal), 0);
              expect(s.current, (s.dealer + 1) % players);
              expectAllCards(s);
            }
          });
        }
      }
    }
  });

  group('scoring', () {
    test('a round is worth 16 points plus pastras', () {
      final s = PastraEngine.newGame(rules: sums, numPlayers: 2, seed: 3);
      s.hands = <List<int>>[<int>[], <int>[]];
      s.deck = <int>[];
      s.table = <int>[];
      s.piles = <List<int>>[
        List<int>.generate(27, (i) => i), // all clubs, 2..A of diamonds
        List<int>.generate(25, (i) => 27 + i),
      ];
      s.pastraCards = <List<int>>[<int>[5], <int>[]];
      s.pastraPoints = <int>[10, 0];
      final r = PastraEngine.computeRoundResult(s);
      expect(r.teams[0].mostCards, isTrue);
      expect(r.teams[0].twoOfClubs, isTrue);
      expect(r.teams[0].tenOfDiamonds, isTrue);
      expect(r.teams[0].total + r.teams[1].total, 16 + 10);
    });

    test('26-26 gives nobody the cards bonus', () {
      final s = PastraEngine.newGame(rules: sums, numPlayers: 2, seed: 3);
      s.piles = <List<int>>[
        List<int>.generate(26, (i) => i),
        List<int>.generate(26, (i) => 26 + i),
      ];
      final r = PastraEngine.computeRoundResult(s);
      expect(r.teams[0].mostCards || r.teams[1].mostCards, isFalse);
    });
  });

  group('full games', () {
    for (final base in <PastraRules>[pile, sums]) {
      for (final players in <int>[2, 4]) {
        for (final perDeal in PastraRules.dealOptions) {
          test('${base.variant.name}, $players players, $perDeal cards per deal', () {
            for (var seed = 1; seed <= 12; seed++) {
              final levels = List<AiLevel>.generate(
                players,
                (i) => AiLevel.values[(seed + i) % 2], // easy / medium: fast
              );
              final s = playGame(players: players, perDeal: perDeal, levels: levels, seed: seed, rules: base);
              expect(s.phase, GamePhase.gameOver);
              expect(max(s.scores[0], s.scores[1]), greaterThanOrEqualTo(s.rules.targetScore));
              expect(s.scores[s.winner], greaterThan(s.scores[1 - s.winner]));
            }
          });
        }
      }
    }

    test('hard bot plays legal moves (1v1 and 2v2)', () {
      playGame(players: 2, perDeal: 4, levels: <AiLevel>[AiLevel.hard, AiLevel.medium], seed: 5);
      playGame(
        players: 4,
        perDeal: 4,
        levels: <AiLevel>[AiLevel.hard, AiLevel.easy, AiLevel.hard, AiLevel.easy],
        seed: 6,
        rules: sums.copyWith(targetScore: 51),
      );
      playGame(
        players: 2,
        perDeal: 6,
        levels: <AiLevel>[AiLevel.hard, AiLevel.medium],
        seed: 7,
        rules: pile.copyWith(targetScore: 51),
      );
      playGame(
        players: 4,
        perDeal: 6,
        levels: <AiLevel>[AiLevel.medium, AiLevel.hard, AiLevel.medium, AiLevel.hard],
        seed: 8,
        rules: pile.copyWith(targetScore: 51),
      );
    });

    test('variant rules still finish', () {
      playGame(
        players: 2,
        perDeal: 6,
        levels: <AiLevel>[AiLevel.medium, AiLevel.easy],
        seed: 9,
        rules: sums.copyWith(
          targetScore: 51,
          jackSweepIsPastra: true,
          jackOnJackPoints: 20,
          pastraOnLastCard: false,
        ),
      );
      playGame(
        players: 4,
        perDeal: 4,
        levels: <AiLevel>[AiLevel.medium, AiLevel.easy, AiLevel.medium, AiLevel.easy],
        seed: 10,
        rules: pile.copyWith(
          targetScore: 51,
          jackSweepIsPastra: true,
          jackOnJackPoints: 25,
          pastraOnLastCard: false,
        ),
      );
    });
  });

  group('serialisation', () {
    test('json round trip', () {
      final s = PastraEngine.newGame(rules: pile.copyWith(cardsPerDeal: 4), numPlayers: 4, seed: 42);
      final rng = Random(1);
      for (var i = 0; i < 9; i++) {
        PastraEngine.applyMove(s, PastraAI.chooseCard(s, AiLevel.medium, rng));
        PastraEngine.advanceAuto(s);
      }
      final copy = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(copy.toJson()), jsonEncode(s.toJson()));
      expect(copy.rules.cardsPerDeal, 4);
      expect(copy.rules.variant, GameVariant.pile);
    });

    test('redacted view hides other hands and the deck', () {
      final s = PastraEngine.newGame(rules: pile, numPlayers: 2, seed: 4);
      final v = s.redactedFor(0);
      expect(v.hands[0], s.hands[0]);
      expect(v.hands[1].every((c) => c == -1), isTrue);
      expect(v.deck.every((c) => c == -1), isTrue);
      expect(v.table, s.table);
    });
  });
}
