import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../engine/perspective.dart';
import '../l10n/social_strings.dart';
import 'online_service.dart';

/// A quick chat message shown next to a seat for a few seconds.
class ChatBubble {
  const ChatBubble(this.id, this.seat, this.message);

  final int id;

  /// Seat as seen on this screen (0 = me).
  final int seat;

  /// `m:<id>` or `e:<emoji>` (see [SocialStrings.chat]).
  final String message;
}

/// The social side of an online table: quick chat between the players and
/// the rematch (`rooms/<code>/chat`, `rooms/<code>/rematch`, `meta/next`).
class RoomSocial extends ChangeNotifier {
  RoomSocial({required this.code, required this.mySeat, required this.players}) {
    _chatSub = OnlineService.ref('rooms/$code/chat').onValue.listen(_onChat, onError: (Object _) {});
    _voteSub = OnlineService.ref('rooms/$code/rematch').onValue.listen(_onVotes, onError: (Object _) {});
    _nextSub = OnlineService.ref('rooms/$code/meta/next').onValue.listen((e) {
      final v = e.snapshot.value;
      final next = v is String && RegExp(r'^\d{4}$').hasMatch(v) ? v : null;
      if (next == nextCode) return;
      nextCode = next;
      _changed();
    }, onError: (Object _) {});
  }

  final String code;

  /// Real seat of this player.
  final int mySeat;
  final int players;

  /// The newest message of every seat (screen seats) that is still shown.
  final Map<int, ChatBubble> bubbles = <int, ChatBubble>{};

  /// Real seats that asked for a rematch.
  Set<int> rematchVotes = <int>{};

  /// The room of the rematch, once the host opened it.
  String? nextCode;

  StreamSubscription<DatabaseEvent>? _chatSub;
  StreamSubscription<DatabaseEvent>? _voteSub;
  StreamSubscription<DatabaseEvent>? _nextSub;
  final Map<int, int> _lastSeen = <int, int>{};
  bool _firstChat = true;
  int _bubbleId = 0;
  int _counter = 0;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  bool get iVoted => rematchVotes.contains(mySeat);

  /// Sends a quick message (at most one every 1.5 seconds).
  bool send(String message) {
    if (_disposed || SocialStrings('en').chat(message).isEmpty) return false;
    final now = DateTime.now();
    if (now.difference(_lastSent) < const Duration(milliseconds: 1500)) return false;
    _lastSent = now;
    _counter = now.millisecondsSinceEpoch > _counter ? now.millisecondsSinceEpoch : _counter + 1;
    _show(0, message);
    OnlineService.ref('rooms/$code/chat/s$mySeat')
        .set(<String, Object?>{'n': _counter, 'm': message})
        .catchError((Object _) {});
    return true;
  }

  /// Asks the host for another game at a new table.
  void voteRematch() {
    if (_disposed || iVoted) return;
    rematchVotes = <int>{...rematchVotes, mySeat};
    _changed();
    OnlineService.ref('rooms/$code/rematch/s$mySeat').set(true).catchError((Object _) {});
  }

  /// Host: tells the guests where the rematch is.
  Future<void> offerRematch(String newCode) async {
    nextCode = newCode;
    _changed();
    try {
      await OnlineService.ref('rooms/$code/meta/next').set(newCode).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  void _onChat(DatabaseEvent e) {
    final v = e.snapshot.value;
    final map = v is Map ? v : const <Object?, Object?>{};
    for (final entry in map.entries) {
      final key = '${entry.key}';
      final seat = int.tryParse(key.startsWith('s') ? key.substring(1) : '');
      final m = entry.value;
      if (seat == null || seat < 0 || seat >= players || m is! Map) continue;
      final n = (m['n'] as num?)?.toInt() ?? 0;
      final message = m['m'];
      if (n <= (_lastSeen[seat] ?? 0)) continue;
      _lastSeen[seat] = n;
      // Old messages (from before we came) and our own are not shown again.
      if (_firstChat || seat == mySeat || message is! String) continue;
      _show(rotateSeat(seat, mySeat, players), message);
    }
    _firstChat = false;
  }

  void _show(int screenSeat, String message) {
    final b = ChatBubble(++_bubbleId, screenSeat, message);
    bubbles[screenSeat] = b;
    _changed();
    Timer(const Duration(milliseconds: 3600), () {
      if (_disposed || bubbles[screenSeat]?.id != b.id) return;
      bubbles.remove(screenSeat);
      _changed();
    });
  }

  void _onVotes(DatabaseEvent e) {
    final v = e.snapshot.value;
    final votes = <int>{};
    if (v is Map) {
      for (final entry in v.entries) {
        final key = '${entry.key}';
        final seat = int.tryParse(key.startsWith('s') ? key.substring(1) : '');
        if (seat != null && entry.value == true) votes.add(seat);
      }
    }
    if (iVoted) votes.add(mySeat);
    rematchVotes = votes;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _chatSub?.cancel();
    _voteSub?.cancel();
    _nextSub?.cancel();
    super.dispose();
  }
}
