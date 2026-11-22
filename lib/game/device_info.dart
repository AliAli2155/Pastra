import 'package:flutter/foundation.dart';

import 'device_info_stub.dart' if (dart.library.js_interop) 'device_info_web.dart' as platform;

/// Which browser or system the app runs on (for the freeze log).
String deviceDescription() {
  final browser = platform.browserDescription();
  return browser ?? '${defaultTargetPlatform.name} app';
}
