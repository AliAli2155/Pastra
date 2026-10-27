import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/game_state.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
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

  @override
  void initState() {
    super.initState();
    c.start();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String _seatName(Strings s, int seat) {
    final info = c.seats[seat];
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

      return Stack(
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
          if (state.phase != GamePhase.playing && !c.busy)
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
      );
    });
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
