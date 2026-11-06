import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/game_state.dart';
import '../../game/app_settings.dart';
import '../../game/progression.dart';
import '../../l10n/strings.dart';
import '../premium/premium.dart';
import '../theme.dart';
import 'round_summary.dart';
import 'wallet_bar.dart';

/// The end of a game: first a big moment (the trophy, the final score, the
/// XP bar filling up and a new level), then, by itself (or at once on
/// request), the full score sheet of the last round ([RoundSummaryPanel]).
///
/// Everything here moves once when it appears and then stands still.
class GameOverView extends StatefulWidget {
  const GameOverView({
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
  final VoidCallback? onPlayAgain;
  final GameXp? xpGain;
  final bool tournament;
  final String? playAgainLabel;
  final VoidCallback? onReview;
  final int reviewCount;

  @override
  State<GameOverView> createState() => _GameOverViewState();
}

class _GameOverViewState extends State<GameOverView> {
  /// How long the big moment stays before the score sheet comes.
  static const Duration showSheetAfter = Duration(milliseconds: 4000);

  bool _sheet = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(showSheetAfter, _showSheet);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showSheet() {
    _timer?.cancel();
    if (mounted && !_sheet) setState(() => _sheet = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _sheet ? KeyedSubtree(key: const ValueKey<String>('sheet'), child: _sheetPanel()) : _moment(context),
    );
  }

  Widget _sheetPanel() {
    return RoundSummaryPanel(
      state: widget.state,
      teamNames: widget.teamNames,
      onNextRound: widget.onNextRound,
      onMainMenu: widget.onMainMenu,
      onPlayAgain: widget.onPlayAgain,
      playAgainLabel: widget.playAgainLabel,
      xpGain: widget.xpGain,
      tournament: widget.tournament,
      onReview: widget.onReview,
      reviewCount: widget.reviewCount,
    );
  }

  Widget _moment(BuildContext context) {
    final s = Strings.of(context);
    final state = widget.state;
    final won = state.winner == 0;
    final team = state.numPlayers == 4;
    final title = team ? (won ? s.teamWon : s.teamLost) : (won ? s.youWon : s.youLost);
    final gain = widget.xpGain;

    final buttons = widget.tournament
        ? GoldButton(label: s.continueGame, icon: Icons.arrow_forward_rounded, onPressed: widget.onMainMenu)
        : Row(
            children: <Widget>[
              Expanded(
                child: GlassButton(
                  label: s.mainMenu,
                  icon: Icons.home_rounded,
                  onPressed: widget.onMainMenu,
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GoldButton(
                  label: widget.playAgainLabel ?? s.playAgain,
                  icon: Icons.replay_rounded,
                  onPressed: widget.onPlayAgain,
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: _Trophy(won: won)),
        const SizedBox(height: 10),
        _PopIn(
          delay: 0.15,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: PremiumText.title.copyWith(fontSize: 34, color: won ? PastraColors.goldLight : PastraColors.text),
          ),
        ),
        const SizedBox(height: 8),
        _PopIn(delay: 0.3, child: _FinalScore(state: state, names: widget.teamNames)),
        if (gain != null) ...<Widget>[
          const SizedBox(height: 18),
          _PopIn(delay: 0.45, child: _XpBar(gain: gain)),
        ],
        const SizedBox(height: 20),
        _PopIn(delay: 0.6, child: buttons),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: _showSheet,
            icon: const Icon(Icons.table_rows_rounded, size: 18),
            label: Text(s.gameScore),
          ),
        ),
      ],
    );

    return ColoredBox(
      key: const ValueKey<String>('moment'),
      color: const Color(0xD90A0B0D),
      child: Stack(
        children: <Widget>[
          // A soft gold (or grey) light behind the trophy.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.45),
                    radius: 0.75,
                    colors: <Color>[
                      (won ? PastraColors.gold : Colors.white).withValues(alpha: won ? 0.22 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // A low screen (a phone held sideways): everything is scaled down
          // to fit, so the buttons never end up below the edge.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: LayoutBuilder(
              builder: (context, box) => Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: min(460.0, box.maxWidth), child: content),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades in and rises a little, [delay] (0..1) into a short entrance.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.delay, required this.child});

  final double delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      builder: (context, t, child) {
        final p = Curves.easeOutCubic.transform(((t - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble());
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 16 * (1 - p)), child: child),
        );
      },
      child: child,
    );
  }
}

/// A big trophy in a gold medallion (a grey one after a defeat) that grows
/// in with a little bounce.
class _Trophy extends StatelessWidget {
  const _Trophy({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: 0.3 + 0.7 * v, child: child),
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: won ? goldGradient : null,
          color: won ? null : PastraColors.raised,
          border: Border.all(color: won ? PastraColors.goldLight : Colors.white24, width: 3),
          boxShadow: <BoxShadow>[
            if (won) BoxShadow(color: PastraColors.gold.withValues(alpha: 0.45), blurRadius: 40),
          ],
        ),
        child: Icon(
          won ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded,
          size: 62,
          color: won ? PastraColors.goldInk : PastraColors.text2,
        ),
      ),
    );
  }
}

