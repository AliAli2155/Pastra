import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/game_state.dart';
import '../../engine/rules.dart';
import '../../game/progression.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import 'suit_icon.dart';
import 'wallet_bar.dart';

/// End-of-round (and end-of-game) score sheet shown over the table.
class RoundSummaryPanel extends StatelessWidget {
  const RoundSummaryPanel({
    super.key,
    required this.state,
    required this.teamNames,
    required this.onNextRound,
    required this.onMainMenu,
    required this.onPlayAgain,
    this.xpGain,
    this.tournament = false,
    this.playAgainLabel,
    this.onReview,
    this.reviewCount = 0,
  });

  final GameState state;
  final List<String> teamNames;
  final VoidCallback onNextRound;
  final VoidCallback onMainMenu;

  /// Null: shown but disabled (online rematch already asked for).
  final VoidCallback? onPlayAgain;

  /// Instead of "play again" (online: "rematch").
  final String? playAgainLabel;

  /// The game review (end of game).
  final VoidCallback? onReview;

  /// Chances missed in the game (shown on the review button).
  final int reviewCount;

  /// XP earned in the finished game (end-of-game panel only).
  final GameXp? xpGain;

  /// Tournament match: one "continue" button back to the bracket.
  final bool tournament;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final result = state.lastResult;
    if (result == null) return const SizedBox.shrink();
    final a = result.teams[0];
    final b = result.teams[1];
    final over = state.phase == GamePhase.gameOver;
    final teamGame = state.numPlayers == 4;
    final weWon = state.winner == 0;
    final rules = state.rules;

    final String title;
    if (!over) {
      title = s.roundOver(state.round);
    } else if (teamGame) {
      title = weWon ? s.teamWon : s.teamLost;
    } else {
      title = weWon ? s.youWon : s.youLost;
    }

