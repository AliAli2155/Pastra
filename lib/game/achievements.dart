import 'package:flutter/material.dart';

import '../engine/pastra_ai.dart';
import 'app_settings.dart';

/// One badge. Counter badges have a [goal] and read their progress from the
/// statistics; the others are unlocked by something that happens in a game.
class Achievement {
  final String id;
  final IconData icon;
  final int goal;
  final int Function(GameStats stats)? progress;

  const Achievement(this.id, this.icon, {this.goal = 1, this.progress});

  bool get isCounter => progress != null;
}

/// All achievements, in the order they are shown. Titles and descriptions
/// are the translation keys `ach_<id>_t` / `ach_<id>_d`.
final List<Achievement> kAchievements = <Achievement>[
  Achievement('games_1', Icons.style_outlined, progress: (s) => s.games),
  Achievement('wins_1', Icons.emoji_events_outlined, progress: (s) => s.wins),
  Achievement('pastras_1', Icons.auto_awesome, progress: (s) => s.pastras),
  const Achievement('jack_pastra', Icons.stars),
  const Achievement('three_pastras', Icons.local_fire_department),
  const Achievement('big_round', Icons.trending_up),
  const Achievement('good_cards', Icons.diamond_outlined),
  const Achievement('win_hard', Icons.psychology_alt_outlined),
  const Achievement('win_2v2', Icons.groups),
  const Achievement('comeback', Icons.replay),
  const Achievement('quick_win', Icons.bolt),
  Achievement('streak_3', Icons.whatshot_outlined, goal: 3, progress: (s) => s.bestStreak),
  Achievement('streak_5', Icons.whatshot, goal: 5, progress: (s) => s.bestStreak),
  Achievement('games_10', Icons.casino_outlined, goal: 10, progress: (s) => s.games),
  Achievement('games_50', Icons.casino, goal: 50, progress: (s) => s.games),
  Achievement('wins_10', Icons.military_tech_outlined, goal: 10, progress: (s) => s.wins),
  Achievement('wins_25', Icons.military_tech, goal: 25, progress: (s) => s.wins),
  Achievement('pastras_25', Icons.workspace_premium_outlined, goal: 25, progress: (s) => s.pastras),
  Achievement('pastras_100', Icons.workspace_premium, goal: 100, progress: (s) => s.pastras),
];

/// What happened in a finished round (from the local player's side).
class RoundFacts {
  final int score;
  final int pastras;
  final int jackPastras;

  /// Our team took both 2♣ and 10♦.
  final bool goodCards;

  const RoundFacts({
    required this.score,
    required this.pastras,
    required this.jackPastras,
    required this.goodCards,
  });
}

/// What happened in a finished game.
class GameFacts {
  final bool won;
  final AiLevel level;
  final int players;
  final int rounds;
  final int target;

  /// Largest lead the other side had after any round.
  final int maxDeficit;

  const GameFacts({
    required this.won,
    required this.level,
    required this.players,
    required this.rounds,
    required this.target,
    required this.maxDeficit,
  });
}

/// Achievements earned by the current statistics and [round] / [game].
List<String> earnedAchievements(GameStats stats, {RoundFacts? round, GameFacts? game}) {
  final ids = <String>[
    for (final a in kAchievements)
      if (a.isCounter && a.progress!(stats) >= a.goal) a.id,
  ];
  if (round != null) {
    if (round.jackPastras > 0) ids.add('jack_pastra');
    if (round.pastras >= 3) ids.add('three_pastras');
    if (round.score >= 40) ids.add('big_round');
    if (round.goodCards) ids.add('good_cards');
  }
  if (game != null && game.won) {
    if (game.level == AiLevel.hard) ids.add('win_hard');
    if (game.players == 4) ids.add('win_2v2');
    if (game.maxDeficit >= 50) ids.add('comeback');
    if (game.rounds <= 5 && game.target >= 101) ids.add('quick_win');
  }
  return ids;
}
