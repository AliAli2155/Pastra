import 'cards.dart';
import 'game_state.dart';
import 'pastra_engine.dart';

/// What kind of chance a play let slip.
enum MissKind { pastra, capture }

/// A better play the player did not make (for the review after the game).
class MissedChance {
  const MissedChance({
    required this.round,
    required this.played,
    required this.better,
    required this.kind,
    required this.points,
    required this.cards,
  });

  final int round;

  /// The card that was played and the one that would have been better.
  final int played;
  final int better;
  final MissKind kind;

  /// Pastra bonus (pastra) or card points taken (capture).
  final int points;

  /// Table cards the better card would have taken.
  final int cards;
}

/// Looks for clearly better plays: a pastra that was possible but not made,
/// or a good capture where a card was simply dropped on the table. Keeping a
/// jack is often wise, so a jack only counts for a big capture.
class MoveReview {
  MoveReview._();

  /// Reviews [played] for the player to move in [s] (the state before the
  /// move). Returns null when the play was fine.
  static MissedChance? review(GameState s, int played) {
    if (s.phase != GamePhase.playing || s.table.isEmpty) return null;
    final hand = s.hands[s.current];
    if (!hand.contains(played)) return null;
    final mine = PastraEngine.preview(s, played);

    MovePreview? bestPastra;
    for (final c in hand) {
      if (c == played) continue;
      final pv = PastraEngine.preview(s, c);
      if (!pv.isPastra || pv.pastraPoints <= mine.pastraPoints) continue;
      if (bestPastra == null || pv.pastraPoints > bestPastra.pastraPoints) bestPastra = pv;
    }
    if (bestPastra != null) {
      return MissedChance(
        round: s.round,
        played: played,
        better: bestPastra.card,
        kind: MissKind.pastra,
        points: bestPastra.pastraPoints,
        cards: bestPastra.captured.length,
      );
    }
    if (mine.isCapture) return null;

    MovePreview? best;
    var bestValue = 0;
    for (final c in hand) {
      if (c == played) continue;
      final pv = PastraEngine.preview(s, c);
      if (!pv.isCapture) continue;
      final pts = pointsOf(pv.captured);
      final n = pv.captured.length;
      final worth = Cards.isJack(c) ? (n >= 5 || pts >= 2) : (pts >= 1 || n >= 3);
      if (!worth) continue;
      final value = pts * 2 + n;
      if (value > bestValue) {
        bestValue = value;
        best = pv;
      }
    }
    if (best == null) return null;
    return MissedChance(
      round: s.round,
      played: played,
      better: best.card,
      kind: MissKind.capture,
      points: pointsOf(best.captured),
      cards: best.captured.length,
    );
  }

  static int pointsOf(List<int> cards) {
    var p = 0;
    for (final c in cards) {
      p += Cards.points(c);
    }
    return p;
  }
}