    // One row per scoring item: (icon, name, our points, their points,
    // our extra text, their extra text).
    final rows = <_ScoreRow>[
      _ScoreRow(
        const _RowBadge(icon: Icons.layers_rounded),
        s.mostCards,
        a.mostCards ? PastraRules.mostCardsBonus : 0,
        b.mostCards ? PastraRules.mostCardsBonus : 0,
        '${a.cards}',
        '${b.cards}',
      ),
      _ScoreRow(const _RowBadge(text: 'A'), s.aces, a.aces, b.aces),
      _ScoreRow(const _RowBadge(text: 'J'), s.jacks, a.jacks, b.jacks),
      _ScoreRow(
        const _RowBadge(text: '2', suit: Cards.clubs),
        s.twoOfClubs,
        a.twoOfClubs ? rules.twoOfClubsBonus : 0,
        b.twoOfClubs ? rules.twoOfClubsBonus : 0,
      ),
      _ScoreRow(
        const _RowBadge(text: '10', suit: Cards.diamonds),
        s.tenOfDiamonds,
        a.tenOfDiamonds ? rules.tenOfDiamondsBonus : 0,
        b.tenOfDiamonds ? rules.tenOfDiamondsBonus : 0,
      ),
      _ScoreRow(
        const _RowBadge(text: 'Π', gold: true),
        s.pastraRow,
        a.pastraPoints,
        b.pastraPoints,
        a.pastras > 0 ? '×${a.pastras}' : null,
        b.pastras > 0 ? '×${b.pastras}' : null,
      ),
    ];

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (over)
          _Trophy(won: weWon)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: PastraColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.round(state.round),
              style: const TextStyle(color: PastraColors.gold, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        const SizedBox(height: 4),
        if (over && weWon)
          FittedBox(fit: BoxFit.scaleDown, child: GoldText(title, size: 26, letterSpacing: 0.5))
        else
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
          ),
      ],
    );

    final sheet = _ScoreSheet(rows: rows, names: teamNames, totals: <int>[a.total, b.total], totalLabel: s.roundTotal);

    final scoreboard = _GameScore(
      label: s.gameScore,
      names: teamNames,
      scores: state.scores,
      target: rules.targetScore,
      targetText: s.target(rules.targetScore),
      winner: over ? state.winner : -1,
    );

    final Widget buttons;
    if (!over) {
      buttons = SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onNextRound,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(s.nextRound),
        ),
      );
    } else if (tournament) {
      buttons = SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(onPressed: onMainMenu, child: Text(s.continueGame)),
      );
    } else {
      buttons = Row(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onMainMenu,
                icon: const Icon(Icons.home_rounded, size: 20),
                label: Text(s.mainMenu, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onPlayAgain,
                icon: const Icon(Icons.replay_rounded, size: 20),
                label: Text(playAgainLabel ?? s.playAgain, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ],
      );
    }

    final review = over && onReview != null
        ? TextButton.icon(
            onPressed: onReview,
            icon: Icon(
              reviewCount == 0 ? Icons.verified_rounded : Icons.manage_search_rounded,
              color: PastraColors.gold,
              size: 20,
            ),
            label: Text(
              reviewCount == 0
                  ? SocialStrings(s.lang).analysis
                  : '${SocialStrings(s.lang).analysis} · ${SocialStrings(s.lang).missedCount(reviewCount)}',
              style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800),
            ),
          )
        : null;

    final side = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        scoreboard,
        if (over && xpGain != null) ...<Widget>[
          const SizedBox(height: 10),
          _XpLine(gain: xpGain!),
        ],
        const SizedBox(height: 14),
        buttons,
        if (review != null) ...<Widget>[const SizedBox(height: 4), review],
      ],
    );

    // The sheet fades and grows in when the round ends.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, box) {
            // Sideways: the score sheet on the left, the game score and the
            // buttons on the right.
            final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 560;
            final content = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(flex: 11, child: sheet),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[header, const SizedBox(height: 8), side],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[header, const SizedBox(height: 10), sheet, const SizedBox(height: 14), side],
                  );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 820 : 460),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xF51A4433), Color(0xF50A1F17)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: PastraColors.gold.withValues(alpha: over && weWon ? 0.9 : 0.5), width: 1.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 30, offset: const Offset(0, 10)),
                      if (over && weWon) BoxShadow(color: PastraColors.gold.withValues(alpha: 0.25), blurRadius: 40),
                    ],
                  ),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScoreRow {
  const _ScoreRow(this.badge, this.label, this.ours, this.theirs, [this.oursNote, this.theirsNote]);

  final Widget badge;
  final String label;
  final int ours;
  final int theirs;
  final String? oursNote;
  final String? theirsNote;
}

/// A small square in front of a score row: a letter, a card or an icon.
class _RowBadge extends StatelessWidget {
  const _RowBadge({this.text, this.suit, this.icon, this.gold = false});

  final String? text;
  final int? suit;
  final IconData? icon;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final red = suit == Cards.diamonds || suit == Cards.hearts;
    final ink = gold ? Colors.black : (red ? PastraColors.cardRed : PastraColors.cardBlack);
    return Container(
      width: 22,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gold ? PastraColors.gold : (icon != null ? Colors.white12 : PastraColors.cream),
        borderRadius: BorderRadius.circular(5),
      ),
      child: icon != null
          ? Icon(icon, size: 18, color: Colors.white70)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(text ?? '', style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w900, height: 1)),
                if (suit != null) SuitIcon(suit: suit!, size: 10, color: ink),
              ],
            ),
    );
  }
}

/// The round's points: one row per item, the better side in gold.
class _ScoreSheet extends StatelessWidget {
  const _ScoreSheet({required this.rows, required this.names, required this.totals, required this.totalLabel});

