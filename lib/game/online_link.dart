/// What a [GameController] needs from the online connection.
abstract class OnlineLink {
  /// Guest: asks the host to play [card].
  void sendMove(int card);

  /// Host: is the player on [seat] still connected?
  bool isRemoteOnline(int seat);

  /// Chips each player pays to play at this table (0 = free).
  int get stake;

  /// Called when the game screen closes.
  void close();
}
