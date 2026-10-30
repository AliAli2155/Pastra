import 'package:flutter/material.dart';

import '../../engine/game_state.dart';
import '../../engine/rules.dart';
import '../../game/progression.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
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
  });

  final GameState state;
  final List<String> teamNames;
  final VoidCallback onNextRound;
  final VoidCallback onMainMenu;
  final VoidCallback onPlayAgain;

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

    String title;
    if (!over) {
      title = s.roundOver(state.round);
    } else if (teamGame) {
      title = weWon ? s.teamWon : s.teamLost;
    } else {
      title = weWon ? s.youWon : s.youLost;
    }

    String pts(int v) => v == 0 ? '–' : '$v';

    final rules = state.rules;
    String two(bool has) => has ? '${rules.twoOfClubsBonus}' : '–';
    String ten(bool has) => has ? '${rules.tenOfDiamondsBonus}' : '–';
    final rows = <List<String>>[
      [
        s.mostCards,
        '${a.mostCards ? PastraRules.mostCardsBonus : 0}  (${a.cards})',
        '${b.mostCards ? PastraRules.mostCardsBonus : 0}  (${b.cards})',
      ],
      [s.aces, pts(a.aces), pts(b.aces)],
      [s.jacks, pts(a.jacks), pts(b.jacks)],
      [s.twoOfClubs, two(a.twoOfClubs), two(b.twoOfClubs)],
      [s.tenOfDiamonds, ten(a.tenOfDiamonds), ten(b.tenOfDiamonds)],
      [
        s.pastraRow,
        a.pastras == 0 ? '–' : '${a.pastraPoints}  (${a.pastras})',
        b.pastras == 0 ? '–' : '${b.pastraPoints}  (${b.pastras})',
      ],
    ];

    const cellStyle = TextStyle(fontSize: 15, color: Colors.white);
    const headStyle = TextStyle(fontSize: 14, color: PastraColors.gold, fontWeight: FontWeight.w700);
    const boldStyle = TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800);

    Widget cell(String text, TextStyle style, {TextAlign align = TextAlign.center}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: Text(text, style: style, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis),
        );

    TableRow row(List<String> r, TextStyle style) => TableRow(children: <Widget>[
          cell(r[0], style, align: TextAlign.start),
          cell(r[1], style),
          cell(r[2], style),
        ]);

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (over)
          Icon(
            weWon ? Icons.emoji_events : Icons.sentiment_neutral,
            color: PastraColors.gold,
            size: 40,
          ),
        if (over && weWon)
          FittedBox(fit: BoxFit.scaleDown, child: GoldText(title, size: 30, letterSpacing: 0.5))
        else
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
      ],
    );
    final table = Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(2.1),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        row(<String>['', teamNames[0], teamNames[1]], headStyle),
        for (final r in rows) row(r, cellStyle),
        row(<String>[s.roundTotal, '${a.total}', '${b.total}'], boldStyle),
      ],
    );
    final score = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(s.gameScore, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          '${state.scores[0]}  :  ${state.scores[1]}',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: PastraColors.gold),
        ),
        Text(
          s.target(state.rules.targetScore),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        if (over && xpGain != null) ...<Widget>[
          const SizedBox(height: 12),
          _XpLine(gain: xpGain!),
        ],
        const SizedBox(height: 16),
        if (!over)
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onNextRound, child: Text(s.nextRound)),
          )
        else if (tournament)
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onMainMenu, child: Text(s.continueGame)),
          )
        else
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onMainMenu,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(s.mainMenu),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: onPlayAgain, child: Text(s.playAgain))),
            ],
          ),
      ],
    );

    // The sheet fades and grows in when the round ends.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, box) {
          // Landscape: the score sheet on the left, totals and buttons on the right.
          final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 560;
          final content = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[header, const SizedBox(height: 8), table],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: score),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 12),
                    table,
                    const Divider(color: Colors.white24, height: 22),
                    score,
                  ],
                );
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 760 : 440),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xF2163A2B), Color(0xF20B2219)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: PastraColors.gold.withValues(alpha: 0.55), width: 1.4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
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
