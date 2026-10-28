import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/online/lobby.dart';

void main() {
  const now = 10000000000;

  Map<String, Object?> entry({
    String host = 'h1',
    int players = 2,
    int joined = 1,
    int created = now - 1000,
    String level = 'hard',
    String name = 'Ali',
  }) =>
      <String, Object?>{
        'host': host,
        'name': name,
        'players': players,
        'joined': joined,
        'created': created,
        'level': level,
      };

  test('open tables: newest first, with their data', () {
    final tables = OpenTable.parseAll(
      <String, Object?>{
        '1111': entry(created: now - 5000),
        '2222': entry(host: 'h2', players: 4, joined: 2, created: now - 100, level: 'easy', name: 'Maria'),
      },
      now: now,
    );
    expect(tables.map((t) => t.code).toList(), <String>['2222', '1111']);
    expect(tables.first.players, 4);
    expect(tables.first.joined, 2);
    expect(tables.first.free, 2);
    expect(tables.first.level, AiLevel.easy);
    expect(tables.first.name, 'Maria');
    expect(tables.last.level, AiLevel.hard);
  });

  test('full, stale, own and broken tables are not listed', () {
    final tables = OpenTable.parseAll(
      <String, Object?>{
        'full': entry(joined: 2),
        'old': entry(created: now - OpenTable.maxAge.inMilliseconds - 1),
        'mine': entry(host: 'me'),
        'bad players': entry(players: 3),
        'empty': entry(joined: 0),
        'junk': 'nope',
        'ok': entry(),
      },
      now: now,
      exceptHost: 'me',
    );
    expect(tables.map((t) => t.code).toList(), <String>['ok']);
  });

  test('no lobby at all', () {
    expect(OpenTable.parseAll(null, now: now), isEmpty);
    expect(OpenTable.parseAll('x', now: now), isEmpty);
  });
}
