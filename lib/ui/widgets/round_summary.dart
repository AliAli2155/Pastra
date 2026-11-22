import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/game_state.dart';
import '../../engine/rules.dart';
import '../../game/avatar_pic.dart';
import '../../game/progression.dart';
import '../../game/sound.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../ege/widgets.dart';
import '../fx/fx.dart';
import '../theme.dart';
import 'avatar.dart';
import 'suit_icon.dart';
import 'wallet_bar.dart';

/// One player at an online table, as the "ready" row shows them.
class ReadyPlayer {
  const ReadyPlayer({required this.name, this.pic = AvatarPic.letter, this.frame = AvatarFrame.none});

  final String name;
  final AvatarPic pic;
  final AvatarFrame frame;
}

/// Online, after a round: the next one starts when everybody is ready.
class RoundReady {
  const RoundReady({required this.players, required this.ready, required this.onReady, this.deadline});

  /// Everybody at the table, the local player first.
  final List<ReadyPlayer> players;

  /// Indexes into [players] of those who are ready.
  final Set<int> ready;

  /// The local player says they are ready.
  final VoidCallback onReady;

  /// When the next round starts anyway.
  final DateTime? deadline;

  bool get iAmReady => ready.contains(0);
}

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
    this.ready,
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

  /// Online, after a round: who is ready for the next one (instead of the
  /// "next round" button).
  final RoundReady? ready;

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

    final titleText = over && weWon
        ? FittedBox(fit: BoxFit.scaleDown, child: GoldText(title, size: 26, letterSpacing: 0.5))
        : Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: PastraColors.text),
          );
    // Game over: the trophy next to the title (saves height on a phone).
    final titleRow = over
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Trophy(won: weWon),
              const SizedBox(width: 10),
              Flexible(child: titleText),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: PastraColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.round(state.round),
                  style: const TextStyle(color: PastraColors.gold, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 4),
              titleText,
            ],
          );
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        titleRow,
      ],
    );

    final sheet = _ScoreSheet(rows: rows, names: teamNames, totals: <int>[a.total, b.total], totalLabel: s.roundTotal);

    final scoreboard = _GameScore(
      label: s.gameScore,
      names: teamNames,
      scores: state.scores,
      before: <int>[for (var i = 0; i < 2; i++) max(0, state.scores[i] - result.teams[i].total)],
      target: rules.targetScore,
      targetText: s.target(rules.targetScore),
      winner: over ? state.winner : -1,
    );

    final Widget buttons;
    if (!over && ready != null) {
      buttons = _ReadyBlock(ready: ready!);
    } else if (!over) {
      buttons = BevelButton(
        onPressed: onNextRound,
        height: 46,
        fontSize: 17,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.arrow_forward_rounded, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(s.nextRound, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
    } else if (tournament) {
      buttons = BevelButton(
        onPressed: onMainMenu,
        height: 46,
        fontSize: 17,
        child: Text(s.continueGame, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    } else {
      buttons = Row(
        children: <Widget>[
          Expanded(
            child: BevelButton(
              gold: false,
              height: 44,
              fontSize: 15,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onMainMenu,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.home_rounded, size: 20),
                  const SizedBox(width: 6),
                  Flexible(child: Text(s.mainMenu, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BevelButton(
              height: 44,
              fontSize: 15,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onPlayAgain,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.replay_rounded, size: 20),
                  const SizedBox(width: 6),
                  Flexible(child: Text(playAgainLabel ?? s.playAgain, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
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
                  : '${SocialStrings(s.lang).analysis} · ${(reviewCount == 1 ? SocialStrings(s.lang).missedOne : SocialStrings(s.lang).missedCount(reviewCount))}',
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
    final panel = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: Container(
        color: const Color(0xBF0A0B0D),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, box) {
            // Sideways: the score sheet on the left, the game score and the
            // buttons on the right.
            final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 560;
            // Big screens: the whole panel grows (text and width) up to 1.6x.
            // A phone held sideways grows a little too, as far as it still fits
            // (the game-over panel is taller than the round panel).
            final zoom = wide
                ? min(box.maxWidth / 700, box.maxHeight / (over ? 350 : (ready != null ? 370 : 310))).clamp(1.0, 1.6).toDouble()
                : (box.maxWidth / 400).clamp(1.0, 1.4).toDouble();
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
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(zoom)),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: (wide ? 820 : 460) * zoom),
                  // A stone tablet; golden while we celebrate a win.
                  child: Tablet(
                    radius: 26,
                    glow: over && weWon,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: content,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    // Then the points are counted row by row.
    return _ScoreCount(
      rows: rows,
      countKey: '${state.round}:${a.total}:${b.total}:${state.scores.join(',')}',
      child: panel,
    );
  }
}

/// When each part of the count happens, in milliseconds from its start:
/// the rows come in one after the other, each row's points go into the round
/// total as it lands, then the game score bars move on (about 2.4 s).
class _CountTiming {
  const _CountTiming(this.rows);

  final int rows;

  static const int lead = 250;
  static const int step = 220;
  static const int rowIn = 220;
  static const int add = 300;
  static const int bars = 550;

  double inStart(int i) => (lead + step * i).toDouble();
  double addStart(int i) => inStart(i) + rowIn;
  double get barStart => addStart(rows - 1) + add;
  int get totalMs => (barStart + bars).round();

  static double _part(double ms, double from, int length) => ((ms - from) / length).clamp(0.0, 1.0).toDouble();

  /// How far row [i] has come in (0 → 1).
  double entered(double ms, int i) => Curves.easeOutCubic.transform(_part(ms, inStart(i), rowIn));

  /// How much of row [i]'s points are in the total (0 → 1).
  double added(double ms, int i) => Curves.easeOutCubic.transform(_part(ms, addStart(i), add));

  /// How far the game score bars have moved on (0 → 1).
  double moved(double ms) => Curves.easeOutCubic.transform(_part(ms, barStart, bars));
}

/// The running count, for the score sheet and the game score under it.
class _CountScope extends InheritedWidget {
  const _CountScope({required this.count, required this.timing, required super.child});

  /// 0 → 1 over [_CountTiming.totalMs].
  final Animation<double> count;
  final _CountTiming timing;

  static _CountScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_CountScope>();

  @override
  bool updateShouldNotify(_CountScope old) => old.count != count || old.timing.rows != timing.rows;
}

/// Runs the count once, with a soft card sound for every row that brought
/// points. A tap skips to the end; with low graphics (or animations switched
/// off) everything is there at once. One animation that stops by itself.
class _ScoreCount extends StatefulWidget {
  const _ScoreCount({required this.rows, required this.countKey, required this.child});

  final List<_ScoreRow> rows;

  /// Same key, same count: an online guest gets the same result again with
  /// every view the host sends, and it is not counted again.
  final String countKey;

  final Widget child;

  @override
  State<_ScoreCount> createState() => _ScoreCountState();
}

class _ScoreCountState extends State<_ScoreCount> with SingleTickerProviderStateMixin {
  late _CountTiming _timing = _CountTiming(widget.rows.length);
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _timing.totalMs),
  )..addListener(_onTick);

  /// Rows whose points went into the total (and made their sound).
  int _counted = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_ScoreCount old) {
    super.didUpdateWidget(old);
    if (old.countKey != widget.countKey) {
      _timing = _CountTiming(widget.rows.length);
      _count.duration = Duration(milliseconds: _timing.totalMs);
      _start();
    }
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  void _start() {
    final still = Fx.low.value || WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (still || widget.rows.isEmpty) {
      _skip();
    } else {
      _counted = 0;
      unawaited(_count.forward(from: 0));
    }
  }

  /// Straight to the end, without the sounds still to come.
  void _skip() {
    _counted = widget.rows.length;
    _count.value = 1;
  }

  void _onTick() {
    final ms = _count.value * _timing.totalMs;
    var points = false;
    while (_counted < widget.rows.length && ms >= _timing.addStart(_counted)) {
      final r = widget.rows[_counted++];
      if (r.ours + r.theirs > 0) points = true;
    }
    // One sound per frame, even if a slow frame landed two rows.
    if (points) SoundFx.instance.play(Sfx.deal, volume: 0.45);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _skip,
      child: _CountScope(count: _count, timing: _timing, child: widget.child),
    );
  }
}

/// Online, after a round: everybody's picture, lit up in gold once they are
/// ready and dim until then, the "I'm ready" button and how long the table
/// still waits. The countdown is a slow timer (once a second) that stops.
class _ReadyBlock extends StatefulWidget {
  const _ReadyBlock({required this.ready});

  final RoundReady ready;

  @override
  State<_ReadyBlock> createState() => _ReadyBlockState();
}

class _ReadyBlockState extends State<_ReadyBlock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft == 0) _tick?.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int? get _secondsLeft {
    final deadline = widget.ready.deadline;
    if (deadline == null) return null;
    final ms = deadline.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final t = OnlineStrings(s.lang);
    final r = widget.ready;
    final f = MediaQuery.textScalerOf(context).scale(1);
    final left = _secondsLeft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < r.players.length; i++)
              Flexible(child: ReadyAvatar(player: r.players[i], ready: r.ready.contains(i), size: 34 * f)),
          ],
        ),
        const SizedBox(height: 8),
        BevelButton(
          onPressed: r.iAmReady ? null : r.onReady,
          gold: !r.iAmReady,
          height: 44,
          fontSize: 16,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(r.iAmReady ? Icons.hourglass_top_rounded : Icons.check_rounded, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(r.iAmReady ? t.waitingOthers : t.readyUp, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        if (left != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t.nextIn(left),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: PastraColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// A player's picture in the "ready" row: a gold, softly glowing ring once
/// they are ready; dim with a faint ring until then.
class ReadyAvatar extends StatelessWidget {
  const ReadyAvatar({super.key, required this.player, required this.ready, this.size = 34});

  final ReadyPlayer player;
  final bool ready;
  final double size;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 280);
    return Semantics(
      label: player.name,
      selected: ready,
      child: SizedBox(
        width: size * 1.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              padding: EdgeInsets.all(size * 0.08),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ready ? PastraColors.gold : Colors.white.withValues(alpha: 0.12),
                boxShadow: ready
                    ? <BoxShadow>[
                        BoxShadow(color: PastraColors.gold.withValues(alpha: 0.6), blurRadius: size * 0.4, spreadRadius: 1),
                      ]
                    : const <BoxShadow>[],
              ),
              child: AnimatedOpacity(
                duration: duration,
                opacity: ready ? 1 : 0.4,
                child: PlayerAvatar(name: player.name, pic: player.pic, frame: player.frame, size: size),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ready ? PastraColors.gold : PastraColors.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
    final f = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      width: 22 * f,
      height: 26 * f,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gold ? PastraColors.gold : (icon != null ? Colors.white12 : PastraColors.cream),
        borderRadius: BorderRadius.circular(5),
      ),
      child: icon != null
          ? Icon(icon, size: 18, color: PastraColors.text2)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(text ?? '', maxLines: 1, softWrap: false, style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w800, height: 1)),
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
    // [pop]: 0 → 1 → 0 while the value goes into the total.
    Widget value(int v, int other, String? note, double pop) {
      final best = v > other;
      final text = Text(
        v == 0 ? '–' : '+$v',
        style: TextStyle(
          color: best ? PastraColors.gold : (v == 0 ? PastraColors.muted : PastraColors.text),
          fontSize: 16,
          fontWeight: best ? FontWeight.w800 : FontWeight.w700,
        ),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (v > 0 && pop > 0) Transform.scale(scale: 1 + 0.25 * pop, child: text) else text,
          if (note != null) ...<Widget>[
            const SizedBox(width: 4),
            Text(note, style: const TextStyle(color: PastraColors.muted, fontSize: 11)),
          ],
        ],
      );
    }

    Widget name(String n, bool ours) => Text(
          n,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ours ? PastraColors.gold : PastraColors.foam,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        );

    // The row lights up softly while its points are counted.
    Widget line(_ScoreRow r, double pop) => Container(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          decoration: BoxDecoration(
            color: r.ours + r.theirs > 0 && pop > 0 ? PastraColors.gold.withValues(alpha: 0.12 * pop) : null,
            borderRadius: BorderRadius.circular(6),
          ),
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
                        style: const TextStyle(color: PastraColors.text2, fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 3, child: value(r.ours, r.theirs, r.oursNote, pop)),
              Expanded(flex: 3, child: value(r.theirs, r.ours, r.theirsNote, pop)),
            ],
          ),
        );

    final header = Row(
      children: <Widget>[
        const Expanded(flex: 5, child: SizedBox()),
        Expanded(flex: 3, child: name(names[0], true)),
        Expanded(flex: 3, child: name(names[1], false)),
      ],
    );

    // [ms]: how far the count is (see [_CountTiming]).
    Widget sheet(_CountTiming timing, double ms) {
      // Row [i] comes in, then lights up while its points are counted.
      Widget rowAt(int i) {
        final a = timing.added(ms, i);
        final row = line(rows[i], a <= 0 || a >= 1 ? 0 : sin(pi * a));
        final e = timing.entered(ms, i);
        if (e >= 1) return row;
        return Opacity(
          opacity: e,
          child: Transform.translate(offset: Offset(0, 14 * (1 - e)), child: row),
        );
      }

      // The round total grows as each row lands; at the end it is the real one.
      final shown = <int>[...totals];
      if (ms < timing.barStart) {
        for (var side = 0; side < 2; side++) {
          var sum = 0.0;
          for (var i = 0; i < rows.length; i++) {
            sum += (side == 0 ? rows[i].ours : rows[i].theirs) * timing.added(ms, i);
          }
          shown[side] = sum.round();
        }
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            header,
            const SizedBox(height: 2),
            // The rows come in one after the other, like dealt cards (a flat
            // slide: nothing under a perspective).
            for (var i = 0; i < rows.length; i++) rowAt(i),
            const Divider(color: Color(0x4DF2C14E), height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: Text(totalLabel, style: const TextStyle(color: PastraColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                for (var i = 0; i < 2; i++)
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${shown[i]}',
                      key: ValueKey<String>('roundTotal$i'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: shown[i] >= shown[1 - i] ? PastraColors.gold : PastraColors.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final scope = _CountScope.maybeOf(context);
    if (scope == null) {
      final timing = _CountTiming(rows.length);
      return sheet(timing, timing.totalMs.toDouble());
    }
    return AnimatedBuilder(
      animation: scope.count,
      builder: (context, _) => sheet(scope.timing, scope.count.value * scope.timing.totalMs),
    );
  }
}

/// The game score with a bar towards the target for each side.
class _GameScore extends StatelessWidget {
  const _GameScore({
    required this.label,
    required this.names,
    required this.scores,
    required this.before,
    required this.target,
    required this.targetText,
    required this.winner,
  });

  final String label;
  final List<String> names;
  final List<int> scores;

  /// The game score before this round: the bars move on from there.
  final List<int> before;
  final int target;
  final String targetText;

  /// Side that won the game (-1 while playing).
  final int winner;

  @override
  Widget build(BuildContext context) {
    // Fixed widths grow with the text size (big screens zoom the panel).
    final f = MediaQuery.textScalerOf(context).scale(1);
    final scope = _CountScope.maybeOf(context);
    // [moved]: 0 (the score before the round) → 1 (the score now).
    Widget side(int i, double moved) {
      final ours = i == 0;
      final color = ours ? PastraColors.gold : PastraColors.teal;
      final shown = before[i] + (scores[i] - before[i]) * moved;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 64 * f,
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
                child: LinearProgressIndicator(
                  value: (shown / max(1, target)).clamp(0.0, 1.0),
                  minHeight: 10,
                  color: color,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56 * f,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (winner == i) const Icon(Icons.emoji_events_rounded, color: PastraColors.gold, size: 14),
                  Flexible(
                    child: Text(
                      '${shown.round()}',
                      key: ValueKey<String>('gameScore$i'),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: ours ? PastraColors.gold : PastraColors.text, fontSize: 18, fontWeight: FontWeight.w800),
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: const TextStyle(color: PastraColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.flag_rounded, color: PastraColors.muted, size: 14),
              const SizedBox(width: 3),
              Text(targetText, style: const TextStyle(color: PastraColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          if (scope == null) ...<Widget>[side(0, 1), side(1, 1)] else
            AnimatedBuilder(
              animation: scope.count,
              builder: (context, _) {
                final moved = scope.timing.moved(scope.count.value * scope.timing.totalMs);
                return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[side(0, moved), side(1, moved)]);
              },
            ),
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
          color: won ? Colors.black : PastraColors.text2,
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
    Widget chip({required Widget child, bool gold = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: gold ? PastraColors.gold.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold ? PastraColors.gold : Colors.white12),
          ),
          child: child,
        );
    // One line of small chips: XP, chips / diamonds, a new level.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        chip(
          child: Text(
            '+${gain.amount} XP',
            style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (gain.chips != 0)
          chip(
            child: Amount(
              chips: gain.chips,
              size: 15,
              sign: true,
              color: gain.chips > 0 ? Colors.white : const Color(0xFFFFB4A9),
            ),
          ),
        if (gain.diamonds != 0) chip(child: Amount(diamonds: gain.diamonds, size: 15, sign: true, color: diamondColor)),
        if (gain.leveledUp)
          Tooltip(
            message: gain.newColors ? s.newColors : '',
            child: chip(
              gold: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.arrow_circle_up_rounded, color: PastraColors.gold, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${s.levelUp} ${s.levelN(gain.levelAfter)}',
                    style: const TextStyle(color: PastraColors.text, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