/// "You 151 – 98 Eleni".
class _FinalScore extends StatelessWidget {
  const _FinalScore({required this.state, required this.names});

  final GameState state;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    Widget side(int i, TextAlign align) => Expanded(
          child: Text(
            names[i],
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: PastraColors.text2, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        );
    Widget score(int i) => TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: state.scores[i]),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            '$v',
            style: TextStyle(
              color: i == state.winner ? PastraColors.gold : PastraColors.text,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: glassDecoration(radius: 16),
      child: Row(
        children: <Widget>[
          side(0, TextAlign.right),
          const SizedBox(width: 12),
          score(0),
          Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 14), color: Colors.white24),
          score(1),
          const SizedBox(width: 12),
          side(1, TextAlign.left),
        ],
      ),
    );
  }
}

/// The level, the bar towards the next one filling up with this game's XP
/// (over the top and again from the start on a new level), and the chips
/// or diamonds won.
class _XpBar extends StatelessWidget {
  const _XpBar({required this.gain});

  final GameXp gain;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final xp = SettingsScope.of(context).xp;
    double fractionAt(int x) {
      final level = Progression.levelOf(x);
      if (level >= Progression.maxLevel) return 1;
      final p = Progression.progress(x);
      return p.needed == 0 ? 1 : (p.into / p.needed).clamp(0.0, 1.0).toDouble();
    }

    final before = fractionAt(max(0, xp - gain.amount));
    final after = fractionAt(xp);
    final up = gain.leveledUp;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        // A new level: up to the top first, then again from the start.
        final crossed = up && t >= 0.55;
        final f = !up
            ? before + (after - before) * t
            : (crossed ? after * ((t - 0.55) / 0.45) : before + (1 - before) * (t / 0.55));
        final level = crossed ? gain.levelAfter : gain.levelBefore;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: panelDecoration(radius: 16, highlight: crossed, shadow: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: goldGradient),
                    child: Text(
                      '$level',
                      style: const TextStyle(color: PastraColors.goldInk, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      crossed ? '${s.levelUp} ${s.levelN(level)}' : s.levelN(level),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: crossed ? PastraColors.goldLight : PastraColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '+${(gain.amount * min(1.0, t * 1.4)).round()} XP',
                    style: const TextStyle(color: PastraColors.teal, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 10,
                  child: LinearProgressIndicator(
                    value: f.clamp(0.0, 1.0).toDouble(),
                    backgroundColor: const Color(0xFF2E333B),
                    valueColor: const AlwaysStoppedAnimation<Color>(PastraColors.gold),
                  ),
                ),
              ),
              if (gain.chips != 0 || gain.diamonds != 0) ...<Widget>[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  children: <Widget>[
                    if (gain.chips != 0)
                      Amount(
                        chips: gain.chips,
                        size: 15,
                        sign: true,
                        color: gain.chips > 0 ? PastraColors.text : PastraColors.coral,
                      ),
                    if (gain.diamonds != 0) Amount(diamonds: gain.diamonds, size: 15, sign: true, color: diamondColor),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
