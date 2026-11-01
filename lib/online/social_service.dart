import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../game/app_settings.dart';
import '../game/friends.dart';
import 'online_service.dart';

/// A player found by their code, or a friend's live status.
class PlayerStatus {
  const PlayerStatus({required this.uid, required this.name, required this.tag, this.online = false, this.seen = 0});

  final String uid;
  final String name;
  final String tag;
  final bool online;

  /// Server time (ms) the player was last connected.
  final int seen;
}

/// The player's own code ("Player #1270") and presence, and finding / watching
/// other players. Data: `users/<uid>` (name, tag, online, seen) and
/// `handles/<name~tag>` → uid (so that name + code finds the player).
class SocialService {
  SocialService._();

  static final SocialService instance = SocialService._();

  /// Off in widget tests (no Firebase there).
  static bool enabled = true;

  AppSettings? _settings;
  bool _starting = false;
  bool _started = false;
  StreamSubscription<DatabaseEvent>? _presence;
  StreamSubscription<DatabaseEvent>? _adds;
  StreamSubscription<DatabaseEvent>? _addsGone;

  /// Friend requests waiting for an answer (people who added this player).
  final ValueNotifier<List<PlayerStatus>> requests = ValueNotifier<List<PlayerStatus>>(const <PlayerStatus>[]);
  Timer? _debounce;
  String _syncedName = '';
  String _syncedFrame = '';
  final Random _rng = Random.secure();

  bool get started => _started;

  /// Gives the player a code (once) and keeps them shown as online while
  /// the app is open. Safe to call often.
  Future<void> start(AppSettings settings) async {
    if (!enabled || _started || _starting) return;
    _starting = true;
    try {
      if (await OnlineService.ensureReady() != null) return;
      _settings = settings;
      if (!await _sync()) return;
      final uid = OnlineService.uid;
      _presence = FirebaseDatabase.instance.ref('.info/connected').onValue.listen((e) async {
        if (e.snapshot.value != true) return;
        try {
          final me = OnlineService.ref('users/$uid');
          await me.child('online').onDisconnect().set(false);
          await me.child('seen').onDisconnect().set(ServerValue.timestamp);
          await me.update(<String, Object?>{'online': true, 'seen': ServerValue.timestamp});
        } catch (_) {}
      });
      settings.addListener(_onSettings);
      _listenAdds(settings);
      _started = true;
    } catch (_) {
    } finally {
      _starting = false;
    }
  }

  /// Somebody added this player by code: it shows up as a friend request
  /// (`friendAdds/<me>/<them>`) that the player accepts or declines.
  void _listenAdds(AppSettings s) {
    final me = OnlineService.uid;
    _adds = OnlineService.ref('friendAdds/$me').onChildAdded.listen((e) async {
      final from = e.snapshot.key;
      if (from == null || from == me) return;
      try {
        final u = await OnlineService.ref('users/$from').once().timeout(const Duration(seconds: 8));
        final st = _status(from, u.snapshot.value);
        if (st == null || st.name.isEmpty || s.friends.any((f) => f.uid == from && f.favorite)) {
          await OnlineService.ref('friendAdds/$me/$from').remove();
          return;
        }
        if (requests.value.every((r) => r.uid != from)) requests.value = <PlayerStatus>[...requests.value, st];
      } catch (_) {}
    });
    _addsGone = OnlineService.ref('friendAdds/$me').onChildRemoved.listen((e) {
      requests.value = <PlayerStatus>[for (final r in requests.value) if (r.uid != e.snapshot.key) r];
    });
  }

  /// Accepts a friend request: the player joins the friends list.
  Future<void> acceptRequest(AppSettings s, PlayerStatus r) async {
    s.addFriend(uid: r.uid, name: r.name, tag: r.tag);
    await _clearRequest(r.uid);
  }

  /// Declines a friend request.
  Future<void> declineRequest(PlayerStatus r) => _clearRequest(r.uid);

