import 'dart:math';

import 'cards.dart';
import 'game_state.dart';
import 'pastra_engine.dart';
import 'rules.dart';

enum AiLevel { easy, medium, hard }

/// Computer players. They only use information a real player has: their own
/// hand, the table, the captured cards and how many cards everybody holds.
///
/// * easy   – mostly greedy, with mistakes.
/// * medium – greedy + estimates what the next opponent can take.
/// * hard   – Monte Carlo: deals the unseen cards many ways, plays the rest of
///   the deal out, blends that with the medium heuristic. In 1v1 with an empty
///   deck it searches the last cards exactly.
class PastraAI {
  PastraAI._();

  /// Value of one captured card for the majority race (3 points over ~27 cards).
  static const double cardWeight = 0.2;

  static const int hardSamples = 24;
  static const double hardBlend = 0.5;

  static double _captureValue(PastraRules rules, Iterable<int> cards) {
    var v = 0.0;
    for (final c in cards) {
      v += cardWeight + rules.pointsOf(c);
    }
    return v;
  }

  static int chooseCard(GameState s, AiLevel level, Random rng) {
    final seat = s.current;
    final hand = s.hands[seat];
    if (hand.length == 1) return hand.first;
    if (level == AiLevel.hard) {
      if (s.numPlayers == 2 && s.deck.isEmpty && s.cardsInHands <= 8) {
        return endgameChoice(s, seat);
      }
      return _monteCarloChoice(s, seat, rng);
    }
    if (level == AiLevel.easy && rng.nextDouble() < 0.35) {
      return hand[rng.nextInt(hand.length)];
    }
    final unseen = PastraEngine.unseenFor(s, seat);
    var best = hand.first;
    var bestScore = double.negativeInfinity;
    for (final c in hand) {
      var score = evaluate(s, seat, c, level, unseen);
      if (level == AiLevel.easy) {
        score += (rng.nextDouble() - 0.5) * 3;
      } else {
        score += (rng.nextDouble() - 0.5) * 0.6;
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  /// P(none of k particular cards is among h cards drawn from U unseen cards).
  static double probNone(int unseen, int k, int h) {
    final draws = h > unseen ? unseen : h;
    var p = 1.0;
    for (var i = 0; i < draws; i++) {
      final remaining = unseen - k - i;
      if (remaining <= 0) return 0;
      p *= remaining / (unseen - i);
    }
    return p;
  }

  static double _oppCaptureValue(GameState s, List<int> table, int card) {
    final cap = PastraEngine.captureFor(s.rules, table, card);
    if (cap.isEmpty) return 0;
    var v = _captureValue(s.rules, cap) + cardWeight + s.rules.pointsOf(card);
    if (cap.length == table.length) {
      v += PastraEngine.pastraValue(s.rules, table, card);
    }
    return v;
  }

  /// Expected gain of the next player (always an opponent) on [tableAfter].
  static double expectedOpponentGain(
      GameState s, int seat, List<int> tableAfter, List<int> unseen) {
    if (tableAfter.isEmpty) return 0;
    final opp = (seat + 1) % s.numPlayers;
    // Cards everybody knows the opponent holds (the kapak altı).
    final known = s.hands[opp].where(s.exposed.contains).toList();
    final h = s.hands[opp].length - known.length;
    final u = unseen.length;
    final values = <double>[];
    final probs = <double>[];
    for (final c in known) {
      final v = _oppCaptureValue(s, tableAfter, c);
      if (v > 0) {
        values.add(v);
        probs.add(1.0);
      }
    }
    if ((h == 0 || u == 0) && values.isEmpty) return 0;
    final byRank = <int, List<int>>{};
    if (h > 0) {
      for (final c in unseen) {
        byRank.putIfAbsent(Cards.rank(c), () => <int>[]).add(c);
      }
    }
    for (final cards in byRank.values) {
      var sum = 0.0;
      for (final c in cards) {
        sum += _oppCaptureValue(s, tableAfter, c);
      }
      final v = sum / cards.length;
      if (v > 0) {
        values.add(v);
        probs.add(1 - probNone(u, cards.length, h));
      }
    }
    final order = List<int>.generate(values.length, (i) => i)
      ..sort((a, b) => values[b].compareTo(values[a]));
    var e = 0.0;
    var noneBetter = 1.0;
    for (final i in order) {
      e += values[i] * probs[i] * noneBetter;
      noneBetter *= 1 - probs[i];
    }
    return e;
  }

  /// Heuristic score of playing [card] (higher is better).
  static double evaluate(
      GameState s, int seat, int card, AiLevel level, List<int> unseen) {
    final pv = PastraEngine.preview(s, card);
    var gain = 0.0;
    List<int> tableAfter;
    if (pv.isCapture) {
      gain = _captureValue(s.rules, pv.captured) + cardWeight + s.rules.pointsOf(card) + pv.pastraPoints;
      final taken = pv.captured.toSet();
      tableAfter = s.table.where((c) => !taken.contains(c)).toList();
    } else {
      tableAfter = List<int>.of(s.table)..add(card);
    }
    final riskWeight = level == AiLevel.easy
        ? 0.25
        : level == AiLevel.medium
            ? 0.7
            : 1.0;
    var score = gain - riskWeight * expectedOpponentGain(s, seat, tableAfter, unseen);
    if (!pv.isCapture) score -= 0.3 * s.rules.pointsOf(card);
    if (level != AiLevel.easy && Cards.isJack(card) && s.hands[seat].length > 1) {
      // A jack sweeps whatever builds up later: keep it if possible.
      score -= s.deck.isNotEmpty ? 1.2 : 0.6;
    }
    if (level == AiLevel.hard && s.deck.isEmpty && pv.isCapture) {
      score += 0.15 * tableAfter.length;
    }
    return score;
  }

  // ---------------------------------------------------------------- hard

  /// Fast policy used inside the Monte Carlo playouts.
  static int _greedyCard(GameState s) {
    final hand = s.hands[s.current];
    var best = hand.first;
    var bestScore = double.negativeInfinity;
    for (final c in hand) {
      final pv = PastraEngine.preview(s, c);
      double score;
      if (pv.isCapture) {
        score = _captureValue(s.rules, pv.captured) +
            cardWeight +
            s.rules.pointsOf(c) +
            pv.pastraPoints -
            (Cards.isJack(c) ? 1.0 : 0.0);
      } else {
        score = -s.rules.pointsOf(c).toDouble() -
            (Cards.isJack(c) ? 2.0 : 0.0) -
            (s.table.isEmpty ? 1.0 : 0.0);
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  /// A copy of [s] where the cards [seat] cannot see are dealt at random.
  static GameState _sampleWorld(GameState s, int seat, Random rng) {
    final w = s.copy();
    final unseen = PastraEngine.unseenFor(s, seat)..shuffle(rng);
    var k = 0;
    for (var p = 0; p < s.numPlayers; p++) {
      if (p == seat) continue;
      final known = s.hands[p].where(s.exposed.contains).toList();
      final n = s.hands[p].length - known.length;
      w.hands[p] = <int>[...known, ...unseen.sublist(k, k + n)];
      k += n;
    }
    // The known kapak altı cards stay at the bottom of the deck.
    w.deck = <int>[...s.deck.where(s.exposed.contains), ...unseen.sublist(k)];
    return w;
  }

  /// Plays the current deal to its end; value for [team].
  static double _playout(GameState w, int team) {
    var v = 0.0;
    while (!w.handsEmpty) {
      final p = w.current;
      final c = _greedyCard(w);
      final pv = PastraEngine.applyMove(w, c);
      if (pv.isCapture) {
        final g = _captureValue(w.rules, pv.captured) + cardWeight + w.rules.pointsOf(c) + pv.pastraPoints;
        v += GameState.teamOf(p) == team ? g : -g;
      }
    }
    if (w.deck.isEmpty) {
      // Last deal: leftovers and the majority are decided now.
      final before = _diff(PastraEngine.computeRoundResult(w), team);
      PastraEngine.collectLeftovers(w);
      v += _diff(PastraEngine.computeRoundResult(w), team) - before;
    }
    return v;
  }

  static double _diff(RoundResult r, int team) =>
      (r.teams[team].total - r.teams[1 - team].total).toDouble();

  static int _monteCarloChoice(GameState s, int seat, Random rng) {
    final hand = s.hands[seat];
    final team = GameState.teamOf(seat);
    final totals = List<double>.filled(hand.length, 0);
    for (var k = 0; k < hardSamples; k++) {
      final world = _sampleWorld(s, seat, rng);
      for (var i = 0; i < hand.length; i++) {
        final w = world.copy();
        final c = hand[i];
        final pv = PastraEngine.applyMove(w, c);
        var v = pv.isCapture
            ? _captureValue(s.rules, pv.captured) + cardWeight + s.rules.pointsOf(c) + pv.pastraPoints
            : 0.0;
        v += _playout(w, team);
        totals[i] += v;
      }
    }
    final unseen = PastraEngine.unseenFor(s, seat);
    var best = hand.first;
    var bestScore = double.negativeInfinity;
    for (var i = 0; i < hand.length; i++) {
      final score = totals[i] / hardSamples +
          hardBlend * evaluate(s, seat, hand[i], AiLevel.hard, unseen);
      if (score > bestScore) {
        bestScore = score;
        best = hand[i];
      }
    }
    return best;
  }

  /// 1v1 with an empty deck: the opponent holds exactly the unseen cards, so
  /// the rest of the round can be searched exactly (alpha-beta).
  static int endgameChoice(GameState s, int seat) {
    final opp = (seat + 1) % 2;
    final root = s.copy();
    // Inferred, not peeked: everything unseen plus the known kapak altı.
    root.hands[opp] = <int>[
      ...PastraEngine.unseenFor(s, seat),
      ...s.hands[opp].where(s.exposed.contains),
    ];
    final team = GameState.teamOf(seat);
    var best = root.hands[seat].first;
    var bestValue = double.negativeInfinity;
    for (final c in List<int>.of(root.hands[seat])) {
      final child = root.copy();
      PastraEngine.applyMove(child, c);
      final v = _minimax(child, team, double.negativeInfinity, double.infinity);
      if (v > bestValue) {
        bestValue = v;
        best = c;
      }
    }
    return best;
  }

  static double _minimax(GameState s, int team, double alpha, double beta) {
    if (s.handsEmpty) {
      final t = s.copy();
      PastraEngine.collectLeftovers(t);
      return _diff(PastraEngine.computeRoundResult(t), team);
    }
    final maximizing = GameState.teamOf(s.current) == team;
    var a = alpha;
    var b = beta;
    var value = maximizing ? double.negativeInfinity : double.infinity;
    for (final c in List<int>.of(s.hands[s.current])) {
      final child = s.copy();
      PastraEngine.applyMove(child, c);
      final v = _minimax(child, team, a, b);
      if (maximizing) {
        if (v > value) value = v;
        if (value > a) a = value;
      } else {
        if (v < value) value = v;
        if (value < b) b = value;
      }
      if (b <= a) break;
    }
    return value;
  }
}
