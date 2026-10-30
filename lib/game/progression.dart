import '../engine/pastra_ai.dart';
import '../ui/theme.dart';

/// Experience points, player levels and the table / card-back colours that
/// unlock at certain levels. Pure Dart, no storage: [AppSettings] keeps the XP.
class Progression {
  Progression._();

  static const int maxLevel = 30;

  /// XP needed to go from level [level] to the next one.
  static int xpToNext(int level) => 80 + 30 * (level - 1);

  /// Total XP at which [level] starts (level 1 starts at 0).
  static int xpForLevel(int level) {
    var total = 0;
    for (var l = 1; l < level.clamp(1, maxLevel); l++) {
      total += xpToNext(l);
    }
    return total;
  }

  static int levelOf(int xp) {
    var level = 1;
    var left = xp < 0 ? 0 : xp;
    while (level < maxLevel && left >= xpToNext(level)) {
      left -= xpToNext(level);
      level++;
    }
    return level;
  }

  /// XP earned inside the current level and the XP this level needs
  /// (both 0 at the maximum level).
  static ({int into, int needed}) progress(int xp) {
    final level = levelOf(xp);
    if (level >= maxLevel) return (into: 0, needed: 0);
    return (into: xp - xpForLevel(level), needed: xpToNext(level));
  }

  // ---- earning XP

  static const int gameBase = 20;
  static const int winBonus = 40;
  static const int pastraXp = 10;
  static const int jackPastraXp = 15;

  /// Beating a harder computer is worth more.
  static double levelFactor(AiLevel level) => switch (level) {
        AiLevel.easy => 1.0,
        AiLevel.medium => 1.5,
        AiLevel.hard => 2.0,
      };

  /// XP of a finished game (the pastras are paid per round, see [roundXp]).
  static int gameXp({required bool won, required AiLevel level}) {
    if (!won) return gameBase;
    return gameBase + (winBonus * levelFactor(level)).round();
  }

  /// XP of the pastras made in one round (a jack pastra counts as a pastra
  /// plus a bonus).
  static int roundXp({required int pastras, required int jackPastras}) =>
      pastras * pastraXp + jackPastras * jackPastraXp;

  /// XP for a player that has stats from before levels existed.
  static int backfill({required int games, required int wins, required int pastras}) =>
      games * gameBase + wins * 60 + pastras * pastraXp;

  // ---- unlocks (level 1 colours are always available)

  static const Map<TableTheme, int> tableLevel = <TableTheme, int>{
    TableTheme.green: 1,
    TableTheme.blue: 4,
    TableTheme.wood: 8,
    TableTheme.red: 12,
    TableTheme.purple: 18,
    TableTheme.night: 26,
  };

  static const Map<CardBackStyle, int> backLevel = <CardBackStyle, int>{
    CardBackStyle.aegean: 1,
    CardBackStyle.red: 2,
    CardBackStyle.green: 5,
    CardBackStyle.black: 10,
    CardBackStyle.purple: 15,
    CardBackStyle.gold: 22,
  };

  static int levelFor(TableTheme t) => tableLevel[t] ?? 1;
  static int levelForBack(CardBackStyle b) => backLevel[b] ?? 1;

  /// Whether anything unlocks at a level in (from, to].
  static bool unlocksBetween(int from, int to) =>
      tableLevel.values.any((l) => l > from && l <= to) || backLevel.values.any((l) => l > from && l <= to);
}

/// What one game gave the local player.
class GameXp {
  const GameXp({
    required this.amount,
    required this.levelBefore,
    required this.levelAfter,
    this.chips = 0,
    this.diamonds = 0,
  });

  final int amount;

  /// Change of the chip and diamond balance in this game (entry fee, pot,
  /// rewards for a new level).
  final int chips;
  final int diamonds;
  final int levelBefore;
  final int levelAfter;

  bool get leveledUp => levelAfter > levelBefore;
  bool get newColors => Progression.unlocksBetween(levelBefore, levelAfter);
}
