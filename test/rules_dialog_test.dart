import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/widgets/rules_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Fx.forceLow();
  // A tap that misses its widget fails the test.
  WidgetController.hitTestWarningShouldBeFatal = true;

  Future<AppSettings> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => showRulesDialog(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return settings;
  }

  for (final size in <Size>[const Size(844, 390), const Size(960, 540), const Size(390, 760)]) {
    testWidgets('game rules fit on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await open(tester, size);
      expect(tester.takeException(), isNull);
      // Wide or low screens show everything at once, without scrolling:
      // the first and the last setting can both be tapped.
      if (size.width >= 720) {
        expect(find.byType(Scrollable), findsNothing);
        await tester.tap(find.text('Pile'));
        await tester.tap(find.text('Reset rules'));
      }
      final ok = tester.getRect(find.text('OK'));
      expect(ok.bottom, lessThanOrEqualTo(size.height), reason: 'OK is cut off');
    });
  }

  testWidgets('reset rules also sets the time back', (tester) async {
    final settings = await open(tester, const Size(960, 540));
    settings.turnSeconds = 0;
    settings.rules = settings.rules.copyWith(targetScore: 51);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset rules'));
    await tester.pumpAndSettle();
    expect(settings.turnSeconds, AppSettings.defaultTurnSeconds);
    expect(settings.rules.targetScore, PastraRules.pileDefaults.targetScore);
  });
}
