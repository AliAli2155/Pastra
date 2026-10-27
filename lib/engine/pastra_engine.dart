import 'dart:math';

import 'cards.dart';
import 'game_state.dart';
import 'rules.dart';

/// Result of playing a card (or of previewing it).
class MovePreview {
  final int card;

  /// Table cards taken by [card]. Empty = the card stays on the table.
  final List<int> captured;

  /// Pastra bonus scored by this play (0 = no pastra).
  final int pastraPoints;

  const MovePreview(this.card, this.captured, this.pastraPoints);

  bool get isCapture => captured.isNotEmpty;

  bool get isPastra => pastraPoints > 0;
}

/// Pure game logic. Everything here is deterministic for a given state, so the
/// same code can run on a server for online games.
class PastraEngine {
  PastraEngine._();

  static const int tableCardsAtStart = 4;

  /// Creates a game and deals the first round. With [firstDealer] omitted the
  /// last seat deals, so seat 0 (the local player) plays first.
  static GameState newGame({
    required PastraRules rules,
    required int numPlayers,
    required int seed,
    int? firstDealer,
  }) {
    assert(numPlayers == 2 || numPlayers == 4);
    final s = GameState(
      rules: rules,
      numPlayers: numPlayers,
      seed: seed,
      dealer: firstDealer ?? numPlayers - 1,
    );
    startRound(s);
    return s;
  }

  /// Shuffles, opens the four table cards and deals the first hands.
  ///
  /// * Pile game: the bottom card of the deck is turned face up ("kapak
  ///   altı") and stays visible under the deck; it is the very last card
  ///   dealt, so it goes to the dealer. Four cards are opened; the last one
  ///   is the top card. A jack may not be the top card: it goes face up
  ///   under the deck and another card is opened.
  /// * Sum game: four cards side by side; a jack is buried back in the deck
  ///   and replaced.
  static void startRound(GameState s) {
    final rng = Random(s.seed * 7919 + s.round);
    final deck = List<int>.generate(Cards.deckSize, (i) => i)..shuffle(rng);
    final table = <int>[];
    final exposed = <int>[];
    if (s.rules.isPile) {
      exposed.add(deck.first);
      while (table.length < tableCardsAtStart) {
        final c = deck.removeLast();
        if (table.length == tableCardsAtStart - 1 && Cards.isJack(c)) {
          deck.insert(0, c);
          exposed.add(c);
        } else {
          table.add(c);
        }
      }
    } else {
      while (table.length < tableCardsAtStart) {
        final c = deck.removeLast();
        if (Cards.isJack(c)) {
          deck.insert(0, c);
        } else {
          table.add(c);
        }
      }
    }
    s.deck = deck;
    s.table = table;
    s.exposed = exposed;
    s.hands = List<List<int>>.generate(s.numPlayers, (_) => <int>[]);
    s.piles = <List<int>>[<int>[], <int>[]];
    s.pastraCards = <List<int>>[<int>[], <int>[]];
    s.pastraPoints = <int>[0, 0];
    s.pileSeat = <int>[-1, -1];
    s.lastCapturer = -1;
    s.dealNumber = 0;
    s.phase = GamePhase.playing;
    s.winner = -1;
    s.lastResult = null;
    dealHands(s);
    s.current = (s.dealer + 1) % s.numPlayers;
  }

  /// Deals [PastraRules.cardsPerDeal] cards to everybody, starting after the
  /// dealer. No cards go to the table on re-deals.
  static void dealHands(GameState s) {
    for (var k = 0; k < s.rules.cardsPerDeal; k++) {
      for (var i = 1; i <= s.numPlayers; i++) {
        if (s.deck.isEmpty) return;
        s.hands[(s.dealer + i) % s.numPlayers].add(s.deck.removeLast());
      }
    }
    s.dealNumber++;
  }

  /// Nothing has been played yet in this round: the opening table cards and
  /// full hands. (The pile game shows the opening cards side by side until
  /// the first card is played.)
  static bool isOpeningPosition(GameState s) =>
      s.phase == GamePhase.playing &&
      s.dealNumber == 1 &&
      s.piles[0].isEmpty &&
      s.piles[1].isEmpty &&
      s.table.length == tableCardsAtStart &&
      s.cardsInHands == s.numPlayers * s.rules.cardsPerDeal;

  static bool needsDeal(GameState s) =>
      s.phase == GamePhase.playing && s.handsEmpty && s.deck.isNotEmpty;

  static bool roundCardsExhausted(GameState s) =>
      s.phase == GamePhase.playing && s.handsEmpty && s.deck.isEmpty;

