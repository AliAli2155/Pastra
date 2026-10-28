import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/game/tournament.dart';

void main() {
  test('new tournament: you and seven different bots', () {
    final t = Tournament.create(Random(1));
    expect(t.bots.length, 8);
    expect(t.bots.where((b) => b == -1).length, 1);
    expect(t.bots[t.humanSlot], -1);
    final names = t.bots.where((b) => b >= 0).toSet();
    expect(names.length, 7);
    expect(t.finished, isFalse);
    expect(t.round, 0);
    expect(t.opponentLevel, AiLevel.easy);
    expect(t.opponentSlot, isNot(t.humanSlot));
    expect(t.opponentSlot ~/ 2, t.humanSlot ~/ 2);
  });

  test('winning every match makes you champion; opponents get harder', () {
    final t = Tournament.create(Random(2));
    final levels = <AiLevel>[];
    for (var i = 0; i < Tournament.rounds; i++) {
      expect(t.finished, isFalse);
      levels.add(t.opponentLevel);
      expect(t.round, i);
      t.reportHumanMatch(true, Random(i));
    }
    expect(levels, <AiLevel>[AiLevel.easy, AiLevel.medium, AiLevel.hard]);
    expect(t.finished, isTrue);
    expect(t.hasChampion, isTrue);
    expect(t.won, isTrue);
    expect(t.wins, 3);
    expect(t.bonusXp, 200);
    expect(t.bracket.map((r) => r.length).toList(), <int>[8, 4, 2, 1]);
  });

  test('a defeat ends it and the rest is played out', () {
    final t = Tournament.create(Random(3));
    t.reportHumanMatch(true, Random(1));
    expect(t.round, 1);
    t.reportHumanMatch(false, Random(2));
    expect(t.humanOut, isTrue);
    expect(t.finished, isTrue);
    expect(t.won, isFalse);
    expect(t.lostRound, 1);
    expect(t.wins, 1);
    expect(t.bonusXp, 30);
    expect(t.hasChampion, isTrue);
    expect(t.championSlot, isNot(t.humanSlot));
    expect(t.bracket.map((r) => r.length).toList(), <int>[8, 4, 2, 1]);
    // The slots of every round come from the previous round.
    for (var r = 1; r < t.bracket.length; r++) {
      expect(t.bracket[r].every(t.bracket[r - 1].contains), isTrue);
    }
  });

  test('losing the first match gives no bonus', () {
    final t = Tournament.create(Random(4));
    t.reportHumanMatch(false, Random(1));
    expect(t.lostRound, 0);
    expect(t.wins, 0);
    expect(t.bonusXp, 0);
  });

  test('json round trip', () {
    final t = Tournament.create(Random(5));
    t.reportHumanMatch(true, Random(1));
    final back = Tournament.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(t.toJson())) as Map));
    expect(back, isNotNull);
    expect(back!.bots, t.bots);
    expect(back.bracket, t.bracket);
    expect(back.humanSlot, t.humanSlot);
    expect(back.round, 1);
    expect(Tournament.fromJson(<String, dynamic>{'bots': <int>[1]}), isNull);
  });
}
