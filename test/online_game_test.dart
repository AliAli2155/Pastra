import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/perspective.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/game_controller.dart';
import 'package:pastra/game/online_link.dart';
import 'package:pastra/game/seats.dart';
import 'package:pastra/online/room_session.dart';
import 'package:pastra/online/room_social.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One player's end of the room.
class _Link implements OnlineLink {
  _Link(this.room, this.seat);

  final _Room room;

  /// Real seat (0 = the host).
  final int seat;

  @override
  void sendMove(int card) => room.send(seat, <String, Object?>{'card': card});

  @override
  void sendReady(int round) => room.send(seat, <String, Object?>{'ready': round});

  @override
  bool isRemoteOnline(int seat) => !room.offline.contains(seat);

  @override
  void reportStandIns(Set<int> seats) => room.reportStandIns(seats);

  @override
  int get stake => 0;

  @override
  RoomSocial get social => throw UnimplementedError();

  @override
  String get code => '1234';

  @override
  int get players => room.players;

  @override
  void close() {}
}

/// A room without a network. The host's views and the guests' moves go
/// through the same functions as in a real room ([hostViews],
/// [readHostView], [translateHostEvent], [readSeatMessage], [guestSeats]), as JSON,
/// a moment later, like through the database.
class _Room {
  _Room({required this.players, required this.people, required this.settings, this.turnSeconds = 0});

  final int players;

  /// Real seats of the guests (the others, apart from the host, are bots).
  final Set<int> people;

  /// Everybody's own settings, by real seat.
  final Map<int, AppSettings> settings;
  final int turnSeconds;

  late final GameController host;
  final Map<int, GameController> guests = <int, GameController>{};

  /// Guests without a connection: nothing reaches them, nothing they send
  /// reaches the host.
  final Set<int> offline = <int>{};
  List<int> standIns = <int>[];

  final Map<int, int> _lastView = <int, int>{};
  final Map<int, Object?> _latest = <int, Object?>{};
  final Map<int, int> _lastMove = <int, int>{};
  final Map<int, int> _sent = <int, int>{};
  int _published = -1;

  /// Views written for each guest.
  final Map<int, int> written = <int, int>{};

  /// Cards a guest could see but must not (another hand, the deck).
  final List<String> leaks = <String>[];

  static const Duration latency = Duration(milliseconds: 40);

  RoomInfo get info => RoomInfo(
        exists: true,
        hostUid: 'host',
        players: players,
        status: 'playing',
        turnSeconds: turnSeconds,
        standIns: standIns,
        seats: <RoomSeat>[
          for (var i = 0; i < players; i++)
            if (i == 0)
              const RoomSeat(uid: 'host', name: 'Ali', online: true)
            else if (people.contains(i))
              RoomSeat(uid: 'u$i', name: 'P$i', online: true)
            else
              RoomSeat(bot: true, online: true, botIndex: i),
        ],
      );

  void start(GameState state) {
    host = GameController(
      settings: settings[0]!,
      seats: <SeatInfo>[
        const SeatInfo.human(),
        for (var i = 1; i < players; i++) people.contains(i) ? SeatInfo.remote('P$i') : SeatInfo.bot(AiLevel.medium, i),
      ],
      state: state,
      link: _Link(this, 0),
    );
    host.addListener(_publish);
    host.start();
    _publish();
  }

  void _publish() {
    if (host.stateVersion == _published) return;
    _published = host.stateVersion;
    for (final view in hostViews(host, _published).entries) {
      final seat = view.key;
      final raw = jsonDecode(jsonEncode(view.value));
      written[seat] = (written[seat] ?? 0) + 1;
      _checkHidden(seat, raw);
      _latest[seat] = raw;
      Timer(latency, () => _deliver(seat, raw));
    }
  }

