import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/widgets/round_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The score sheet counts the points row by row: the round total grows as
/// each row lands, then the game score moves on from where it was.
void main() {
  // Round totals 18 : 8, the game score goes from 22 : 22 to 40 : 30.
  const ours = TeamRoundScore(
    cards: 30,
    aces: 2,
    jacks: 1,
    honours: 9,
    twoOfClubs: true,
    tenOfDiamonds: false,
    pastras: 1,
    pastraPoints: 10,
    mostCards: true,
    total: 18,
  );
  const theirs = TeamRoundScore(
    cards: 22,
    aces: 2,
    jacks: 3,
    honours: 11,
    twoOfClubs: false,
    tenOfDiamonds: true,
    pastras: 0,
    pastraPoints: 0,
    mostCards: false,
    total: 8,
  );

  GameState roundOver({RoundResult result = const RoundResult(<TeamRoundScore>[ours, theirs]), int round = 2}) =>
      PastraEngine.newGame(rules: const PastraRules(), numPlayers: 2, seed: 1)
        ..phase = GamePhase.roundOver
        ..round = round
        ..scores = <int>[22 + result.teams[0].total, 22 + result.teams[1].total]
        ..lastResult = result;

  var nextRound = 0;

  Future<void> show(WidgetTester tester, GameState state, {FxMode fx = FxMode.auto}) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    // (Loading the settings sets the graphics quality they keep.)
    Fx.setMode(fx);
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        home: Scaffold(
          body: RoundSummaryPanel(
            state: state,
            teamNames: const <String>['Ali', 'Eleni'],
            onNextRound: () => nextRound++,
            onMainMenu: () {},
            onPlayAgain: () {},
          ),
        ),
      ),
    ));
  }

  int shown(WidgetTester tester, String key) => int.parse(tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!);
  List<int> totals(WidgetTester tester) => <int>[shown(tester, 'roundTotal0'), shown(tester, 'roundTotal1')];
  List<int> game(WidgetTester tester) => <int>[shown(tester, 'gameScore0'), shown(tester, 'gameScore1')];

  setUp(() => nextRound = 0);
  tearDown(() => Fx.setMode(FxMode.auto));

  testWidgets('the round total grows row by row, then the game score moves on', (tester) async {
    await show(tester, roundOver());
    await tester.pump();
    expect(totals(tester), <int>[0, 0]);
    expect(game(tester), <int>[22, 22]);

    // Every 100 ms: the totals only grow, the game score waits for them.
    var last = <int>[0, 0];
    var between = false;
    for (var ms = 100; ms <= 1800; ms += 100) {
      await tester.pump(const Duration(milliseconds: 100));
      final now = totals(tester);
      expect(now[0], greaterThanOrEqualTo(last[0]), reason: 'at $ms ms');
      expect(now[1], greaterThanOrEqualTo(last[1]), reason: 'at $ms ms');
      if (now[0] > 0 && now[0] < 18) between = true;
      expect(game(tester), <int>[22, 22], reason: 'the game score waits for the round (at $ms ms)');
      last = now;
    }
    expect(between, isTrue, reason: 'the total went up step by step');

    // The game score bars move on from the old score.
    await tester.pump(const Duration(milliseconds: 250));
    expect(totals(tester), <int>[18, 8]);
    final g = game(tester);
    expect(g[0], inExclusiveRange(22, 40));

    // And it all stops by itself.
    await tester.pumpAndSettle();
    expect(totals(tester), <int>[18, 8]);
    expect(game(tester), <int>[40, 30]);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap skips to the end', (tester) async {
    await show(tester, roundOver());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(totals(tester)[0], lessThan(18));
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(totals(tester), <int>[18, 8]);
    expect(game(tester), <int>[40, 30]);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('"Next round" works while the points are counted, and does not skip them', (tester) async {
    await show(tester, roundOver());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Next round'));
    expect(nextRound, 1);
    await tester.pump();
    expect(totals(tester)[0], lessThan(18));
    await tester.pumpAndSettle();
    expect(totals(tester), <int>[18, 8]);
  });

  testWidgets('the same result again (an online guest) is not counted again', (tester) async {
    await show(tester, roundOver());
    await tester.pumpAndSettle();
    expect(totals(tester), <int>[18, 8]);

    // The host sends the same state again: a new object, the same result.
    final again = roundOver();
    await show(tester, GameState.fromJson(again.toJson()));
    await tester.pump();
    expect(totals(tester), <int>[18, 8]);
    expect(tester.binding.transientCallbackCount, 0);

    // A new round's result is counted from the start.
    const other = TeamRoundScore(
      cards: 26,
      aces: 1,
      jacks: 2,
      honours: 10,
      twoOfClubs: false,
      tenOfDiamonds: false,
      pastras: 0,
      pastraPoints: 0,
      mostCards: false,
      total: 3,
    );
    await show(tester, roundOver(result: const RoundResult(<TeamRoundScore>[other, ours]), round: 3));
    await tester.pump();
    expect(totals(tester), <int>[0, 0]);
    await tester.pumpAndSettle();
    expect(totals(tester), <int>[3, 18]);
  });

  testWidgets('low graphics: everything is there at once', (tester) async {
    await show(tester, roundOver(), fx: FxMode.low);
    await tester.pump();
    expect(totals(tester), <int>[18, 8]);
    expect(game(tester), <int>[40, 30]);
  });
}
