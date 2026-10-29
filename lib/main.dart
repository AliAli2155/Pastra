import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'game/app_settings.dart';
import 'game/game_controller.dart';
import 'game/sound.dart';
import 'online/leaderboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    // Played sideways, like okey / uno apps, full screen.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  final settings = await AppSettings.load();
  // Load the sounds in the background so the first ones are not late.
  SoundFx.instance.preload();
  GameController.onGameFinished = (s) => Leaderboard.submit(s);
  runApp(PastraApp(settings: settings));
}
