import '../game/app_settings.dart';
import '../game/progression.dart';
import '../game/seasons.dart';
import 'online_service.dart';

/// One row of the online leaderboard (`leaderboard/<uid>`).
class LeaderEntry {
  const LeaderEntry({
    required this.uid,
    required this.name,
    required this.xp,
    required this.wins,
    required this.games,
    this.frame = AvatarFrame.none,
    this.storedLevel,
  });

  final AvatarFrame frame;

  /// Season rows carry the player's level (their XP is the season XP).
  final int? storedLevel;

  final String uid;
  final String name;
  final int xp;
  final int wins;
  final int games;

  int get level => storedLevel ?? Progression.levelOf(xp);

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
          frame: AvatarFrame.values.where((f) => f.name == raw['frame']).firstOrNull ?? AvatarFrame.none,
          storedLevel: (raw['lvl'] as num?)?.toInt(),
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
      final now = DateTime.now().millisecondsSinceEpoch;
      await OnlineService.ref('leaderboard/${OnlineService.uid}').set(<String, Object?>{
        'name': name,
        'xp': settings.xp,
        'wins': settings.gamesWon,
        'games': settings.gamesPlayed,
        'frame': settings.avatarFrame.name,
        'updated': now,
      });
      // This month's season: only the XP earned in it.
      if (settings.seasonXp > 0) {
        await OnlineService.ref('seasons/${settings.season}/${OnlineService.uid}').set(<String, Object?>{
          'name': name,
          'xp': settings.seasonXp,
          'wins': settings.seasonWins,
          'games': settings.seasonGames,
          'lvl': settings.playerLevel,
          'frame': settings.avatarFrame.name,
          'updated': now,
        });
      }
    } catch (_) {}
  }

  /// Takes the player off the board (and this season's ranking).
  static Future<void> remove({String? season}) async {
    try {
      if (await OnlineService.ensureReady() != null) return;
      await OnlineService.ref('leaderboard/${OnlineService.uid}').remove();
      await OnlineService.ref('seasons/${season ?? Seasons.current()}/${OnlineService.uid}').remove();
    } catch (_) {}
  }

  /// The best [limit] players of a season (by the XP earned in it).
  static Future<List<LeaderEntry>> season(String id, {int limit = 50}) async {
    final problem = await OnlineService.ensureReady();
    if (problem != null) throw StateError(problem);
    final event = await OnlineService.ref('seasons/$id').orderByChild('xp').limitToLast(limit).once().timeout(const Duration(seconds: 10));
    return LeaderEntry.parseAll(event.snapshot.value).take(limit).toList();
  }

  /// Gives the badge of a finished season the player took part in. Returns
  /// null when nothing is waiting or the ranking cannot be read now (it is
  /// tried again next time).
  static Future<SeasonBadge?> finishPendingSeason(AppSettings settings) async {
    final pending = settings.seasonsPending;
    if (pending.isEmpty) return null;
    final id = pending.first;
    var rank = 0;
    if (settings.showOnLeaderboard) {
      try {
        final rows = await season(id, limit: 100);
        final me = OnlineService.uid;
        final i = rows.indexWhere((r) => r.uid == me);
        rank = i < 0 ? 0 : i + 1;
      } catch (_) {
        return null;
      }
    }
    return settings.finishSeason(id, rank);
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
