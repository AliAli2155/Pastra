/// What a [GameController] needs from the online connection.
abstract class OnlineLink {
  /// Guest: asks the host to play [card].
  void sendMove(int card);

  /// Host: is the player on [seat] still connected?
  bool isRemoteOnline(int seat);

  /// Called when the game screen closes.
  void close();
}
