import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../engine/pastra_ai.dart';
import 'online_service.dart';

/// A public table in the lobby (`lobby/<code>` in the database).
class OpenTable {
  const OpenTable({
    required this.code,
    required this.hostUid,
    required this.name,
    required this.players,
    required this.joined,
    required this.level,
    required this.created,
  });

  final String code;
  final String hostUid;
  final String name;
  final int players;
  final int joined;
  final AiLevel level;

  /// Milliseconds since epoch.
  final int created;

  int get free => players - joined;

  /// Tables whose host vanished without cleaning up are older than this.
  static const Duration maxAge = Duration(hours: 2);

  /// Turns the raw `lobby` node into a list: newest first, without full or
  /// stale tables and without the tables of [exceptHost] (yourself).
  static List<OpenTable> parseAll(Object? value, {required int now, String? exceptHost}) {
    if (value is! Map) return const <OpenTable>[];
    final out = <OpenTable>[];
    value.forEach((key, raw) {
      if (raw is! Map) return;
      final players = (raw['players'] as num?)?.toInt() ?? 0;
      final joined = (raw['joined'] as num?)?.toInt() ?? 0;
      final created = (raw['created'] as num?)?.toInt() ?? 0;
      final host = raw['host'] as String? ?? '';
      if (players != 2 && players != 4) return;
      if (joined >= players || joined < 1) return;
      if (now - created > maxAge.inMilliseconds) return;
      if (exceptHost != null && host == exceptHost) return;
      final levelName = raw['level'] as String? ?? AiLevel.medium.name;
      out.add(
        OpenTable(
          code: '$key',
          hostUid: host,
          name: raw['name'] as String? ?? '',
          players: players,
          joined: joined,
          level: AiLevel.values.firstWhere((l) => l.name == levelName, orElse: () => AiLevel.medium),
          created: created,
        ),
      );
    });
    out.sort((a, b) => b.created.compareTo(a.created));
    return out;
  }
}

/// Reads the public tables.
class Lobby {
  Lobby._();

  static DatabaseReference get _ref => OnlineService.ref('lobby');

  /// Live list of open tables (not including your own).
  static Stream<List<OpenTable>> watch() => _ref.onValue.map(
        (e) => OpenTable.parseAll(e.snapshot.value, now: DateTime.now().millisecondsSinceEpoch, exceptHost: OnlineService.uid),
      );

  /// The open tables once; empty when the lobby cannot be read (the caller
  /// then opens a table itself).
  static Future<List<OpenTable>> list() async {
    try {
      // `once()` (a listener that stops after the first value) rather than
      // `get()`: on the web `get()` can fail right after connecting ("client
      // is offline"), and quick match then never found the open tables.
      final event = await _ref.once().timeout(const Duration(seconds: 8));
      return OpenTable.parseAll(
        event.snapshot.value,
        now: DateTime.now().millisecondsSinceEpoch,
        exceptHost: OnlineService.uid,
      );
    } catch (_) {
      return const <OpenTable>[];
    }
  }

  /// The best table for a quick match: 1v1 before 2v2, then the one with
  /// the fewest free seats (it starts soonest), then the newest.
  static List<OpenTable> forQuickMatch(List<OpenTable> tables) => tables.toList()
    ..sort((a, b) {
      if (a.players != b.players) return a.players.compareTo(b.players);
      if (a.free != b.free) return a.free.compareTo(b.free);
      return b.created.compareTo(a.created);
    });

  /// Writes (or replaces) the entry of a table. Never throws: a table that
  /// cannot be listed can still be joined with its code.
  static Future<bool> publish(String code, Map<String, Object?> data) async {
    try {
      final ref = OnlineService.ref('lobby/$code');
      await ref.onDisconnect().remove();
      await ref.set(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Keeps the table listed while the subscription lives. The entry is
  /// removed by the server when the connection drops (a host that vanished)
  /// and written again on every reconnect — a phone or a background browser
  /// tab loses its connection now and then, and the table must come back.
  static StreamSubscription<void> keepListed(String code, Map<String, Object?> Function() entry) {
    final connected = FirebaseDatabase.instance.ref('.info/connected');
    return connected.onValue.asyncMap((event) async {
      if (event.snapshot.value != true) return;
      await publish(code, entry());
    }).listen((_) {});
  }

  static Future<void> setJoined(String code, int joined) async {
    try {
      await OnlineService.ref('lobby/$code/joined').set(joined);
    } catch (_) {}
  }

  static Future<void> remove(String code) async {
    try {
      await OnlineService.ref('lobby/$code').remove();
    } catch (_) {}
  }
}
