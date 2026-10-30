/// Monthly seasons: the XP earned in a calendar month (UTC) makes the
/// season ranking; at the end the best players get a badge. Pure Dart.
class Seasons {
  Seasons._();

  /// Season id of [t]: "yyyymm" (UTC, so it is the same for everybody).
  static String idOf(DateTime t) {
    final u = t.toUtc();
    return '${u.year}${u.month.toString().padLeft(2, '0')}';
  }

  static String current() => idOf(DateTime.now());

  static int year(String id) => int.parse(id.substring(0, 4));
  static int month(String id) => int.parse(id.substring(4, 6));

  /// When the season [id] ends (start of the next month, UTC).
  static DateTime endOf(String id) => DateTime.utc(year(id), month(id) + 1);

  static Duration timeLeft(DateTime now) => endOf(idOf(now)).difference(now.toUtc());

  static bool isValid(String id) => RegExp(r'^\d{6}$').hasMatch(id) && month(id) >= 1 && month(id) <= 12;

  /// Badge tier for a final [rank] (0 = not in the list).
  static SeasonTier tierFor(int rank) {
    if (rank == 1) return SeasonTier.champion;
    if (rank >= 2 && rank <= 3) return SeasonTier.top3;
    if (rank >= 4 && rank <= 10) return SeasonTier.top10;
    if (rank >= 11 && rank <= 100) return SeasonTier.top100;
    return SeasonTier.player;
  }

  static int rewardXp(SeasonTier tier) => switch (tier) {
        SeasonTier.champion => 500,
        SeasonTier.top3 => 300,
        SeasonTier.top10 => 200,
        SeasonTier.top100 => 100,
        SeasonTier.player => 30,
      };
}

enum SeasonTier { champion, top3, top10, top100, player }

/// A finished season of the local player.
class SeasonBadge {
  const SeasonBadge({required this.season, required this.rank, required this.tier});

  final String season;

  /// Final place (0 = unknown / not in the top 100).
  final int rank;
  final SeasonTier tier;

  Map<String, Object> toJson() => <String, Object>{'s': season, 'r': rank, 't': tier.name};

  static SeasonBadge? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['s'];
    final r = j['r'];
    final t = SeasonTier.values.where((x) => x.name == j['t']);
    if (s is! String || r is! num || t.isEmpty) return null;
    return SeasonBadge(season: s, rank: r.toInt(), tier: t.first);
  }
}
