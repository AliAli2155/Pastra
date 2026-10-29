import 'dart:math' show max;

/// Online tournaments ("cups") without a server: every device computes the
/// same bracket from the same data (the registrations and the results
/// written so far), so nobody has to organise them.
///
/// * Scheduled cups ([CupType.scheduled]) start at fixed times; a friends
///   cup starts when its creator presses Start. The start time is the cut:
///   only registrations made before it count.
/// * Players play in groups of [CupRules.size] by registration order
///   (players 9–16 form a second bracket at the same time, and so on, up to
///   [CupRules.maxGroups]); empty places get bots.
/// * A match whose players are known is "ready"; its result is written by
///   the players. Bots against bots are decided by a seeded coin, the same on
///   every device.
/// * Nobody there after [CupRules.noShow]: that side loses; a match that
///   takes longer than the cup's timeout is decided (see [CupBracket.claims]).
class CupRules {
  CupRules._();

  /// Players per bracket.
  static const int size = 8;

  /// At most this many parallel brackets (the free Firebase plan allows
  /// about 100 connections at a time).
  static const int maxGroups = 12;

  static const Duration noShow = Duration(seconds: 90);
}

/// A kind of cup.
class CupType {
  const CupType._(
    this.id,
    this.everyMinutes,
    this.offsetMinutes,
    this.targetScore,
    this.teamSize,
    this.timeout, {
    this.fixedTeams = false,
  });

  /// Kind (q, c, t, f); with the options it makes the database key.
  final String id;

  /// The team cup is always 2v2 (only its points can be chosen).
  final bool fixedTeams;

  /// 0 for a friends cup (no schedule).
  final int everyMinutes;
  final int offsetMinutes;
  final int targetScore;

  /// 1 = 1v1, 2 = teams of two (2v2).
  final int teamSize;

  /// A ready match that takes longer than this is decided.
  final Duration timeout;

  static const CupType quick = CupType._('q', 15, 0, 51, 1, Duration(minutes: 20));
  static const CupType classic = CupType._('c', 30, 0, 101, 1, Duration(minutes: 30));
  static const CupType team = CupType._('t', 30, 15, 51, 2, Duration(minutes: 20), fixedTeams: true);
  static const CupType friends = CupType._('f', 0, 0, 51, 1, Duration(minutes: 20));

  /// The same kind and schedule with the player's choice of 1v1 / 2v2 and
  /// target score. Players who chose differently play in different cups.
  CupType withOptions({int? teamSize, int? targetScore}) {
    final teams = fixedTeams ? this.teamSize : ((teamSize ?? this.teamSize) == 2 ? 2 : 1);
    final target = targetScore ?? this.targetScore;
    return CupType._(
      id,
      everyMinutes,
      offsetMinutes,
      target,
      teams,
      // Longer games may take longer before a match is decided.
      Duration(minutes: 10 + target ~/ 5),
      fixedTeams: fixedTeams,
    );
  }

  static const List<CupType> scheduled = <CupType>[quick, classic, team];

  /// A friends cup as its creator set it up (1v1 or 2v2, target score).
  factory CupType.friendsWith({required int teamSize, required int targetScore}) =>
      friends.withOptions(teamSize: teamSize, targetScore: targetScore);

  bool get isScheduled => everyMinutes > 0;

  int get _every => everyMinutes * 60000;
  int get _offset => offsetMinutes * 60000;

  /// Start of the next cup after [now].
  int nextStart(int now) => ((now - _offset) ~/ _every + 1) * _every + _offset;

  /// Start of the cup that began last (it may still be running).
  int currentStart(int now) => (now - _offset) ~/ _every * _every + _offset;

  /// Database key of the scheduled cup starting at [start] (kind and
  /// options, e.g. `q2x101_1761822000000`).
  String keyFor(int start) => '$id${teamSize}x${targetScore}_$start';

  /// Places in a bracket (players or teams).
  int get entrants => CupRules.size ~/ teamSize;

  /// Rounds of a bracket: 3 for 8 players, 2 for 4 teams.
  int get rounds {
    var r = 0;
    for (var n = entrants; n > 1; n ~/= 2) {
      r++;
    }
    return r;
  }

  /// Most groups: a friends cup is one bracket.
  int get maxGroups => isScheduled ? CupRules.maxGroups : 1;
}

/// One player of a bracket place: a registered person or a bot.
class CupMember {
  const CupMember.player(String this.uid, this.name) : botIndex = -1;

  const CupMember.bot(this.botIndex)
      : uid = null,
        name = '';

  final String? uid;
  final String name;

  /// Index into the bot names (bots only).
  final int botIndex;

  bool get isBot => uid == null;
}

/// A place in the bracket: one player (1v1) or a team of two.
class CupEntrant {
  const CupEntrant(this.members);

  final List<CupMember> members;

  bool get isBot => members.every((m) => m.isBot);

