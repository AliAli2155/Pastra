import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/game_state.dart';
import '../../engine/pastra_engine.dart';
import '../../game/achievements.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../game/quests.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../../online/online_service.dart';
import '../../online/room_session.dart';
import '../../online/room_social.dart';
import '../ege/fly_card.dart';
import '../ege/table_stage.dart';
import '../ege/widgets.dart';
import '../fx/fx.dart';
import '../premium/premium.dart';
import '../table_layout.dart';
import '../theme.dart';
import '../widgets/fullscreen_button.dart';
import '../widgets/game_over.dart';
import '../widgets/game_review.dart';
import '../widgets/name_prompt.dart';
import '../widgets/playing_card.dart';
import '../widgets/quick_chat.dart';
import '../widgets/round_summary.dart';
import 'online_screen.dart';
import 'rules_screen.dart';

/// The card table. Owns (and disposes) its [GameController].
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller, this.training = false});

  final GameController controller;

  /// Training: the guided tour again, hints and tips.
  final bool training;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;

  /// Hand card being dragged and how far it has moved.
  int? _dragCard;

  /// The playable card under the mouse (computers).
  int? _hoverCard;
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
    final fresh = c.state.round == 1 && PastraEngine.isOpeningPosition(c.state);
    if (!c.isOnline && fresh && (widget.training || !c.settings.tutorialDone)) {
      _tutorialStep = 0;
    } else {
      c.start();
    }
    c.link?.social.addListener(_onSocial);
  }

  // ------------------------------------------------------------ online extras

  bool _rematchBusy = false;
  bool _joiningRematch = false;

  /// Guest: the host opened the rematch table; join it if we asked for it.
  void _onSocial() {
    final social = c.link?.social;
    if (social == null || !mounted) return;
    if (social.nextCode != null && social.iVoted && !c.isHostOfLink) _joinRematch();
  }

  /// Host: opens a new table for the same people and tells them. Guest: asks
  /// the host (and joins as soon as the table is there).
  Future<void> _rematch() async {
    final link = c.link;
    if (link == null || _rematchBusy) return;
    if (link is! HostRoom) {
      link.social.voteRematch();
      _onSocial();
      return;
    }
    final settings = c.settings;
    final s = Strings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _rematchBusy = true);
    try {
      final room = await HostRoom.create(
        settings,
        players: link.players,
        level: link.level,
        name: settings.playerName.isEmpty ? s.you : settings.playerName,
        autoStart: true,
        stake: link.stake,
      );
      room.expectedPeople = 1 + c.seats.where((x) => x.isRemote).length;
      await link.social.offerRematch(room.code);
      if (!mounted) {
        room.close();
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => LobbyScreen(host: room, rematch: true)),
      );
    } on OnlineException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(OnlineStrings(settings.language).error(e.code))));
      if (mounted) setState(() => _rematchBusy = false);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(OnlineStrings(settings.language).error('network'))));
      if (mounted) setState(() => _rematchBusy = false);
    }
  }

  Future<void> _joinRematch() async {
    final code = c.link?.social.nextCode;
    if (code == null || _joiningRematch) return;
    _joiningRematch = true;
    final settings = c.settings;
    final s = Strings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final room = await GuestRoom.join(code, settings, settings.playerName.isEmpty ? s.you : settings.playerName);
      if (!mounted) {
        room.close();
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => LobbyScreen(guest: room, rematch: true)),
      );
    } on OnlineException catch (e) {
      _joiningRematch = false;
      messenger.showSnackBar(SnackBar(content: Text(OnlineStrings(settings.language).error(e.code))));
    } catch (_) {
      _joiningRematch = false;
    }
  }

  void _openChat() {
    final social = c.link?.social;
    if (social == null) return;
    showQuickChat(context, social);
  }

  /// The hinted card glows and what it takes lights up; the line under the
  /// table already says what it does (no message over the hand).
  void _hint() => c.showHint();

  /// Hints: offline games except tournament matches.
  bool get _hintsAllowed => !c.isOnline && !c.tournament;

  void _tutorialNext() {
    final step = _tutorialStep;
    if (step == null) return;
    if (step + 1 < _tutorialSteps.length) {
      setState(() => _tutorialStep = step + 1);
    } else {
      _tutorialEnd();
    }
  }

  Future<void> _tutorialEnd() async {
    setState(() => _tutorialStep = null);
    c.settings.tutorialDone = true;
    // A new player: now their name (shown at the table and online).
    if (c.settings.playerName.isEmpty) await askPlayerName(context);
    if (!mounted) return;
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

  Widget _tutorialOverlay(Strings s, TableLayout layout, StageGeometry geo) {
    final index = _tutorialStep!;
    final step = _tutorialSteps[index];
    final focus = _tutorialFocus(step, layout, geo.size);
    return Positioned.fill(
      child: _TutorialOverlay(
        // Drawn flat over the whole area: the highlight is where the thing
        // is seen on the screen.
        focus: focus == null ? null : geo.projectRect(focus),
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
    c.link?.social.removeListener(_onSocial);
    c.saveNow();
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
    c.pauseTurnTimer();
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.leaveTitle),
        content: Text(
          c.isOnline
              ? OnlineStrings(c.settings.language).leaveOnline
              : (c.tournament ? s.leaveMatchBody : s.leaveBody),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.leave)),
        ],
      ),
    );
    if (leave != true || !mounted) {
      c.resumeTurnTimer();
      return;
    }
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
        body: Felt(
          // The cards are the show here: the sky stands still.
          animated: false,
          fit: false,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable?>[c, c.link?.social]),
              builder: (context, _) {
                final s = Strings.of(context);
                return Column(
                  children: <Widget>[
                    _TopBar(
                      state: c.state,
                      teamNames: _teamNames(s),
                      onBack: _requestLeave,
                      onHint: _hintsAllowed && c.isHumanTurn ? _hint : null,
                      showHint: _hintsAllowed,
                      onChat: c.isOnline ? _openChat : null,
                      onRules: () async {
                        c.pauseTurnTimer();
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => RulesScreen(variant: c.state.rules.variant)),
                        );
                        c.resumeTurnTimer();
                      },
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
    // Low graphics quality: the table is shown flat instead of leaning back.
    return ValueListenableBuilder<bool>(
      valueListenable: Fx.low,
      builder: (context, low, _) => LayoutBuilder(builder: (context, box) {
        final area = Size(box.maxWidth, box.maxHeight);
        final geo = StageGeometry.fit(area, tilted: !low);
        final layout = TableLayout.compute(
          size: geo.size,
          state: state,
          selected: c.selected,
          pending: c.pending,
          highlighted: c.highlighted,
          tableShown: c.tableShown,
          landing: c.landing,
          scale: TableLayout.scaleFor(geo.size),
        );
        _dropLine = layout.dropLine;
        if (_dragCard != null && !c.isHumanTurn) {
          // The turn changed under the finger (should not happen): let go.
          _dragCard = null;
          _dragDelta = Offset.zero;
          _overTable = false;
        }
        _updateStagger(state);
        int zOf(MapEntry<int, CardPlacement> e) => e.key == _dragCard ? 10000 : e.value.z;
        final entries = layout.cards.entries.toList()..sort((a, b) => zOf(a).compareTo(zOf(b)));
        final duration = Duration(milliseconds: settings.fastAnimations ? 200 : 320);
        final event = c.pastraEvent;
        // Name plates, counters and messages are not part of the tilted
        // table: they are drawn flat on top of it, where the place they
        // belong to appears on the screen.
        Rect screen(Rect r) => geo.projectRect(r);

        return _Shake(
          trigger: event?.id ?? 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: c.clearSelection),
              ),
              // The table itself, leaned back.
              Positioned.fill(
                child: IgnorePointer(
                  child: TableStage(
                    geometry: geo,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(painter: StageFeltPainter(table: Look.table, rim: geo.rim)),
                          ),
                        ),
                        Positioned.fromRect(
                          rect: layout.tableRect.inflate(6),
                          child: RepaintBoundary(child: CustomPaint(painter: TableZonePainter(highlight: _overTable))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // My own name plate at the bottom left (gold while it is my turn),
              // under the cards so it never hides one.
              Positioned(
                left: 10,
                bottom: 8,
                child: IgnorePointer(child: _myPlate(s)),
              ),
              // A card put down on the table: a soft ring on the cloth
              // around it when it lands.
              if (_landed(layout) case final rect?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _LandingRing(
                      key: ValueKey<int>(c.lastMove!.id),
                      geometry: geo,
                      rect: rect,
                      flight: duration,
                    ),
                  ),
                ),
              // The cards lie on it. They are not drawn through the
              // perspective (slow, above all in a browser): each one is
              // placed, sized and slanted like the part of the table under it.
              for (final e in entries) _card(e.key, e.value, duration, geo),
              if (state.deck.isNotEmpty)
                // On the deck itself: beside it the card a player has just
                // played may show, the face-up cards under it stick out at the
                // bottom right, and a side hand may be below it.
                _badge(screen(layout.deckRect), '${state.deck.length}', Icons.layers_outlined, onTop: true),
              for (var t = 0; t < 2; t++)
                if (state.piles[t].isNotEmpty)
                  _badge(
                    screen(layout.pileRects[t]),
                    state.pastraCards[t].isEmpty
                        ? '${state.piles[t].length}'
                        : '${state.piles[t].length} · Π${state.pastraCards[t].length}',
                    Icons.style_outlined,
                    // It bumps when captured cards arrive. A new pile's counter
                    // grows in when they first get there (all its cards were
                    // just taken: from the table, and the card that took them).
                    bumpKey: state.piles[t].length,
                    fresh: state.piles[t].where((card) => !_gathered.containsKey(card)).length <= 1,
                  ),
              for (final entry in layout.seatRects.entries)
                _seatLabel(
                  s,
                  entry.key,
                  screen(entry.value),
                  layout.seatSides[entry.key] ?? SeatSide.top,
                  area,
                  moveCardWidth: layout.smallCardWidth * 0.8 * geo.scaleAt(entry.value.center),
                ),
              // The seat across the table shows its last card in its name plate row.
              if (c.lastMove != null &&
                  layout.seatRects.containsKey(c.lastMove!.seat) &&
                  layout.seatSides[c.lastMove!.seat] != SeatSide.top)
                _lastMoveChip(layout, c.lastMove!, geo),
              if (event != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _PastraBurst(key: ValueKey<int>(event.id), center: geo.project(layout.playCenter)),
                  ),
                ),
              // Our pastra: confetti over the whole table.
              if (event != null && (event.seat == 0 || (c.isTeamGame && event.seat == 2)))
                Positioned.fill(
                  child: IgnorePointer(child: _Confetti(key: ValueKey<int>(event.id))),
                ),
              Positioned.fromRect(
                rect: screen(layout.infoRect),
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
              if (c.quadAlert != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: _QuadBanner(
                        key: ValueKey<int>(c.quadAlert!.id),
                        cards: c.quadAlert!.cards,
                        subtitle: s.quadBy(_seatName(s, c.quadAlert!.seat)),
                        footer: s.quadRedeal,
                        cardWidth: min(64.0 * TableLayout.scaleFor(box.biggest), max(36.0, box.maxWidth / 11)),
                      ),
                    ),
                  ),
                ),
              if (_tutorialStep != null) _tutorialOverlay(s, layout, geo),
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
              for (final b in c.link?.social.bubbles.values ?? const <ChatBubble>[]) _chatBubble(s, layout, b, geo),
              if (c.onlineClosed)
                Positioned.fill(
                  child: _OnlineClosedOverlay(
                    text: c.link?.social.nextCode != null
                        ? SocialStrings(c.settings.language).rematchReady
                        : OnlineStrings(c.settings.language).hostLeft,
                    button: OnlineStrings(c.settings.language).back,
                    onBack: () => Navigator.of(context).pop(),
                    action: c.link?.social.nextCode != null ? SocialStrings(c.settings.language).join : null,
                    onAction: _joinRematch,
                  ),
                ),
              if (state.phase != GamePhase.playing && !c.busy && !c.onlineClosed)
                // A key, so that toasts or chat bubbles appearing before it in the
                // stack do not rebuild the panel (it would open a second time).
                Positioned.fill(
                  key: const ValueKey<String>('round-summary'),
                  child: state.phase == GamePhase.gameOver
                      // The end of the game: the trophy, the score and the XP
                      // first; the score sheet on request.
                      ? GameOverView(
                          state: state,
                          teamNames: _teamNames(s),
                          onNextRound: c.nextRound,
                          onMainMenu: () => Navigator.of(context).pop(),
                          onPlayAgain: c.isOnline ? (_rematchAvailable ? _rematch : null) : _playAgain,
                          playAgainLabel: c.isOnline ? _rematchLabel() : null,
                          xpGain: c.xpGain,
                          tournament: c.tournament,
                          onReview: () => showGameReview(context, c.misses),
                          reviewCount: c.misses.length,
                        )
                      : RoundSummaryPanel(
                          state: state,
                          teamNames: _teamNames(s),
                          onNextRound: c.nextRound,
                          onMainMenu: () => Navigator.of(context).pop(),
                          onPlayAgain: c.isOnline ? (_rematchAvailable ? _rematch : null) : _playAgain,
                          playAgainLabel: c.isOnline ? _rematchLabel() : null,
                          xpGain: c.xpGain,
                          tournament: c.tournament,
                          onReview: () => showGameReview(context, c.misses),
                          reviewCount: c.misses.length,
                        ),
                ),
              // Confetti over everything when we won the game.
              if (state.phase == GamePhase.gameOver && !c.busy && !c.onlineClosed && state.winner == 0)
                Positioned.fill(
                  child: IgnorePointer(child: _Confetti(key: ValueKey<String>('won-${state.round}'))),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// Online: rematch is possible while the table is still there.
  bool get _rematchAvailable {
    final social = c.link?.social;
    if (social == null || _rematchBusy) return false;
    if (c.isHostOfLink) return true;
    return !social.iVoted || social.nextCode != null;
  }

  String _rematchLabel() {
    final t = SocialStrings(c.settings.language);
    final social = c.link?.social;
    if (social == null) return t.rematch;
    if (c.isHostOfLink) {
      final n = social.rematchVotes.where((x) => x != social.mySeat).length;
      return n > 0 ? t.rematchVotes(n) : t.rematch;
    }
    if (social.nextCode != null) return t.join;
    return social.iVoted ? t.rematchWait : t.rematch;
  }

  /// A quick chat message next to the seat that sent it.
  Widget _chatBubble(Strings s, TableLayout layout, ChatBubble b, StageGeometry geo) {
    final text = SocialStrings(s.lang).chat(b.message);
    if (text.isEmpty) return const SizedBox.shrink();
    final seatRect = layout.seatRects[b.seat];
    final rect = seatRect == null ? null : geo.projectRect(seatRect);
    final side = layout.seatSides[b.seat];
    Offset anchor;
    Offset shift;
    if (rect == null || side == null) {
      // Me: above my hand.
      anchor = geo.project(Offset(geo.size.width / 2, layout.dropLine - 8));
      shift = const Offset(-0.5, -1);
    } else {
      switch (side) {
        case SeatSide.top:
          anchor = Offset(rect.center.dx, rect.bottom + 34);
          shift = const Offset(-0.5, 0);
        case SeatSide.left:
          anchor = Offset(rect.right + 10, rect.center.dy);
          shift = const Offset(0, -0.5);
        case SeatSide.right:
          anchor = Offset(rect.left - 10, rect.center.dy);
          shift = const Offset(-1, -0.5);
        case SeatSide.bottom:
          anchor = Offset(rect.center.dx, rect.top - 8);
          shift = const Offset(-0.5, -1);
      }
    }
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: shift,
          child: QuickChatBubble(key: ValueKey<int>(b.id), text: text, emoji: b.message.startsWith('e:')),
        ),
      ),
    );
  }

  /// The card a bot just played, shown small next to it for a moment
  /// (with a tick when it took the pile).
  Widget _lastMoveChip(TableLayout layout, LastMove move, StageGeometry geo) {
    final seatRect = layout.seatRects[move.seat]!;
    final rect = geo.projectRect(seatRect);
    final side = layout.seatSides[move.seat] ?? SeatSide.top;
    final w = layout.smallCardWidth * 0.8 * geo.scaleAt(seatRect.center);
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
      child: IgnorePointer(child: _moveCard(move)),
    );
  }

  /// The card a player has just played, shown small next to them for a
  /// moment (a gold tick when it captured).
  Widget _moveCard(LastMove move) {
    return _FadingChip(
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
                child: const Icon(Icons.check, size: 12, color: PastraColors.goldInk),
              ),
            ),
        ],
      ),
    );
  }

  // ---- dealing and gathering one card after the other

  int _staggerVersion = -1;
  Set<int> _prevDeck = <int>{};
  Set<int> _prevTable = <int>{};

  /// Order of the cards just dealt (deck → hands) and just gathered (table
  /// → pile): each one leaves a little after the one before.
  Map<int, int> _dealt = <int, int>{};
  Map<int, int> _gathered = <int, int>{};
  DateTime _staggerAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _updateStagger(GameState state) {
    if (c.stateVersion == _staggerVersion) return;
    _staggerVersion = c.stateVersion;
    final dealt = <int, int>{};
    if (_prevDeck.isNotEmpty) {
      var longest = 0;
      for (final h in state.hands) {
        longest = max(longest, h.length);
      }
      var i = 0;
      for (var k = 0; k < longest; k++) {
        for (var seat = 0; seat < state.numPlayers; seat++) {
          // Dealing starts left of the dealer.
          final who = (state.dealer + 1 + seat) % state.numPlayers;
          final hand = state.hands[who];
          if (k < hand.length && _prevDeck.contains(hand[k])) dealt[hand[k]] = i++;
        }
      }
    }
    final gathered = <int, int>{};
    var j = 0;
    for (final pile in state.piles) {
      for (final card in pile) {
        if (_prevTable.contains(card)) gathered[card] = j++;
      }
    }
    // A new deal or capture replaces the old order; otherwise the order is
    // kept a moment longer, so that cards still on their way keep moving
    // smoothly.
    final now = DateTime.now();
    if (dealt.isNotEmpty || gathered.isNotEmpty || now.difference(_staggerAt) > const Duration(milliseconds: 1200)) {
      _dealt = dealt;
      _gathered = gathered;
      _staggerAt = now;
    }
    _prevDeck = state.deck.toSet();
    _prevTable = state.table.toSet();
  }

  Widget _card(int card, CardPlacement p, Duration duration, StageGeometry geo) {
    final dragging = card == _dragCard;
    // On a computer a playable card rises a little under the mouse.
    final hovered = card == _hoverCard && p.interactive && !p.selected && c.isHumanTurn;
    final rect = dragging
        ? p.rect.shift(_dragDelta)
        : (hovered ? p.rect.shift(Offset(0, -p.rect.height * 0.08)) : p.rect);
    final canDrag = p.interactive && c.isHumanTurn;
    final fast = c.settings.fastAnimations;
    final state = c.state;
    // Only while the card is still where it went (a card played from the
    // hand moves at once).
    final dealtIndex = _dealt[card];
    final gatheredIndex = _gathered[card];
    final inHand = dealtIndex != null && state.hands.any((h) => h.contains(card));
    final inPile = gatheredIndex != null && state.piles.any((pile) => pile.contains(card));
    final delay = inHand ? dealtIndex * (fast ? 25 : 45) : (inPile ? min(gatheredIndex, 12) * (fast ? 6 : 10) : 0);
    // The card glides to its place (with a little arc on a long way); a card
    // held by a finger follows it at once.
    return FlyCard(
      key: ValueKey<int>(card),
      rect: rect,
      angle: p.angle,
      duration: duration,
      delay: Duration(milliseconds: delay),
      still: dragging,
      hop: !Fx.low.value,
      geometry: geo,
      child: RepaintBoundary(
        child: MouseRegion(
          cursor: p.interactive && c.isHumanTurn ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: p.interactive ? (_) => setState(() => _hoverCard = card) : null,
          onExit: p.interactive ? (_) => setState(() => _hoverCard = _hoverCard == card ? null : _hoverCard) : null,
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
            simple: p.simple,
            highlighted: p.highlighted || (card == c.hintCard && p.interactive),
            selected: p.selected,
          ),
        ),
        ),
      ),
    );
  }

  /// A small counter (cards in the deck or in a pile) under a place on the
  /// table, or [onTop] of it. [anchor] is where that place is seen on the
  /// screen.
  Widget _badge(Rect anchor, String text, IconData icon, {bool onTop = false, int? bumpKey, bool fresh = false}) {
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: const Color(0xFFC9D6CF)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFFE4ECE7), fontWeight: FontWeight.w700)),
        ],
      ),
    );
    if (bumpKey != null) chip = _Bump(key: ValueKey<int>(bumpKey), fresh: fresh, child: chip);
    return Positioned(
      left: anchor.left - 14,
      width: anchor.width + 28,
      top: onTop ? anchor.center.dy - 10 : anchor.bottom - 9,
      child: IgnorePointer(child: Center(child: chip)),
    );
  }

  /// Where the card just put down lies on the flat table, while it is a
  /// card that stays on the table (not a capture). Null otherwise and in low
  /// graphics quality.
  Rect? _landed(TableLayout layout) {
    final move = c.lastMove;
    if (move == null || move.captured || Fx.low.value) return null;
    if (!c.state.table.contains(move.card)) return null;
    return layout.cards[move.card]?.rect;
  }

  /// A player's round picture; when their turn starts a gold ring grows out
  /// of it once (not in low graphics quality).
  Widget _withTurnPing(bool active, Widget avatar) {
    if (!active || Fx.low.value) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(child: _TurnPing(key: ValueKey<int>(c.turnId))),
        avatar,
      ],
    );
  }

  /// My name plate: the initial in a gold ring and my name; it lights up
  /// on my turn.
  Widget _myPlate(Strings s) {
    final name = _seatName(s, 0);
    final mine = c.isHumanTurn;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(3, 3, 12, 3),
      decoration: plateDecoration(radius: 20, glow: mine, edge: 0.35),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _withTurnPing(
            mine,
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PastraColors.raised,
                border: Border.all(color: PastraColors.gold, width: 2),
              ),
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: PastraColors.gold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: mine ? PastraColors.goldLight : PastraColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The name plate of a seat, centred under the place of the player on the
  /// screen ([rect]) and never outside the [area].
  Widget _seatLabel(Strings s, int seat, Rect rect, SeatSide side, Size area, {double moveCardWidth = 0}) {
    final state = c.state;
    final active = state.phase == GamePhase.playing && state.current == seat;
    final thinking = active && c.botThinking;
    final isPartner = c.isTeamGame && seat == 2;
    final info = c.seats[seat];
    final name = _seatName(s, seat);
    // Name plate: a small round "avatar" (robot for the computer, the
    // initial for a person), the name, and a gold glow on the player's turn.
    // The ring is gold on the player's turn, teal otherwise.
    final avatar = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PastraColors.raised,
        border: Border.all(color: active ? PastraColors.gold : PastraColors.teal, width: 2),
      ),
      child: info.isBot
          ? Icon(Icons.smart_toy_rounded, size: 14, color: active ? PastraColors.gold : PastraColors.text)
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? PastraColors.gold : PastraColors.text,
              ),
            ),
    );
    final tag = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(3, 3, 11, 3),
      decoration: plateDecoration(radius: 16, glow: active, edge: 0.35),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _withTurnPing(active, avatar),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: active ? PastraColors.goldLight : PastraColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (c.offlineSeats.contains(seat)) ...<Widget>[
            const SizedBox(width: 4),
            const Icon(Icons.wifi_off_rounded, size: 13, color: PastraColors.coral),
          ],
          if (isPartner) ...<Widget>[
            const SizedBox(width: 4),
            const Icon(Icons.handshake_outlined, size: 13, color: PastraColors.teal),
          ],
          if (thinking) ...<Widget>[
            const SizedBox(width: 6),
            if (c.turnLimit != null)
              _Countdown(key: ValueKey<int>(c.turnId), duration: c.turnLimit!, size: 18)
            else
              const _ThinkingDots(),
          ],
        ],
      ),
    );
    if (side == SeatSide.top) {
      // Beside the hand across the table, on its left (under it the plate
      // would cover the cards in the middle on a low screen), with the card
      // this player has just played next to it.
      final last = c.lastMove;
      final move = last != null && last.seat == seat && moveCardWidth > 0 ? last : null;
      final cardH = moveCardWidth * TableLayout.cardRatio;
      final width = 180.0 + (move != null ? moveCardWidth + 8 : 0.0);
      final height = move != null ? max(34.0, cardH) : 34.0;
      return Positioned(
        left: max(0.0, rect.left - width - 8),
        width: width,
        top: rect.center.dy - height / 2,
        height: height,
        child: IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (move != null) ...<Widget>[
                SizedBox(width: moveCardWidth, height: cardH, child: _moveCard(move)),
                const SizedBox(width: 8),
              ],
              Flexible(child: tag),
            ],
          ),
        ),
      );
    }
    const width = 120.0;
    final left = min(max(rect.center.dx - width / 2, 0.0), max(0.0, area.width - width));
    return Positioned(
      left: left,
      width: width,
      top: rect.bottom + 2,
      child: IgnorePointer(child: Center(child: tag)),
    );
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
        // A new message pops in; during my turn it changes with the chosen
        // card, and pops only when the turn starts.
        child: _PopIn(
          key: ValueKey<String>(c.isHumanTurn && leftover == null ? 'turn-${c.turnId}' : main),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: plateDecoration(radius: 14, glow: gold, edge: 0.3),
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
                  color: gold ? PastraColors.goldLight : PastraColors.text,
                ),
              ),
              if (sub != null)
                Text(
                  '   $sub',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, color: PastraColors.text2, fontWeight: FontWeight.w500),
                ),
            ],
          ),
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
    this.onHint,
    this.showHint = false,
    this.onChat,
  });

  final GameState state;
  final List<String> teamNames;
  final VoidCallback onBack;
  final VoidCallback onRules;

  /// Hint button (offline; null = disabled now).
  final VoidCallback? onHint;
  final bool showHint;

  /// Quick chat (online games).
  final VoidCallback? onChat;

  /// One slim row with the scoreboard (a glass pill) exactly in the middle,
  /// the back button on the left and the glass buttons on the right.
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    // Phones: the round / target text only when there is room next to the
    // scoreboard; the buttons stay big enough for a thumb.
    final roomForInfo = MediaQuery.sizeOf(context).width >= 1000;
    Widget name(String text, TextAlign align) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            text,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFFC9D0D8), fontWeight: FontWeight.w600),
          ),
        );
    // The score counts up to its new value (and pops when it changes).
    Widget score(int value, bool ours) => _ScoreNumber(value: value, ours: ours);
    final board = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xCC181B20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          name(teamNames[0], TextAlign.right),
          const SizedBox(width: 10),
          score(state.scores[0], true),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withValues(alpha: 0.2),
          ),
          score(state.scores[1], false),
          const SizedBox(width: 10),
          name(teamNames[1], TextAlign.left),
          if (roomForInfo) ...<Widget>[
            const SizedBox(width: 12),
            Text(
              '/ ${state.rules.targetScore} · ${s.round(state.round)}',
              style: const TextStyle(fontSize: 12, color: PastraColors.muted, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
    const btn = 40.0;
    const gap = 8.0;
    Widget button(IconData icon, String tooltip, VoidCallback? onTap, {Color color = PastraColors.text}) => Padding(
          padding: const EdgeInsetsDirectional.only(start: gap),
          child: GlassIconButton(icon: icon, tooltip: tooltip, onPressed: onTap, size: btn, color: color),
        );
    // The board stays centred: both sides get the room of the wider (right) one.
    final buttons = (showHint ? 1 : 0) + (onChat != null ? 1 : 0) + 1;
    final sideRoom = 10.0 + buttons * (btn + gap) + (kIsWeb ? 48.0 : 0.0);
    return SizedBox(
      height: 54,
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GlassIconButton(icon: Icons.arrow_back_rounded, tooltip: s.leave, onPressed: onBack, size: btn),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sideRoom),
            // Its own layer: a score counting up does not repaint the rest.
            child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: RepaintBoundary(child: board))),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (onChat != null) button(Icons.chat_bubble_outline_rounded, SocialStrings(s.lang).quickChat, onChat),
                  if (showHint)
                    button(
                      Icons.lightbulb_outline_rounded,
                      SocialStrings(s.lang).hint,
                      onHint,
                      color: PastraColors.gold,
                    ),
                  button(Icons.menu_book_outlined, s.rules, onRules),
                  const FullscreenButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ring that empties while a player thinks; shows the seconds left.
///
/// It moves five times a second, not with every frame: anything that moves
/// makes the whole table be drawn again, and a turn is long.
class _Countdown extends StatefulWidget {
  const _Countdown({super.key, required this.duration, this.size = 20});

  final Duration duration;
  final double size;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  static const Duration _step = Duration(milliseconds: 200);

  final Stopwatch _watch = Stopwatch()..start();
  Timer? _timer;
  int _steps = 0;

  /// Time gone: the clock, or the steps taken when they are ahead of it
  /// (tests run on a fake clock).
  int get _gone => max(_watch.elapsedMilliseconds, _steps * _step.inMilliseconds);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_step, (_) {
      _steps++;
      if (_gone >= widget.duration.inMilliseconds) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final total = widget.duration.inMilliseconds;
    final v = total <= 0 ? 0.0 : (1 - _gone / total).clamp(0.0, 1.0).toDouble();
    final left = (v * widget.duration.inSeconds).ceil();
    final color = v > 0.3 ? PastraColors.gold : PastraColors.coral;
    return RepaintBoundary(
      child: SizedBox(
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
                backgroundColor: Colors.white12,
              ),
            ),
            Text(
              '$left',
              style: TextStyle(fontSize: size * 0.48, color: color, fontWeight: FontWeight.w800, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots that light up one after the other while a player thinks
/// (three steps a second, not an endless spinner).
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> {
  Timer? _timer;
  int _lit = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 330), (_) => setState(() => _lit = (_lit + 1) % 3));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < 3; i++)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PastraColors.gold.withValues(alpha: i == _lit ? 1.0 : 0.35),
              ),
            ),
        ],
      ),
    );
  }
}

