import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

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

/// The player's own code ("Ali #2155") and presence, and finding / watching
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
      _started = true;
    } catch (_) {
    } finally {
      _starting = false;
    }
  }

  static String _nameOf(AppSettings s) {
    var name = s.playerName.trim();
    if (name.isEmpty) name = 'Player';
    return name.length > 16 ? name.substring(0, 16) : name;
  }

  /// Stops the presence and the name updates (e.g. when the player turns
  /// online features off); [start] begins again.
  void stop() {
    _presence?.cancel();
    _presence = null;
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
