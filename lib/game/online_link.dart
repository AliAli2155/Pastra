import '../online/room_social.dart';

/// What a [GameController] needs from the online connection.
abstract class OnlineLink {
  /// Guest: asks the host to play [card].
  void sendMove(int card);

  /// Guest: tells the host the player is ready for the round after [round].
  void sendReady(int round);

  /// Host: is the player on [seat] still connected?
  bool isRemoteOnline(int seat);

  /// Host: these seats are now played by a bot (their player is gone);
  /// the guests show it.
  void reportStandIns(Set<int> seats);

  /// Chips each player pays to play at this table (0 = free).
  int get stake;

  /// Quick chat and rematch of the table.
  RoomSocial get social;

  /// The room code.
  String get code;

  /// Number of seats at the table.
  int get players;

  /// Called when the game screen closes.
  void close();
}
