import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/cards.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';

/// Engine paths the other tests did not reach (found with the coverage
/// report): the void deal at the start of a round, saving and loading a
/// state at the end of a round (the online guests get it like that), the
/// automatic advance and the refused moves.
void main() {
  const rules = PastraRules();

  /// Plays with bots (and [PastraEngine.advanceAuto]) until [stop] holds.
  void playUntil(GameState s, bool Function(GameState s) stop, {int seed = 1}) {
    final rng = Random(seed);
    for (var guard = 0; guard < 5000 && !stop(s); guard++) {
      if (s.phase == GamePhase.playing && !PastraEngine.needsDeal(s) && !PastraEngine.roundCardsExhausted(s)) {
        PastraEngine.applyMove(s, PastraAI.chooseCard(s.copy(), AiLevel.medium, rng));
      } else if (s.phase == GamePhase.playing) {
        PastraEngine.advanceAuto(s);
      } else if (s.phase == GamePhase.roundOver) {
        PastraEngine.startNextRound(s);
      } else {
        break;
      }
    }
  }

  test('a four of a kind in the first deal voids it: dealt again, every card kept', () {
    for (final players in <int>[2, 4]) {
      GameState? hit;
      for (var seed = 0; seed < 50000 && hit == null; seed++) {
        final s = GameState(rules: rules, numPlayers: players, seed: seed, dealer: players - 1);
        PastraEngine.startRound(s);
        if (s.quads.isNotEmpty) hit = s;
      }
      expect(hit, isNotNull, reason: 'a deal with four of a kind for $players players');
      final s = hit!;
      // The void hand is shown to everybody: the whole hand, with the four.
      for (final q in s.quads) {
        expect(q.cards.length, rules.cardsPerDeal);
        expect(PastraEngine.hasFourOfAKind(q.cards), isTrue);
      }
      for (final h in s.hands) {
        expect(PastraEngine.hasFourOfAKind(h), isFalse);
        expect(h.length, rules.cardsPerDeal);
      }
      // Nothing lost or doubled, the opening cards and the dealer unchanged.
      final all = <int>[...s.deck, ...s.table, ...s.hands.expand((h) => h)];
      expect(all.toSet().length, Cards.deckSize);
      expect(all.length, Cards.deckSize);
      expect(s.table.length, PastraEngine.tableCardsAtStart);
      expect(s.dealer, players - 1);
      expect(s.current, 0);
      // The face-up cards under the deck are still at its bottom.
      final bottom = s.deck.take(s.exposed.where(s.deck.contains).length).toSet();
      expect(bottom, s.exposed.where(s.deck.contains).toSet());
    }
  });

  for (final players in <int>[2, 4]) {
    test('the end of a round is saved and loaded whole ($players players)', () {
      final s = PastraEngine.newGame(rules: rules, numPlayers: players, seed: 31);
      playUntil(s, (s) => s.phase == GamePhase.roundOver || s.phase == GamePhase.gameOver);
      expect(s.lastResult, isNotNull);
      final back = GameState.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(s.toJson())) as Map),
      );
      expect(back.phase, s.phase);
      expect(back.scores, s.scores);
      expect(back.round, s.round);
      expect(back.dealer, s.dealer);
      final a = s.lastResult!.teams;
      final b = back.lastResult!.teams;
      for (var t = 0; t < 2; t++) {
        expect(b[t].toJson(), a[t].toJson());
        expect(b[t].total, a[t].total);
      }
      // And it goes on from there like the original.
      if (back.phase == GamePhase.roundOver) {
        PastraEngine.startNextRound(back);
        expect(back.round, s.round + 1);
        expect(back.phase, GamePhase.playing);
      }
    });
  }

  test('a whole game with the automatic advance ends with a winner over the target', () {
    final s = PastraEngine.newGame(rules: rules, numPlayers: 2, seed: 77);
    playUntil(s, (s) => s.phase == GamePhase.gameOver, seed: 5);
    expect(s.phase, GamePhase.gameOver);
    expect(s.winner, anyOf(0, 1));
    expect(s.scores[s.winner], greaterThanOrEqualTo(rules.targetScore));
    expect(s.scores[s.winner], greaterThan(s.scores[1 - s.winner]));
    final back = GameState.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(s.toJson())) as Map));
    expect(back.phase, GamePhase.gameOver);
    expect(back.winner, s.winner);
  });

  group('refused moves', () {
    test('a card that is not in the hand', () {
      final s = PastraEngine.newGame(rules: rules, numPlayers: 2, seed: 3);
      final other = s.hands[1 - s.current].first;
      expect(() => PastraEngine.applyMove(s, other), throwsArgumentError);
    });
    test('a move when the round is not being played', () {
      final s = PastraEngine.newGame(rules: rules, numPlayers: 2, seed: 3);
      playUntil(s, (s) => s.phase != GamePhase.playing);
      expect(() => PastraEngine.applyMove(s, 0), throwsStateError);
    });
    test('a new round before the round is over', () {
      final s = PastraEngine.newGame(rules: rules, numPlayers: 2, seed: 3);
      expect(() => PastraEngine.startNextRound(s), throwsStateError);
    });
  });
}