  bool has(String uid) => members.any((m) => m.uid == uid);
}

/// A registration as stored in the database.
class CupSignup {
  const CupSignup(this.uid, this.name, this.time);

  final String uid;
  final String name;

  /// Server time of the registration.
  final int time;
}

/// A written result.
class CupResult {
  const CupResult(this.winner, this.time);

  /// Bracket position of the winner.
  final int winner;

  /// Server time it was written.
  final int time;
}

enum CupMatchStatus {
  /// A previous match is not decided yet.
  waiting,

  /// Both sides are known: to be played.
  ready,

  /// Decided.
  done,
}

class CupMatch {
  const CupMatch({
    this.group = 0,
    required this.round,
    required this.index,
    required this.a,
    required this.b,
    required this.status,
    this.readyAt,
    this.winner,
    this.doneAt,
  });

  /// Parallel group (0 = the first 8 players).
  final int group;
  final int round;
  final int index;

  /// Bracket positions of the two sides (null while unknown).
  final int? a;
  final int? b;
  final CupMatchStatus status;

  /// When both sides became known.
  final int? readyAt;
  final int? winner;
  final int? doneAt;

  String get id => matchId(group, round, index);

  static String matchId(int group, int round, int index) => 'g${group}r${round}m$index';

  bool involves(int position) => a == position || b == position;
}

/// A result this device should write because the rules decide the match
/// (no-show or timeout).
class CupClaim {
  const CupClaim(this.matchId, this.winner);

  final String matchId;
  final int winner;
}

class CupBracket {
  CupBracket._(this.start, this.group, this.entrants, this.matches);

  /// Start time of the cup (seeds every random choice).
  final int start;

  /// Parallel group of this bracket.
  final int group;
  final List<CupEntrant> entrants;

  /// `matches[round][index]`.
  final List<List<CupMatch>> matches;

  /// Bracket position of [uid], or -1.
  int positionOf(String uid) => entrants.indexWhere((e) => e.has(uid));

  int? get champion => matches.last.single.winner;

  bool get finished => champion != null;

  /// The match of [position] that is not decided yet (null if out or done).
  CupMatch? openMatchOf(int position) {
    for (final round in matches) {
      for (final m in round) {
        if (m.involves(position) && m.status != CupMatchStatus.done) return m;
      }
    }
    return null;
  }

  /// Matches won by [position].
  int winsOf(int position) {
    var wins = 0;
    for (final round in matches) {
      for (final m in round) {
        if (m.status == CupMatchStatus.done && m.winner == position) wins++;
      }
    }
    return wins;
  }

  /// Round in which [position] lost, -1 if it did not (yet).
  int lostIn(int position) {
    for (final round in matches) {
      for (final m in round) {
        if (m.status == CupMatchStatus.done && m.involves(position) && m.winner != position) return m.round;
      }
    }
    return -1;
  }

  /// The registrations that count (made before [start]), in order: by time,
  /// then uid.
  static List<CupSignup> ordered(int start, List<CupSignup> signups) {
    return signups.where((s) => s.time < start).toList()
      ..sort((x, y) => x.time != y.time ? x.time.compareTo(y.time) : x.uid.compareTo(y.uid));
  }

  /// The group [uid] plays in, or -1 (not registered in time, or every group
  /// is full).
  static int groupOf(int start, List<CupSignup> signups, String uid, {int maxGroups = CupRules.maxGroups}) {
    final i = ordered(start, signups).indexWhere((s) => s.uid == uid);
    if (i < 0) return -1;
    final g = i ~/ CupRules.size;
    return g < maxGroups ? g : -1;
  }

  /// How many groups the registrations make (at least one).
  static int groupCount(int start, List<CupSignup> signups, {int maxGroups = CupRules.maxGroups}) {
    final n = ordered(start, signups).length;
    final g = (n + CupRules.size - 1) ~/ CupRules.size;
    return g < 1 ? 1 : (g > maxGroups ? maxGroups : g);
  }

  /// The places of one group: its players and bots for the empty seats,
  /// shuffled (seeded with the start and group, the same on every device)
  /// and, for team cups, paired into teams.
  static List<CupEntrant> entrantsFor(
    int start,
    List<CupSignup> signups, {
    int group = 0,
    int teamSize = 1,
    required int botNames,
  }) {
    final people = ordered(start, signups)
        .skip(group * CupRules.size)
        .take(CupRules.size)
        .map((s) => CupMember.player(s.uid, s.name))
        .toList();
    final rng = CupRandom(_seed(start, 'entrants$group'));
    final names = rng.shuffled(List<int>.generate(botNames, (i) => i));
    final all = rng.shuffled(<CupMember>[
      ...people,
      for (var i = 0; people.length + i < CupRules.size; i++) CupMember.bot(names[i % names.length]),
    ]);
    return <CupEntrant>[
      for (var i = 0; i < all.length; i += teamSize) CupEntrant(all.sublist(i, i + teamSize)),
    ];
  }

