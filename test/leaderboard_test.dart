import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/online/leaderboard.dart';

void main() {
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
