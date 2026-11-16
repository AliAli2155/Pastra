import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/l10n/online_strings.dart';
import 'package:pastra/online/room_session.dart';
import 'package:pastra/ui/premium/premium.dart';
import 'package:pastra/ui/screens/online_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/menu_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screens.dart';

/// The waiting room on phones held sideways and on computers, for the host
/// (seat controls, start) and a guest ("Sit here"), with the app's own fonts:
/// everything fits, nothing has to be scrolled, the start button is there.
void main() {
  quietApp();

  const phones = <Size>[Size(667, 375), Size(740, 360), Size(844, 390), Size(932, 430)];
  const computers = <Size>[Size(1024, 768), Size(1280, 720), Size(1366, 768), Size(1440, 900), Size(1920, 1080)];

  RoomInfo room(int players, {bool full = false}) => RoomInfo(
        exists: true,
        hostUid: 'me',
        players: players,
        seats: <RoomSeat>[
          const RoomSeat(uid: 'me', name: 'Alexandros', online: true, pic: 'diamond', frame: 'silver'),
          if (players == 4) ...<RoomSeat>[
            const RoomSeat(uid: 'a', name: 'Konstantina', online: true, pic: 'boat'),
            if (full) const RoomSeat(uid: 'c', name: 'Παναγιώτης', online: true) else const RoomSeat(),
            const RoomSeat(uid: 'b', name: 'Nikos', online: false, pic: 'cat'),
          ] else
            const RoomSeat(),
        ],
      );

  /// The waiting room as the host ([host]) or the guest on seat 1 sees it.
  /// Returns whether the start button (host) could be pressed.
  Future<bool> open(WidgetTester tester, Size size, int players, {required bool host, String language = 'tr'}) async {
    await loadRealFonts();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': language, 'sound': false});
    final settings = await AppSettings.load();
    final t = OnlineStrings(language);
    final info = room(players);
    var started = false;
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        theme: buildPastraTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: Text(t.online)),
          body: Felt(
            child: SafeArea(
              top: false,
              child: LobbyLayout(
                codeCard: RoomCodeCard(code: '3920', onInviteFriends: host ? () {} : null),
                table: RoomTable(info: info, small: players == 4),
                seats: <Widget>[
                  for (var i = 0; i < players; i++)
                    RoomSeatRow(
                      info: info,
                      index: i,
                      mine: host ? i == 0 : i == 1,
                      compact: players == 4,
                      picked: host && players == 4 && i == 3,
                      onTap: host && i > 0 ? () {} : null,
                      onSit: !host && i > 1 && info.seats[i].uid == null ? () {} : null,
                    ),
                ],
                actions: host
                    ? <Widget>[
                        if (players == 4) SeatArrangeControls(seatChoice: true, onSeatChoice: (_) {}),
                        Text(t.botFills, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        BigButton(icon: Icons.play_arrow_rounded, label: t.start, onPressed: () => started = true),
                      ]
                    : <Widget>[
                        Text(t.waitForHost, textAlign: TextAlign.center),
                      ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    // Nothing has anything to scroll.
    for (final e in find.byType(Scrollable).evaluate()) {
      final position = (e as StatefulElement).state as ScrollableState;
      expect(position.position.maxScrollExtent, 0, reason: 'scrolls at ${size.width}x${size.height}');
    }
    if (!host) return false;
    final start = tester.getRect(find.text(t.start));
    expect(start.bottom, lessThanOrEqualTo(size.height));
    expect(start.top, greaterThan(0));
    await tester.tap(find.text(t.start));
    return started;
  }

  for (final size in <Size>[...phones, ...computers]) {
    for (final players in <int>[4, 2]) {
      testWidgets('host waiting room for $players fits at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        expect(await open(tester, size, players, host: true), isTrue);
      });
      testWidgets('guest waiting room for $players fits at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await open(tester, size, players, host: false);
        if (players == 4) expect(find.text(OnlineStrings('tr').sitHere), findsOneWidget);
      });
    }
  }

  // Long words: German and Greek on the smallest phone.
  for (final language in <String>['de', 'el', 'ru', 'ar']) {
    testWidgets('waiting room in $language fits on a small phone', (tester) async {
      expect(await open(tester, const Size(667, 375), 4, host: true, language: language), isTrue);
      await open(tester, const Size(667, 375), 4, host: false, language: language);
    });
  }

  testWidgets('the invite card has only the link and the friends buttons', (tester) async {
    await open(tester, const Size(1000, 540), 4, host: true);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Telegram'), findsNothing);
    expect(find.byType(GoldButton), findsOneWidget);
    expect(find.byType(GlassButton), findsOneWidget);
  });
}
