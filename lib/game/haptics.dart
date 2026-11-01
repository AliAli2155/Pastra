import 'haptics_stub.dart' if (dart.library.js_interop) 'haptics_web.dart' as impl;

/// Vibration feedback that also works in the browser.
class Haptics {
  Haptics._();

  /// Selecting a card.
  static void tick() => impl.buzz(0);

  /// Playing a card.
  static void play() => impl.buzz(1);

  /// Taking cards.
  static void capture() => impl.buzz(2);

  /// A pastra, a quad, the end of a game.
  static void big() => impl.buzz(3);
}