  /// Table cards captured when [card] is played onto [table].
  ///
  /// * Pile game: a card of the same rank as the top card (the last one), or
  ///   a jack, takes the whole pile.
  /// * Sum game: see [sumCapture].
  static List<int> captureFor(PastraRules rules, List<int> table, int card) {
    if (table.isEmpty) return const <int>[];
    if (rules.isPile) {
      if (Cards.isJack(card) || Cards.rank(card) == Cards.rank(table.last)) {
        return List<int>.of(table);
      }
      return const <int>[];
    }
    return sumCapture(table, card);
  }

  /// Capture in the sum game.
  ///
  /// * Jack: takes the whole table.
  /// * Queen / king: take every table card of the same rank.
  /// * Ace..10: take every group of numeral cards whose values add up to the
  ///   card's value (a single equal card is such a group). Groups may not
  ///   share cards; the largest possible capture is taken, ties broken by
  ///   points (so 2♣ / 10♦ / aces are preferred).
  static List<int> sumCapture(List<int> table, int card) {
    if (table.isEmpty) return const <int>[];
    final r = Cards.rank(card);
    if (r == Cards.jack) return List<int>.of(table);
    if (r > 10) return table.where((c) => Cards.rank(c) == r).toList();

    final nums = table.where(Cards.isNumeral).toList();
    final n = nums.length;
    if (n == 0) return const <int>[];

    // Every subset of numeral table cards that sums to r, as bit masks.
    final subsets = <int>[];
    void collect(int start, int sum, int mask) {
      for (var i = start; i < n; i++) {
        final ns = sum + Cards.rank(nums[i]);
        if (ns > r) continue;
        final nm = mask | (1 << i);
        if (ns == r) {
          subsets.add(nm);
        } else {
          collect(i + 1, ns, nm);
        }
      }
    }

    collect(0, 0, 0);
    if (subsets.isEmpty) return const <int>[];

    final byLowest = List<List<int>>.generate(n, (_) => <int>[]);
    for (final m in subsets) {
      var i = 0;
      while (((m >> i) & 1) == 0) {
        i++;
      }
      byLowest[i].add(m);
    }

    var bestMask = 0;
    var bestCount = -1;
    var bestPoints = -1;
    void search(int i, int used) {
      if (i == n) {
        var count = 0;
        var pts = 0;
        for (var j = 0; j < n; j++) {
          if (((used >> j) & 1) == 1) {
            count++;
            pts += Cards.points(nums[j]);
          }
        }
        if (count > bestCount || (count == bestCount && pts > bestPoints)) {
          bestCount = count;
          bestPoints = pts;
          bestMask = used;
        }
        return;
      }
      if (((used >> i) & 1) == 1) {
        search(i + 1, used);
        return;
      }
      for (final m in byLowest[i]) {
        if ((m & used) == 0) search(i + 1, used | m);
      }
      search(i + 1, used);
    }

    search(0, 0);
    final out = <int>[];
    for (var j = 0; j < n; j++) {
      if (((bestMask >> j) & 1) == 1) out.add(nums[j]);
    }
    return out;
  }

  /// Pastra bonus for taking the whole [table] with [card] (ignores the
  /// last-card rule).
  static int pastraValue(PastraRules rules, List<int> table, int card) {
    if (rules.isPile) {
      // Only a lone card can be a pastra.
      if (table.length != 1) return 0;
      final under = table.first;
      if (Cards.isJack(card)) {
        if (Cards.isJack(under)) return rules.jackOnJackPoints;
        return rules.jackSweepIsPastra ? rules.pastraPoints : 0;
      }
      return Cards.rank(card) == Cards.rank(under) ? rules.pastraPoints : 0;
    }
    if (Cards.isJack(card)) {
      if (table.length == 1 && Cards.isJack(table.first)) return rules.jackOnJackPoints;
      return rules.jackSweepIsPastra ? rules.pastraPoints : 0;
    }
    return rules.pastraPoints;
  }

  /// True when the coming play is the final card of the round.
  static bool isLastCardOfRound(GameState s) => s.deck.isEmpty && s.cardsInHands == 1;

  /// What would happen if the current player played [card].
  static MovePreview preview(GameState s, int card) {
    final captured = captureFor(s.rules, s.table, card);
    var pts = 0;
    if (captured.isNotEmpty && captured.length == s.table.length) {
      pts = pastraValue(s.rules, s.table, card);
      if (pts > 0 && !s.rules.pastraOnLastCard && isLastCardOfRound(s)) pts = 0;
    }
    return MovePreview(card, captured, pts);
  }

