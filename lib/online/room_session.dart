import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../engine/game_state.dart';
import '../engine/pastra_ai.dart';
import '../engine/pastra_engine.dart';
import '../engine/perspective.dart';
import '../engine/rules.dart';
import '../game/app_settings.dart';
import '../game/game_controller.dart';
import '../game/online_link.dart';
import '../game/seats.dart';
import 'lobby.dart';
import 'online_service.dart';

Map<String, dynamic>? _map(Object? v) {
  if (v is! Map) return null;
  return v.map((k, x) => MapEntry('$k', x));
}

/// One seat of a room as stored in the database.
class RoomSeat {
  final String? uid;
  final String name;
  final bool bot;
  final bool online;

  /// Bot seats: index of the bot's name (the same on every screen), -1 = unknown.
  final int botIndex;

  const RoomSeat({this.uid, this.name = '', this.bot = false, this.online = false, this.botIndex = -1});

  bool get taken => uid != null || bot;
}

/// Room data everybody may read: settings and who sits where.
class RoomInfo {
  final bool exists;
  final String hostUid;
  final int players;
  final String status; // lobby | playing | closed
  final bool hostOnline;
  final AiLevel level;
  final int turnSeconds;
  final List<RoomSeat> seats;

  const RoomInfo({
    this.exists = false,
    this.hostUid = '',
    this.players = 2,
    this.status = 'lobby',
    this.hostOnline = true,
    this.level = AiLevel.medium,
    this.turnSeconds = 0,
    this.seats = const <RoomSeat>[],
  });

  int get joined => seats.where((s) => s.uid != null).length;
}

/// Watches `meta` and `seats` of a room and exposes them as [info].
class RoomWatcher extends ChangeNotifier {
  RoomWatcher(this.code) {
    _meta = OnlineService.ref('rooms/$code/meta').onValue.listen((e) {
      _metaValue = _map(e.snapshot.value);
      _rebuild();
    });
    _seats = OnlineService.ref('rooms/$code/seats').onValue.listen((e) {
      _seatsValue = _map(e.snapshot.value);
      _rebuild();
    });
  }

  final String code;
  RoomInfo info = const RoomInfo();
  StreamSubscription<DatabaseEvent>? _meta;
  StreamSubscription<DatabaseEvent>? _seats;
  Map<String, dynamic>? _metaValue;
  Map<String, dynamic>? _seatsValue;
  bool _disposed = false;

  void _rebuild() {
    final m = _metaValue;
    if (m == null) {
      info = const RoomInfo();
    } else {
      final players = (m['players'] as num?)?.toInt() ?? 2;
      final levelName = m['level'] as String? ?? AiLevel.medium.name;
      final seats = <RoomSeat>[];
      for (var i = 0; i < players; i++) {
        final s = _map(_seatsValue?['s$i']);
        seats.add(
          s == null
              ? const RoomSeat()
              : RoomSeat(
                  uid: s['uid'] as String?,
                  name: s['name'] as String? ?? '',
                  bot: s['bot'] == true,
                  online: s['online'] == true,
                  botIndex: (s['botIndex'] as num?)?.toInt() ?? -1,
                ),
        );
      }
      info = RoomInfo(
        exists: true,
        hostUid: m['host'] as String? ?? '',
        players: players,
        status: m['status'] as String? ?? 'lobby',
        hostOnline: m['hostOnline'] != false,
        level: AiLevel.values.firstWhere((l) => l.name == levelName, orElse: () => AiLevel.medium),
        turnSeconds: (m['turn'] as num?)?.toInt() ?? 0,
        seats: seats,
      );
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _meta?.cancel();
    _seats?.cancel();
    super.dispose();
  }
}

// ======================================================================
// Host
// ======================================================================

/// The player who created the room. Runs the game: the engine lives in the
/// host's [GameController], guests only send their moves and receive the
/// state they are allowed to see.
class HostRoom implements OnlineLink {
  HostRoom._(
    this.code,
    this.players,
    this.level,
    this.settings,
    this.watcher,
    this._presence, {
    this.isPublic = false,
    this.autoStart = false,
  }) {
    if (isPublic) watcher.addListener(_syncLobby);
  }

