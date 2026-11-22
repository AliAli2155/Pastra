import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/app.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/avatar_pic.dart';
import 'package:pastra/game/game_controller.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/game/seats.dart';
import 'package:pastra/online/social_service.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/premium/premium.dart';
import 'package:pastra/ui/screens/game_screen.dart';
import 'package:pastra/ui/screens/home_screen.dart';
import 'package:pastra/ui/screens/level_path_screen.dart';
import 'package:pastra/ui/screens/quests_screen.dart';
import 'package:pastra/ui/screens/rules_screen.dart';
import 'package:pastra/ui/screens/settings_screen.dart';
import 'package:pastra/ui/screens/stats_screen.dart';
import 'package:pastra/ui/screens/store_screen.dart';
import 'package:pastra/ui/screens/tournament_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/game_over.dart';
import 'package:pastra/ui/widgets/invite_banner.dart';
import 'package:pastra/ui/widgets/profile_card.dart';
import 'package:pastra/ui/widgets/round_summary.dart';
import 'package:pastra/ui/widgets/wallet_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screens every check walks through (the screen sweep, the screenshot
/// gallery), with what each needs. Screens that need Firebase (online,
/// friends, leaderboard) are left out.
class SweepScreen {
  const SweepScreen(this.name, this.build, {this.game, this.setUp});

  final String name;

  /// The screen; [game] screens get their controller.
  final Widget Function(GameController? game) build;

  /// Players of the table for a game screen (null: no game).
  final int? game;

  /// Something to do once it is shown (open a dialog, …).
  final Future<void> Function(WidgetTester tester)? setUp;
}

final List<SweepScreen> sweepScreens = <SweepScreen>[
  SweepScreen('lobby', (_) => const _Lobby()),
  SweepScreen('profile', (_) => const _Lobby(), setUp: _openProfile),
  SweepScreen('quests', (_) => const QuestsScreen()),
  SweepScreen('level_path', (_) => const LevelPathScreen()),
  SweepScreen('tournament', (_) => const TournamentScreen()),
  SweepScreen('rules', (_) => const RulesScreen()),
  for (var i = 0; i < 4; i++) SweepScreen('stats_$i', (_) => StatsScreen(initialTab: i)),
  for (var i = 0; i < 5; i++) SweepScreen('settings_$i', (_) => SettingsScreen(initialTab: i)),
  for (var i = 0; i < 8; i++) SweepScreen('store_$i', (_) => StoreScreen(initialTab: i)),
  SweepScreen('quick_game', (_) => const _Lobby(), setUp: _openQuickGame),
  SweepScreen('game_over', (_) => _gameOver(sheet: false)),
  SweepScreen('score_sheet', (_) => _gameOver(sheet: true)),
  SweepScreen('round_ready', (_) => roundReadySheet()),
  SweepScreen('table_1v1', (c) => GameScreen(controller: c!), game: 2),
  SweepScreen('table_2v2', (c) => GameScreen(controller: c!), game: 4),
];

/// The lobby as the app shows it (with its banners over it).
class _Lobby extends StatelessWidget {
  const _Lobby();

  @override
  Widget build(BuildContext context) => PastraApp(settings: SettingsScope.of(context));
}

