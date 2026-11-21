import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/crash_reports.dart';

/// Crash reports never stand in the way of the game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without Firebase (here: no native side) the game starts anyway', () async {
    final before = FlutterError.onError;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await startCrashReports().timeout(const Duration(seconds: 5));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    // Nothing was taken over: errors are handled as before.
    expect(FlutterError.onError, same(before));
  });

  test('nothing happens on the computers (Windows, macOS, Linux)', () async {
    final before = FlutterError.onError;
    for (final platform in <TargetPlatform>[TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await startCrashReports();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
    expect(FlutterError.onError, same(before));
  });
}