/// A score in the top bar. It counts up to a new value and, while it does,
/// grows and lights up for a moment.
class _ScoreNumber extends StatefulWidget {
  const _ScoreNumber({required this.value, required this.ours});

  final int value;

  /// Our team's score is gold.
  final bool ours;

  @override
  State<_ScoreNumber> createState() => _ScoreNumberState();
}

class _ScoreNumberState extends State<_ScoreNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late int _from = widget.value;
  late int _to = widget.value;

  int _at(double t) => (_from + (_to - _from) * Curves.easeOutCubic.transform(t)).round();

  @override
  void didUpdateWidget(_ScoreNumber old) {
    super.didUpdateWidget(old);
    if (widget.value == _to) return;
    _from = _at(_c.value);
    _to = widget.value;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.ours ? PastraColors.gold : PastraColors.text;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Up and back in the first half of the count.
        final pop = _c.isAnimating ? sin(pi * min(1.0, t / 0.5)) : 0.0;
        return Transform.scale(
          scale: 1 + 0.22 * pop,
          child: Text(
            '${_at(t)}',
            style: TextStyle(
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Color.lerp(base, PastraColors.goldLight, pop),
            ),
          ),
        );
      },
    );
  }
}

/// Pops its child in (grows from a little smaller and fades in) once, when
/// it is first shown. A new key shows it again.
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: 0.82 + 0.18 * t, child: child),
      ),
    );
  }
}

