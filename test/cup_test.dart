import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/online/cup_logic.dart';

void main() {
  const start = 1800000 * 1000; // a time on the 15- and 30-minute grid
  const signups = <CupSignup>[
    CupSignup('bob', 'Bob', start - 5000),
    CupSignup('ali', 'Ali', start - 9000),
    CupSignup('late', 'Late', start + 10), // after the start: does not count
  ];
  const timeout = Duration(minutes: 20);

  List<CupEntrant> entrants({int teamSize = 1}) =>
      CupBracket.entrantsFor(start, signups, teamSize: teamSize, botNames: 40);

  String sig(CupEntrant e) => e.members.map((m) => m.uid ?? 'bot${m.botIndex}').join('+');

  test('schedules: quick every 15 min, classic every 30, team at :15 and :45', () {
    expect(CupType.quick.nextStart(start), start + 15 * 60000);
    expect(CupType.quick.nextStart(start - 1), start);
    expect(CupType.quick.currentStart(start + 5), start);
    expect(CupType.classic.nextStart(start), start + 30 * 60000);
    expect(CupType.team.nextStart(start), start + 15 * 60000);
    expect(CupType.team.nextStart(start + 15 * 60000), start + 45 * 60000);
    expect(CupType.team.currentStart(start + 20 * 60000), start + 15 * 60000);
    expect(CupType.quick.rounds, 3);
    expect(CupType.team.rounds, 2);
    expect(CupType.friends.isScheduled, isFalse);
    expect(CupType.friends.maxGroups, 1);
  });

  test('a friends cup can be 2v2 and to any target', () {
    final f = CupType.friendsWith(teamSize: 2, targetScore: 151);
    expect(f.teamSize, 2);
    expect(f.targetScore, 151);
    expect(f.rounds, 2);
    expect(f.maxGroups, 1);
    expect(f.isScheduled, isFalse);
    expect(f.timeout, greaterThan(CupType.friendsWith(teamSize: 1, targetScore: 51).timeout));
    expect(CupType.friendsWith(teamSize: 1, targetScore: 51).rounds, 3);
  });

  test('the same 8 entrants on every device: players before the start, bots for the rest', () {
    final a = entrants();
    final b = entrants();
    expect(a.length, 8);
    expect(a.map(sig).toList(), b.map(sig).toList());
    final people = a.expand((e) => e.members).where((m) => !m.isBot).map((m) => m.uid).toSet();
    expect(people, <String>{'ali', 'bob'});
    final bots = a.expand((e) => e.members).where((m) => m.isBot).map((m) => m.botIndex).toList();
    expect(bots.length, 6);
    expect(bots.toSet().length, 6, reason: 'different bot names');
  });

  test('team cups pair the 8 players into 4 teams of two', () {
    final teams = entrants(teamSize: 2);
    expect(teams.length, 4);
    expect(teams.every((e) => e.members.length == 2), isTrue);
    final br = CupBracket.compute(start: start, entrants: teams, results: const <String, CupResult>{});
    expect(br.matches.map((r) => r.length).toList(), <int>[2, 1]);
  });

  test('bot against bot is decided at once, matches with players wait for them', () {
    final e = entrants();
    final br = CupBracket.compute(start: start, entrants: e, results: const <String, CupResult>{});
    for (final m in br.matches[0]) {
      final bothBots = e[m.a!].isBot && e[m.b!].isBot;
      expect(m.status, bothBots ? CupMatchStatus.done : CupMatchStatus.ready);
      expect(m.readyAt, start);
    }
    expect(br.finished, isFalse);
    expect(br.openMatchOf(br.positionOf('ali'))?.status, CupMatchStatus.ready);
  });

  test('written results move the players on until there is a champion', () {
    final e = entrants();
    final results = <String, CupResult>{};
    var t = start + 1000;
    for (var guard = 0; guard < 10; guard++) {
      final br = CupBracket.compute(start: start, entrants: e, results: results);
      if (br.finished) break;
      for (final round in br.matches) {
        for (final m in round) {
          if (m.status != CupMatchStatus.ready) continue;
          final ali = br.positionOf('ali');
          results[m.id] = CupResult(m.involves(ali) ? ali : m.a!, t += 1000);
        }
      }
    }
    final br = CupBracket.compute(start: start, entrants: e, results: results);
    final ali = br.positionOf('ali');
    expect(br.finished, isTrue);
    expect(br.champion, ali);
    expect(br.winsOf(ali), 3);
    expect(br.lostIn(ali), -1);
    expect(br.matches.map((r) => r.length).toList(), <int>[4, 2, 1]);
  });

  test('a result for somebody who is not in the match is ignored', () {
    final e = entrants();
    final br0 = CupBracket.compute(start: start, entrants: e, results: const <String, CupResult>{});
    final ali = br0.positionOf('ali');
    final m = br0.openMatchOf(ali)!;
    final outsider = List<int>.generate(8, (i) => i).firstWhere((p) => !m.involves(p));
    final br = CupBracket.compute(start: start, entrants: e, results: <String, CupResult>{m.id: CupResult(outsider, start + 1)});
    expect(br.openMatchOf(ali)?.id, m.id);
  });

  test('no-show and timeout claims', () {
    final e = entrants();
    final br = CupBracket.compute(start: start, entrants: e, results: const <String, CupResult>{});
    final ali = br.positionOf('ali');
    final m = br.openMatchOf(ali)!;
    final opp = m.a == ali ? m.b! : m.a!;
    List<CupClaim> at(int t, Set<String> here) =>
        br.claims(t, here, timeout: timeout).where((c) => c.matchId == m.id).toList();
    expect(at(start + 200000, <String>{'ali', 'bob'}), isEmpty);
    expect(at(start + 1000, <String>{'bob'}), isEmpty);
    final noShow = at(start + CupRules.noShow.inMilliseconds, <String>{'bob'});
    if (e[opp].isBot || e[opp].has('bob')) expect(noShow.single.winner, opp);
    expect(at(start + timeout.inMilliseconds, <String>{'ali', 'bob'}).single.winner, anyOf(ali, opp));
  });

  test('seating: the first person hosts on seat 0, partners on 0 and 2', () {
    const bot1 = CupMember.bot(1);
    const bot2 = CupMember.bot(2);
    const bot3 = CupMember.bot(3);
    const ali = CupMember.player('ali', 'Ali');
    const bob = CupMember.player('bob', 'Bob');
    final oneVsOne = CupBracket.seating(const CupEntrant(<CupMember>[bot1]), const CupEntrant(<CupMember>[ali]));
    expect(oneVsOne.map((m) => m.uid).toList(), <String?>['ali', null]);
    final team = CupBracket.seating(
      const CupEntrant(<CupMember>[bot1, bob]),
      const CupEntrant(<CupMember>[ali, bot2]),
    );
    expect(team[0].uid, 'bob');
    expect(team[2].botIndex, 1, reason: "bob's partner sits opposite him");
    expect(<int>{team[1].botIndex, team[3].botIndex}.contains(2), isTrue);
    expect(team.where((m) => m.uid == 'ali').length, 1);
    expect(team.contains(bot3), isFalse);
  });

  test('players 9 and up play a second bracket at the same time', () {
    final many = <CupSignup>[
      for (var i = 0; i < 10; i++) CupSignup('p$i', 'P$i', start - 100000 + i),
    ];
    expect(CupBracket.groupCount(start, many), 2);
    expect(CupBracket.groupOf(start, many, 'p0'), 0);
    expect(CupBracket.groupOf(start, many, 'p8'), 1);
    expect(CupBracket.groupOf(start, many, 'nobody'), -1);
    expect(CupBracket.groupOf(start, many, 'p8', maxGroups: 1), -1, reason: 'a friends cup is one bracket');
    final g1 = CupBracket.entrantsFor(start, many, group: 1, botNames: 40);
    expect(g1.expand((e) => e.members).where((m) => !m.isBot).map((m) => m.uid).toSet(), <String>{'p8', 'p9'});
    final br = CupBracket.compute(start: start, group: 1, entrants: g1, results: const <String, CupResult>{});
    expect(br.matches.expand((r) => r).every((m) => m.id.startsWith('g1')), isTrue);
  });

  test('there is a last group', () {
    final crowd = <CupSignup>[
      for (var i = 0; i < CupRules.size * CupRules.maxGroups + 3; i++) CupSignup('u$i', '', start - 1000000 + i),
    ];
    expect(CupBracket.groupCount(start, crowd), CupRules.maxGroups);
    expect(CupBracket.groupOf(start, crowd, 'u${CupRules.size * CupRules.maxGroups}'), -1);
  });

  test('the cup random numbers are fixed (same on phone and web)', () {
    final r = CupRandom(12345);
    final first = (12346 * 48271) % 2147483647;
    expect(r.nextInt(1000), first % 1000);
    final list = CupRandom(7).shuffled(List<int>.generate(10, (i) => i));
    expect(list.toSet(), Set<int>.from(List<int>.generate(10, (i) => i)));
  });
}
