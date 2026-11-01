// Not on the web: the phone's own haptic engine (see haptics_web.dart).

import 'package:flutter/services.dart';

/// [strength]: 0 = tick, 1 = light, 2 = medium, 3 = heavy.
void buzz(int strength) {
  switch (strength) {
    case 0:
      HapticFeedback.selectionClick();
    case 1:
      HapticFeedback.lightImpact();
    case 2:
      HapticFeedback.mediumImpact();
    default:
      HapticFeedback.heavyImpact();
  }
}