/// Grows its child for a moment, a little after it is shown (when the cards
/// flying to a pile arrive there). A new key bumps it again. A [fresh] one
/// is hidden until then and grows in.
class _Bump extends StatelessWidget {
  const _Bump({super.key, required this.child, this.fresh = false});

  final Widget child;
  final bool fresh;

  static const double _wait = 0.45;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      child: child,
      builder: (context, t, child) {
        final double scale;
        if (t < _wait) {
          scale = fresh ? 0 : 1;
        } else {
          final k = (t - _wait) / (1 - _wait);
          scale = fresh ? Curves.easeOutBack.transform(k) : 1 + 0.3 * sin(pi * k);
        }
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

/// Gold rings that grow out of a player's round picture once, when their
/// turn starts. It fills the picture and draws around it.
class _TurnPing extends StatefulWidget {
  const _TurnPing({super.key});

  @override
  State<_TurnPing> createState() => _TurnPingState();
}

class _TurnPingState extends State<_TurnPing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _PingPainter(_c))));
  }
}

class _PingPainter extends CustomPainter {
  _PingPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    if (t <= 0 || t >= 1 || size.isEmpty) return;
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    final paint = Paint()..style = PaintingStyle.stroke;
    // Two rings, the second a little later.
    for (var i = 0; i < 2; i++) {
      final lt = ((t - i * 0.25) / 0.75).clamp(0.0, 1.0);
      if (lt <= 0 || lt >= 1) continue;
      final e = Curves.easeOutCubic.transform(lt);
      paint
        ..strokeWidth = 2.4 * (1 - e) + 0.4
        ..color = PastraColors.gold.withValues(alpha: 0.85 * (1 - lt));
      canvas.drawCircle(center, base + e * base * 0.95, paint);
    }
  }

  @override
  bool shouldRepaint(_PingPainter oldDelegate) => false;
}

