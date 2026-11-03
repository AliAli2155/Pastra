import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// How much decoration and animation is drawn (graphics quality).
enum FxMode { auto, high, low }

/// Graphics quality for the whole app. In [FxMode.auto] the frame times are
/// watched, and when the device keeps missing frames the decoration (moving
/// stars and waves, sparks, soft shadows) is switched off by itself.
/// Widgets listen to [low] and draw the cheaper version.
class Fx {
  Fx._();

  /// True when decorative effects should be reduced.
  static final ValueNotifier<bool> low = ValueNotifier<bool>(false);

  static FxMode _mode = FxMode.auto;
  static bool _autoLow = false;
  static bool _forced = false;
  static bool _watching = false;
  static int _seen = 0;
  static int _window = 0;
  static int _slow = 0;

  static FxMode get mode => _mode;

  /// Sets the quality chosen in the settings.
  static void setMode(FxMode mode) {
    _mode = mode;
    _autoLow = false;
    _seen = 0;
    _window = 0;
    _slow = 0;
    _apply();
  }

  static bool _wantLow() {
    if (_forced) return true;
    return switch (_mode) {
      FxMode.low => true,
      FxMode.high => false,
      FxMode.auto => _autoLow,
    };
  }

  static void _apply() {
    final value = _wantLow();
    if (low.value != value) low.value = value;
  }

  /// Tests: no endless animations (they would never let `pumpAndSettle`
  /// finish).
  @visibleForTesting
  static void forceLow() {
    _forced = true;
    _apply();
  }

  /// Starts watching the frame times (used by [FxMode.auto]).
  static void watch() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      if (_mode != FxMode.auto || _autoLow) return;
      for (final t in timings) {
        _seen++;
        // The start-up and the first screen changes are always a little slow.
        if (_seen < 150) continue;
        _window++;
        if (t.totalSpan.inMilliseconds > 34) _slow++;
        if (_window >= 120) {
          // One frame in five took longer than two refreshes: too slow.
          if (_slow >= 24) {
            _autoLow = true;
            _apply();
            return;
          }
          _window = 0;
          _slow = 0;
        }
      }
    });
  }
}
