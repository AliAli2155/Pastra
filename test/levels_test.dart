import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/economy.dart';
import 'package:pastra/game/progression.dart';

void main() {
  test('levels: saved indexes keep their meaning, ordered from easiest to strongest', () {
    expect(AiLevel.values.take(3), <AiLevel>[AiLevel.easy, AiLevel.medium, AiLevel.hard]);
    expect(AiLevel.ordered.first, AiLevel.beginner);
    expect(AiLevel.ordered.last, AiLevel.master);
    expect(AiLevel.ordered.toSet(), AiLevel.values.toSet());
    for (var i = 1; i < AiLevel.ordered.length; i++) {
      final a = AiLevel.ordered[i - 1], b = AiLevel.ordered[i];
      expect(b.rank, greaterThan(a.rank));
      expect(Economy.offlineWin(b), greaterThan(Economy.offlineWin(a)));
      expect(Progression.levelFactor(b), greaterThan(Progression.levelFactor(a)));
    }
    expect(AiLevel.expert.samples, greaterThan(AiLevel.hard.samples));
    expect(AiLevel.master.samples, greaterThan(AiLevel.expert.samples));
  });

  test('every level plays a card from its hand', () async {
    for (final level in AiLevel.ordered) {
      final s = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 5);
      final card = PastraAI.chooseCard(s.copy(), level, Random(1));
      expect(s.hands[s.current], contains(card), reason: level.name);
      final sliced = await PastraAI.chooseCardSliced(s.copy(), level, Random(1));
      expect(s.hands[s.current], contains(sliced), reason: level.name);
    }
  });

  test('stats saved with three levels are kept', () {
    final st = GameStats.fromJson(<String, dynamic>{
      'gamesByLevel': <int>[4, 5, 6],
      'winsByLevel': <int>[1, 2, 3],
    });
    expect(st.gamesByLevel, hasLength(AiLevel.values.length));
    expect(st.gamesByLevel.take(3), <int>[4, 5, 6]);
    expect(st.winsByLevel.take(3), <int>[1, 2, 3]);
    expect(st.gamesByLevel[AiLevel.master.index], 0);
  });
}