/// A soft light ring on the cloth around a card that was put down: it
/// grows out from the card's edge and fades as the card lands. [rect] is the
/// card's place on the flat table; the ring is drawn where it is seen. It
/// waits for the [flight] of the card first.
class _LandingRing extends StatefulWidget {
  const _LandingRing({super.key, required this.geometry, required this.rect, required this.flight});

  final StageGeometry geometry;
  final Rect rect;
  final Duration flight;

  @override
  State<_LandingRing> createState() => _LandingRingState();
}

class _LandingRingState extends State<_LandingRing> with SingleTickerProviderStateMixin {
  static const int _ringMs = 520;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.flight + const Duration(milliseconds: _ringMs),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flight = widget.flight.inMilliseconds;
    // Starts just before the card touches the cloth.
    final start = flight * 0.85 / (flight + _ringMs);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LandingPainter(_c, widget.geometry, widget.rect, start),
        size: Size.infinite,
      ),
    );
  }
}

class _LandingPainter extends CustomPainter {
  _LandingPainter(this.anim, this.geometry, this.rect, this.start) : super(repaint: anim);

  final Animation<double> anim;
  final StageGeometry geometry;
  final Rect rect;
  final double start;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (anim.value - start) / (1 - start);
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOutCubic.transform(t);
    final ring = geometry.projectRect(rect.inflate(rect.width * (0.04 + 0.3 * e)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(ring, Radius.circular(ring.width * 0.12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - e) + 0.5
        ..color = PastraColors.goldLight.withValues(alpha: 0.5 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_LandingPainter oldDelegate) => false;
}

/// Four of a kind: the hand is shown face up to everybody.
class _QuadBanner extends StatelessWidget {
  const _QuadBanner({
    super.key,
    required this.cards,
    required this.subtitle,
    required this.footer,
    required this.cardWidth,
  });

  final List<int> cards;
  final String subtitle;
  final String footer;
  final double cardWidth;

  static String _label(int rank) => switch (rank) {
        1 => 'A',
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        _ => '$rank',
      };

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    for (final c in cards) {
      counts[Cards.rank(c)] = (counts[Cards.rank(c)] ?? 0) + 1;
    }
    var rank = Cards.rank(cards.first);
    counts.forEach((r, n) {
      if (n >= 4) rank = r;
    });
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: tabletDecoration(radius: 20, glow: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '4 × ${_label(rank)}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: PastraColors.gold),
            ),
            Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.white)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final c in cards)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: SizedBox(
                      width: cardWidth,
                      height: cardWidth * 1.42,
                      child: PlayingCardView(card: c, faceUp: true),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(footer, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
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
        decoration: tabletDecoration(radius: 20, glow: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: PastraColors.gold,
                letterSpacing: 1.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 16, color: PastraColors.text2, fontWeight: FontWeight.w600),
            ),
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
    PastraColors.goldLight,
    PastraColors.teal,
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

/// Pops in, stays for a moment, then fades out. Only the pop and the fade
/// are animated; in between nothing has to be drawn again.
class _FadingChip extends StatefulWidget {
  const _FadingChip({super.key, required this.child});

  final Widget child;

  @override
  State<_FadingChip> createState() => _FadingChipState();
}

class _FadingChipState extends State<_FadingChip> {
  bool _shown = false;
  bool _gone = false;
  Timer? _fade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    _fade = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown && !_gone ? 1.0 : 0.0,
      duration: Duration(milliseconds: _gone ? 600 : 190),
      child: AnimatedScale(
        scale: _shown ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
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
    // Daily quests use the same toast ("q:<quest id>").
    final quest = id.startsWith(GameController.questToastPrefix)
        ? Quests.byId(id.substring(GameController.questToastPrefix.length))
        : null;
    final p = ProgressStrings(s.lang);
    final icon = quest != null
        ? Icons.task_alt_rounded
        : kAchievements.firstWhere((a) => a.id == id, orElse: () => const Achievement('?', Icons.emoji_events)).icon;
    final header = quest != null ? p.questDone : s.achUnlocked;
    final title = quest != null ? '${p.quest(quest)} · +${quest.xp} XP' : s.achTitle(id);
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
        decoration: plateDecoration(radius: 16, glow: true),
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
                Text(header, style: const TextStyle(fontSize: 11, color: PastraColors.gold)),
                Text(
                  title,
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
        decoration: tabletDecoration(radius: 18, glow: true),
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
    canvas.drawPath(dim, Paint()..color = PastraColors.night.withValues(alpha: 0.7));
    if (f != null) {
      final ring = RRect.fromRectAndRadius(f, const Radius.circular(14));
      // A wide faint ring under a thin bright one: a glow without a blur.
      canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = PastraColors.gold.withValues(alpha: 0.2),
      );
      canvas.drawRRect(
        ring,
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
  const _OnlineClosedOverlay({
    required this.text,
    required this.button,
    required this.onBack,
    this.action,
    this.onAction,
  });

  final String text;
  final String button;
  final VoidCallback onBack;

  /// A second, main button (join the rematch).
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xEB111316),
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
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                if (action != null) OutlinedButton(onPressed: onBack, child: Text(button)),
                if (action != null)
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(action!),
                  )
                else
                  FilledButton(onPressed: onBack, child: Text(button)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Colourful paper pieces falling over the table (our pastra).
class _Confetti extends StatefulWidget {
  const _Confetti({super.key});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _ConfettiPainter(_c, widget.key.hashCode), size: Size.infinite),
    );
  }
}

class _Piece {
  _Piece(Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.35,
        speed = 0.55 + r.nextDouble() * 0.6,
        drift = (r.nextDouble() - 0.5) * 0.25,
        spin = (r.nextDouble() - 0.5) * 18,
        w = 5 + r.nextDouble() * 5,
        h = 8 + r.nextDouble() * 8,
        color = _ConfettiPainter.colors[r.nextInt(_ConfettiPainter.colors.length)];

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double spin;
  final double w;
  final double h;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, int seed)
      : _pieces = List<_Piece>.generate(70, (i) => _Piece(Random(seed + i * 104729))),
        super(repaint: anim);

  static const List<Color> colors = <Color>[
    PastraColors.gold,
    PastraColors.goldLight,
    PastraColors.teal,
    PastraColors.coral,
    PastraColors.cream,
  ];

  final Animation<double> anim;
  final List<_Piece> _pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    if (t <= 0 || t >= 1 || size.isEmpty) return;
    final paint = Paint();
    for (final p in _pieces) {
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final y = -20 + (size.height + 40) * lt * p.speed * 1.4;
      final x = size.width * (p.x + p.drift * lt) + sin(lt * 9 + p.x * 20) * 14;
      final fade = lt > 0.8 ? (1 - lt) / 0.2 : 1.0;
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * lt);
      // A turning piece: its width shrinks and grows.
      final flip = cos(lt * 12 + p.x * 10).abs();
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.w * (0.3 + 0.7 * flip), height: p.h), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => false;
}