  /// Listed in the lobby (open tables), so anybody can join.
  final bool isPublic;

  /// Starts by itself as soon as every seat is taken (quick match).
  final bool autoStart;

  /// Rules for this room instead of the host's settings (tournament matches
  /// are played to a fixed target).
  PastraRules? rulesOverride;

  /// Tournament match: the bot (name index) for each seat that no person
  /// takes, their level, how many people are expected and when to start
  /// anyway (with bots for whoever did not come).
  Map<int, int> seatBots = const <int, int>{};
  AiLevel? botLevel;
  int? expectedPeople;
  DateTime? startBy;
  int _listedJoined = 1;

  final String code;
  final int players;
  final AiLevel level;
  final AppSettings settings;
  final RoomWatcher watcher;
  final StreamSubscription<void> _presence;

  GameController? controller;
  final List<StreamSubscription<DatabaseEvent>> _moveSubs = <StreamSubscription<DatabaseEvent>>[];
  final Map<int, int> _lastMove = <int, int>{};
  int _published = -1;
  Future<void> _writes = Future<void>.value();
  bool _closed = false;

  /// Opens the room with a fixed [code] (a tournament match): both players
  /// know the code, the host creates it and the guest joins. Taking it over
  /// again after a reconnect is allowed for the same host.
  static Future<HostRoom> createWithCode(
    AppSettings settings, {
    required String code,
    required String name,
    required PastraRules rules,
    int players = 2,
    Map<int, int> seatBots = const <int, int>{},
    AiLevel botLevel = AiLevel.medium,
    int? expectedPeople,
    DateTime? startBy,
  }) async {
    final uid = OnlineService.uid;
    final tx = await OnlineService.ref('rooms/$code/meta').runTransaction((value) {
      if (value is Map && value['host'] != uid) return Transaction.abort();
      return Transaction.success(<String, Object?>{
        'host': uid,
        'players': players,
        'status': 'lobby',
        'hostOnline': true,
        'level': botLevel.name,
        'turn': settings.turnSeconds,
        'created': DateTime.now().millisecondsSinceEpoch,
      });
    });
    if (!tx.committed) throw const OnlineException('started');
    await OnlineService.ref('rooms/$code/seats/s0').set(<String, Object?>{
      'uid': uid,
      'name': name,
      'online': true,
    });
    final presence = OnlineService.keepOnline(<String>[
      'rooms/$code/meta/hostOnline',
      'rooms/$code/seats/s0/online',
    ]).listen((_) {});
    return HostRoom._(code, players, botLevel, settings, RoomWatcher(code), presence, autoStart: true)
      ..rulesOverride = rules
      ..seatBots = seatBots
      ..botLevel = botLevel
      ..expectedPeople = expectedPeople
      ..startBy = startBy;
  }

  static Future<HostRoom> create(
    AppSettings settings, {
    required int players,
    required AiLevel level,
    required String name,
    bool public = false,
    bool autoStart = false,
  }) async {
    final rnd = Random.secure();
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = (1000 + rnd.nextInt(9000)).toString();
      final uid = OnlineService.uid;
      final tx = await OnlineService.ref('rooms/$code/meta').runTransaction((value) {
        if (value != null) return Transaction.abort();
        return Transaction.success(<String, Object?>{
          'host': uid,
          'players': players,
          'status': 'lobby',
          'hostOnline': true,
          'level': level.name,
          'turn': settings.turnSeconds,
          'created': DateTime.now().millisecondsSinceEpoch,
        });
      });
      if (!tx.committed) continue;
      await OnlineService.ref('rooms/$code/seats/s0').set(<String, Object?>{
        'uid': uid,
        'name': name,
        'online': true,
      });
      final presence = OnlineService.keepOnline(<String>[
        'rooms/$code/meta/hostOnline',
        'rooms/$code/seats/s0/online',
      ]).listen((_) {});
      if (public) {
        await Lobby.publish(code, <String, Object?>{
          'host': uid,
          'name': name,
          'players': players,
          'joined': 1,
          'level': level.name,
          'created': DateTime.now().millisecondsSinceEpoch,
        });
      }
      return HostRoom._(code, players, level, settings, RoomWatcher(code), presence, isPublic: public, autoStart: autoStart);
    }
    throw const OnlineException('network');
  }

