import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/rules_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Fx.forceLow();
  // A tap that misses its widget fails the test.
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('every rules section fits in the rail on a phone held sideways', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(SettingsScope(settings: settings, child: const MaterialApp(home: RulesScreen())));
    await tester.pumpAndSettle();

    // The last section is on the screen and can be tapped without scrolling.
    final last = find.text('In the app').first;
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(390));
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
