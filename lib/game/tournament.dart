import 'dart:math';

import '../engine/pastra_ai.dart';
import 'seats.dart';

/// An offline knockout tournament: 8 players (you and 7 bots), three rounds
/// (quarterfinal, semifinal, final). The computer you meet gets stronger each
/// round. Pure Dart; [AppSettings] stores the JSON between sessions.
class Tournament {
  Tournament._({
    required this.bots,
    required this.ratings,
    required this.humanSlot,
    required this.bracket,
    this.humanOut = false,
    this.lostRound = -1,
    this.bonusPaid = false,
  });

  static const int size = 8;
  static const int rounds = 3;

  /// Index into the bot-name list per slot (-1 = the local player).
  final List<int> bots;

  /// How strong each bot is when two bots play each other (0..1).
  final List<double> ratings;

  final int humanSlot;

  /// `bracket[r]` = the slots playing in round r, in pairs (0 vs 1, 2 vs 3 …).
  /// `bracket[r + 1]` exists once round r is decided; the last list holds the
  /// champion.
  final List<List<int>> bracket;

  bool humanOut;

  /// Round (0..2) in which the player lost; -1 while still in.
  int lostRound;

  /// Whether the XP bonus was already given.
  bool bonusPaid;

  factory Tournament.create([Random? random]) {
    final rng = random ?? Random();
    final names = SeatInfo.randomBotNames(size - 1);
    final humanSlot = rng.nextInt(size);
    final bots = <int>[];
    var n = 0;
    for (var i = 0; i < size; i++) {
      bots.add(i == humanSlot ? -1 : names[n++]);
    }
    return Tournament._(
      bots: bots,
      ratings: List<double>.generate(size, (_) => 0.3 + rng.nextDouble() * 0.4),
      humanSlot: humanSlot,
      bracket: <List<int>>[List<int>.generate(size, (i) => i)],
    );
  }

  /// The round being played (0 = quarterfinal). After the final it stays 2.
  int get round => humanOut ? lostRound : min(bracket.length - 1, rounds - 1);

  bool get hasChampion => bracket.length > rounds;

  int? get championSlot => hasChampion ? bracket[rounds][0] : null;

  bool get won => championSlot == humanSlot;

  bool get finished => humanOut || hasChampion;

  /// Matches the player has won (0..3).
  int get wins => humanOut ? lostRound : (hasChampion ? rounds : round);

  /// The computer gets stronger every round.
  static AiLevel levelFor(int round) => switch (round) {
        0 => AiLevel.easy,
        1 => AiLevel.medium,
        _ => AiLevel.hard,
      };

  AiLevel get opponentLevel => levelFor(round);

  /// Slot of the player's opponent in the current round (-1 when finished).
  int get opponentSlot {
    if (finished) return -1;
    final pos = bracket[round].indexOf(humanSlot);
    return bracket[round][pos ^ 1];
  }

  /// XP bonus for the result: 30 per round won, 200 for the title.
  int get bonusXp => switch (wins) {
        0 => 0,
        1 => 30,
        2 => 80,
        _ => 200,
      };

  /// Records the result of the player's match and plays the other matches of
  /// the round. After a defeat the rest of the tournament is played out too.
  void reportHumanMatch(bool humanWon, [Random? random]) {
    if (finished) return;
    final rng = random ?? Random();
    final playing = round;
    final current = bracket[playing];
    final next = <int>[];
    for (var i = 0; i < current.length; i += 2) {
      final a = current[i];
      final b = current[i + 1];
      if (a == humanSlot || b == humanSlot) {
        final other = a == humanSlot ? b : a;
        next.add(humanWon ? humanSlot : other);
      } else {
        next.add(_botMatch(a, b, rng));
      }
    }
    bracket.add(next);
    if (!humanWon) {
      humanOut = true;
      lostRound = playing;
      while (bracket.last.length > 1) {
        final cur = bracket.last;
        bracket.add(<int>[
          for (var i = 0; i < cur.length; i += 2) _botMatch(cur[i], cur[i + 1], rng),
        ]);
      }
    }
  }

  int _botMatch(int a, int b, Random rng) {
    final pa = ratings[a] / (ratings[a] + ratings[b]);
    return rng.nextDouble() < pa ? a : b;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bots': bots,
        'ratings': ratings,
        'humanSlot': humanSlot,
        'bracket': bracket,
        'humanOut': humanOut,
        'lostRound': lostRound,
        'bonusPaid': bonusPaid,
      };

  /// Null when [j] is not a valid tournament.
  static Tournament? fromJson(Map<String, dynamic> j) {
    try {
      final bots = (j['bots'] as List).map((e) => (e as num).toInt()).toList();
      final ratings = (j['ratings'] as List).map((e) => (e as num).toDouble()).toList();
      final bracket = (j['bracket'] as List)
          .map((r) => (r as List).map((e) => (e as num).toInt()).toList())
          .toList();
      final humanSlot = (j['humanSlot'] as num).toInt();
      if (bots.length != size || ratings.length != size || bracket.isEmpty || bracket.length > rounds + 1) {
        return null;
      }
      if (humanSlot < 0 || humanSlot >= size || bracket[0].length != size) return null;
      return Tournament._(
        bots: bots,
        ratings: ratings,
        humanSlot: humanSlot,
        bracket: bracket,
        humanOut: j['humanOut'] == true,
        lostRound: (j['lostRound'] as num?)?.toInt() ?? -1,
        bonusPaid: j['bonusPaid'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
