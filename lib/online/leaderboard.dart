import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../game/app_settings.dart';
import '../game/avatar_pic.dart';
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
    this.pic = AvatarPic.letter,
    this.storedLevel,
    this.tag = '',
  });

  /// The picture in the player's avatar.
  final AvatarPic pic;

  /// The player's code ("#2155"); empty for old rows.
  final String tag;

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
          pic: AvatarPic.byName(raw['pic']),
          storedLevel: (raw['lvl'] as num?)?.toInt(),
          tag: raw['tag'] is String ? raw['tag'] as String : '',
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

  /// Whether the local player gets a row: they chose to appear on the board
  /// and played at least one game (just opening the board writes nothing).
  static bool wantsRow(AppSettings settings) => settings.showOnLeaderboard && settings.gamesPlayed > 0;

  /// Writes the local player's row (see [wantsRow]).
  static Future<void> submit(AppSettings settings) async {
    if (!wantsRow(settings)) return;
    try {
      if (await OnlineService.ensureReady() != null) return;
      final raw = settings.playerName.trim();
      // Without a name: the neutral "Player" that is also in the player code
      // ("Player #2155"), never "You", which other players would read.
      var name = raw.isEmpty ? settings.handleName : raw;
      if (name.length > maxNameLength) name = name.substring(0, maxNameLength);
      // The database only accepts believable steps (see the rules: at most
      // [maxXpStep] XP and [maxGameStep] games per update, one update every
      // [minGap]), so a changed saved game cannot jump to the top. A player
      // who is further ahead locally catches up a step per game.
      final lb = OnlineService.ref('leaderboard/${OnlineService.uid}');
      final old = await _row(lb);
      if (_tooSoon(old)) return;
      final games = _clampGames(settings.gamesPlayed, old);
      await lb.set(<String, Object?>{
        'name': name,
        'xp': _clampXp(settings.xp, games, old),
        'wins': min(settings.gamesWon, games),
        'games': games,
        'frame': settings.avatarFrame.name,
        'pic': settings.avatarPic.name,
        if (settings.playerTag != null) 'tag': settings.playerTag,
        'updated': ServerValue.timestamp,
      });
      // This month's season: only the XP earned in it.
      if (settings.seasonXp > 0) {
        final sr = OnlineService.ref('seasons/${settings.season}/${OnlineService.uid}');
        final sold = await _row(sr);
        if (_tooSoon(sold)) return;
        final sgames = _clampGames(settings.seasonGames, sold);
        await sr.set(<String, Object?>{
          'name': name,
          'xp': _clampXp(settings.seasonXp, sgames, sold),
          'wins': min(settings.seasonWins, sgames),
          'games': sgames,
          'lvl': settings.playerLevel,
          'frame': settings.avatarFrame.name,
          'pic': settings.avatarPic.name,
          if (settings.playerTag != null) 'tag': settings.playerTag,
          'updated': ServerValue.timestamp,
        });
      }
    } catch (_) {}
  }

  // ---- limits (the same numbers are in database.rules.json)

  static const int maxXpStep = 1500;
  static const int maxGameStep = 3;
  static const int xpPerGame = 300;
  static const int xpBase = 3000;
  static const Duration minGap = Duration(seconds: 10);

  static Future<Map<Object?, Object?>?> _row(DatabaseReference ref) async {
    final v = (await ref.once().timeout(const Duration(seconds: 8))).snapshot.value;
    return v is Map ? v : null;
  }

  static int _int(Map<Object?, Object?>? row, String key) => (row?[key] as num?)?.toInt() ?? 0;

  static bool _tooSoon(Map<Object?, Object?>? old) => isTooSoon(old, OnlineService.serverNow);

  /// True when the last update is younger than [minGap] (server time [now]).
  @visibleForTesting
  static bool isTooSoon(Map<Object?, Object?>? old, int now) =>
      old != null && now - _int(old, 'updated') < minGap.inMilliseconds + 500;

  static int _clampGames(int local, Map<Object?, Object?>? old) => clampGames(local, old);

  static int _clampXp(int local, int games, Map<Object?, Object?>? old) => clampXp(local, games, old);

  /// Games to publish: at most [maxGameStep] more than the stored row.
  @visibleForTesting
  static int clampGames(int local, Map<Object?, Object?>? old) =>
      old == null ? local : min(local, _int(old, 'games') + maxGameStep);

  /// XP to publish: believable for the games played and a limited step up.
  @visibleForTesting
  static int clampXp(int local, int games, Map<Object?, Object?>? old) {
    var xp = min(local, games * xpPerGame + xpBase);
    if (old != null) xp = min(xp, _int(old, 'xp') + maxXpStep);
    return max(0, xp);
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
