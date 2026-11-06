import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/widgets/game_over.dart';
import 'package:pastra/ui/widgets/round_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Fx.forceLow();

  // A phone held sideways, a small laptop window and a phone held upright.
  for (final size in <Size>[const Size(844, 390), const Size(960, 540), const Size(390, 760)]) {
    testWidgets('game over fits on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false, 'xp': 40});
      final settings = await AppSettings.load();
      final state = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 7)
        ..phase = GamePhase.gameOver
        ..winner = 1
        ..scores = <int>[24, 64];

      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: MaterialApp(
            home: Scaffold(
              body: GameOverView(
                state: state,
                teamNames: const <String>['You', 'Sam'],
                onNextRound: () {},
                onMainMenu: () {},
                onPlayAgain: () {},
                xpGain: const GameXp(amount: 20, levelBefore: 1, levelAfter: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Both buttons and the score sheet link are on the screen, not below it.
      for (final label in <String>['Main menu', 'Play again', 'Game score']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$label is cut off');
        expect(rect.top, greaterThanOrEqualTo(0));
      }
    });
  }

  testWidgets('the score sheet comes by itself after the big moment', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    final state = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 7)
      ..phase = GamePhase.gameOver
      ..winner = 0
      ..scores = <int>[154, 64];
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: MaterialApp(
          home: Scaffold(
            body: GameOverView(
              state: state,
              teamNames: const <String>['You', 'Sam'],
              onNextRound: () {},
              onMainMenu: () {},
              onPlayAgain: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(RoundSummaryPanel), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(RoundSummaryPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