  /// Plays [card] for the current player. Does not deal or finish the round:
  /// call [needsDeal] / [roundCardsExhausted] afterwards (or [advanceAuto]).
  static MovePreview applyMove(GameState s, int card) {
    if (s.phase != GamePhase.playing) {
      throw StateError('The round is not being played');
    }
    final p = s.current;
    final hand = s.hands[p];
    if (!hand.contains(card)) {
      throw ArgumentError('Card $card is not in the hand of seat $p');
    }
    final pv = preview(s, card);
    hand.remove(card);
    final team = GameState.teamOf(p);
    if (pv.isCapture) {
      final taken = pv.captured.toSet();
      s.table = s.table.where((c) => !taken.contains(c)).toList();
      s.piles[team]
        ..addAll(pv.captured)
        ..add(card);
      s.lastCapturer = p;
      if (s.pileSeat[team] < 0) s.pileSeat[team] = p;
      if (pv.isPastra) {
        s.pastraPoints[team] += pv.pastraPoints;
        s.pastraCards[team].add(card);
      }
    } else {
      s.table = List<int>.of(s.table)..add(card);
    }
    s.current = (p + 1) % s.numPlayers;
    return pv;
  }

  /// End of round: cards left on the table go to the last capturer.
  static void collectLeftovers(GameState s) {
    if (s.table.isEmpty) return;
    final seat = s.lastCapturer >= 0 ? s.lastCapturer : s.dealer;
    final team = GameState.teamOf(seat);
    if (s.pileSeat[team] < 0) s.pileSeat[team] = seat;
    s.piles[team].addAll(s.table);
    s.table = <int>[];
  }

  /// Scores the piles as they are now (does not change the state).
  static RoundResult computeRoundResult(GameState s) {
    final rules = s.rules;
    final counts = <int>[s.piles[0].length, s.piles[1].length];
    final teams = <TeamRoundScore>[];
    for (var t = 0; t < 2; t++) {
      final pile = s.piles[t];
      var aces = 0;
      var jacks = 0;
      var honours = 0;
      for (final c in pile) {
        final r = Cards.rank(c);
        if (r == Cards.ace) {
          aces++;
        } else if (r == Cards.jack) {
          jacks++;
        }
        if (r == Cards.ace || r >= 10) honours++;
      }
      final two = pile.contains(Cards.twoOfClubs);
      final ten = pile.contains(Cards.tenOfDiamonds);
      final most = counts[t] > counts[1 - t];
      final cardPoints = rules.isPile ? honours : aces + jacks;
      final total = (most ? PastraRules.mostCardsBonus : 0) +
          cardPoints +
          (two ? rules.twoOfClubsBonus : 0) +
          (ten ? rules.tenOfDiamondsBonus : 0) +
          s.pastraPoints[t];
      teams.add(TeamRoundScore(
        cards: counts[t],
        aces: aces,
        jacks: jacks,
        honours: honours,
        twoOfClubs: two,
        tenOfDiamonds: ten,
        pastras: s.pastraCards[t].length,
        pastraPoints: s.pastraPoints[t],
        mostCards: most,
        total: total,
      ));
    }
    return RoundResult(teams);
  }

  /// Adds the round to the game totals and decides whether the game is over.
  static RoundResult scoreRound(GameState s) {
    final res = computeRoundResult(s);
    s.scores[0] += res.teams[0].total;
    s.scores[1] += res.teams[1].total;
    s.lastResult = res;
    final top = max(s.scores[0], s.scores[1]);
    if (top >= s.rules.targetScore && s.scores[0] != s.scores[1]) {
      s.phase = GamePhase.gameOver;
      s.winner = s.scores[0] > s.scores[1] ? 0 : 1;
    } else {
      s.phase = GamePhase.roundOver;
    }
    return res;
  }

  /// Next round: the deal passes to the next seat.
  static void startNextRound(GameState s) {
    if (s.phase != GamePhase.roundOver) {
      throw StateError('The round is not over');
    }
    s.dealer = (s.dealer + 1) % s.numPlayers;
    s.round++;
    startRound(s);
  }

  /// Deals or finishes the round if needed. Used by simulations and bots; the
  /// UI does the same steps one by one so it can animate them.
  static void advanceAuto(GameState s) {
    if (needsDeal(s)) {
      dealHands(s);
    } else if (roundCardsExhausted(s)) {
      collectLeftovers(s);
      scoreRound(s);
    }
  }

  /// Cards [seat] has not seen: in other hands or still in the deck (the
  /// face-up "kapak altı" cards count as seen).
  static List<int> unseenFor(GameState s, int seat) {
    final seen = List<bool>.filled(Cards.deckSize, false);
    for (final c in s.hands[seat]) {
      seen[c] = true;
    }
    for (final c in s.table) {
      seen[c] = true;
    }
    for (final pile in s.piles) {
      for (final c in pile) {
        seen[c] = true;
      }
    }
    for (final c in s.exposed) {
      seen[c] = true;
    }
    final out = <int>[];
    for (var i = 0; i < Cards.deckSize; i++) {
      if (!seen[i]) out.add(i);
    }
    return out;
  }
}
