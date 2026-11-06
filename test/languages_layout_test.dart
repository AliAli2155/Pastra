import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/app.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/l10n/translations.dart';
import 'package:pastra/online/social_service.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/premium/premium.dart';
import 'package:pastra/ui/screens/friends_screen.dart';
import 'package:pastra/ui/screens/rules_screen.dart';
import 'package:pastra/ui/widgets/game_over.dart';
import 'package:pastra/ui/widgets/invite_banner.dart';
import 'package:pastra/ui/widgets/rules_editor.dart';
import 'package:pastra/ui/widgets/wallet_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screens with long texts and tight layouts, in every language: long
/// words (German, Russian), another script (Greek, Chinese) and right to
/// left (Arabic). A text that does not fit is an overflow error, which fails
/// the test.
void main() {
  Fx.forceLow();
  dailyBonusAutoShow = false;
  inviteListenerEnabled = false;
  SocialService.enabled = false;

  Future<AppSettings> setUp(WidgetTester tester, String lang, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(
      <String, Object>{'language': lang, 'sound': false, 'tutorialDone': true, 'xp': 40, 'gamesPlayed': 3},
    );
    return AppSettings.load();
  }

  Widget host(AppSettings settings, Widget home) => SettingsScope(
        settings: settings,
        child: MaterialApp(
          home: Directionality(
            textDirection: settings.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: home,
          ),
        ),
      );

  void onScreen(WidgetTester tester, Finder finder, Size size) {
    for (final rect in finder.evaluate().map((e) => tester.getRect(find.byWidget(e.widget)))) {
      expect(rect.top, greaterThanOrEqualTo(-0.5));
      expect(rect.bottom, lessThanOrEqualTo(size.height + 0.5));
    }
  }

  for (final lang in kLanguageNames.keys) {
    group(lang, () {
      for (final size in <Size>[const Size(844, 390), const Size(390, 760), const Size(960, 540)]) {
        final name = '${size.width.toInt()}x${size.height.toInt()}';

        testWidgets('lobby fits on $name', (tester) async {
          final settings = await setUp(tester, lang, size);
          await tester.pumpWidget(PastraApp(settings: settings));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('game over fits on $name', (tester) async {
          final settings = await setUp(tester, lang, size);
          final state = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 3)
            ..phase = GamePhase.gameOver
            ..winner = 0
            ..scores = <int>[164, 98];
          await tester.pumpWidget(
            host(
              settings,
              Scaffold(
                body: GameOverView(
                  state: state,
                  teamNames: const <String>['Alexandros', 'Konstantina'],
                  onNextRound: () {},
                  onMainMenu: () {},
                  onPlayAgain: () {},
                  xpGain: const GameXp(amount: 120, levelBefore: 1, levelAfter: 2),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          onScreen(tester, find.byType(GoldButton), size);
          onScreen(tester, find.byType(GlassButton), size);
        });

        testWidgets('game rules fit on $name', (tester) async {
          final settings = await setUp(tester, lang, size);
          await tester.pumpWidget(
            host(
              settings,
              Scaffold(
                body: Builder(
                  builder: (context) =>
                      TextButton(onPressed: () => showRulesDialog(context), child: const Text('open')),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          onScreen(tester, find.byType(FilledButton), size);
        });

        testWidgets('rules and friends fit on $name', (tester) async {
          final settings = await setUp(tester, lang, size);
          await tester.pumpWidget(host(settings, const RulesScreen()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(host(settings, const FriendsScreen()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
