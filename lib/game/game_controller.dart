import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/cards.dart';
import '../engine/game_state.dart';
import '../engine/pastra_ai.dart';
import '../engine/pastra_engine.dart';
import 'achievements.dart';
import 'app_settings.dart';
import 'online_link.dart';
import 'seats.dart';
import 'sound.dart';

/// A card that was just played and is about to capture [captured].
class PendingPlay {
  final int seat;
  final int card;
  final List<int> captured;

  const PendingPlay(this.seat, this.card, this.captured);
}

/// The latest card played, shown for a moment next to that player.
class LastMove {
  final int id;
  final int seat;
  final int card;
  final bool captured;

  const LastMove(this.id, this.seat, this.card, this.captured);
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
    this.link,
    this.isGuest = false,
    this.hostTurnSeconds = 0,
  }) : _state = state;

  /// Online connection (null in a local game).
  final OnlineLink? link;

  /// Online guest: the host runs the game, this controller only shows the
  /// states it receives and sends the player's moves.
  final bool isGuest;

  /// Online guest: the host's time limit per move (0 = none).
  final int hostTurnSeconds;

  bool get isOnline => link != null;

  /// Grows every time the game state changes (the online host publishes
  /// the new state when it sees a new value).
  int stateVersion = 0;

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

  LastMove? lastMove;

  /// Achievement being announced right now (id), then the waiting ones.
  String? achievementToast;
  final List<String> _toastQueue = <String>[];
  bool _toastRunning = false;

  /// Largest lead the other team had after a round of this game.
  int _maxDeficit = 0;

  /// Pastras the local player made in this round (for the statistics).
  int _roundPastras = 0;
  int _roundJackPastras = 0;
  Timer? _warnTimer;

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
  Duration? get turnLimit {
    final secs = isGuest ? hostTurnSeconds : settings.turnSeconds;
    return secs > 0 ? Duration(seconds: secs) : null;
  }

  int _eventCounter = 0;
  bool _busy = false;
  bool _started = false;
  bool _disposed = false;

  /// Online guest: a move was sent and the host has not answered yet.
  bool _sent = false;
  Timer? _sentTimer;

  /// Online host: seat whose move we are waiting for.
  int? _awaitingRemote;
  Timer? _offlineTimer;
  int _offlineTicks = 0;
  Timer? _autoNextTimer;
  final Map<int, int> _queuedMoves = <int, int>{};

  /// Online guest: the host left, the game cannot continue.
  bool onlineClosed = false;

  void markOnlineClosed() {
    if (onlineClosed) return;
    onlineClosed = true;
    _notify();
  }

  int get numPlayers => _state.numPlayers;

  bool get isTeamGame => _state.numPlayers == 4;

  bool get busy => _busy;

  bool get isHumanTurn =>
      _state.phase == GamePhase.playing &&
      !_busy &&
      pending == null &&
      _state.current == humanSeat &&
      !_sent &&
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
    if (isGuest) {
      _notify();
      return;
    }
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
    SoundFx.instance.play(Sfx.shuffle, volume: 0.8);
    _notify();
    await _wait(settings.sound ? 1000 : 400);
    final n = _state.table.length;
    for (var i = 1; i <= n; i++) {
      if (_disposed) return;
      tableShown = i;
      SoundFx.instance.play(Sfx.deal);
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
    if (isGuest) {
      _guestPlay(card);
      return;
    }
    _busy = true;
    _turnTimer?.cancel();
    _turnTimer = null;
    _warnTimer?.cancel();
    _warnTimer = null;
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
    stateVersion++;
    pending = null;
    landing = result.isCapture ? null : card;
    lastMove = LastMove(++_eventCounter, seat, card, result.isCapture);
    if (result.isPastra) {
      final event = PastraEvent(++_eventCounter, seat, result.pastraPoints);
      pastraEvent = event;
      SoundFx.instance.play(Sfx.pastra);
      if (settings.haptics) HapticFeedback.heavyImpact();
      if (seat == humanSeat) {
        _roundPastras++;
        if (Cards.isJack(card)) _roundJackPastras++;
      }
      _clearEventLater(event.id);
    } else {
      SoundFx.instance.play(result.isCapture ? Sfx.capture : Sfx.play);
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
      stateVersion++;
      SoundFx.instance.play(Sfx.deal);
      _notify();
      await _wait(700);
      if (_disposed) return;
    } else if (PastraEngine.roundCardsExhausted(_state)) {
      await _wait(300);
      if (_disposed) return;
      if (_state.table.isNotEmpty) {
        leftoverSeat = _state.lastCapturer >= 0 ? _state.lastCapturer : _state.dealer;
        PastraEngine.collectLeftovers(_state);
        stateVersion++;
        _notify();
        await _wait(1100);
        if (_disposed) return;
        leftoverSeat = null;
      }
      PastraEngine.scoreRound(_state);
      stateVersion++;
      final ourTeam = GameState.teamOf(humanSeat);
      final ours = _state.lastResult?.teams[ourTeam];
      settings.recordRound(
        score: ours?.total ?? 0,
        pastras: _roundPastras,
        jackPastras: _roundJackPastras,
      );
      final roundFacts = RoundFacts(
        score: ours?.total ?? 0,
        pastras: _roundPastras,
        jackPastras: _roundJackPastras,
        goodCards: (ours?.twoOfClubs ?? false) && (ours?.tenOfDiamonds ?? false),
      );
      _roundPastras = 0;
      _roundJackPastras = 0;
      lastMove = null;
      final deficit = _state.scores[1 - ourTeam] - _state.scores[ourTeam];
      if (deficit > _maxDeficit) _maxDeficit = deficit;
      GameFacts? gameFacts;
      if (_state.phase == GamePhase.gameOver) {
        final won = _state.winner == ourTeam;
        settings.recordGame(won: won, players: _state.numPlayers, level: seats[1].level);
        gameFacts = GameFacts(
          won: won,
          level: seats[1].level,
          players: _state.numPlayers,
          rounds: _state.round,
          target: _state.rules.targetScore,
          maxDeficit: _maxDeficit,
        );
        SoundFx.instance.play(won ? Sfx.win : Sfx.lose);
        settings.clearSavedGame();
      }
      _announce(settings.unlockAchievements(
        earnedAchievements(settings.stats, round: roundFacts, game: gameFacts),
      ));
      if (_state.phase != GamePhase.gameOver) _save();
      _busy = false;
      _notify();
      if (link != null && _state.phase == GamePhase.roundOver) {
        // Online: nobody waits forever for the host to tap "next round".
        _autoNextTimer?.cancel();
        _autoNextTimer = Timer(const Duration(seconds: 12), nextRound);
      }
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
    if (seats[seat].isRemote) {
      _waitForRemote(seat);
      return;
    }
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
    _warnTimer?.cancel();
    _warnTimer = null;
    if (seats[_state.current].isHuman) SoundFx.instance.play(Sfx.turn, volume: 0.7);
    final limit = turnLimit;
    if (limit == null || seats[_state.current].isBot) return;
    if (limit.inSeconds > 5) {
      final warnId = turnId;
      _warnTimer = Timer(limit - const Duration(seconds: 5), () {
        if (!_disposed && warnId == turnId && isHumanTurn) SoundFx.instance.play(Sfx.tick);
      });
    }
    final id = turnId;
    _turnTimer = Timer(limit, () {
      if (_disposed || id != turnId) return;
      final cur = _state.current;
      if (seats[cur].isRemote) {
        _remoteFallback(cur);
        return;
      }
      if (!isHumanTurn) return;
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
    if (isGuest) return;
    if (_state.phase != GamePhase.roundOver || _busy) return;
    _autoNextTimer?.cancel();
    PastraEngine.startNextRound(_state);
    stateVersion++;
    selected = null;
    _save();
    if (_isFreshRound) {
      _revealOpening();
    } else {
      _notify();
      _scheduleBot();
    }
  }

  /// Shows newly unlocked achievements one after another.
  Future<void> _announce(List<String> ids) async {
    _toastQueue.addAll(ids);
    if (_toastRunning) return;
    _toastRunning = true;
    while (_toastQueue.isNotEmpty && !_disposed) {
      achievementToast = _toastQueue.removeAt(0);
      _notify();
      await Future<void>.delayed(const Duration(milliseconds: 2800));
    }
    if (_disposed) return;
    achievementToast = null;
    _toastRunning = false;
    _notify();
  }

  void _clearEventLater(int id) {
    Future<void>.delayed(_duration(1500), () {
      if (_disposed || pastraEvent?.id != id) return;
      pastraEvent = null;
      notifyListeners();
    });
  }

  void _save() {
    if (link != null || _state.phase == GamePhase.gameOver) return;
    settings.saveGame(jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seats': seats.map((s) => s.toJson()).toList(),
        'state': _state.toJson(),
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // --------------------------------------------------------------- online

  /// Host: the player on [seat] wants to play [card].
  void submitRemoteMove(int seat, int card) {
    if (_disposed || isGuest) return;
    if (_state.phase != GamePhase.playing || _state.current != seat) return;
    if (!_state.hands[seat].contains(card)) return;
    if (_awaitingRemote != seat) {
      // The move came in before we started waiting (the host is still
      // finishing the previous animation): keep it for a moment.
      _queuedMoves[seat] = card;
      return;
    }
    _stopWaiting();
    _busy = true;
    _play(card);
  }

  void _waitForRemote(int seat) {
    _awaitingRemote = seat;
    final queued = _queuedMoves.remove(seat);
    if (queued != null && _state.hands[seat].contains(queued)) {
      submitRemoteMove(seat, queued);
      return;
    }
    _offlineTicks = 0;
    _offlineTimer?.cancel();
    _offlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _awaitingRemote != seat) return;
      if (link?.isRemoteOnline(seat) ?? true) {
        _offlineTicks = 0;
        return;
      }
      // Disconnected: after a few seconds a bot plays for that player.
      if (++_offlineTicks >= 4) _remoteFallback(seat);
    });
    _notify();
  }

  void _stopWaiting() {
    _awaitingRemote = null;
    _offlineTimer?.cancel();
    _offlineTimer = null;
  }

  /// Time ran out or the player is offline: a bot picks the card.
  void _remoteFallback(int seat) {
    if (_disposed || _awaitingRemote != seat || _busy) return;
    _stopWaiting();
    _busy = true;
    _runBot(seat);
  }

  /// Guest: asks the host to play [card].
  void _guestPlay(int card) {
    selected = null;
    _sent = true;
    _sentTimer?.cancel();
    // If the host never answers (move refused), the player may try again.
    _sentTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed || !_sent) return;
      _sent = false;
      _notify();
    });
    link?.sendMove(card);
    _notify();
  }

  /// Guest: the host sent a new state (already seen from our seat) and,
  /// optionally, what just happened (`move`, `pastra`, `leftover`; seats
  /// already translated to our numbering).
  void applyHostView(GameState next, Map<String, dynamic>? ev) {
    if (_disposed) return;
    final wasOver = _state.phase == GamePhase.gameOver;
    final turnChanged = next.current != _state.current ||
        next.cardsInHands != _state.cardsInHands ||
        next.phase != _state.phase;
    _state = next;
    stateVersion++;
    _sent = false;
    _sentTimer?.cancel();
    selected = null;
    pending = null;
    landing = null;
    tableShown = null;
    final mv = ev?['move'];
    if (mv is Map) {
      final id = (mv['id'] as num).toInt();
      if (lastMove?.id != id) {
        final isCapture = mv['cap'] == true;
        lastMove = LastMove(id, (mv['seat'] as num).toInt(), (mv['card'] as num).toInt(), isCapture);
        SoundFx.instance.play(isCapture ? Sfx.capture : Sfx.play);
      }
    }
    final pa = ev?['pastra'];
    if (pa is Map) {
      final id = (pa['id'] as num).toInt();
      if (pastraEvent?.id != id) {
        final event = PastraEvent(id, (pa['seat'] as num).toInt(), (pa['pts'] as num).toInt());
        pastraEvent = event;
        SoundFx.instance.play(Sfx.pastra);
        if (settings.haptics) HapticFeedback.heavyImpact();
        _clearEventLater(event.id);
      }
    }
    final lo = ev?['leftover'];
    leftoverSeat = lo is num ? lo.toInt() : null;
    if (_state.phase == GamePhase.playing && turnChanged) {
      turnId++;
      if (_state.current == humanSeat) SoundFx.instance.play(Sfx.turn, volume: 0.7);
    }
    if (_state.phase == GamePhase.gameOver && !wasOver) {
      SoundFx.instance.play(_state.winner == 0 ? Sfx.win : Sfx.lose);
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _turnTimer?.cancel();
    _warnTimer?.cancel();
    _offlineTimer?.cancel();
    _autoNextTimer?.cancel();
    _sentTimer?.cancel();
    link?.close();
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
