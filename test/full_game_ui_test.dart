import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/game_controller.dart';
import 'package:pastra/game/match_history.dart';
import 'package:pastra/game/seats.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/game_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/game_over.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whole games on the real table screen, from the deal to the game over and
/// the match history, with the bots and a time limit for my moves.
void main() {
  Fx.forceLow();

  for (final players in <int>[2, 4]) {
    testWidgets('a whole ${players == 2 ? '1v1' : '2v2'} game on the table', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'language': 'en',
        'sound': false,
        'tutorialDone': true,
        'fastAnimations': true,
        'turnSeconds': 10,
      });
      final settings = await AppSettings.load();
      final c = GameController(
        settings: settings,
        seats: SeatInfo.lineup(players, AiLevel.easy),
        state: PastraEngine.newGame(rules: settings.rules, numPlayers: players, seed: 5 + players),
      );
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(theme: buildPastraTheme(), home: GameScreen(controller: c)),
      ));

      var rounds = 0;
      var myMoves = 0;
      for (var step = 0; step < 40000 && c.state.phase != GamePhase.gameOver; step++) {
        await tester.pump(const Duration(milliseconds: 100));
        final e = tester.takeException();
        if (e != null) {
          debugPrint('STEP $step phase ${c.state.phase} current ${c.state.current} ex: $e');
          for (final r in tester.allRenderObjects) {
            if (r is RenderFlex && r.toString().contains('OVERFLOWING')) {
              debugPrint('OVERFLOW ${r.debugCreator}');
              debugPrint(r.toStringDeep().split('\n').take(25).join('\n'));
            }
          }
          fail('exception at step $step');
        }
        if (c.state.phase == GamePhase.roundOver) {
          // The score sheet of the round: go on.
          rounds++;
          c.nextRound();
          continue;
        }
        // Every other turn I play at once; otherwise the time runs out and
        // a card is played for me.
        if (c.isHumanTurn && c.state.hands[0].isNotEmpty && step.isEven && myMoves++ % 3 != 0) {
          c.playCard(c.state.hands[0].first);
        }
      }
      expect(c.state.phase, GamePhase.gameOver);
      // The big moment, then the score sheet by itself.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(GameOverView), findsOneWidget);
      expect(tester.takeException(), isNull);
      // It is in the match history, from my side.
      final last = settings.history.first;
      expect(last.players, players);
      expect(last.mode, MatchMode.offline);
      expect(last.won, c.state.winner == 0);
      expect(last.ours, c.state.scores[0]);
      expect(last.theirs, c.state.scores[1]);
      expect(last.canRematch, isTrue);
      expect(rounds, greaterThan(0));
      expect(settings.stats.games, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