Future<void> _openQuickGame(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  final settings = SettingsScope.read(context);
  unawaited(showDialog<void>(
    context: context,
    builder: (_) => PremiumDialog(
      child: NewGameSheet(initialPlayers: settings.players, initialLevel: settings.level),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The end of a game: the big moment, or the score sheet of the last round.
Widget _gameOver({required bool sheet}) {
  final state = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 7);
  // A real last round (with its score sheet) up to the game over.
  final rng = Random(3);
  while (state.phase != GamePhase.gameOver) {
    if (state.phase == GamePhase.roundOver) {
      PastraEngine.startNextRound(state);
    } else if (PastraEngine.needsDeal(state) || PastraEngine.roundCardsExhausted(state)) {
      PastraEngine.advanceAuto(state);
    } else {
      PastraEngine.applyMove(state, PastraAI.chooseCard(state.copy(), AiLevel.medium, rng));
    }
  }
  return Scaffold(
    body: sheet
        ? RoundSummaryPanel(
            state: state,
            teamNames: const <String>['Ali', 'Konstantina'],
            onNextRound: () {},
            onMainMenu: () {},
            onPlayAgain: () {},
            xpGain: const GameXp(amount: 120, levelBefore: 11, levelAfter: 12, chips: 400),
          )
        : GameOverView(
            state: state,
            teamNames: const <String>['Ali', 'Konstantina'],
            onNextRound: () {},
            onMainMenu: () {},
            onPlayAgain: () {},
            xpGain: const GameXp(amount: 120, levelBefore: 11, levelAfter: 12, chips: 400),
          ),
  );
}

/// An online 2v2 table after a round: who is ready for the next one (the
/// local player and their partner are).
Widget roundReadySheet({Set<int> ready = const <int>{0, 2}, VoidCallback? onReady}) {
  final state = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 4, seed: 7);
  final rng = Random(3);
  while (state.phase != GamePhase.roundOver) {
    if (PastraEngine.needsDeal(state) || PastraEngine.roundCardsExhausted(state)) {
      PastraEngine.advanceAuto(state);
    } else {
      PastraEngine.applyMove(state, PastraAI.chooseCard(state.copy(), AiLevel.medium, rng));
    }
  }
  return Scaffold(
    body: RoundSummaryPanel(
      state: state,
      teamNames: const <String>['Ali · Eleni', 'Konstantina · Nikos'],
      onNextRound: () {},
      onMainMenu: () {},
      onPlayAgain: () {},
      ready: RoundReady(
        players: <ReadyPlayer>[
          ReadyPlayer(name: 'Ali', pic: AvatarPic.byName('boat'), frame: AvatarFrame.gold),
          const ReadyPlayer(name: 'Konstantina'),
          ReadyPlayer(name: 'Eleni', pic: AvatarPic.byName('cat')),
          ReadyPlayer(name: 'Nikos', pic: AvatarPic.byName('diamond'), frame: AvatarFrame.silver),
        ],
        ready: ready,
        deadline: DateTime.now().add(const Duration(seconds: 24)),
        onReady: onReady ?? () {},
      ),
    ),
  );
}

Future<void> _openProfile(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(showMyProfile(context, onLevelPath: () {}, onAppearance: () {}));
  await tester.pumpAndSettle();
}

/// No Firebase, no daily bonus dialog, no endless animations in the tests.
void quietApp() {
  Fx.forceLow();
  dailyBonusAutoShow = false;
  inviteListenerEnabled = false;
  SocialService.enabled = false;
}

bool _fontsLoaded = false;

/// The app's own fonts (and the icons), so that text is measured and drawn
/// as on a phone, not in the test font with its square letters.
Future<void> loadRealFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (!f.existsSync()) continue;
      loader.addFont(Future<ByteData>.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  const weights = <String>['Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  await load('Outfit', <String>[for (final w in weights) 'assets/fonts/Outfit-$w.ttf']);
  await load('Manrope', <String>[for (final w in weights) 'assets/fonts/Manrope-$w.ttf']);
  // The icons come with the Flutter SDK: next to the test runner.
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path && !dir.path.endsWith('${Platform.pathSeparator}artifacts')) {
    dir = dir.parent;
  }
  await load('MaterialIcons', <String>['${dir.path}/material_fonts/MaterialIcons-Regular.otf']);
}

/// Shows [screen] at [size] in [language] (with a level, chips and a few
/// games behind the player, so that the screens are not empty).
Future<GameController?> pumpSweepScreen(WidgetTester tester, SweepScreen screen, Size size, String language) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues(<String, Object>{
    'language': language,
    'sound': false,
    'tutorialDone': true,
    'xp': 2600,
    'chips': 25000,
    'diamonds': 40,
    'playerName': 'Ali',
    'turnSeconds': 20,
  });
  final settings = await AppSettings.load();
  GameController? game;
  final players = screen.game;
  if (players != null) {
    game = GameController(
      settings: settings,
      seats: SeatInfo.lineup(players, AiLevel.expert),
      state: PastraEngine.newGame(rules: settings.rules, numPlayers: players, seed: 17),
    );
  }
  final child = screen.build(game);
  await tester.pumpWidget(
    SettingsScope(
      settings: settings,
      child: child is _Lobby
          ? child
          : MaterialApp(theme: buildPastraTheme(), debugShowCheckedModeBanner: false, home: child),
    ),
  );
  if (players != null) {
    // The deal and the opening cards.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else {
    await tester.pumpAndSettle();
  }
  await screen.setUp?.call(tester);
  return game;
}

/// Leaves a screen (and a game's timers) behind before the next one.
Future<void> leaveSweepScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
  tester.view.reset();
}
