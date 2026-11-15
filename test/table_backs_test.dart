import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/game_controller.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/game/seats.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/game_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/playing_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Fx.forceLow();

  Future<GameController> open(WidgetTester tester, List<SeatInfo> seats, {int turnSeconds = 0}) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'language': 'en',
      'sound': false,
      'tutorialDone': true,
      'turnSeconds': turnSeconds,
    });
    final settings = await AppSettings.load();
    final c = GameController(
      settings: settings,
      seats: seats,
      state: PastraEngine.newGame(rules: settings.rules, numPlayers: seats.length, seed: 11),
    );
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: buildPastraTheme(), home: GameScreen(controller: c)),
    ));
    // The deal and the four opening cards.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return c;
  }

  Future<void> close(WidgetTester tester, GameController c) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Iterable<PlayingCardView> faceDown(WidgetTester tester) =>
      tester.widgetList<PlayingCardView>(find.byType(PlayingCardView)).where((v) => !v.faceUp);

  testWidgets('an online player\'s cards show the back they chose', (tester) async {
    final c = await open(tester, const <SeatInfo>[SeatInfo.human(), SeatInfo.remote('Eleni', back: 'ruby')]);
    final hand = c.state.hands[1].length;
    expect(hand, greaterThan(0));
    final ruby = faceDown(tester).where((v) => v.backStyle == CardBackStyle.ruby).length;
    expect(ruby, hand);
    // Everything else face down (the deck) keeps my own back.
    expect(faceDown(tester).where((v) => v.backStyle == null).length, faceDown(tester).length - hand);
    expect(faceDown(tester).length - hand, greaterThan(20));
    await close(tester, c);
  });

  testWidgets('a player without a known back plays with mine', (tester) async {
    final c = await open(tester, const <SeatInfo>[SeatInfo.human(), SeatInfo.remote('Nikos')]);
    expect(faceDown(tester).every((v) => v.backStyle == null), isTrue);
    await close(tester, c);
  });

  testWidgets('bots play with a back of their own, never mine', (tester) async {
    final c = await open(tester, SeatInfo.lineup(4, AiLevel.medium));
    for (var seat = 1; seat < 4; seat++) {
      final n = c.state.hands[seat].length;
      final backs = faceDown(tester).map((v) => v.backStyle).whereType<CardBackStyle>().toList();
      expect(backs.length, greaterThanOrEqualTo(n));
    }
    final backs = faceDown(tester).map((v) => v.backStyle).whereType<CardBackStyle>().toSet();
    // Three bots, three different backs, all from the level path (the ones
    // the appearance settings show), never a store back.
    expect(backs.length, 3);
    expect(Progression.backLevel.keys, containsAll(backs));
    expect(backs, isNot(contains(c.settings.cardBack)));
    expect(backs, isNot(contains(CardBackStyle.aegean)));
    await close(tester, c);
  });

  bool hasRing(WidgetTester tester) =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TimerRing').evaluate().isNotEmpty;

  testWidgets('with a time limit the ring sits on the avatar of the player to move', (tester) async {
    final c = await open(tester, const <SeatInfo>[SeatInfo.human(), SeatInfo.remote('Eleni')], turnSeconds: 20);
    expect(c.turnLimit, isNotNull);
    expect(hasRing(tester), isTrue);
    expect(tester.takeException(), isNull);
    await close(tester, c);
  });

  testWidgets('no time limit, no ring', (tester) async {
    final c = await open(tester, const <SeatInfo>[SeatInfo.human(), SeatInfo.remote('Eleni')]);
    expect(hasRing(tester), isFalse);
    await close(tester, c);
  });
}
