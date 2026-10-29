import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/online/cup_logic.dart';

void main() {
  const slot = 1800000 * 1000; // a start time on the 30-minute grid
  const signups = <CupSignup>[
    CupSignup('bob', 'Bob', slot - 5000),
    CupSignup('ali', 'Ali', slot - 9000),
    CupSignup('late', 'Late', slot + 10), // after the start: does not count
  ];

  List<CupEntrant> entrants() => CupBracket.entrantsFor(slot, signups, botNames: 40);

  test('slots are every 30 minutes', () {
    expect(CupRules.nextSlot(slot), slot + CupRules.slotMs);
    expect(CupRules.nextSlot(slot - 1), slot);
    expect(CupRules.currentSlot(slot + 5), slot);
  });

  test('the same 8 entrants on every device: players before the start, bots for the rest', () {
    final a = entrants();
    final b = entrants();
    expect(a.length, CupRules.size);
    expect(a.map((e) => e.uid ?? 'bot${e.botIndex}').toList(), b.map((e) => e.uid ?? 'bot${e.botIndex}').toList());
    expect(a.where((e) => !e.isBot).map((e) => e.uid).toSet(), <String>{'ali', 'bob'});
    final bots = a.where((e) => e.isBot).map((e) => e.botIndex).toList();
    expect(bots.length, 6);
    expect(bots.toSet().length, 6, reason: 'different bot names');
  });

  test('bot against bot is decided at once, matches with players wait for them', () {
    final e = entrants();
    final br = CupBracket.compute(slot: slot, entrants: e, results: const <String, CupResult>{});
    for (final m in br.matches[0]) {
      final bothBots = e[m.a!].isBot && e[m.b!].isBot;
      expect(m.status, bothBots ? CupMatchStatus.done : CupMatchStatus.ready);
      expect(m.readyAt, slot);
    }
    expect(br.finished, isFalse);
    final ali = br.positionOf('ali');
    expect(br.openMatchOf(ali)?.status, CupMatchStatus.ready);
  });

  test('written results move the players on until there is a champion', () {
    final e = entrants();
    final results = <String, CupResult>{};
    var t = slot + 1000;
    for (var guard = 0; guard < 10; guard++) {
      final br = CupBracket.compute(slot: slot, entrants: e, results: results);
      if (br.finished) break;
      for (final round in br.matches) {
        for (final m in round) {
          if (m.status != CupMatchStatus.ready) continue;
          // Ali always wins; otherwise the first player.
          final w = e[m.a!].uid == 'ali' || e[m.b!].uid == 'ali' ? br.positionOf('ali') : m.a!;
          results[m.id] = CupResult(w, t += 1000);
        }
      }
    }
    final br = CupBracket.compute(slot: slot, entrants: e, results: results);
    expect(br.finished, isTrue);
    expect(br.champion, br.positionOf('ali'));
    expect(br.winsOf(br.positionOf('ali')), 3);
    expect(br.lostIn(br.positionOf('ali')), -1);
    expect(br.matches.map((r) => r.length).toList(), <int>[4, 2, 1]);
  });

  test('a result for somebody who is not in the match is ignored', () {
    final e = entrants();
    final br0 = CupBracket.compute(slot: slot, entrants: e, results: const <String, CupResult>{});
    final ali = br0.positionOf('ali');
    final m = br0.openMatchOf(ali)!;
    final outsider = List<int>.generate(8, (i) => i).firstWhere((p) => !m.involves(p));
    final br = CupBracket.compute(slot: slot, entrants: e, results: <String, CupResult>{m.id: CupResult(outsider, slot + 1)});
    expect(br.openMatchOf(ali)?.id, m.id);
  });

  test('no-show and timeout claims', () {
    final e = entrants();
    final br = CupBracket.compute(slot: slot, entrants: e, results: const <String, CupResult>{});
    final ali = br.positionOf('ali');
    final m = br.openMatchOf(ali)!;
    final opp = m.a == ali ? m.b! : m.a!;
    // Everybody there: nothing to decide.
    expect(br.claims(slot + 200000, <String>{'ali', 'bob'}).where((c) => c.matchId == m.id), isEmpty);
    // Too early to call a no-show.
    expect(br.claims(slot + 1000, <String>{'bob'}).where((c) => c.matchId == m.id), isEmpty);
    // Ali is not there after 90 s: the opponent wins (a bot, or Bob if present).
    final noShow = br.claims(slot + CupRules.noShow.inMilliseconds, <String>{'bob'}).where((c) => c.matchId == m.id);
    if (e[opp].isBot || e[opp].uid == 'bob') {
      expect(noShow.single.winner, opp);
    }
    // After the timeout something is always decided.
    final afterTimeout = br.claims(slot + CupRules.timeout.inMilliseconds, <String>{'ali', 'bob'});
    expect(afterTimeout.where((c) => c.matchId == m.id).single.winner, anyOf(ali, opp));
  });
}
