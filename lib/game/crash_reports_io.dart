// Android and iOS: Firebase Crashlytics (see crash_reports.dart).

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../build_info.dart';
import '../firebase_options.dart';

Future<void> startCrashReports() async {
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    if (kDebugMode) return;
    await crashlytics.setCustomKey('channel', BuildInfo.channel);
    if (BuildInfo.commit.isNotEmpty) await crashlytics.setCustomKey('commit', BuildInfo.commit);
    // Errors in the game's code: shown as before (in the log), and reported.
    FlutterError.onError = (details) => unawaited(crashlytics.recordFlutterError(details));
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(crashlytics.recordError(error, stack));
      return true;
    };
  } catch (_) {
    // No Firebase (no connection to Google Play services, a test): the game
    // starts anyway, without crash reports.
  }
}
