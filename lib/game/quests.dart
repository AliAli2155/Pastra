import 'dart:math';

import '../engine/pastra_ai.dart';

/// How hard a daily quest is. Every day has one of each.
enum QuestTier { easy, medium, hard }

/// One kind of daily quest. [kind] is also the translation key (`q_<kind>`).
class QuestDef {
  const QuestDef(this.id, this.kind, this.goal, this.xp, this.tier);

  final String id;
  final String kind;
  final int goal;
  final int xp;
  final QuestTier tier;
}

/// Something that happened in a game, from the local player's side. A
/// finished round and the end of the game can come in the same event.
class QuestEvent {
  const QuestEvent({
    this.pastras = 0,
    this.jackPastras = 0,
    this.rounds = 0,
    this.roundScore = 0,
    this.goodCards = false,
    this.gameOver = false,
    this.won = false,
    this.online = false,
    this.players = 2,
    this.level,
  });

  final int pastras;
  final int jackPastras;
  final int rounds;

  /// Our team's points in the finished round.
  final int roundScore;

  /// Our team took both 2♣ and 10♦ in the round.
  final bool goodCards;
  final bool gameOver;
  final bool won;
  final bool online;
  final int players;

  /// The computer's level in an offline game (null online).
  final AiLevel? level;
}

/// Daily quests: three a day (easy, medium, hard), different for every
/// player and every day. Pure Dart; [AppSettings] keeps the progress.
class Quests {
  Quests._();

  static const List<QuestDef> all = <QuestDef>[
    QuestDef('play_2', 'play', 2, 40, QuestTier.easy),
    QuestDef('win_1', 'win1', 1, 50, QuestTier.easy),
    QuestDef('pastra_2', 'pastra', 2, 50, QuestTier.easy),
    QuestDef('rounds_6', 'rounds', 6, 40, QuestTier.easy),
    QuestDef('team_1', 'team', 1, 50, QuestTier.easy),
    QuestDef('play_4', 'play', 4, 80, QuestTier.medium),
    QuestDef('pastra_5', 'pastra', 5, 100, QuestTier.medium),
    QuestDef('round_30', 'round', 30, 80, QuestTier.medium),
    QuestDef('good_1', 'good', 1, 80, QuestTier.medium),
    QuestDef('online_1', 'online', 1, 80, QuestTier.medium),
    QuestDef('team_win', 'teamWin', 1, 90, QuestTier.medium),
    QuestDef('win_3', 'win', 3, 130, QuestTier.hard),
    QuestDef('jack_1', 'jack', 1, 120, QuestTier.hard),
    QuestDef('hard_1', 'hard', 1, 140, QuestTier.hard),
    QuestDef('online_win', 'onlineWin', 1, 140, QuestTier.hard),
    QuestDef('streak_2', 'streak', 2, 130, QuestTier.hard),
  ];

  /// Extra XP when all three quests of the day are collected.
  static const int allBonusXp = 100;

  /// Chips per quest when the chip economy is on.
  static int chipsFor(QuestDef q) => q.xp * 3;
  static const int allBonusChips = 300;
  static const int allBonusDiamonds = 1;

  static QuestDef? byId(String id) {
    for (final q in all) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// Seed of a player's quests on [day]: every player gets other quests.
  static int seed(int playerSeed, int day) {
    var h = (playerSeed ^ 0x5bd1e995) & 0x7fffffff;
    h = (h * 31 + day * 7919) & 0x7fffffff;
    h ^= h >> 13;
    h = (h * 0x2f0b3) & 0x7fffffff;
    return h;
  }

  /// The three quests of a day: one easy, one medium, one hard.
  static List<String> pick(int seed) {
    final r = Random(seed);
    return <String>[
      for (final tier in QuestTier.values) _ofTier(tier)[r.nextInt(_ofTier(tier).length)].id,
    ];
  }

  /// Another quest of the same tier for [id] (not one of [current]).
  static String? reroll(List<String> current, String id, int seed) {
    final q = byId(id);
    if (q == null) return null;
    final options = <QuestDef>[
      for (final o in _ofTier(q.tier))
        if (!current.contains(o.id)) o,
    ];
    if (options.isEmpty) return null;
    return options[Random(seed).nextInt(options.length)].id;
  }

  static List<QuestDef> _ofTier(QuestTier tier) => <QuestDef>[
        for (final q in all)
          if (q.tier == tier) q,
      ];

  /// New progress of [q] after [e] ([progress] is the progress before).
  static int advance(QuestDef q, int progress, QuestEvent e) {
    if (progress >= q.goal) return progress;
    final next = switch (q.kind) {
      'play' => progress + (e.gameOver ? 1 : 0),
      'win' || 'win1' => progress + (e.gameOver && e.won ? 1 : 0),
      'pastra' => progress + e.pastras,
      'jack' => progress + e.jackPastras,
      'rounds' => progress + e.rounds,
      'team' => progress + (e.gameOver && e.players == 4 ? 1 : 0),
      'teamWin' => progress + (e.gameOver && e.won && e.players == 4 ? 1 : 0),
      'online' => progress + (e.gameOver && e.online ? 1 : 0),
      'onlineWin' => progress + (e.gameOver && e.online && e.won ? 1 : 0),
      'hard' => progress + (e.gameOver && e.won && !e.online && e.level == AiLevel.hard ? 1 : 0),
      'round' => e.rounds > 0 && e.roundScore >= q.goal ? q.goal : progress,
      'good' => progress + (e.rounds > 0 && e.goodCards ? 1 : 0),
      // Wins in a row: a lost game starts again from zero.
      'streak' => e.gameOver ? (e.won ? progress + 1 : 0) : progress,
      _ => progress,
    };
    return next.clamp(0, q.goal);
  }

  /// Time until the quests change (local midnight).
  static Duration untilTomorrow(DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
}

/// One of today's quests with its progress.
class QuestState {
  const QuestState(this.def, this.progress, this.claimed);

  final QuestDef def;
  final int progress;
  final bool claimed;

  bool get done => progress >= def.goal;
}