  /// Keeps the number of players in the lobby list up to date.
  void _syncLobby() {
    if (_closed || _started) return;
    final joined = watcher.info.joined;
    if (joined < 1 || joined == _listedJoined) return;
    _listedJoined = joined;
    Lobby.setJoined(code, joined);
  }

  bool _started = false;

  /// Fills the empty seats with bots and starts the game.
  Future<GameController> start() async {
    final info = watcher.info;
    _started = true;
    if (isPublic) Lobby.remove(code);
    final seats = <SeatInfo>[const SeatInfo.human()];
    final botNames = SeatInfo.randomBotNames(players);
    for (var i = 1; i < players; i++) {
      final rs = i < info.seats.length ? info.seats[i] : const RoomSeat();
      if (rs.uid != null) {
        seats.add(SeatInfo.remote(rs.name));
      } else {
        final botLevel = this.botLevel ?? ((i == 2 && level == AiLevel.easy) ? AiLevel.medium : level);
        final botIndex = seatBots[i] ?? botNames[i];
        seats.add(SeatInfo.bot(botLevel, botIndex));
        await OnlineService.ref('rooms/$code/seats/s$i').set(<String, Object?>{
          'bot': true,
          'name': '',
          'online': true,
          'botIndex': botIndex,
        });
      }
    }
    final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    final state = PastraEngine.newGame(rules: rulesOverride ?? settings.rules, numPlayers: players, seed: seed);
    final c = GameController(settings: settings, seats: seats, state: state, link: this);
    controller = c;
    for (var i = 1; i < players; i++) {
      if (!seats[i].isRemote) continue;
      final seat = i;
      _moveSubs.add(
        OnlineService.ref('rooms/$code/moves/s$seat').onValue.listen((e) {
          final m = _map(e.snapshot.value);
          if (m == null) return;
          final n = (m['n'] as num?)?.toInt() ?? 0;
          if (n <= (_lastMove[seat] ?? 0)) return;
          _lastMove[seat] = n;
          final card = (m['card'] as num?)?.toInt();
          if (card != null) c.submitRemoteMove(seat, card);
        }),
      );
    }
    c.addListener(_onChange);
    _publish();
    await OnlineService.ref('rooms/$code/meta/status').set('playing');
    return c;
  }

  void _onChange() {
    final c = controller;
    if (c == null || _closed) return;
    if (c.stateVersion != _published) _publish();
  }

  void _publish() {
    final c = controller;
    if (c == null) return;
    _published = c.stateVersion;
    final state = c.state;
    final move = c.lastMove;
    final pastra = c.pastraEvent;
    final ev = jsonEncode(<String, Object?>{
      if (move != null)
        'move': <String, Object?>{'id': move.id, 'seat': move.seat, 'card': move.card, 'cap': move.captured},
      if (pastra != null) 'pastra': <String, Object?>{'id': pastra.id, 'seat': pastra.seat, 'pts': pastra.points},
      if (c.quadAlert != null)
        'quad': <String, Object?>{'id': c.quadAlert!.id, 'seat': c.quadAlert!.seat, 'cards': c.quadAlert!.cards},
      'leftover': c.leftoverSeat,
    });
    for (var i = 1; i < players; i++) {
      if (!c.seats[i].isRemote) continue;
      final view = rotateStateFor(state.redactedFor(i), i);
      final payload = <String, Object?>{
        'v': _published,
        's': jsonEncode(view.toJson()),
        'e': ev,
      };
      final seat = i;
      _writes = _writes.then((_) => OnlineService.ref('rooms/$code/views/s$seat').set(payload)).catchError((Object _) {});
    }
  }

