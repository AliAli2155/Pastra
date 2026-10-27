import 'game_state.dart';

/// [s] as seen from [seat]: the seats are renumbered so that [seat] becomes
/// seat 0 (the player at the bottom of the screen). The turn order stays the
/// same. When [seat] is odd the two teams swap places too, because the
/// local player's team is always team 0.
///
/// Used by online play: the host keeps the real seat numbers and sends each
/// guest the state rotated for that guest, so the screen code never needs to
/// know which seat the local player really has.
GameState rotateStateFor(GameState s, int seat) {
  final c = s.copy();
  if (seat == 0) return c;
  final n = s.numPlayers;
  final swap = seat.isOdd;

  int seatMap(int old) => old < 0 ? old : (old - seat + n) % n;
  List<T> byTeam<T>(List<T> l) => swap ? <T>[l[1], l[0]] : l;

  final hands = List<List<int>>.generate(n, (_) => <int>[]);
  for (var i = 0; i < n; i++) {
    hands[seatMap(i)] = c.hands[i];
  }
  c.hands = hands;
  c.current = seatMap(s.current);
  c.dealer = seatMap(s.dealer);
  c.lastCapturer = seatMap(s.lastCapturer);
  c.pileSeat = byTeam(s.pileSeat.map(seatMap).toList());
  c.piles = byTeam(c.piles);
  c.pastraCards = byTeam(c.pastraCards);
  c.pastraPoints = byTeam(c.pastraPoints);
  c.scores = byTeam(c.scores);
  if (swap && s.winner >= 0) c.winner = 1 - s.winner;
  final result = s.lastResult;
  if (result != null && swap) {
    c.lastResult = RoundResult(<TeamRoundScore>[result.teams[1], result.teams[0]]);
  }
  return c;
}

/// Seat number of [real] as seen from [seat] (see [rotateStateFor]).
int rotateSeat(int real, int seat, int numPlayers) =>
    real < 0 ? real : (real - seat + numPlayers) % numPlayers;
