import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/l10n/online_strings.dart';
import 'package:pastra/online/room_session.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/premium/premium.dart';
import 'package:pastra/ui/screens/online_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/invite_share.dart';
import 'package:pastra/ui/widgets/menu_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The waiting room of a 2v2 (and a 1v1) table: the seats, the table and
/// the start button fit without scrolling, the invite card has only the two
/// buttons.
void main() {
  Fx.forceLow();

  RoomInfo room(int players) => RoomInfo(
        exists: true,
        hostUid: 'me',
        players: players,
        seats: <RoomSeat>[
          const RoomSeat(uid: 'me', name: 'Ali', online: true, pic: 'diamond', frame: 'silver'),
          for (var i = 1; i < players; i++) const RoomSeat(),
        ],
      );

  Future<bool> open(WidgetTester tester, Size size, int players) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'tr', 'sound': false});
    final settings = await AppSettings.load();
    const t = OnlineStrings('tr');
    final info = room(players);
    var started = false;
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: buildPastraTheme(),
        home: Scaffold(
          appBar: AppBar(title: const Text('Online')),
          body: Felt(
            child: SafeArea(
              top: false,
              child: LobbyLayout(
                codeCard: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: glassDecoration(radius: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(t.roomCode),
                      const Text('3920',
                          style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: 12)),
                      Text(t.shareCode),
                      const SizedBox(height: 12),
                      InviteShareRow(code: '3920', onInviteFriends: () {}),
                    ],
                  ),
                ),
                table: RoomTable(info: info, small: players == 4),
                seats: <Widget>[
                  for (var i = 0; i < players; i++)
                    RoomSeatRow(info: info, index: i, mine: i == 0, compact: players == 4),
                ],
                actions: <Widget>[
                  Text(t.botFills, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  BigButton(icon: Icons.play_arrow_rounded, label: t.start, onPressed: () => started = true),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Nothing scrolls in the right column: the start button is on the screen.
    final start = tester.getRect(find.text(t.start));
    expect(start.bottom, lessThanOrEqualTo(size.height));
    expect(start.top, greaterThan(0));
    await tester.tap(find.text(t.start));
    return started;
  }

  for (final size in <Size>[const Size(1000, 540), const Size(960, 540), const Size(844, 390), const Size(1280, 800)]) {
    for (final players in <int>[4, 2]) {
      testWidgets('waiting room for $players fits at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        expect(await open(tester, size, players), isTrue);
        expect(find.byType(Scrollable).evaluate().where((e) => e.widget is! EditableText).length, lessThanOrEqualTo(1));
      });
    }
  }

  testWidgets('the invite card has only the link and the friends buttons', (tester) async {
    await open(tester, const Size(1000, 540), 4);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Telegram'), findsNothing);
    expect(find.byType(GoldButton), findsOneWidget);
    expect(find.byType(GlassButton), findsOneWidget);
  });
}
