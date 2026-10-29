import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'cup_logic.dart';
import 'online_service.dart';

/// Everything stored for one cup (`cups/<slot>`).
class CupData {
  const CupData({
    required this.slot,
    this.signups = const <CupSignup>[],
    this.results = const <String, CupResult>{},
    this.present = const <String>{},
  });

  final int slot;
  final List<CupSignup> signups;
  final Map<String, CupResult> results;

  /// uids of the players that have the cup screen open.
  final Set<String> present;

  bool isRegistered(String uid) => signups.any((s) => s.uid == uid && s.time < slot);

  /// Registrations that count (made before the start).
  int get count => signups.where((s) => s.time < slot).length;

  static CupData parse(int slot, Object? value) {
    if (value is! Map) return CupData(slot: slot);
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
    return CupData(slot: slot, signups: signups, results: results, present: present);
  }
}

/// Reads and writes the scheduled tournaments.
class CupService {
  CupService._();

  static DatabaseReference _ref(int slot) => OnlineService.ref('cups/$slot');

  static Stream<CupData> watch(int slot) => _ref(slot).onValue.map((e) => CupData.parse(slot, e.snapshot.value));

  static Future<void> register(int slot, String name) => _ref(slot).child('players/${OnlineService.uid}').set(
        <String, Object?>{'name': name, 't': ServerValue.timestamp},
      );

  static Future<void> unregister(int slot) => _ref(slot).child('players/${OnlineService.uid}').remove();

  /// Writes a result; the first one wins (the database refuses a second).
  static Future<void> report(int slot, String matchId, int winner) async {
    try {
      await _ref(slot).child('results/$matchId').set(<String, Object?>{'w': winner, 't': ServerValue.timestamp});
    } catch (_) {}
  }

  /// Marks the player as present while the subscription lives.
  static StreamSubscription<void> keepPresent(int slot) =>
      OnlineService.keepOnline(<String>['cups/$slot/online/${OnlineService.uid}']).listen((_) {});
}
