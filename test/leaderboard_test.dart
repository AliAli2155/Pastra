import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/online/leaderboard.dart';

void main() {
  limitTests();
  test('ranking: most XP first, then wins, then name', () {
    final rows = LeaderEntry.parseAll(<String, Object?>{
      'a': <String, Object?>{'name': 'Bea', 'xp': 500, 'wins': 4, 'games': 9},
      'b': <String, Object?>{'name': 'Ali', 'xp': 900, 'wins': 1, 'games': 2},
      'c': <String, Object?>{'name': 'Zed', 'xp': 500, 'wins': 6, 'games': 9},
      'd': <String, Object?>{'name': 'Cem', 'xp': 500, 'wins': 4, 'games': 5},
    });
    expect(rows.map((r) => r.uid).toList(), <String>['b', 'c', 'a', 'd']);
    expect(rows.first.level, greaterThan(1));
  });

  test('broken rows are skipped', () {
    final rows = LeaderEntry.parseAll(<String, Object?>{
      'ok': <String, Object?>{'name': ' Ali ', 'xp': 10},
      'noXp': <String, Object?>{'name': 'x'},
      'negative': <String, Object?>{'name': 'x', 'xp': -5},
      'junk': 'nope',
    });
    expect(rows.map((r) => r.uid).toList(), <String>['ok']);
    expect(rows.single.name, 'Ali');
    expect(rows.single.wins, 0);
    expect(LeaderEntry.parseAll(null), isEmpty);
  });
}

void limitTests() {
  group('leaderboard limits', () {
    Map<Object?, Object?> row({int xp = 0, int games = 0, int updated = 0}) =>
        <Object?, Object?>{'xp': xp, 'games': games, 'updated': updated};

    test('a first row is only capped by the games played', () {
      expect(Leaderboard.clampGames(40, null), 40);
      expect(Leaderboard.clampXp(999999, 10, null), 10 * Leaderboard.xpPerGame + Leaderboard.xpBase);
      expect(Leaderboard.clampXp(500, 10, null), 500);
    });

    test('games and XP can only climb a step per update', () {
      final old = row(xp: 2000, games: 10);
      expect(Leaderboard.clampGames(500, old), 10 + Leaderboard.maxGameStep);
      expect(Leaderboard.clampGames(11, old), 11);
      expect(Leaderboard.clampXp(50000, 13, old), 2000 + Leaderboard.maxXpStep);
      expect(Leaderboard.clampXp(2100, 13, old), 2100);
    });

    test('XP is never negative', () {
      expect(Leaderboard.clampXp(-50, 0, null), 0);
    });

    test('updates closer than the minimum gap are refused', () {
      final old = row(updated: 100000);
      expect(Leaderboard.isTooSoon(null, 100000), isFalse);
      expect(Leaderboard.isTooSoon(old, 100000 + 5000), isTrue);
      expect(Leaderboard.isTooSoon(old, 100000 + Leaderboard.minGap.inMilliseconds + 600), isFalse);
    });
  });
}
