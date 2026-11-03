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
  static int _badWindows = 0;

  /// Frames judged together (about two seconds).
  static const int _windowFrames = 120;

  /// Slow stretches in a row before the quality goes down. A short heavy
  /// moment (a pastra with confetti, a new screen) can spoil two of them at
  /// most, so only a device that keeps missing frames gets low quality.
  static const int _badWindowsNeeded = 3;

  static FxMode get mode => _mode;

  /// Sets the quality chosen in the settings.
  static void setMode(FxMode mode) {
    _mode = mode;
    _autoLow = false;
    _seen = 0;
    _window = 0;
    _slow = 0;
    _badWindows = 0;
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

  /// Starts watching the frame times (used by [FxMode.auto]). Not in debug
  /// builds: they are always slow (above all on the web) and would always
  /// end up in low quality.
  static void watch() {
    if (_watching || kDebugMode) return;
    _watching = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        addFrame(t.totalSpan);
      }
    });
  }

  /// Counts one drawn frame that took [span] (automatic quality only).
  @visibleForTesting
  static void addFrame(Duration span) {
    if (_mode != FxMode.auto || _autoLow) return;
    _seen++;
    // The start-up and the first screen changes are always a little slow.
    if (_seen < 150) return;
    _window++;
    if (span.inMilliseconds > 34) _slow++;
    if (_window < _windowFrames) return;
    // One frame in four took longer than two refreshes: a slow stretch.
    _badWindows = _slow >= _windowFrames ~/ 4 ? _badWindows + 1 : 0;
    _window = 0;
    _slow = 0;
    if (_badWindows >= _badWindowsNeeded) {
      _autoLow = true;
      _apply();
    }
  }
}