  /// The guest on [seat] sees only their own hand and the face-up cards.
  void _checkHidden(int seat, Object? raw) {
    final m = raw! as Map;
    final seen = GameState.fromJson(Map<String, dynamic>.from(jsonDecode(m['s'] as String) as Map));
    final real = host.state;
    final exposed = real.exposed.toSet();
    final mine = real.hands[seat].toSet();
    if (!seen.hands[0].toSet().containsAll(mine) || seen.hands[0].length != mine.length) {
      leaks.add('seat $seat got a wrong own hand');
    }
    for (var i = 1; i < seen.hands.length; i++) {
      for (final c in seen.hands[i]) {
        if (c >= 0 && !exposed.contains(c)) leaks.add('seat $seat saw card $c in hand $i');
      }
    }
    for (final c in seen.deck) {
      if (c >= 0 && !exposed.contains(c)) leaks.add('seat $seat saw card $c in the deck');
    }
    if (seen.seed != 0) leaks.add('seat $seat got the seed');
  }

  void _deliver(int seat, Object? raw) {
    if (offline.contains(seat)) return;
    final view = readHostView(raw, _lastView[seat] ?? -1);
    if (view == null) return;
    _lastView[seat] = view.version;
    var g = guests[seat];
    if (g == null) {
      g = GameController(
        settings: settings[seat]!,
        seats: guestSeats(info, seat, players),
        state: view.state,
        link: _Link(this, seat),
        isGuest: true,
        hostTurnSeconds: turnSeconds,
      );
      guests[seat] = g;
      g.start();
    }
    g.applyHostView(view.state, translateHostEvent(view.events, seat, players));
  }

  /// A guest's move or "ready", through their slot `moves/s<seat>`.
  void send(int seat, Map<String, Object?> message) {
    final n = _sent[seat] = (_sent[seat] ?? 0) + 1;
    final raw = jsonDecode(jsonEncode(<String, Object?>{'n': n, ...message}));
    Timer(latency, () {
      if (offline.contains(seat)) return;
      final m = readSeatMessage(raw, _lastMove[seat] ?? 0);
      if (m == null) return;
      _lastMove[seat] = m.n;
      final card = m.card;
      final ready = m.ready;
      if (card != null) host.submitRemoteMove(seat, card);
      if (ready != null) host.remoteReady(seat, ready);
    });
  }

  /// The host writes the stand-ins into the room; every guest shows them in
  /// their own numbering.
  void reportStandIns(Set<int> seats) {
    standIns = seats.toList()..sort();
    for (final g in guests.entries) {
      g.value.setStandIns(<int>[for (final real in standIns) rotateSeat(real, g.key, players)]);
    }
  }

  void goOffline(int seat) => offline.add(seat);

  /// Back online: the database hands over the newest view.
  void comeBack(int seat) {
    offline.remove(seat);
    final raw = _latest[seat];
    if (raw != null) Timer(latency, () => _deliver(seat, raw));
  }

  void dispose() {
    host.dispose();
    for (final g in guests.values) {
      g.dispose();
    }
  }
}

