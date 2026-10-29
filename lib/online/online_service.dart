import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart';

/// Starts Firebase on first use and signs the player in anonymously.
class OnlineService {
  static bool _ready = false;

  /// Returns null when online play is available, otherwise a short
  /// description of what is missing.
  static Future<String?> ensureReady() async {
    if (_ready) return null;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      // The difference between this clock and the server's (scheduled
      // tournaments must agree on the time).
      FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((e) {
        final v = e.snapshot.value;
        if (v is num) _offset = v.toInt();
      });
      _ready = true;
      return null;
    } catch (e) {
      return '$e';
    }
  }

  static int _offset = 0;

  /// The server's time in milliseconds since the epoch (estimated).
  static int get serverNow => DateTime.now().millisecondsSinceEpoch + _offset;

  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  static DatabaseReference ref(String path) => FirebaseDatabase.instance.ref(path);

  /// Keeps `path` (a boolean) true while this device is connected, and false
  /// when the connection drops. Reconnecting sets it back to true.
  static Stream<void> keepOnline(List<String> paths) {
    final connected = FirebaseDatabase.instance.ref('.info/connected');
    return connected.onValue.asyncMap((event) async {
      if (event.snapshot.value != true) return;
      for (final path in paths) {
        final r = FirebaseDatabase.instance.ref(path);
        await r.onDisconnect().set(false);
        await r.set(true);
      }
    });
  }
}

/// Something went wrong while creating or joining a room.
class OnlineException implements Exception {
  /// `notFound`, `started`, `full` or `network`.
  final String code;

  const OnlineException(this.code);

  @override
  String toString() => 'OnlineException($code)';
}
