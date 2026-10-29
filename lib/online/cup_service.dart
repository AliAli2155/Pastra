import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

import 'cup_logic.dart';
import 'online_service.dart';

/// Everything stored for one cup (`cups/<key>`).
class CupData {
  const CupData({
    required this.key,
    this.start,
    this.host,
    this.teamSize = 1,
    this.targetScore = 51,
    this.signups = const <CupSignup>[],
    this.results = const <String, CupResult>{},
    this.present = const <String>{},
  });

  final String key;

  /// When it starts / started (null: a friends cup not started yet).
  final int? start;

  /// Creator of a friends cup.
  final String? host;

  /// A friends cup: 1v1 or 2v2 and the target score its creator chose.
  final int teamSize;
  final int targetScore;

  CupType get friendsType => CupType.friendsWith(teamSize: teamSize, targetScore: targetScore);
  final List<CupSignup> signups;
  final Map<String, CupResult> results;

  /// uids of the players that have the cup screen open.
  final Set<String> present;

  bool get started => start != null && OnlineService.serverNow >= start!;

  bool hasSignup(String uid) => signups.any((s) => s.uid == uid);

  /// Plays in this cup (registered in time and not beyond the last group).
  bool plays(String uid, CupType type) =>
      start != null && CupBracket.groupOf(start!, signups, uid, maxGroups: type.maxGroups) >= 0;

  /// [scheduledStart] for scheduled cups; a friends cup reads `meta/start`.
  static CupData parse(String key, Object? value, {int? scheduledStart}) {
    if (value is! Map) return CupData(key: key, start: scheduledStart);
    final signups = <CupSignup>[];
    final players = value['players'];
    if (players is Map) {
      players.forEach((uid, raw) {
        if (raw is! Map) return;
        final t = raw['t'];
        if (t is! num) return;
        signups.add(CupSignup('$uid', (raw['name'] as String? ?? '').trim(), t.toInt()));
      });
    }
    final results = <String, CupResult>{};
    final res = value['results'];
    if (res is Map) {
      res.forEach((id, raw) {
        if (raw is! Map) return;
        final w = raw['w'];
        final t = raw['t'];
        if (w is! num || t is! num) return;
        results['$id'] = CupResult(w.toInt(), t.toInt());
      });
    }
    final present = <String>{};
    final online = value['online'];
    if (online is Map) {
      online.forEach((uid, v) {
        if (v == true) present.add('$uid');
      });
    }
    final meta = value['meta'];
    final metaStart = meta is Map ? meta['start'] : null;
    return CupData(
      key: key,
      start: scheduledStart ?? (metaStart is num ? metaStart.toInt() : null),
      host: meta is Map ? meta['host'] as String? : null,
      teamSize: meta is Map && meta['teams'] == 2 ? 2 : 1,
      targetScore: meta is Map && meta['target'] is num ? (meta['target'] as num).toInt() : 51,
      signups: signups,
      results: results,
      present: present,
    );
  }
}

/// Reads and writes the cups.
class CupService {
  CupService._();

  static DatabaseReference _ref(String key) => OnlineService.ref('cups/$key');

  static Stream<CupData> watch(String key, {int? scheduledStart}) =>
      _ref(key).onValue.map((e) => CupData.parse(key, e.snapshot.value, scheduledStart: scheduledStart));

  static Future<CupData> read(String key) async =>
      CupData.parse(key, (await _ref(key).once().timeout(const Duration(seconds: 8))).snapshot.value);

  static Future<void> register(String key, String name) => _ref(key).child('players/${OnlineService.uid}').set(
        <String, Object?>{'name': name, 't': ServerValue.timestamp},
      );

  static Future<void> unregister(String key) => _ref(key).child('players/${OnlineService.uid}').remove();

  /// Writes a result; the first one wins (the database refuses a second).
  static Future<void> report(String key, String matchId, int winner) async {
    try {
      await _ref(key).child('results/$matchId').set(<String, Object?>{'w': winner, 't': ServerValue.timestamp});
    } catch (_) {}
  }

  /// Marks the player as present while the subscription lives.
  static StreamSubscription<void> keepPresent(String key) =>
      OnlineService.keepOnline(<String>['cups/$key/online/${OnlineService.uid}']).listen((_) {});

  /// Opens a friends cup with a new 5-digit code and registers its creator.
  static Future<String> createFriendsCup(String name, {int teamSize = 1, int targetScore = 51}) async {
    final rnd = Random.secure();
    final uid = OnlineService.uid;
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = (10000 + rnd.nextInt(90000)).toString();
      final tx = await _ref('${CupType.friends.id}$code').child('meta').runTransaction((value) {
        if (value != null) return Transaction.abort();
        return Transaction.success(<String, Object?>{
          'host': uid,
          'created': ServerValue.timestamp,
          'teams': teamSize,
          'target': targetScore,
        });
      });
      if (!tx.committed) continue;
      await register('${CupType.friends.id}$code', name);
      return code;
    }
    throw StateError('no free code');
  }

  /// The creator starts a friends cup: registrations close now.
  static Future<void> startFriendsCup(String key) => _ref(key).child('meta/start').set(ServerValue.timestamp);
}
