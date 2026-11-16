import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/online/room_session.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/online_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choosing seats in the waiting room of a 2v2 table.
void main() {
  Fx.forceLow();

  const ali = RoomSeat(uid: 'host', name: 'Ali', online: true);
  const eleni = RoomSeat(uid: 'u1', name: 'Eleni', online: true);
  const nikos = RoomSeat(uid: 'u2', name: 'Nikos', online: true);

  group('a guest follows their seat', () {
    test('stays where they are while it is theirs', () {
      // Moving themselves: for a moment on both seats.
      expect(followSeat(const <RoomSeat>[ali, eleni, RoomSeat(), eleni], 'u1', 3), 3);
    });
    test('follows the host who moved them', () {
      expect(followSeat(const <RoomSeat>[ali, RoomSeat(), eleni, RoomSeat()], 'u1', 1), 2);
    });
    test('keeps the seat while they are nowhere', () {
      expect(followSeat(const <RoomSeat>[ali, RoomSeat(), RoomSeat(), RoomSeat()], 'u1', 1), 1);
    });
  });

  group('the host moves players', () {
    final a = <String, dynamic>{'uid': 'u1', 'name': 'Eleni', 'online': true};
    final b = <String, dynamic>{'uid': 'u2', 'name': 'Nikos', 'online': true};
    test('to a free seat', () {
      expect(seatMoveUpdate(a, null, 1, 2), <String, Object?>{'s2': a, 's1': null});
    });
    test('or swaps two players', () {
      expect(seatMoveUpdate(a, b, 1, 3), <String, Object?>{'s3': a, 's1': b});
    });
    test('nothing to move, nothing written', () {
      expect(seatMoveUpdate(null, null, 1, 2), isEmpty);
    });
  });

  Future<void> show(WidgetTester tester, Widget row) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'tr'});
    final settings = await AppSettings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: buildPastraTheme(), home: Scaffold(body: Center(child: SizedBox(width: 420, child: row)))),
    ));
  }

  const room = RoomInfo(exists: true, players: 4, seats: <RoomSeat>[ali, eleni, RoomSeat(), nikos]);

  testWidgets('a free seat offers "Sit here"', (tester) async {
    var sat = false;
    await show(tester, RoomSeatRow(info: room, index: 2, compact: true, onSit: () => sat = true));
    await tester.tap(find.text('Buraya otur'));
    expect(sat, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a taken seat offers no "Sit here"', (tester) async {
    await show(tester, RoomSeatRow(info: room, index: 1, compact: true, onSit: () {}));
    expect(find.text('Buraya otur'), findsNothing);
  });

  testWidgets('the player the host picked asks "Where to?"', (tester) async {
    var taps = 0;
    await show(tester, RoomSeatRow(info: room, index: 3, compact: true, picked: true, onTap: () => taps++));
    expect(find.text('Nereye?'), findsOneWidget);
    await tester.tap(find.text('Nikos'));
    expect(taps, 1);
  });
}
