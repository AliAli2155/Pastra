import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/game_state.dart';
import '../../engine/pastra_engine.dart';
import '../../game/achievements.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../table_layout.dart';
import '../theme.dart';
import '../widgets/playing_card.dart';
import '../widgets/round_summary.dart';
import 'rules_screen.dart';

/// The card table. Owns (and disposes) its [GameController].
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;

  /// Hand card being dragged and how far it has moved.
  int? _dragCard;
  Offset _dragDelta = Offset.zero;
  bool _overTable = false;

  /// From the last layout: a dragged card released above it is played.
  double _dropLine = 0;

  void _dragStart(int card) {
    if (!c.isHumanTurn) return;
    setState(() {
      _dragCard = card;
      _dragDelta = Offset.zero;
      _overTable = false;
    });
    c.select(card);
  }

  void _dragUpdate(int card, Offset delta, Rect rect) {
    if (_dragCard != card) return;
    setState(() {
      _dragDelta += delta;
      _overTable = rect.center.dy + _dragDelta.dy < _dropLine;
    });
  }

  void _dragEnd(int card) {
    if (_dragCard != card) return;
    final play = _overTable;
    setState(() {
      _dragCard = null;
      _dragDelta = Offset.zero;
      _overTable = false;
    });
    if (play) {
      c.playCard(card);
    } else {
      c.clearSelection();
    }
  }

  /// Tutorial step being shown (null = no tutorial). The game starts when
  /// the tutorial is finished or skipped.
  int? _tutorialStep;

  List<String> get _tutorialSteps => c.state.rules.isPile
      ? const <String>['hand', 'pile', 'pastra', 'deck', 'timer', 'score']
      : const <String>['hand', 'table', 'pastraSums', 'deckSums', 'timer', 'scoreSums'];

  @override
  void initState() {
    super.initState();
    if (!c.isOnline && !c.settings.tutorialDone && c.state.round == 1 && PastraEngine.isOpeningPosition(c.state)) {
      _tutorialStep = 0;
    } else {
      c.start();
    }
  }

  void _tutorialNext() {
    final step = _tutorialStep;
    if (step == null) return;
    if (step + 1 < _tutorialSteps.length) {
      setState(() => _tutorialStep = step + 1);
    } else {
      _tutorialEnd();
    }
  }

  void _tutorialEnd() {
    setState(() => _tutorialStep = null);
    c.settings.tutorialDone = true;
    c.start();
  }

  /// Area the current tutorial step points at, in table coordinates.
  Rect? _tutorialFocus(String step, TableLayout layout, Size size) {
    Rect? union(Iterable<Rect> rects) {
      Rect? r;
      for (final x in rects) {
        r = r == null ? x : r.expandToInclude(x);
      }
      return r;
    }

    switch (step) {
      case 'hand':
        return union(layout.cards.values.where((p) => p.interactive).map((p) => p.rect))?.inflate(8);
      case 'pile':
      case 'table':
      case 'pastra':
      case 'pastraSums':
        return union(c.state.table.map((card) => layout.cards[card]?.rect).whereType<Rect>())?.inflate(10);
      case 'deck':
      case 'deckSums':
        final d = layout.deckRect;
        return Rect.fromLTRB(d.left, d.top, d.right + d.width * 1.4, d.bottom).inflate(6);
      case 'timer':
        return layout.infoRect.inflate(4);
      default:
        return null;
    }
  }

  Widget _tutorialOverlay(Strings s, TableLayout layout, Size size) {
    final index = _tutorialStep!;
    final step = _tutorialSteps[index];
    return Positioned.fill(
      child: _TutorialOverlay(
        focus: _tutorialFocus(step, layout, size),
        title: s.tutorialTitle(step),
        body: s.tutorialBody(step),
        step: index,
        total: _tutorialSteps.length,
        nextLabel: index + 1 < _tutorialSteps.length ? s.tutorialNext : s.tutorialDone,
        skipLabel: s.tutorialSkip,
        onNext: _tutorialNext,
        onSkip: _tutorialEnd,
      ),
    );
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String _seatName(Strings s, int seat) {
    final info = c.seats[seat];
    if (info.name != null && info.name!.isNotEmpty) return info.name!;
    if (info.isHuman) {
      final name = c.settings.playerName;
      return name.isEmpty ? s.you : name;
    }
    return s.botName(info.botIndex);
  }

  List<String> _teamNames(Strings s) =>
      c.isTeamGame ? <String>[s.us, s.them] : <String>[_seatName(s, 0), _seatName(s, 1)];

  Future<void> _requestLeave() async {
    if (c.state.phase == GamePhase.gameOver) {
      Navigator.of(context).pop();
      return;
    }
    final s = Strings.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.leaveTitle),
        content: Text(s.leaveBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.leave)),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    Navigator.of(context).pop();
  }

  void _playAgain() {
    if (c.isOnline) {
      Navigator.of(context).pop();
      return;
    }
    final settings = c.settings;
    final next = GameController.newGame(
      settings,
      players: c.numPlayers,
      level: c.seats[1].level,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GameScreen(controller: next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _requestLeave();
      },
      child: Scaffold(
        body: Container(
          decoration: feltDecoration,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: c,
              builder: (context, _) {
                final s = Strings.of(context);
                return Column(
                  children: <Widget>[
                    _TopBar(
                      state: c.state,
                      teamNames: _teamNames(s),
                      onBack: _requestLeave,
                      onRules: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => RulesScreen(variant: c.state.rules.variant)),
                      ),
                    ),
                    // Own layer: moving cards never repaint the felt or the top bar.
                    Expanded(child: RepaintBoundary(child: _buildTable(context, s))),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, Strings s) {
    final settings = SettingsScope.of(context);
    final state = c.state;
    return LayoutBuilder(builder: (context, box) {
      final layout = TableLayout.compute(
        size: Size(box.maxWidth, box.maxHeight),
        state: state,
        selected: c.selected,
        pending: c.pending,
        highlighted: c.highlighted,
        tableShown: c.tableShown,
        landing: c.landing,
      );
      _dropLine = layout.dropLine;
      if (_dragCard != null && !c.isHumanTurn) {
        // The turn changed under the finger (should not happen): let go.
        _dragCard = null;
        _dragDelta = Offset.zero;
        _overTable = false;
      }
      int zOf(MapEntry<int, CardPlacement> e) => e.key == _dragCard ? 10000 : e.value.z;
      final entries = layout.cards.entries.toList()..sort((a, b) => zOf(a).compareTo(zOf(b)));
      final duration = Duration(milliseconds: settings.fastAnimations ? 240 : 420);
      final event = c.pastraEvent;

      return _Shake(
        trigger: event?.id ?? 0,
        child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: c.clearSelection),
          ),
          Positioned.fromRect(
            rect: layout.tableRect.inflate(6),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _overTable ? PastraColors.gold.withValues(alpha: 0.08) : null,
                  border: Border.all(
                    color: _overTable ? PastraColors.gold : Colors.white.withValues(alpha: 0.07),
                    width: _overTable ? 2 : 1.5,
                  ),
                ),
              ),
            ),
          ),
          for (final e in entries) _card(e.key, e.value, duration),
          if (state.deck.isNotEmpty)
            _badge(layout.deckRect, '${state.deck.length}', Icons.layers_outlined),
          for (var t = 0; t < 2; t++)
            if (state.piles[t].isNotEmpty)
              _badge(
                layout.pileRects[t],
                state.pastraCards[t].isEmpty
                    ? '${state.piles[t].length}'
                    : '${state.piles[t].length} · Π${state.pastraCards[t].length}',
                Icons.style_outlined,
              ),
          for (final entry in layout.seatRects.entries)
            _seatLabel(s, entry.key, entry.value, layout.seatSides[entry.key] ?? SeatSide.top),
          if (c.lastMove != null && layout.seatRects.containsKey(c.lastMove!.seat)) _lastMoveChip(layout, c.lastMove!),
          if (event != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _PastraBurst(key: ValueKey<int>(event.id), center: layout.playCenter),
              ),
            ),
          Positioned.fromRect(
            rect: layout.infoRect,
            child: IgnorePointer(child: _infoLine(s)),
          ),
          if (event != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: _PastraBanner(
                    key: ValueKey<int>(event.id),
                    title: s.pastraBanner,
                    subtitle: '${_seatName(s, event.seat)}  ${s.plusPoints(event.points)}',
                  ),
                ),
              ),
            ),
          if (_tutorialStep != null) _tutorialOverlay(s, layout, Size(box.maxWidth, box.maxHeight)),
          if (c.achievementToast != null)
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: _AchievementToast(key: ValueKey<String>(c.achievementToast!), id: c.achievementToast!),
                ),
              ),
            ),
          if (c.onlineClosed)
            Positioned.fill(
              child: _OnlineClosedOverlay(
                text: OnlineStrings(c.settings.language).hostLeft,
                button: OnlineStrings(c.settings.language).back,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          if (state.phase != GamePhase.playing && !c.busy && !c.onlineClosed)
            Positioned.fill(
              child: RoundSummaryPanel(
                state: state,
                teamNames: _teamNames(s),
                onNextRound: c.nextRound,
                onMainMenu: () => Navigator.of(context).pop(),
                onPlayAgain: _playAgain,
              ),
            ),
        ],
      ),
      );
    });
  }

  /// The card a bot just played, shown small next to it for a moment
  /// (with a tick when it took the pile).
  Widget _lastMoveChip(TableLayout layout, LastMove move) {
    final rect = layout.seatRects[move.seat]!;
    final side = layout.seatSides[move.seat] ?? SeatSide.top;
    final w = layout.smallCardWidth * 0.8;
    final h = w * TableLayout.cardRatio;
    final topLeft = switch (side) {
      SeatSide.top => Offset(rect.left - w - 12, rect.top + (rect.height - h) / 2),
      SeatSide.left => Offset(rect.right + 6, rect.bottom - h),
      SeatSide.right => Offset(rect.left - w - 6, rect.bottom - h),
      SeatSide.bottom => Offset(rect.left, rect.top - h - 6),
    };
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: w,
      height: h,
      child: IgnorePointer(
        child: _FadingChip(
          key: ValueKey<int>(move.id),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(child: PlayingCardView(card: move.card, faceUp: true)),
              if (move.captured)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: PastraColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.black),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(int card, CardPlacement p, Duration duration) {
    final dragging = card == _dragCard;
    final rect = dragging ? p.rect.shift(_dragDelta) : p.rect;
    final canDrag = p.interactive && c.isHumanTurn;
    return AnimatedPositioned(
      key: ValueKey<int>(card),
      duration: dragging ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: RepaintBoundary(
        child: Transform.rotate(
          angle: p.angle,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: p.interactive ? () => c.tapHandCard(card) : null,
            onPanStart: canDrag ? (_) => _dragStart(card) : null,
            onPanUpdate: p.interactive ? (d) => _dragUpdate(card, d.delta, p.rect) : null,
            onPanEnd: p.interactive ? (_) => _dragEnd(card) : null,
            onPanCancel: p.interactive ? () => _dragEnd(card) : null,
            child: PlayingCardView(
              card: card,
              faceUp: p.faceUp,
              covered: p.covered,
              highlighted: p.highlighted,
              selected: p.selected,
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(Rect anchor, String text, IconData icon) {
    return Positioned(
      left: anchor.left - 14,
      width: anchor.width + 28,
      top: anchor.bottom - 9,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 11, color: Colors.white70),
                const SizedBox(width: 3),
                Text(text, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seatLabel(Strings s, int seat, Rect rect, SeatSide side) {
    final state = c.state;
    final active = state.phase == GamePhase.playing && state.current == seat;
    final thinking = active && c.botThinking;
    final isPartner = c.isTeamGame && seat == 2;
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? PastraColors.gold.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? PastraColors.gold : Colors.transparent, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isPartner) ...<Widget>[
            const Icon(Icons.people_outline, size: 13, color: PastraColors.gold),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              _seatName(s, seat),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (thinking) ...<Widget>[
            const SizedBox(width: 6),
            if (c.turnLimit != null)
              _Countdown(key: ValueKey<int>(c.turnId), duration: c.turnLimit!, size: 18)
            else
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: PastraColors.gold),
              ),
          ],
        ],
      ),
    );
    switch (side) {
      case SeatSide.top:
        return Positioned(
          left: rect.center.dx - 90,
          width: 180,
          top: rect.bottom + 2,
          child: IgnorePointer(child: Center(child: tag)),
        );
      case SeatSide.right:
        return Positioned(
          right: TableLayout.margin - 4,
          width: 120,
          top: rect.bottom + 3,
          child: IgnorePointer(child: Align(alignment: Alignment.centerRight, child: tag)),
        );
      default:
        return Positioned(
          left: TableLayout.margin - 4,
          width: 120,
          top: rect.bottom + 3,
          child: IgnorePointer(child: Align(alignment: Alignment.centerLeft, child: tag)),
        );
    }
  }

  Widget _infoLine(Strings s) {
    final state = c.state;
    String? main;
    String? sub;
    var gold = false;
    final leftover = c.leftoverSeat;
    if (leftover != null) {
      main = s.leftoversTo(c.isTeamGame
          ? (GameState.teamOf(leftover) == 0 ? s.us : s.them)
          : _seatName(s, leftover));
    } else if (c.isHumanTurn) {
      final pv = c.selectedPreview;
      if (pv == null) {
        main = s.yourTurn;
        gold = true;
        sub = state.deck.isEmpty ? '${s.lastDeal} · ${s.dragHint}' : s.dragHint;
      } else {
        final pile = state.rules.isPile;
        if (pv.isPastra) {
          main = '${s.pastraBanner}  +${pv.pastraPoints}';
          gold = true;
        } else if (!pv.isCapture) {
          main = pile ? s.goesOnPile : s.staysOnTable;
        } else if (Cards.isJack(pv.card) && pv.captured.length == state.table.length) {
          main = pile ? s.jackTakesPile : s.jackSweeps;
        } else {
          // In the pile game the size of the pile is for you to remember.
          main = pile ? s.takesPile : s.takes(pv.captured.length + 1);
        }
        sub = _dragCard == null ? s.tapAgain : (_overTable ? s.dropToPlay : s.dragHint);
      }
    } else if (c.botThinking) {
      main = '${_seatName(s, state.current)} ${s.thinking}';
    }
    if (main == null) return const SizedBox.shrink();
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (c.isHumanTurn && c.turnLimit != null) ...<Widget>[
                _Countdown(key: ValueKey<int>(c.turnId), duration: c.turnLimit!),
                const SizedBox(width: 8),
              ],
              Text(
                main,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: gold ? PastraColors.gold : Colors.white,
                ),
              ),
              if (sub != null)
                Text(
                  '   $sub',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.teamNames,
    required this.onBack,
    required this.onRules,
  });

  final GameState state;
  final List<String> teamNames;
  final VoidCallback onBack;
  final VoidCallback onRules;

  /// One slim row with the scoreboard exactly in the middle.
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    Widget name(String text, TextAlign align) => SizedBox(
          width: 96,
          child: Text(
            text,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        );
    Widget score(int value, bool ours) => Container(
          constraints: const BoxConstraints(minWidth: 46),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: ours ? PastraColors.gold : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: ours ? Colors.black : Colors.white,
            ),
          ),
        );
    final board = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          name(teamNames[0], TextAlign.right),
          const SizedBox(width: 8),
          score(state.scores[0], true),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(':', style: TextStyle(fontSize: 20, color: Colors.white54, fontWeight: FontWeight.w700)),
          ),
          score(state.scores[1], false),
          const SizedBox(width: 8),
          name(teamNames[1], TextAlign.left),
        ],
      ),
    );
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: s.leave,
              visualDensity: VisualDensity.compact,
            ),
          ),
          Center(child: FittedBox(fit: BoxFit.scaleDown, child: board)),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${s.round(state.round)} · ${s.target(state.rules.targetScore)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                IconButton(
                  onPressed: onRules,
                  icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
                  tooltip: s.rules,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ring that empties while a player thinks; shows the seconds left.
class _Countdown extends StatelessWidget {
  const _Countdown({super.key, required this.duration, this.size = 20});

  final Duration duration;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 0),
        duration: duration,
        builder: (context, v, _) {
          final left = (v * duration.inSeconds).ceil();
          final color = v > 0.3 ? PastraColors.gold : const Color(0xFFFF6B5B);
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: v,
                    strokeWidth: 2.4,
                    color: color,
                    backgroundColor: Colors.white24,
                  ),
                ),
                Text(
                  '$left',
                  style: TextStyle(fontSize: size * 0.48, color: color, fontWeight: FontWeight.w800, height: 1),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PastraBanner extends StatelessWidget {
  const _PastraBanner({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PastraColors.gold, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(color: PastraColors.gold.withValues(alpha: 0.45), blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: PastraColors.gold,
                letterSpacing: 2,
              ),
            ),
            Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Shakes its child briefly whenever [trigger] changes (a pastra). The child
/// keeps its state, so card animations are not disturbed.
class _Shake extends StatefulWidget {
  const _Shake({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger != 0) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        final dx = _c.isAnimating ? sin(t * pi * 9) * (1 - t) * 7 : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// Gold ring and sparks bursting from the pile on a pastra.
class _PastraBurst extends StatefulWidget {
  const _PastraBurst({super.key, required this.center});

  final Offset center;

  @override
  State<_PastraBurst> createState() => _PastraBurstState();
}

class _PastraBurstState extends State<_PastraBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BurstPainter(_c, widget.center, widget.key.hashCode),
        size: Size.infinite,
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.anim, this.center, int seed)
      : _particles = List<_Spark>.generate(34, (i) {
          final r = Random(seed + i * 7919);
          return _Spark(
            angle: r.nextDouble() * 2 * pi,
            speed: 90 + r.nextDouble() * 220,
            size: 2.5 + r.nextDouble() * 4.5,
            hue: r.nextInt(3),
          );
        }),
        super(repaint: anim);

  final Animation<double> anim;
  final Offset center;
  final List<_Spark> _particles;

  static const List<Color> _colors = <Color>[
    PastraColors.gold,
    Color(0xFFFFF3C4),
    Color(0xFFFF9F43),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    if (t <= 0 || t >= 1) return;
    // Expanding ring.
    final ringT = Curves.easeOutCubic.transform(min(1.0, t * 1.6));
    canvas.drawCircle(
      center,
      20 + ringT * 120,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - ringT) + 1
        ..color = PastraColors.gold.withValues(alpha: (1 - ringT) * 0.9),
    );
    // Sparks with a little gravity.
    final fade = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
    final paint = Paint();
    for (final p in _particles) {
      final d = p.speed * Curves.easeOutQuad.transform(t);
      final pos = center + Offset(cos(p.angle) * d, sin(p.angle) * d + 140 * t * t);
      paint.color = _colors[p.hue].withValues(alpha: fade);
      canvas.drawCircle(pos, p.size * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => false;
}

class _Spark {
  final double angle;
  final double speed;
  final double size;
  final int hue;

  const _Spark({required this.angle, required this.speed, required this.size, required this.hue});
}

/// Pops in, stays for a moment, then fades out.
class _FadingChip extends StatelessWidget {
  const _FadingChip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 3200),
      child: child,
      builder: (context, t, child) {
        final opacity = t < 0.06 ? t / 0.06 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
        final scale = t < 0.06 ? 0.6 + 0.4 * (t / 0.06) : 1.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

/// "Achievement unlocked" banner that slides in from the top.
class _AchievementToast extends StatelessWidget {
  const _AchievementToast({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final icon = kAchievements
        .firstWhere((a) => a.id == id, orElse: () => const Achievement('?', Icons.emoji_events))
        .icon;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2700),
      builder: (context, t, child) {
        final inT = (t / 0.12).clamp(0.0, 1.0);
        final outT = t > 0.88 ? (1 - (t - 0.88) / 0.12) : 1.0;
        return Opacity(
          opacity: (inT * outT).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, -30 * (1 - Curves.easeOut.transform(inT))), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PastraColors.gold, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: PastraColors.gold, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: Colors.black),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.achUnlocked, style: const TextStyle(fontSize: 11, color: PastraColors.gold)),
                Text(
                  s.achTitle(id),
                  style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims the table except [focus] and explains one thing.
class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay({
    required this.focus,
    required this.title,
    required this.body,
    required this.step,
    required this.total,
    required this.nextLabel,
    required this.skipLabel,
    required this.onNext,
    required this.onSkip,
  });

  final Rect? focus;
  final String title;
  final String body;
  final int step;
  final int total;
  final String nextLabel;
  final String skipLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final f = focus;
      final bubble = Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        decoration: BoxDecoration(
          color: PastraColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PastraColors.gold, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: PastraColors.gold)),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: Text(body, style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.35)),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (var i = 0; i < total; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == step ? PastraColors.gold : Colors.white24,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Buttons wrap onto a second line when the labels are long.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  TextButton(
                    onPressed: onSkip,
                    child: Text(skipLabel, style: const TextStyle(color: Colors.white70)),
                  ),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
                    child: Text(nextLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _DimPainter(f)),
            ),
          ),
          Positioned.fill(
            child: CustomSingleChildLayout(delegate: _BubbleLayout(f), child: bubble),
          ),
        ],
      );
    });
  }
}

