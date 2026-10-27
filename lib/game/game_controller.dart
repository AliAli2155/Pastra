import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/game_state.dart';
import '../engine/pastra_ai.dart';
import '../engine/pastra_engine.dart';
import 'app_settings.dart';
import 'seats.dart';

/// A card that was just played and is about to capture [captured].
class PendingPlay {
  final int seat;
  final int card;
  final List<int> captured;

  const PendingPlay(this.seat, this.card, this.captured);
}

/// Shown as the big "ΠΑΣΤΡΑ!" banner.
class PastraEvent {
  final int id;
  final int seat;
  final int points;

  const PastraEvent(this.id, this.seat, this.points);
}

/// Drives one game: human input, bot turns, deals, scoring and saving.
/// The UI only reads the fields and calls the public methods.
class GameController extends ChangeNotifier {
  GameController({
    required this.settings,
    required this.seats,
    required GameState state,
  }) : _state = state;

  /// The local player always sits on seat 0.
  static const int humanSeat = 0;

  factory GameController.newGame(AppSettings settings, {required int players, required AiLevel level}) {
    final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    final state = PastraEngine.newGame(
      rules: settings.rules,
      numPlayers: players,
      seed: seed,
    );
    return GameController(
      settings: settings,
      seats: SeatInfo.lineup(players, level),
      state: state,
    );
  }

  /// Restores the saved game, or returns null if there is none / it is broken.
  static GameController? fromSaved(AppSettings settings) {
    final raw = settings.savedGame;
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final state = GameState.fromJson(Map<String, dynamic>.from(json['state'] as Map));
      final seats = (json['seats'] as List)
          .map((e) => SeatInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (seats.length != state.numPlayers || state.phase == GamePhase.gameOver) return null;
      return GameController(settings: settings, seats: seats, state: state);
    } catch (_) {
      return null;
    }
  }

  final AppSettings settings;
  final List<SeatInfo> seats;
  final Random _rng = Random();
  GameState _state;

  GameState get state => _state;

  /// Card the human has tapped once (preview shown, tap again to play).
  int? selected;

  /// Card on its way to capture (shown on the table for a moment).
  PendingPlay? pending;

  PastraEvent? pastraEvent;

  /// Seat whose team just received the leftover table cards.
  int? leftoverSeat;

  /// Pile game, start of a round: how many of the four opening cards have
  /// been dealt so far (null = all of them). The others are still drawn on
  /// the deck.
  int? tableShown;

  /// Pile game: card that is still flying onto the pile. Until it lands the
  /// card below it keeps its face, so nothing disappears too early.
  int? landing;

  /// Changes every time a player's turn starts (the UI restarts the
  /// countdown when it changes).
  int turnId = 0;
  Timer? _turnTimer;

  /// Time each player has for a move, or null without a limit.
  Duration? get turnLimit =>
      settings.turnSeconds > 0 ? Duration(seconds: settings.turnSeconds) : null;

  int _eventCounter = 0;
  bool _busy = false;
  bool _started = false;
  bool _disposed = false;

  int get numPlayers => _state.numPlayers;

  bool get isTeamGame => _state.numPlayers == 4;

  bool get busy => _busy;

  bool get isHumanTurn =>
      _state.phase == GamePhase.playing &&
      !_busy &&
      pending == null &&
      _state.current == humanSeat &&
      _state.hands[humanSeat].isNotEmpty;

  /// A bot is choosing its card right now.
  bool get botThinking =>
      _busy &&
      pending == null &&
      tableShown == null &&
      _state.phase == GamePhase.playing &&
      seats[_state.current].isBot;

  MovePreview? get selectedPreview {
    final c = selected;
    if (c == null || !isHumanTurn) return null;
    return PastraEngine.preview(_state, c);
  }

  /// Table cards highlighted on screen: what the pending play takes, or what
  /// the selected card would take.
  Set<int> get highlighted {
    final p = pending;
    if (p != null) return p.captured.toSet();
    final pv = selectedPreview;
    if (pv != null) return pv.captured.toSet();
    return const <int>{};
  }

  void start() {
    if (_started) return;
    _started = true;
    if (PastraEngine.needsDeal(_state) || PastraEngine.roundCardsExhausted(_state)) {
      _busy = true;
      _afterMove();
    } else if (_isFreshRound) {
      _revealOpening();
    } else {
      _scheduleBot();
    }
  }

  /// Pile game, nothing played yet in this round.
  bool get _isFreshRound => _state.rules.isPile && PastraEngine.isOpeningPosition(_state);

  /// Deals the opening cards one by one, face up and side by side. They stay
  /// like that (the rightmost is the top card) until the first card is
  /// played; then they are gathered into the pile.
  Future<void> _revealOpening() async {
    _busy = true;
    tableShown = 0;
    _notify();
    await _wait(400);
    final n = _state.table.length;
    for (var i = 1; i <= n; i++) {
      if (_disposed) return;
      tableShown = i;
      _notify();
      await _wait(i == n ? 450 : 330);
    }
    if (_disposed) return;
    tableShown = null;
    _busy = false;
    _notify();
    _scheduleBot();
  }

  Duration _duration(int ms) => Duration(milliseconds: settings.fastAnimations ? (ms * 0.55).round() : ms);

  Future<void> _wait(int ms) => Future<void>.delayed(_duration(ms));

  // ---------------------------------------------------------------- input

  void tapHandCard(int card) {
    if (!isHumanTurn || !_state.hands[humanSeat].contains(card)) return;
    if (selected == card) {
      _play(card);
      return;
    }
    selected = card;
    if (settings.haptics) HapticFeedback.selectionClick();
    _notify();
  }