  final List<_ScoreRow> rows;
  final List<String> names;
  final List<int> totals;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    Widget value(int v, int other, String? note) {
      final best = v > other;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            v == 0 ? '–' : '+$v',
            style: TextStyle(
              color: best ? PastraColors.gold : (v == 0 ? Colors.white38 : Colors.white),
              fontSize: 16,
              fontWeight: best ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          if (note != null) ...<Widget>[
            const SizedBox(width: 4),
            Text(note, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ],
      );
    }

    Widget name(String n) => Text(
          n,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w900),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(flex: 3, child: name(names[0])),
              Expanded(flex: 3, child: name(names[1])),
            ],
          ),
          const SizedBox(height: 2),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: <Widget>[
                        r.badge,
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            r.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(flex: 3, child: value(r.ours, r.theirs, r.oursNote)),
                  Expanded(flex: 3, child: value(r.theirs, r.ours, r.theirsNote)),
                ],
              ),
            ),
          const Divider(color: Colors.white24, height: 10),
          Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Text(totalLabel, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              for (var i = 0; i < 2; i++)
                Expanded(
                  flex: 3,
                  child: Text(
                    '${totals[i]}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: totals[i] >= totals[1 - i] ? PastraColors.gold : Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The game score with a bar towards the target for each side.
class _GameScore extends StatelessWidget {
  const _GameScore({
    required this.label,
    required this.names,
    required this.scores,
    required this.target,
    required this.targetText,
    required this.winner,
  });

  final String label;
  final List<String> names;
  final List<int> scores;
  final int target;
  final String targetText;

  /// Side that won the game (-1 while playing).
  final int winner;

  @override
  Widget build(BuildContext context) {
    Widget side(int i) {
      final ours = i == 0;
      final color = ours ? PastraColors.gold : const Color(0xFF9FB4C7);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 64,
              child: Text(
                names[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: (scores[i] / max(1, target)).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 10,
                    color: color,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (winner == i) const Icon(Icons.emoji_events_rounded, color: PastraColors.gold, size: 14),
                  Flexible(
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: scores[i]),
                      duration: const Duration(milliseconds: 900),
                      builder: (context, v, _) => Text(
                        '$v',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: ours ? PastraColors.gold : Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.flag_rounded, color: Colors.white54, size: 14),
              const SizedBox(width: 3),
              Text(targetText, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          side(0),
          side(1),
        ],
      ),
    );
  }
}

/// A trophy that pops in (won) or a quiet card fan (lost).
class _Trophy extends StatelessWidget {
  const _Trophy({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: 0.4 + 0.6 * v, child: child),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: won
              ? const RadialGradient(colors: <Color>[Color(0xFFFFE08A), Color(0xFFD9A21E)])
              : null,
          color: won ? null : Colors.white12,
          boxShadow: won ? <BoxShadow>[BoxShadow(color: PastraColors.gold.withValues(alpha: 0.5), blurRadius: 18)] : null,
        ),
        child: Icon(
          won ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded,
          color: won ? Colors.black : Colors.white70,
          size: 24,
        ),
      ),
    );
  }
}

/// "+120 XP", and a level-up message when the game gave a new level.
class _XpLine extends StatelessWidget {
  const _XpLine({required this.gain});

  final GameXp gain;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '+${gain.amount} XP',
          style: const TextStyle(color: PastraColors.gold, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (gain.chips != 0 || gain.diamonds != 0) ...<Widget>[
          const SizedBox(height: 4),
          Wrap(
            spacing: 14,
            alignment: WrapAlignment.center,
            children: <Widget>[
              if (gain.chips != 0)
                Amount(
                  chips: gain.chips,
                  size: 18,
                  sign: true,
                  color: gain.chips > 0 ? Colors.white : const Color(0xFFFFB4A9),
                ),
              if (gain.diamonds != 0) Amount(diamonds: gain.diamonds, size: 18, sign: true, color: diamondColor),
            ],
          ),
        ],
        if (gain.leveledUp) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: PastraColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PastraColors.gold),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${s.levelUp}  ${s.levelN(gain.levelAfter)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                if (gain.newColors)
                  Text(
                    s.newColors,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