  Future<void> _clearRequest(String uid) async {
    requests.value = <PlayerStatus>[for (final r in requests.value) if (r.uid != uid) r];
    try {
      await OnlineService.ref('friendAdds/${OnlineService.uid}/$uid').remove();
    } catch (_) {}
  }

  /// Tells [uid] that this player added them, so they get this player in
  /// their list as well.
  static Future<void> tellAdded(String uid) async {
    try {
      await OnlineService.ref('friendAdds/$uid/${OnlineService.uid}').set(<String, Object?>{'t': ServerValue.timestamp});
    } catch (_) {}
  }

  static String _nameOf(AppSettings s) {
    final name = s.handleName;
    return name.length > 16 ? name.substring(0, 16) : name;
  }

  /// Stops the presence and the name updates (e.g. when the player turns
  /// online features off); [start] begins again.
  void stop() {
    _presence?.cancel();
    _presence = null;
    _adds?.cancel();
    _adds = null;
    _addsGone?.cancel();
    _addsGone = null;
    requests.value = const <PlayerStatus>[];
    _debounce?.cancel();
    _settings?.removeListener(_onSettings);
    _started = false;
  }

  String _randomTag() => (1000 + _rng.nextInt(9000)).toString();

  /// Registers name + tag (a new tag when that pair is taken) and writes the
  /// public profile.
  Future<bool> _sync() async {
    final s = _settings;
    if (s == null) return false;
    final uid = OnlineService.uid;
    final name = _nameOf(s);
    var tag = s.playerTag ?? _randomTag();
    var key = PlayerHandle.keyOf(name, tag);
    if (key != s.handleKey) {
      var claimed = false;
      for (var attempt = 0; attempt < 12 && !claimed; attempt++) {
        final tx = await OnlineService.ref('handles/$key').runTransaction((value) {
          if (value != null && value != uid) return Transaction.abort();
          return Transaction.success(uid);
        });
        if (tx.committed) {
          claimed = true;
        } else {
          tag = _randomTag();
          key = PlayerHandle.keyOf(name, tag);
        }
      }
      if (!claimed) return false;
      final old = s.handleKey;
      if (old != null && old != key) {
        OnlineService.ref('handles/$old').remove().catchError((Object _) {});
      }
      s.setHandle(tag: tag, key: key);
    }
    await OnlineService.ref('users/$uid').update(<String, Object?>{
      'name': name,
      'tag': tag,
      'frame': s.avatarFrame.name,
      'lvl': s.playerLevel,
    });
    _syncedName = name;
    _syncedFrame = s.avatarFrame.name;
    return true;
  }

  /// A new name (or frame) is published a moment after the last change.
  void _onSettings() {
    final s = _settings;
    if (s == null) return;
    if (_nameOf(s) == _syncedName && s.avatarFrame.name == _syncedFrame) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      _sync().catchError((Object _) => false);
    });
  }

  /// The player with this name and code; null when there is none.
  static Future<PlayerStatus?> find(String name, String tag) async {
    if (await OnlineService.ensureReady() != null) throw StateError('offline');
    final key = PlayerHandle.keyOf(name, tag);
    final h = await OnlineService.ref('handles/$key').once().timeout(const Duration(seconds: 8));
    final uid = h.snapshot.value;
    if (uid is! String) return null;
    final u = await OnlineService.ref('users/$uid').once().timeout(const Duration(seconds: 8));
    return _status(uid, u.snapshot.value);
  }

  /// A friend's name, code and whether they are online, live.
  static Stream<PlayerStatus?> watch(String uid) async* {
    if (!enabled || await OnlineService.ensureReady() != null) return;
    yield* OnlineService.ref('users/$uid').onValue.map((e) => _status(uid, e.snapshot.value));
  }

  static PlayerStatus? _status(String uid, Object? v) {
    if (v is! Map) return null;
    return PlayerStatus(
      uid: uid,
      name: '${v['name'] ?? ''}',
      tag: '${v['tag'] ?? ''}',
      online: v['online'] == true,
      seen: (v['seen'] as num?)?.toInt() ?? 0,
    );
  }
}