void main() {
  /// Settings of one player (all in the same test storage, apart in memory).
  Future<AppSettings> player({int turnSeconds = 0}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'language': 'en',
      'sound': false,
      'haptics': false,
      'fastAnimations': true,
      'turnSeconds': turnSeconds,
    });
    return AppSettings.load();
  }

  Future<_Room> openRoom({required int players, required Set<int> people, int turnSeconds = 0, int target = 41, int seed = 11}) async {
    final settings = <int, AppSettings>{0: await player(turnSeconds: turnSeconds)};
    for (final seat in people) {
      settings[seat] = await player();
    }
    final room = _Room(players: players, people: people, settings: settings, turnSeconds: turnSeconds);
    room.start(PastraEngine.newGame(rules: PastraRules(targetScore: target), numPlayers: players, seed: seed));
    return room;
  }

  /// Everybody at the table plays a random card of their own when it is
  /// their turn (apart from [idle] seats) and, after a round, says they are
  /// ready (unless [ready] is false). Every 100 ms of game time until [done].
  Future<void> play(
    WidgetTester tester,
    _Room room,
    bool Function() done, {
    Set<int> idle = const <int>{},
    bool ready = true,
    int seconds = 1200,
  }) async {
    final rng = Random(3);
    int pick(List<int> hand) => hand[rng.nextInt(hand.length)];
    for (var t = 0; t < seconds * 10 && !done(); t++) {
      await tester.pump(const Duration(milliseconds: 100));
      final h = room.host;
      if (h.isHumanTurn) h.playCard(pick(h.state.hands[0]));
      if (ready && h.state.phase == GamePhase.roundOver) h.readyUp();
      for (final g in room.guests.entries) {
        if (idle.contains(g.key) || room.offline.contains(g.key)) continue;
        if (g.value.isHumanTurn) g.value.playCard(pick(g.value.state.hands[0]));
        if (ready && g.value.state.phase == GamePhase.roundOver) g.value.readyUp();
      }
    }
  }

  /// Host and guest agree on the game (the guest sees it from their seat).
  void expectSameGame(_Room room) {
    final real = room.host.state;
    for (final g in room.guests.entries) {
      final seen = g.value.state;
      final turned = rotateStateFor(real, g.key);
      expect(seen.phase, real.phase, reason: 'phase of seat ${g.key}');
      expect(seen.scores, turned.scores, reason: 'scores of seat ${g.key}');
      expect(seen.round, real.round);
      expect(seen.winner, turned.winner);
      expect(seen.table, turned.table);
      expect(seen.hands[0], turned.hands[0], reason: 'own hand of seat ${g.key}');
      for (var i = 1; i < seen.hands.length; i++) {
        expect(seen.hands[i].length, turned.hands[i].length);
      }
    }
  }

  bool over(_Room room) =>
      room.host.state.phase == GamePhase.gameOver &&
      room.guests.length == room.people.length &&
      room.guests.values.every((g) => g.state.phase == GamePhase.gameOver && g.xpGain != null);

  testWidgets('1v1: a whole game through the room; the guest sees only their cards and gets the same result', (tester) async {
    final room = await openRoom(players: 2, people: <int>{1});
    await play(tester, room, () => over(room));
    expect(room.host.state.phase, GamePhase.gameOver);
    expect(room.leaks, isEmpty);
    expect(room.written[1], greaterThan(50));
    await tester.pump(const Duration(seconds: 2));
    expectSameGame(room);

    // The guest's game counts once for them: statistics, XP, history.
    final guest = room.guests[1]!;
    final settings = room.settings[1]!;
    expect(guest.xpGain, isNotNull);
    expect(settings.history, hasLength(1));
    expect(settings.history.first.won, guest.state.winner == 0);
    expect(settings.history.first.ours, guest.state.scores[0]);
    final xp = settings.xp;
    // The same last view once more (sent again after a reconnect).
    guest.applyHostView(GameState.fromJson(guest.state.toJson()), null);
    await tester.pump(const Duration(seconds: 2));
    expect(settings.history, hasLength(1));
    expect(settings.xp, xp);

    room.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('2v2: two guests and a bot play a whole game with the host', (tester) async {
    final room = await openRoom(players: 4, people: <int>{1, 2}, seed: 23);
    await play(tester, room, () => over(room));
    expect(room.host.state.phase, GamePhase.gameOver);
    expect(room.leaks, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expectSameGame(room);
    // Seat 2 is the host's partner: the same team, the same result.
    expect(room.guests[2]!.state.winner, room.host.state.winner);
    // Seat 1 is on the other team: they won when the host lost.
    expect(room.guests[1]!.state.winner, 1 - room.host.state.winner);
    // Every guest sees the others from their own seat: for the guest on
    // seat 1 the next one is the other guest, the partner across is the bot.
    final seats1 = room.guests[1]!.seats;
    expect(seats1[1].name, 'P2');
    expect(seats1[2].isBot, isTrue);
    expect(seats1[3].name, 'Ali');
    room.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a guest who loses the connection gets a bot in their seat until they are back', (tester) async {
    final room = await openRoom(players: 2, people: <int>{1}, target: 151);
    // A few moves first.
    var moves = 0;
    room.host.addListener(() => moves = room.host.lastMove?.id ?? moves);
    await play(tester, room, () => moves >= 6);
    expect(room.host.standIns, isEmpty);

    room.goOffline(1);
    final before = moves;
    await play(tester, room, () => moves >= before + 8, seconds: 120);
    expect(room.host.standIns, <int>{1});
    expect(room.host.offlineSeats, <int>{1});
    expect(room.standIns, <int>[1]);
    expect(moves, greaterThanOrEqualTo(before + 8), reason: 'the game went on without them');

    // Back: the bot leaves, the guest gets the newest state and plays again.
    room.comeBack(1);
    await play(tester, room, () => room.host.standIns.isEmpty, seconds: 10);
    expect(room.host.standIns, isEmpty);
    expect(room.guests[1]!.standIns, isEmpty);
    final back = moves;
    await play(tester, room, () => moves >= back + 6, seconds: 120);
    await tester.pump(const Duration(seconds: 3));
    expect(room.leaks, isEmpty);
    expectSameGame(room);
    room.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('time runs out for a guest: a bot plays their card', (tester) async {
    final room = await openRoom(players: 2, people: <int>{1}, turnSeconds: 10, target: 151);
    await play(tester, room, () => room.guests.isNotEmpty && room.host.state.current == 1, seconds: 30);
    final hand = room.host.state.hands[1].length;
    // The guest does nothing: after 10 seconds their card is played for them.
    await play(tester, room, () => room.host.state.hands[1].length < hand, idle: <int>{1}, seconds: 14);
    expect(room.host.state.hands[1].length, lessThan(hand));
    expect(room.host.standIns, isEmpty, reason: 'still connected: no stand-in');
    room.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a move the host never gets can be made again', (tester) async {
    final room = await openRoom(players: 2, people: <int>{1}, target: 151);
    await play(tester, room, () => room.guests.isNotEmpty && room.guests[1]!.isHumanTurn, idle: <int>{1}, seconds: 30);
    final guest = room.guests[1]!;
    // The move goes nowhere (the connection drops right then).
    room.offline.add(1);
    guest.playCard(guest.state.hands[0].first);
    expect(guest.isHumanTurn, isFalse);
    expect(guest.pending, isNotNull, reason: 'the card shows on the table at once');
    await tester.pump(const Duration(milliseconds: 200));
    room.offline.remove(1);
    await tester.pump(const Duration(seconds: 5));
    expect(guest.pending, isNull);
    expect(guest.isHumanTurn, isTrue);
    room.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a void deal (four of a kind) is shown to the guest too, from their seat', (tester) async {
    // A seed whose first deal has four of a kind.
    var seed = 0;
    while (PastraEngine.newGame(rules: const PastraRules(), numPlayers: 2, seed: seed).quads.isEmpty) {
      seed++;
    }
    final room = await openRoom(players: 2, people: <int>{1}, target: 151, seed: seed);
    final quadSeat = room.host.state.quads.first.seat;
    // What the guest's table shows, from their first view on.
    GameController? watched;
    QuadAlert? seen;
    await play(tester, room, () {
      final g = room.guests[1];
      if (g != null && watched == null) {
        watched = g;
        g.addListener(() => seen ??= g.quadAlert);
      }
      return seen != null;
    }, seconds: 20);
    expect(seen, isNotNull);
    expect(seen!.seat, rotateSeat(quadSeat, 1, 2));
    expect(seen!.cards, hasLength(const PastraRules().cardsPerDeal));
    // It goes away again, and the game goes on.
    await play(tester, room, () => room.guests[1]!.quadAlert == null, seconds: 10);
    expect(room.guests[1]!.quadAlert, isNull);
    room.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  group('ready for the next round', () {
    /// Plays until the round is over on the host and every guest's screen,
    /// nobody saying "ready".
    Future<_Room> toRoundEnd(WidgetTester tester, {required int players, required Set<int> people}) async {
      final room = await openRoom(players: players, people: people, target: 500, seed: 41);
      await play(
        tester,
        room,
        () =>
            room.host.state.phase == GamePhase.roundOver &&
            room.guests.length == people.length &&
            room.guests.values.every((g) => g.state.phase == GamePhase.roundOver && g.readyDeadline != null),
        ready: false,
        seconds: 300,
      );
      expect(room.host.state.phase, GamePhase.roundOver);
      expect(room.host.state.round, 1, reason: 'the first round is still waiting');
      return room;
    }

    Future<void> wait(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('2v2: the next round starts when everybody is ready, and everybody sees who is', (tester) async {
      final room = await toRoundEnd(tester, players: 4, people: <int>{1, 2});
      final host = room.host;
      final g1 = room.guests[1]!;
      final g2 = room.guests[2]!;
      final round = host.state.round;
      // Only the bot (seat 3) is ready; each guest sees it from their seat.
      expect(host.readySeats, <int>{3});
      expect(g1.readySeats, <int>{rotateSeat(3, 1, 4)});
      expect(g2.readySeats, <int>{rotateSeat(3, 2, 4)});
      expect(g1.readyDeadline!.difference(DateTime.now()).inSeconds, inInclusiveRange(20, 30));

      // Nobody else: the table waits.
      await wait(tester, 5000);
      expect(host.state.phase, GamePhase.roundOver);

      g1.readyUp();
      expect(g1.iAmReady, isTrue, reason: 'my own ring lights up at once');
      await wait(tester, 300);
      expect(host.readySeats, <int>{1, 3});
      expect(g2.readySeats, <int>{rotateSeat(1, 2, 4), rotateSeat(3, 2, 4)});

      host.readyUp();
      await wait(tester, 300);
      expect(host.readySeats, <int>{0, 1, 3});
      expect(g1.readySeats, <int>{0, rotateSeat(0, 1, 4), rotateSeat(3, 1, 4)});
      expect(host.state.phase, GamePhase.roundOver, reason: 'seat 2 is not ready yet');

      // The last one: a moment later the next round is dealt.
      g2.readyUp();
      await wait(tester, 1500);
      expect(host.state.phase, GamePhase.playing);
      expect(host.state.round, round + 1);
      await wait(tester, 1000);
      expect(g1.state.round, round + 1);
      expect(g1.readySeats, isEmpty);
      expect(g1.readyDeadline, isNull);
      room.dispose();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('nobody waits forever: after 30 seconds the next round starts anyway', (tester) async {
      final room = await toRoundEnd(tester, players: 2, people: <int>{1});
      final round = room.host.state.round;
      room.host.readyUp();
      await wait(tester, 28000);
      expect(room.host.state.phase, GamePhase.roundOver, reason: 'the guest has not said ready');
      await wait(tester, 3000);
      expect(room.host.state.phase, GamePhase.playing);
      expect(room.host.state.round, round + 1);
      room.dispose();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a guest who is gone counts as ready once a bot plays for them', (tester) async {
      final room = await toRoundEnd(tester, players: 2, people: <int>{1});
      room.host.readyUp();
      room.goOffline(1);
      await wait(tester, 2000);
      expect(room.host.state.phase, GamePhase.roundOver);
      await wait(tester, 5000);
      expect(room.host.standIns, <int>{1});
      expect(room.host.state.phase, GamePhase.playing);
      room.dispose();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a "ready" from an older round, or for someone else, does not count', (tester) async {
      final room = await toRoundEnd(tester, players: 2, people: <int>{1});
      final host = room.host;
      host.remoteReady(1, host.state.round - 1);
      host.remoteReady(0, host.state.round);
      host.remoteReady(5, host.state.round);
      expect(host.readySeats, isEmpty);
      // Twice is once.
      host.remoteReady(1, host.state.round);
      final v = host.stateVersion;
      host.remoteReady(1, host.state.round);
      expect(host.stateVersion, v);
      expect(host.readySeats, <int>{1});
      room.dispose();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('offline games know nothing of it', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
      final settings = await AppSettings.load();
      final state = PastraEngine.newGame(rules: const PastraRules(), numPlayers: 2, seed: 4)..phase = GamePhase.roundOver;
      final c = GameController(settings: settings, seats: SeatInfo.lineup(2, AiLevel.medium), state: state);
      c.readyUp();
      expect(c.readySeats, isEmpty);
      expect(c.readyDeadline, isNull);
      c.dispose();
    });
  });

  group('messages', () {
    final state = PastraEngine.newGame(rules: const PastraRules(), numPlayers: 4, seed: 5);
    Map<String, Object?> view(int v) => <String, Object?>{'v': v, 's': jsonEncode(state.toJson()), 'e': '{}'};

    test('a guest takes only newer views and skips broken ones', () {
      expect(readHostView(view(3), 2)?.version, 3);
      expect(readHostView(view(3), 3), isNull, reason: 'the same again');
      expect(readHostView(view(2), 3), isNull, reason: 'an older one');
      expect(readHostView(<String, Object?>{'v': 9, 's': 'not json'}, 3), isNull);
      expect(readHostView(<String, Object?>{'v': 9}, 3), isNull);
      expect(readHostView('text', 3), isNull);
      expect(readHostView(null, 3), isNull);
    });

    test('the host takes each move and each "ready" once', () {
      expect(readSeatMessage(<String, Object?>{'n': 5, 'card': 12}, 4), (n: 5, card: 12, ready: null));
      expect(readSeatMessage(<String, Object?>{'n': 6, 'ready': 3}, 5), (n: 6, card: null, ready: 3));
      expect(readSeatMessage(<String, Object?>{'n': 5, 'card': 12}, 5), isNull);
      expect(readSeatMessage(<String, Object?>{'n': 6}, 5), isNull);
      expect(readSeatMessage(<String, Object?>{'n': 6, 'card': 'ace'}, 5), isNull);
      expect(readSeatMessage(<String, Object?>{'n': 6, 'ready': 'yes'}, 5), isNull);
      expect(readSeatMessage(<String, Object?>{'card': 12}, 0), isNull);
      expect(readSeatMessage(null, 0), isNull);
    });

    test('seats in the host\'s events are turned to the guest\'s seat', () {
      final ev = jsonEncode(<String, Object?>{
        'move': <String, Object?>{'id': 7, 'seat': 0, 'card': 9, 'cap': true},
        'pastra': <String, Object?>{'id': 2, 'seat': 3, 'pts': 10},
        'quad': <String, Object?>{'id': 1, 'seat': 2, 'cards': <int>[1, 14, 27, 40, 5, 6]},
        'leftover': 1,
      });
      final t = translateHostEvent(ev, 2, 4)!;
      expect((t['move'] as Map)['seat'], 2);
      expect((t['move'] as Map)['card'], 9);
      expect((t['pastra'] as Map)['seat'], 1);
      expect((t['quad'] as Map)['seat'], 0);
      expect(t['leftover'], 3);
      // 1v1: the host is the other player.
      expect((translateHostEvent(ev, 1, 2)!['move'] as Map)['seat'], 1);
    });

    test('broken events are left out, not a crash', () {
      expect(translateHostEvent(null, 1, 2), isNull);
      expect(translateHostEvent('not json', 1, 2), isNull);
      final t = translateHostEvent(jsonEncode(<String, Object?>{'move': <String, Object?>{'id': 1, 'seat': 'x'}, 'leftover': null}), 1, 2)!;
      expect(t, isEmpty);
    });

    test('a guest sees the table from their seat', () {
      const info = RoomInfo(
        exists: true,
        players: 4,
        level: AiLevel.easy,
        seats: <RoomSeat>[
          RoomSeat(uid: 'host', name: 'Ali', online: true, pic: 'boat'),
          RoomSeat(uid: 'u1', name: 'Eleni', online: true),
          RoomSeat(uid: 'u2', name: 'Nikos', online: true),
          RoomSeat(bot: true, online: true, botIndex: 7),
        ],
      );
      final seats = guestSeats(info, 2, 4);
      expect(seats[0].isHuman, isTrue);
      expect(seats[1].isBot, isTrue, reason: 'real seat 3');
      expect(seats[1].botIndex, 7);
      expect(seats[1].level, AiLevel.easy);
      expect(seats[2].name, 'Ali', reason: 'real seat 0, across: the partner');
      expect(seats[2].pic, 'boat');
      expect(seats[3].name, 'Eleni', reason: 'real seat 1');
      // A bot on the real seat 2 (a partner) plays at least medium.
      final fromOne = guestSeats(
        const RoomInfo(exists: true, players: 4, level: AiLevel.easy, seats: <RoomSeat>[
          RoomSeat(uid: 'host'),
          RoomSeat(uid: 'u1'),
          RoomSeat(bot: true),
          RoomSeat(),
        ]),
        1,
        4,
      );
      expect(fromOne[1].level, AiLevel.medium, reason: 'real seat 2');
      expect(fromOne[1].botIndex, 2, reason: 'no name stored: the seat number');
      expect(fromOne[2].level, AiLevel.easy, reason: 'real seat 3, empty: a bot too');
    });

    test('room data is read, and wrong data falls back to defaults', () {
      final info = roomInfoFrom(
        <String, Object?>{
          'host': 'h',
          'players': 4,
          'status': 'playing',
          'level': 'hard',
          'turn': 20,
          'bots': <Object?>[1, 'x', 9, 3],
          'seatChoice': false,
          'hostOnline': false,
        },
        <String, Object?>{
          's0': <String, Object?>{'uid': 'h', 'name': 'Ali', 'online': true, 'pic': 'boat', 'frame': 'gold', 'back': 'ruby'},
          's2': <String, Object?>{'bot': true, 'botIndex': 4, 'online': true},
          's3': 'garbage',
        },
      );
      expect(info.exists, isTrue);
      expect(info.hostUid, 'h');
      expect(info.players, 4);
      expect(info.status, 'playing');
      expect(info.level, AiLevel.hard);
      expect(info.turnSeconds, 20);
      expect(info.standIns, <int>[1, 3]);
      expect(info.seatChoice, isFalse);
      expect(info.hostOnline, isFalse);
      expect(info.seats[0].name, 'Ali');
      expect(info.seats[0].back, 'ruby');
      expect(info.seats[1].taken, isFalse);
      expect(info.seats[2].bot, isTrue);
      expect(info.seats[2].botIndex, 4);
      expect(info.seats[3].taken, isFalse);

      final odd = roomInfoFrom(
        <String, Object?>{'host': 5, 'players': 'four', 'level': 3, 'turn': 'x', 'status': null},
        <String, Object?>{'s0': <String, Object?>{'uid': 12, 'name': 7, 'botIndex': 'x'}},
      );
      expect(odd.players, 2);
      expect(odd.hostUid, '');
      expect(odd.level, AiLevel.medium);
      expect(odd.turnSeconds, 0);
      expect(odd.status, 'lobby');
      expect(odd.seats[0].uid, isNull);
      expect(odd.seats[0].name, '');
      expect(roomInfoFrom(null, null).exists, isFalse);
      expect(roomInfoFrom(<String, Object?>{'players': 1000}, null).seats, hasLength(2));
    });

    test('the host writes a view only for the people, and hides the rest', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
      final settings = await AppSettings.load();
      final c = GameController(
        settings: settings,
        seats: const <SeatInfo>[SeatInfo.human(), SeatInfo.remote('Eleni'), SeatInfo.bot(AiLevel.medium, 2), SeatInfo.remote('Nikos')],
        state: PastraEngine.newGame(rules: const PastraRules(), numPlayers: 4, seed: 9),
      );
      final views = hostViews(c, 4);
      expect(views.keys, <int>[1, 3]);
      final seen = readHostView(views[3], 0)!;
      expect(seen.version, 4);
      expect(seen.state.hands[0], c.state.hands[3]);
      expect(seen.state.hands[1].every((x) => x < 0 || c.state.exposed.contains(x)), isTrue);
      expect(seen.state.seed, 0);
      expect(translateHostEvent(seen.events, 3, 4), <String, dynamic>{});
      c.dispose();
    });
  });
}
