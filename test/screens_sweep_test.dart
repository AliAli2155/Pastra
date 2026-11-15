import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';

import 'support/screens.dart';

/// Every screen of the app, in every language, at the sizes Ali checks (a
/// phone held sideways, a small and a big window), drawn with the app's own
/// fonts: nothing may overflow and nothing may throw.
void main() {
  quietApp();

  const sizes = <Size>[Size(844, 390), Size(960, 540), Size(1280, 720)];
  for (final size in sizes) {
    for (final language in AppSettings.languages) {
      testWidgets('every screen in $language at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await loadRealFonts();
        final problems = <String>[];
        for (final screen in sweepScreens) {
          await pumpSweepScreen(tester, screen, size, language);
          // It really is on the screen.
          if (find.byType(Scaffold).evaluate().isEmpty) problems.add('${screen.name}: nothing shown');
          final error = tester.takeException();
          if (error != null) {
            final where = <String>[
              for (final r in tester.allRenderObjects)
                if (r is RenderFlex && r.toString().contains('OVERFLOWING')) '${r.debugCreator}'.split('\n').first,
            ];
            problems.add('${screen.name}: $error ${where.take(1).join()}');
          }
          await leaveSweepScreen(tester);
          tester.takeException();
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  }
}