  @override
  void sendMove(int card) {}

  @override
  bool isRemoteOnline(int seat) {
    final seats = watcher.info.seats;
    return seat < seats.length ? seats[seat].online : false;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (isPublic) {
      watcher.removeListener(_syncLobby);
      Lobby.remove(code);
    }
    controller?.removeListener(_onChange);
    for (final s in _moveSubs) {
      s.cancel();
    }
    _presence.cancel();
    // Tells the guests that the room is over.
    OnlineService.ref('rooms/$code/meta/status').set('closed').catchError((Object _) {});
    OnlineService.ref('rooms/$code/meta/hostOnline').set(false).catchError((Object _) {});
    watcher.dispose();
  }
}

// ======================================================================
// Guest
// ======================================================================

class GuestRoom implements OnlineLink {
  GuestRoom._(this.code, this.mySeat, this.settings, this.watcher, this._presence) {
    _viewSub = OnlineService.ref('rooms/$code/views/s$mySeat').onValue.listen(_onView);
    watcher.addListener(_onRoom);
  }

  final String code;
  final int mySeat;
  final AppSettings settings;
  final RoomWatcher watcher;
  final StreamSubscription<void> _presence;

  /// Set when the first state of the game arrives.
  final ValueNotifier<GameController?> controller = ValueNotifier<GameController?>(null);

  /// True when the host closed the room (or stayed offline for a while).
  final ValueNotifier<bool> closed = ValueNotifier<bool>(false);

  StreamSubscription<DatabaseEvent>? _viewSub;
  Timer? _hostGoneTimer;
  int _lastView = -1;
  int _moveCounter = 0;
  bool _left = false;

  int get players => watcher.info.players;

  /// Joins the room; [seat] takes exactly that seat (tournament matches).
  static Future<GuestRoom> join(String code, AppSettings settings, String name, {int? seat}) async {
    final uid = OnlineService.uid;
    final DataSnapshot metaSnap;
    final DataSnapshot seatsSnap;
    try {
      metaSnap = await OnlineService.ref('rooms/$code/meta').get();
      seatsSnap = await OnlineService.ref('rooms/$code/seats').get();
    } catch (_) {
      throw const OnlineException('network');
    }
    final meta = _map(metaSnap.value);
    if (meta == null || meta['status'] == 'closed') throw const OnlineException('notFound');
    final players = (meta['players'] as num?)?.toInt() ?? 2;
    final seats = _map(seatsSnap.value);
    int? mine;
    for (var i = 0; i < players; i++) {
      if (_map(seats?['s$i'])?['uid'] == uid) mine = i;
    }
    if (mine == null) {
      if (meta['status'] != 'lobby') throw const OnlineException('started');
      for (var i = seat ?? 1; i < (seat == null ? players : seat + 1) && mine == null; i++) {
        final tx = await OnlineService.ref('rooms/$code/seats/s$i').runTransaction((value) {
          if (value != null) return Transaction.abort();
          return Transaction.success(<String, Object?>{'uid': uid, 'name': name, 'online': true});
        });
        if (tx.committed) mine = i;
      }
      if (mine == null) throw const OnlineException('full');
    }
    final presence = OnlineService.keepOnline(<String>['rooms/$code/seats/s$mine/online']).listen((_) {});
    return GuestRoom._(code, mine, settings, RoomWatcher(code), presence);
  }

