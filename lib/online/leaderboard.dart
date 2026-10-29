import '../game/app_settings.dart';
import '../game/progression.dart';
import 'online_service.dart';

/// One row of the online leaderboard (`leaderboard/<uid>`).
class LeaderEntry {
  const LeaderEntry({
    required this.uid,
    required this.name,
    required this.xp,
    required this.wins,
    required this.games,
  });

  final String uid;
  final String name;
  final int xp;
  final int wins;
  final int games;

  int get level => Progression.levelOf(xp);

  /// Turns the raw `leaderboard` node into a ranking: most XP first, then
  /// most wins, then name. Rows with broken data are skipped.
  static List<LeaderEntry> parseAll(Object? value) {
    if (value is! Map) return const <LeaderEntry>[];
    final out = <LeaderEntry>[];
    value.forEach((key, raw) {
      if (raw is! Map) return;
      final xp = raw['xp'];
      if (xp is! num || xp < 0) return;
      final name = (raw['name'] as String? ?? '').trim();
      out.add(
        LeaderEntry(
          uid: '$key',
          name: name,
          xp: xp.toInt(),
          wins: (raw['wins'] as num?)?.toInt() ?? 0,
          games: (raw['games'] as num?)?.toInt() ?? 0,
        ),
      );
    });
    out.sort((a, b) {
      final byXp = b.xp.compareTo(a.xp);
      if (byXp != 0) return byXp;
      final byWins = b.wins.compareTo(a.wins);
      if (byWins != 0) return byWins;
      return a.name.compareTo(b.name);
    });
    return out;
  }
}

/// Publishes the player's XP and reads the ranking. Every call is best
/// effort: without internet or Firebase nothing happens.
class Leaderboard {
  Leaderboard._();

  static const int maxNameLength = 16;

  /// Writes the local player's row (when they chose to appear on the board).
  static Future<void> submit(AppSettings settings, {String fallbackName = 'Player'}) async {
    if (!settings.showOnLeaderboard) return;
    try {
      if (await OnlineService.ensureReady() != null) return;
      final raw = settings.playerName.trim();
      var name = raw.isEmpty ? fallbackName : raw;
      if (name.length > maxNameLength) name = name.substring(0, maxNameLength);
      await OnlineService.ref('leaderboard/${OnlineService.uid}').set(<String, Object?>{
        'name': name,
        'xp': settings.xp,
        'wins': settings.gamesWon,
        'games': settings.gamesPlayed,
        'updated': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  /// Takes the player off the board.
  static Future<void> remove() async {
    try {
      if (await OnlineService.ensureReady() != null) return;
      await OnlineService.ref('leaderboard/${OnlineService.uid}').remove();
    } catch (_) {}
  }

  /// The best [limit] players. Throws when the board cannot be read.
  static Future<List<LeaderEntry>> top({int limit = 50}) async {
    final problem = await OnlineService.ensureReady();
    if (problem != null) throw StateError(problem);
    final event = await OnlineService.ref('leaderboard').orderByChild('xp').limitToLast(limit).once().timeout(const Duration(seconds: 10));
    final snap = event.snapshot;
    return LeaderEntry.parseAll(snap.value).take(limit).toList();
  }
}
