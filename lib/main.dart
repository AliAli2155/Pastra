import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'build_info.dart';
import 'game/app_settings.dart';
import 'game/crash_reports.dart';
import 'game/freeze_log.dart';
import 'game/game_controller.dart';
import 'game/sound.dart';
import 'online/leaderboard.dart';
import 'ui/fx/fx.dart';
import 'ui/widgets/playing_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android and iOS: crash reports (never holds up the start for long).
  await startCrashReports().timeout(const Duration(seconds: 4), onTimeout: () {});
  if (!kIsWeb) {
    // Played sideways, like okey / uno apps, full screen.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  final settings = await AppSettings.load();
  // The pictures of the court cards that have one (before the first card).
  await CourtImages.load();
  // Load the sounds in the background so the first ones are not late.
  unawaited(SoundFx.instance.preload());
  GameController.onGameFinished = (s) {
    FreezeLog.note('leaderboard update');
    unawaited(Leaderboard.submit(s));
  };
  // Automatic graphics quality: switches decoration off on slow devices.
  Fx.watch();
  // Preview builds: freezes are recorded (Settings > About).
  if (BuildInfo.preview) unawaited(FreezeLog.start());
  runApp(PastraApp(settings: settings));
}