  void _onRoom() {
    final info = watcher.info;
    final gone = !info.exists || info.status == 'closed';
    if (gone) {
      _hostClosed();
      return;
    }
    if (!info.hostOnline) {
      _hostGoneTimer ??= Timer(const Duration(seconds: 20), _hostClosed);
    } else {
      _hostGoneTimer?.cancel();
      _hostGoneTimer = null;
    }
  }

  void _hostClosed() {
    if (_left) return;
    closed.value = true;
    controller.value?.markOnlineClosed();
  }

  void _onView(DatabaseEvent event) {
    if (_left) return;
    final m = _map(event.snapshot.value);
    if (m == null) return;
    final v = (m['v'] as num?)?.toInt() ?? 0;
    if (v <= _lastView) return;
    _lastView = v;
    final GameState state;
    try {
      state = GameState.fromJson(Map<String, dynamic>.from(jsonDecode(m['s'] as String) as Map));
    } catch (_) {
      return;
    }
    var c = controller.value;
    if (c == null) {
      c = _buildController(state);
      controller.value = c;
    }
    c.applyHostView(state, _translate(m['e']));
  }

  GameController _buildController(GameState state) {
    final info = watcher.info;
    final n = state.numPlayers;
    final seats = <SeatInfo>[const SeatInfo.human()];
    for (var i = 1; i < n; i++) {
      final real = (i + mySeat) % n;
      final rs = real < info.seats.length ? info.seats[real] : const RoomSeat();
      if (rs.bot || rs.uid == null) {
        final botLevel = (real == 2 && info.level == AiLevel.easy) ? AiLevel.medium : info.level;
        seats.add(SeatInfo.bot(botLevel, rs.botIndex >= 0 ? rs.botIndex : real));
      } else {
        seats.add(SeatInfo.remote(rs.name));
      }
    }
    return GameController(
      settings: settings,
      seats: seats,
      state: state,
      link: this,
      isGuest: true,
      hostTurnSeconds: info.turnSeconds,
    );
  }

  /// Seat numbers in the host's message are the real ones; the screen uses
  /// numbers seen from our seat.
  Map<String, dynamic>? _translate(Object? raw) {
    if (raw is! String) return null;
    final Map<String, dynamic> ev;
    try {
      ev = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
    final n = watcher.info.players;
    int tr(Object? seat) => rotateSeat((seat as num).toInt(), mySeat, n);
    final out = <String, dynamic>{};
    final mv = _map(ev['move']);
    if (mv != null) out['move'] = <String, dynamic>{...mv, 'seat': tr(mv['seat'])};
    final pa = _map(ev['pastra']);
    if (pa != null) out['pastra'] = <String, dynamic>{...pa, 'seat': tr(pa['seat'])};
    final qd = _map(ev['quad']);
    if (qd != null) out['quad'] = <String, dynamic>{...qd, 'seat': tr(qd['seat'])};
    final lo = ev['leftover'];
    if (lo is num) out['leftover'] = tr(lo);
    return out;
  }

  @override
  void sendMove(int card) {
    // Always increasing, also after reconnecting with a fresh GuestRoom.
    _moveCounter = max(_moveCounter + 1, DateTime.now().microsecondsSinceEpoch);
    OnlineService.ref('rooms/$code/moves/s$mySeat')
        .set(<String, Object?>{'n': _moveCounter, 'card': card})
        .catchError((Object _) {});
  }

  @override
  bool isRemoteOnline(int seat) => true;

  /// Leaves the room (from the lobby the seat is given back).
  @override
  void close() {
    if (_left) return;
    _left = true;
    _hostGoneTimer?.cancel();
    _viewSub?.cancel();
    watcher.removeListener(_onRoom);
    _presence.cancel();
    final seatRef = OnlineService.ref('rooms/$code/seats/s$mySeat');
    if (watcher.info.status == 'lobby') {
      seatRef.remove().catchError((Object _) {});
    } else {
      seatRef.child('online').set(false).catchError((Object _) {});
    }
    watcher.dispose();
  }
}