/// Places the tutorial bubble next to the highlighted area so that it is
/// always fully on screen: below it, above it, beside it, or (on very small
/// screens) wherever it fits best.
class _BubbleLayout extends SingleChildLayoutDelegate {
  _BubbleLayout(this.focus);

  final Rect? focus;
  static const double margin = 12;
  static const double gap = 12;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double w = min<double>(340.0, max<double>(0.0, constraints.maxWidth - 2 * margin));
    final double h = max<double>(0.0, constraints.maxHeight - 2 * margin);
    return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: h);
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    double clampX(double x) => x.clamp(margin, max<double>(margin, size.width - child.width - margin)).toDouble();
    double clampY(double y) => y.clamp(margin, max<double>(margin, size.height - child.height - margin)).toDouble();
    final f = focus;
    if (f == null) {
      return Offset(clampX((size.width - child.width) / 2), clampY((size.height - child.height) / 2));
    }
    final double x = clampX(f.center.dx - child.width / 2);
    final double belowY = f.bottom + gap;
    final double aboveY = f.top - gap - child.height;
    final bool fitsBelow = belowY + child.height <= size.height - margin;
    final bool fitsAbove = aboveY >= margin;
    // Prefer the side with more room.
    final bool preferBelow = f.center.dy < size.height / 2;
    if (fitsBelow && (preferBelow || !fitsAbove)) return Offset(x, belowY);
    if (fitsAbove) return Offset(x, aboveY);
    final double y = clampY(f.center.dy - child.height / 2);
    if (f.right + gap + child.width <= size.width - margin) return Offset(f.right + gap, y);
    if (f.left - gap - child.width >= margin) return Offset(f.left - gap - child.width, y);
    return Offset(x, clampY(preferBelow ? belowY : aboveY));
  }

  @override
  bool shouldRelayout(_BubbleLayout oldDelegate) => oldDelegate.focus != focus;
}

class _DimPainter extends CustomPainter {
  const _DimPainter(this.focus);

  final Rect? focus;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final f = focus;
    if (f != null) {
      dim.addRRect(RRect.fromRectAndRadius(f, const Radius.circular(14)));
      dim.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.62));
    if (f != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(f, const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = PastraColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(_DimPainter oldDelegate) => oldDelegate.focus != focus;
}


/// Shown to an online guest when the host has left the game.
class _OnlineClosedOverlay extends StatelessWidget {
  const _OnlineClosedOverlay({required this.text, required this.button, required this.onBack});

  final String text;
  final String button;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: Text(button)),
          ],
        ),
      ),
    );
  }
}
