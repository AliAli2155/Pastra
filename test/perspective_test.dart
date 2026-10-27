import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/perspective.dart';
import 'package:pastra/engine/rules.dart';

void main() {
  for (final players in <int>[2, 4]) {
    test('rotating for every seat keeps the cards and turn order ($players players)', () {
      final s = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: players, seed: 7);
      s.scores = <int>[10, 20];
      s.piles = <List<int>>[<int>[1, 2], <int>[3]];
      for (var seat = 0; seat < players; seat++) {
        final r = rotateStateFor(s, seat);
        // The local player's hand is the real hand of [seat].
        expect(r.hands[0], s.hands[seat]);
        // Next player in turn order stays next.
        for (var i = 0; i < players; i++) {
          expect(r.hands[(i - seat + players) % players], s.hands[i]);
        }
        expect(r.current, (s.current - seat + players) % players);
        expect(r.dealer, (s.dealer - seat + players) % players);
        // Team 0 is the local player's team.
        final swap = seat.isOdd;
        expect(r.scores, swap ? <int>[20, 10] : <int>[10, 20]);
        expect(r.piles[0], swap ? s.piles[1] : s.piles[0]);
        expect(rotateSeat(seat, seat, players), 0);
      }
    });
  }

  test('rotated state survives JSON (what goes over the network)', () {
    final s = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 4, seed: 3);
    final view = rotateStateFor(s.redactedFor(1), 1);
    final back = GameState.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(view.toJson())) as Map));
    expect(back.hands[0], s.hands[1]);
    // Other hands are hidden but keep their size.
    expect(back.hands[1].every((c) => c == -1), isTrue);
    expect(back.hands[1].length, s.hands[2].length);
    expect(back.deck.every((c) => c == -1), isTrue);
  });
}
