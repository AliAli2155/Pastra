import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/game_controller.dart';
import 'package:pastra/game/online_link.dart';
import 'package:pastra/game/seats.dart';
import 'package:pastra/online/room_social.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The host's side of a room, without a network.
class _FakeLink implements OnlineLink {
  bool online = true;
  Set<int> reported = <int>{};

  @override
  bool isRemoteOnline(int seat) => online;

  @override
  void reportStandIns(Set<int> seats) => reported = Set<int>.of(seats);

  @override
  void sendMove(int card) {}

  @override
  void sendReady(int round) {}

  @override
  int get stake => 0;

  @override
  RoomSocial get social => throw UnimplementedError();

  @override
  String get code => '1234';

  @override
  int get players => 2;

  @override
  void close() {}
}

void main() {
  testWidgets('a bot plays for a player who is gone, until they are back', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false, 'turnSeconds': 0});
    final settings = await AppSettings.load();
    final link = _FakeLink();
    final c = GameController(
      settings: settings,
      seats: const <SeatInfo>[SeatInfo.human(), SeatInfo.remote('Eleni')],
      state: PastraEngine.newGame(rules: settings.rules, numPlayers: 2, seed: 7),
      link: link,
    );
    c.start();

    // Plays my cards whenever it is my turn; counts the other seat's moves.
    var theirMoves = 0;
    var lastHand = -1;
    Future<void> run(Duration time) async {
      final end = time.inMilliseconds;
      for (var t = 0; t < end; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
        if (c.state.phase != GamePhase.playing) continue;
        if (c.isHumanTurn && c.state.hands[0].isNotEmpty) c.playCard(c.state.hands[0].first);
        final n = c.state.hands[1].length;
        if (lastHand >= 0 && n < lastHand) theirMoves++;
        lastHand = n;
      }
    }

    await run(const Duration(seconds: 6));
    expect(c.standIns, isEmpty);
    final before = theirMoves;
    expect(c.isHumanTurn || c.state.current == 1, isTrue);

    // Eleni's connection drops: after a few seconds a bot takes her seat
    // and plays her cards without waiting for her.
    link.online = false;
    await run(const Duration(seconds: 5));
    expect(c.standIns, <int>{1});
    expect(c.offlineSeats, <int>{1});
    expect(link.reported, <int>{1});
    await run(const Duration(seconds: 12));
    expect(theirMoves, greaterThan(before + 1));

    // She is back: the seat is hers again (the game waits for her moves).
    link.online = true;
    await run(const Duration(seconds: 2));
    expect(c.standIns, isEmpty);
    expect(c.offlineSeats, isEmpty);
    expect(link.reported, isEmpty);
    final atReturn = theirMoves;
    await run(const Duration(seconds: 8));
    expect(theirMoves, lessThanOrEqualTo(atReturn + 1));

    c.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  test('the room to go back to is forgotten after it ended', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en'});
    final settings = await AppSettings.load();
    expect(settings.lastRoom, isNull);
    settings.rememberRoom('4821');
    expect(settings.lastRoom, '4821');
    settings.rememberRoom(null);
    expect(settings.lastRoom, isNull);
  });
}
