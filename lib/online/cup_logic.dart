import 'dart:math' show max;

/// The scheduled online tournament ("cup"), without a server: every device
/// computes the same bracket from the same data (the registrations and the
/// results written so far), so nobody has to organise it.
///
/// * A cup starts every [slotMinutes] minutes; its id is its start time.
/// * The first [size] players who registered before the start take part;
///   the empty places get bots.
/// * Matches are 1v1 to [targetScore]. A match whose players are known is
///   "ready"; its result is written by the players. Bot against bot is
///   decided by a seeded coin, the same on every device.
/// * Somebody who is not there loses after [noShow]; a match that takes
///   longer than [timeout] is decided (see [CupBracket.claims]).
class CupRules {
  CupRules._();

  static const int slotMinutes = 30;
  static const int slotMs = slotMinutes * 60 * 1000;
  static const int size = 8;
  static const int rounds = 3;
  static const int targetScore = 51;
  static const Duration noShow = Duration(seconds: 90);
  static const Duration timeout = Duration(minutes: 20);

  /// Start of the next cup after [now].
  static int nextSlot(int now) => (now ~/ slotMs + 1) * slotMs;

  /// Start of the cup that began last (it may still be running).
  static int currentSlot(int now) => now ~/ slotMs * slotMs;
}

/// A place in the bracket: a registered player or a bot.
class CupEntrant {
  const CupEntrant.player(String this.uid, this.name) : botIndex = -1;

  const CupEntrant.bot(this.botIndex)
      : uid = null,
        name = '';

  final String? uid;
  final String name;

  /// Index into the bot names (bots only).
  final int botIndex;

  bool get isBot => uid == null;
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

  /// Bracket position (0..7) of the winner.
  final int winner;

  /// Server time it was written.
  final int time;
}

enum CupMatchStatus {
  /// A previous match is not decided yet.
  waiting,

  /// Both players are known: to be played.
  ready,

  /// Decided.
  done,
}

class CupMatch {
  const CupMatch({
    required this.round,
    required this.index,
    required this.a,
    required this.b,
    required this.status,
    this.readyAt,
    this.winner,
    this.doneAt,
  });

  final int round;
  final int index;

  /// Bracket positions of the two players (null while unknown).
  final int? a;
  final int? b;
  final CupMatchStatus status;

  /// When both players became known.
  final int? readyAt;
  final int? winner;
  final int? doneAt;

  String get id => 'r${round}m$index';

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
  CupBracket._(this.slot, this.entrants, this.matches);

  final int slot;
  final List<CupEntrant> entrants;

  /// `matches[round][index]`.
  final List<List<CupMatch>> matches;

  /// Bracket position of [uid], or -1.
  int positionOf(String uid) => entrants.indexWhere((e) => e.uid == uid);

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

  /// The players of the cup: the first [CupRules.size] registrations before
  /// the start (by time, then uid), the rest bots, all placed by a shuffle
  /// seeded with the slot — the same on every device.
  static List<CupEntrant> entrantsFor(int slot, List<CupSignup> signups, {required int botNames}) {
    final valid = signups.where((s) => s.time < slot).toList()
      ..sort((x, y) => x.time != y.time ? x.time.compareTo(y.time) : x.uid.compareTo(y.uid));
    final people = valid.take(CupRules.size).map((s) => CupEntrant.player(s.uid, s.name)).toList();
    final rng = CupRandom(_seed(slot, 'entrants'));
    final names = rng.shuffled(List<int>.generate(botNames, (i) => i));
    final all = <CupEntrant>[
      ...people,
      for (var i = 0; people.length + i < CupRules.size; i++) CupEntrant.bot(names[i % names.length]),
    ];
    return rng.shuffled(all);
  }

  /// Works out every match from the entrants and the written results.
  static CupBracket compute({
    required int slot,
    required List<CupEntrant> entrants,
    required Map<String, CupResult> results,
  }) {
    final rounds = <List<CupMatch>>[];
    // Players of the next round and when they became known.
    var players = <int?>[for (var i = 0; i < entrants.length; i++) i];
    var known = <int?>[for (var i = 0; i < entrants.length; i++) slot];
    for (var r = 0; r < CupRules.rounds; r++) {
      final round = <CupMatch>[];
      final nextPlayers = <int?>[];
      final nextKnown = <int?>[];
      for (var i = 0; i < players.length ~/ 2; i++) {
        final a = players[2 * i];
        final b = players[2 * i + 1];
        final id = 'r${r}m$i';
        if (a == null || b == null) {
          round.add(CupMatch(round: r, index: i, a: a, b: b, status: CupMatchStatus.waiting));
          nextPlayers.add(null);
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
          winner = CupRandom(_seed(slot, id)).nextBool() ? a : b;
          doneAt = readyAt;
        }
        round.add(
          CupMatch(
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
        nextPlayers.add(winner);
        nextKnown.add(doneAt);
      }
      rounds.add(round);
      players = nextPlayers;
      known = nextKnown;
    }
    return CupBracket._(slot, entrants, rounds);
  }

  /// Results the rules decide, for ready matches without a result:
  /// * after [CupRules.noShow], a player who is not there loses (to a bot or
  ///   to a player who is there);
  /// * after [CupRules.timeout], the one who is there wins, or a seeded coin
  ///   decides.
  /// [present] are the uids of the players that are on the cup screen.
  List<CupClaim> claims(int now, Set<String> present) {
    final out = <CupClaim>[];
    for (final round in matches) {
      for (final m in round) {
        if (m.status != CupMatchStatus.ready) continue;
        final a = m.a!;
        final b = m.b!;
        bool here(int p) => entrants[p].isBot || present.contains(entrants[p].uid);
        final waited = now - m.readyAt!;
        if (waited >= CupRules.timeout.inMilliseconds) {
          final winner = here(a) && !here(b)
              ? a
              : here(b) && !here(a)
                  ? b
                  : (CupRandom(_seed(slot, '${m.id}timeout')).nextBool() ? a : b);
          out.add(CupClaim(m.id, winner));
        } else if (waited >= CupRules.noShow.inMilliseconds && here(a) != here(b)) {
          out.add(CupClaim(m.id, here(a) ? a : b));
        }
      }
    }
    return out;
  }

  static int _seed(int slot, String salt) {
    var h = (slot ~/ 1000) & 0x7fffffff;
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
