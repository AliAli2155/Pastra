import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/match_history.dart';
import 'package:pastra/game/seats.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/game_screen.dart';
import 'package:pastra/ui/screens/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

MatchRecord _game(int i, {bool online = false, int players = 2}) => MatchRecord(
      time: DateTime(2026, 11, 12, 10, i).millisecondsSinceEpoch,
      won: i.isEven,
      ours: 151 + i,
      theirs: 90,
      mode: online ? MatchMode.online : MatchMode.offline,
      level: AiLevel.expert,
      pastras: i % 3,
      others: online
          ? const <MatchPlayer>[MatchPlayer(name: 'Eleni', pic: 'boat', frame: 'gold')]
          : <MatchPlayer>[
              for (var k = 1; k < players; k++) MatchPlayer.of(SeatInfo.bot(AiLevel.expert, k + i)),
            ],
    );

void main() {
  Fx.forceLow();

  test('a record survives saving, older games fall off after 20', () {
    final r = _game(1, players: 4);
    final back = MatchRecord.fromJson(r.toJson())!;
    expect(back.ours, r.ours);
    expect(back.won, r.won);
    expect(back.players, 4);
    expect(back.partner!.botIndex, r.others[1].botIndex);
    expect(back.opponents.length, 2);
    expect(back.canRematch, isTrue);
    expect(back.rematchSeats().map((s) => s.botIndex).toList(), <int>[-1, ...r.others.map((p) => p.botIndex)]);
    expect(_game(2, online: true).canRematch, isFalse);
    var list = <MatchRecord>[];
    for (var i = 0; i < 25; i++) {
      list = MatchRecord.add(list, _game(i));
    }
    expect(list.length, 20);
    expect(list.first.ours, 151 + 24);
    expect(MatchRecord.fromJson('nonsense'), isNull);
  });

  Future<AppSettings> open(WidgetTester tester, Size size, {bool empty = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    if (!empty) {
      for (var i = 0; i < 20; i++) {
        settings.addMatch(_game(i, online: i % 5 == 0, players: i % 4 == 1 ? 4 : 2));
      }
    }
    await tester.pumpWidget(SettingsScope(settings: settings, child: const MaterialApp(home: StatsScreen())));
    await tester.pumpAndSettle();
    // (On a narrow screen the tabs are pills in a row that scrolls.)
    await tester.ensureVisible(find.text('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match history'));
    await tester.pumpAndSettle();
    return settings;
  }

  for (final size in <Size>[const Size(844, 390), const Size(390, 760)]) {
    testWidgets('match history fits at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await open(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.replay_rounded), findsWidgets);
      expect(find.text('Eleni'), findsWidgets);
    });
  }

  testWidgets('an empty history says so', (tester) async {
    await open(tester, const Size(844, 390), empty: true);
    expect(find.textContaining('No games yet'), findsOneWidget);
  });

  testWidgets('rematch starts a game against the same bots', (tester) async {
    await open(tester, const Size(1280, 720));
    await tester.tap(find.byIcon(Icons.replay_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);
    // Leave the game (timers of the deal) before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