  /// Shows what [card] would take (used when a drag starts).
  void select(int card) {
    if (!isHumanTurn || !_state.hands[humanSeat].contains(card) || selected == card) return;
    selected = card;
    if (settings.haptics) HapticFeedback.selectionClick();
    _notify();
  }

  /// Plays [card] right away (a card dragged onto the table).
  void playCard(int card) {
    if (!isHumanTurn || !_state.hands[humanSeat].contains(card)) return;
    _play(card);
  }

  void clearSelection() {
    if (selected == null) return;
    selected = null;
    _notify();
  }

  void playSelected() {
    final c = selected;
    if (c != null && isHumanTurn) _play(c);
  }

  // ----------------------------------------------------------------- flow

  Future<void> _play(int card) async {
    _busy = true;
    _turnTimer?.cancel();
    _turnTimer = null;
    final seat = _state.current;
    final pv = PastraEngine.preview(_state, card);
    selected = null;
    if (pv.isCapture) {
      pending = PendingPlay(seat, card, pv.captured);
      _notify();
      await _wait(650);
      if (_disposed) return;
    }
    final result = PastraEngine.applyMove(_state, card);
    pending = null;
    landing = result.isCapture ? null : card;
    if (result.isPastra) {
      final event = PastraEvent(++_eventCounter, seat, result.pastraPoints);
      pastraEvent = event;
      if (settings.haptics) HapticFeedback.mediumImpact();
      _clearEventLater(event.id);
    }
    _notify();
    await _wait(result.isCapture ? 450 : 380);
    if (_disposed) return;
    if (landing != null) {
      landing = null;
      _notify();
    }
    await _afterMove();
  }

  Future<void> _afterMove() async {
    if (PastraEngine.needsDeal(_state)) {
      await _wait(250);
      if (_disposed) return;
      PastraEngine.dealHands(_state);
      _notify();
      await _wait(700);
      if (_disposed) return;
    } else if (PastraEngine.roundCardsExhausted(_state)) {
      await _wait(300);
      if (_disposed) return;
      if (_state.table.isNotEmpty) {
        leftoverSeat = _state.lastCapturer >= 0 ? _state.lastCapturer : _state.dealer;
        PastraEngine.collectLeftovers(_state);
        _notify();
        await _wait(1100);
        if (_disposed) return;
        leftoverSeat = null;
      }
      PastraEngine.scoreRound(_state);
      if (_state.phase == GamePhase.gameOver) {
        settings.recordGame(won: _state.winner == GameState.teamOf(humanSeat));
        settings.clearSavedGame();
      } else {
        _save();
      }
      _busy = false;
      _notify();
      return;
    }
    _busy = false;
    _save();
    _notify();
    _scheduleBot();
  }

  void _scheduleBot() {
    if (_disposed || _busy || _state.phase != GamePhase.playing) return;
    _beginTurn();
    final seat = _state.current;
    if (!seats[seat].isBot) return;
    _busy = true;
    _notify();
    _runBot(seat);
  }

  /// A new turn: restart the countdown. When the human runs out of time a
  /// card is played for them (the selected one, or a sensible choice).
  void _beginTurn() {
    turnId++;
    _turnTimer?.cancel();
    _turnTimer = null;
    final limit = turnLimit;
    if (limit == null || seats[_state.current].isBot) return;
    final id = turnId;
    _turnTimer = Timer(limit, () {
      if (_disposed || id != turnId || !isHumanTurn) return;
      final hand = _state.hands[humanSeat];
      final pick = selected != null && hand.contains(selected)
          ? selected!
          : PastraAI.chooseCard(_state.copy(), AiLevel.medium, _rng);
      _play(pick);
    });
  }

  Future<void> _runBot(int seat) async {
    final level = seats[seat].level;
    await _wait(level == AiLevel.hard ? 450 : 700);
    if (_disposed) return;
    final snapshot = _state.copy();
    final seed = _rng.nextInt(1 << 30);
    int card;
    try {
      card = level == AiLevel.hard
          ? await _chooseInBackground(snapshot, level, seed)
          : PastraAI.chooseCard(snapshot, level, Random(seed));
    } catch (_) {
      card = PastraAI.chooseCard(snapshot, level, Random(seed));
    }
    if (_disposed) return;
    if (!_state.hands[seat].contains(card)) card = _state.hands[seat].first;
    await _play(card);
  }

  /// Runs the (slower) hard bot on a background isolate. `compute` also works
  /// on the web, where it simply runs on the main thread (a hard move takes
  /// only a few milliseconds).
  static Future<int> _chooseInBackground(GameState snapshot, AiLevel level, int seed) {
    return compute<_BotTask, int>(_runBotTask, _BotTask(snapshot, level, seed));
  }

  static int _runBotTask(_BotTask t) => PastraAI.chooseCard(t.state, t.level, Random(t.seed));

  /// Starts the next round after the summary.
  void nextRound() {
    if (_state.phase != GamePhase.roundOver || _busy) return;
    PastraEngine.startNextRound(_state);
    selected = null;
    _save();
    if (_isFreshRound) {
      _revealOpening();
    } else {
      _notify();
      _scheduleBot();
    }
  }

  void _clearEventLater(int id) {
    Future<void>.delayed(_duration(1500), () {
      if (_disposed || pastraEvent?.id != id) return;
      pastraEvent = null;
      notifyListeners();
    });
  }

  void _save() {
    if (_state.phase == GamePhase.gameOver) return;
    settings.saveGame(jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seats': seats.map((s) => s.toJson()).toList(),
        'state': _state.toJson(),
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _turnTimer?.cancel();
    super.dispose();
  }
}

/// Input of a background bot move (sent to another isolate on mobile).
class _BotTask {
  final GameState state;
  final AiLevel level;
  final int seed;

  const _BotTask(this.state, this.level, this.seed);
}