  /// Works out every match from the places and the written results.
  static CupBracket compute({
    required int start,
    int group = 0,
    required List<CupEntrant> entrants,
    required Map<String, CupResult> results,
  }) {
    final rounds = <List<CupMatch>>[];
    // Sides of the next round and when they became known.
    var sides = <int?>[for (var i = 0; i < entrants.length; i++) i];
    var known = <int?>[for (var i = 0; i < entrants.length; i++) start];
    for (var r = 0; sides.length > 1; r++) {
      final round = <CupMatch>[];
      final nextSides = <int?>[];
      final nextKnown = <int?>[];
      for (var i = 0; i < sides.length ~/ 2; i++) {
        final a = sides[2 * i];
        final b = sides[2 * i + 1];
        final id = CupMatch.matchId(group, r, i);
        if (a == null || b == null) {
          round.add(CupMatch(group: group, round: r, index: i, a: a, b: b, status: CupMatchStatus.waiting));
          nextSides.add(null);
          nextKnown.add(null);
          continue;
        }
        final readyAt = max(known[2 * i]!, known[2 * i + 1]!);
        final written = results[id];
        int? winner;
        int? doneAt;
        if (written != null && (written.winner == a || written.winner == b)) {
          winner = written.winner;
          doneAt = max(written.time, readyAt);
        } else if (entrants[a].isBot && entrants[b].isBot) {
          winner = CupRandom(_seed(start, id)).nextBool() ? a : b;
          doneAt = readyAt;
        }
        round.add(
          CupMatch(
            group: group,
            round: r,
            index: i,
            a: a,
            b: b,
            status: winner == null ? CupMatchStatus.ready : CupMatchStatus.done,
            readyAt: readyAt,
            winner: winner,
            doneAt: doneAt,
          ),
        );
        nextSides.add(winner);
        nextKnown.add(doneAt);
      }
      rounds.add(round);
      sides = nextSides;
      known = nextKnown;
    }
    return CupBracket._(start, group, entrants, rounds);
  }

  /// Results the rules decide, for ready matches without a result:
  /// * after [CupRules.noShow], a side with nobody there loses (to bots or
  ///   to a side that is there);
  /// * after [timeout], the side that is there wins, or a seeded coin
  ///   decides.
  /// [present] are the uids of the players that are on the cup screen.
  List<CupClaim> claims(int now, Set<String> present, {required Duration timeout}) {
    final out = <CupClaim>[];
    bool here(int p) => entrants[p].isBot || entrants[p].members.any((m) => !m.isBot && present.contains(m.uid));
    for (final round in matches) {
      for (final m in round) {
        if (m.status != CupMatchStatus.ready) continue;
        final a = m.a!;
        final b = m.b!;
        final waited = now - m.readyAt!;
        if (waited >= timeout.inMilliseconds) {
          final winner = here(a) && !here(b)
              ? a
              : here(b) && !here(a)
                  ? b
                  : (CupRandom(_seed(start, '${m.id}timeout')).nextBool() ? a : b);
          out.add(CupClaim(m.id, winner));
        } else if (waited >= CupRules.noShow.inMilliseconds && here(a) != here(b)) {
          out.add(CupClaim(m.id, here(a) ? a : b));
        }
      }
    }
    return out;
  }

  /// Who sits where in the room of a match: the host (the first person of
  /// side [a], else of side [b]) on seat 0. In a 2v2 the partner sits on
  /// seat 2 and the other team on seats 1 and 3.
  static List<CupMember> seating(CupEntrant a, CupEntrant b) {
    final first = <CupMember>[...a.members, ...b.members].firstWhere((m) => !m.isBot);
    final mine = a.has(first.uid!) ? a : b;
    final other = identical(mine, a) ? b : a;
    if (mine.members.length == 1) return <CupMember>[first, other.members[0]];
    final partner = mine.members.firstWhere((m) => !identical(m, first));
    return <CupMember>[first, other.members[0], partner, other.members[1]];
  }

  static int _seed(int start, String salt) {
    var h = (start ~/ 1000) & 0x7fffffff;
    for (final c in salt.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }
}

/// A tiny random generator that gives exactly the same numbers on every
/// platform (phone and web must build the same bracket). `dart:math`'s
/// Random does not promise that. Park–Miller: all values stay below 2^53,
/// so JavaScript numbers are exact.
class CupRandom {
  CupRandom(int seed) : _state = seed % 2147483646 + 1;

  int _state;

  int _next() {
    _state = (_state * 48271) % 2147483647;
    return _state;
  }

  int nextInt(int n) => _next() % n;

  bool nextBool() => _next() % 2 == 0;

  /// A shuffled copy of [list] (Fisher–Yates).
  List<T> shuffled<T>(List<T> list) {
    final out = List<T>.of(list);
    for (var i = out.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }
}
