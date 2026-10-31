import 'package:firebase_database/firebase_database.dart';

import 'online_service.dart';

/// An invitation to a room from another player.
class TableInvite {
  const TableInvite({required this.fromUid, required this.name, required this.code, required this.time});

  final String fromUid;
  final String name;
  final String code;

  /// Server time in milliseconds.
  final int time;
}

/// Invitations between players (`invites/<to>/<from>`): the receiver sees a
/// banner while the game is open and joins with one tap.
class Invites {
  Invites._();

  /// An invitation older than this is ignored.
  static const Duration maxAge = Duration(minutes: 15);

  static Future<bool> send({required String toUid, required String name, required String code}) async {
    try {
      if (await OnlineService.ensureReady() != null) return false;
      var clean = name.trim();
      if (clean.length > 16) clean = clean.substring(0, 16);
      await OnlineService.ref('invites/$toUid/${OnlineService.uid}').set(<String, Object?>{
        'name': clean,
        'code': code,
        't': ServerValue.timestamp,
      }).timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The invitations for this player, newest first (fresh ones only).
  static Stream<List<TableInvite>> watch() async* {
    if (await OnlineService.ensureReady() != null) return;
    yield* OnlineService.ref('invites/${OnlineService.uid}').onValue.map((e) {
      final v = e.snapshot.value;
      final out = <TableInvite>[];
      if (v is Map) {
        final now = OnlineService.serverNow;
        v.forEach((key, raw) {
          if (raw is! Map) return;
          final code = raw['code'];
          final t = raw['t'];
          if (code is! String || t is! num) return;
          if (now - t.toInt() > maxAge.inMilliseconds) return;
          out.add(TableInvite(fromUid: '$key', name: '${raw['name'] ?? ''}', code: code, time: t.toInt()));
        });
      }
      out.sort((a, b) => b.time.compareTo(a.time));
      return out;
    });
  }

  static Future<void> dismiss(String fromUid) async {
    try {
      await OnlineService.ref('invites/${OnlineService.uid}/$fromUid').remove();
    } catch (_) {}
  }
}
