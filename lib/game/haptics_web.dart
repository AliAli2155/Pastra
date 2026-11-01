import 'dart:js_interop';

// The vibration helper in web/index.html (`window.pastraBuzz`): navigator.vibrate
// on Android, a haptic switch trick on iPhone (iOS 18+).

@JS('pastraBuzz')
external void _buzz(int ms);

/// [strength]: 0 = tick, 1 = light, 2 = medium, 3 = heavy.
void buzz(int strength) {
  try {
    _buzz(const <int>[8, 14, 26, 55][strength.clamp(0, 3)]);
  } catch (_) {}
}
