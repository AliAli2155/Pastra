import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/ui/ege/widgets.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/round_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screens.dart';

/// Online, after a round: everybody's picture lights up in gold once they
/// are ready; "I'm ready" is the local player's button.
void main() {
  quietApp();

  Future<void> show(WidgetTester tester, Widget sheet, {Size size = const Size(844, 390), String language = 'en'}) async {
    await loadRealFonts();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': language, 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: buildPastraTheme(), debugShowCheckedModeBanner: false, home: sheet),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  double opacityOf(WidgetTester tester, String name) {
    final avatar = find.ancestor(of: find.text(name), matching: find.byType(ReadyAvatar));
    return tester.widget<AnimatedOpacity>(find.descendant(of: avatar, matching: find.byType(AnimatedOpacity))).opacity;
  }

  BoxDecoration ringOf(WidgetTester tester, String name) {
    final avatar = find.ancestor(of: find.text(name), matching: find.byType(ReadyAvatar));
    return tester.widget<AnimatedContainer>(find.descendant(of: avatar, matching: find.byType(AnimatedContainer)).first).decoration!
        as BoxDecoration;
  }

  testWidgets('who is ready shines in gold, the others stay dim', (tester) async {
    await show(tester, roundReadySheet());
    expect(find.byType(ReadyAvatar), findsNWidgets(4));
    for (final name in <String>['Ali', 'Eleni']) {
      expect(opacityOf(tester, name), 1, reason: name);
      expect(ringOf(tester, name).color, PastraColors.gold);
      expect(ringOf(tester, name).boxShadow, isNotEmpty, reason: 'a soft glow');
    }
    for (final name in <String>['Konstantina', 'Nikos']) {
      expect(opacityOf(tester, name), lessThan(0.5), reason: name);
      expect(ringOf(tester, name).color, isNot(PastraColors.gold));
      expect(ringOf(tester, name).boxShadow, isEmpty);
    }
    // I said I am ready: the button waits for the others.
    expect(find.text('Waiting for the others…'), findsOneWidget);
    expect(find.textContaining('Next round in'), findsOneWidget);
    expect(find.text('Next round'), findsNothing, reason: 'online: no "next round" button');
  });

  testWidgets('"I\'m ready" is pressed once', (tester) async {
    var pressed = 0;
    await show(tester, roundReadySheet(ready: const <int>{2}, onReady: () => pressed++));
    expect(opacityOf(tester, 'Ali'), lessThan(0.5));
    await tester.tap(find.text("I'm ready"));
    expect(pressed, 1);

    // The controller marks me ready: my ring lights up, the button waits.
    await show(tester, roundReadySheet(ready: const <int>{0, 2}, onReady: () => pressed++));
    expect(opacityOf(tester, 'Ali'), 1);
    await tester.tap(find.text('Waiting for the others…'));
    expect(pressed, 1);
  });

  for (final language in <String>['de', 'el', 'ru', 'tr', 'ar']) {
    testWidgets('fits on a small phone held sideways in $language', (tester) async {
      await show(tester, roundReadySheet(ready: const <int>{2}), size: const Size(667, 375), language: language);
      expect(find.byType(ReadyAvatar), findsNWidgets(4));
      final button = tester.getRect(find.byType(BevelButton));
      expect(button.bottom, lessThanOrEqualTo(375));
      // Nothing has to be scrolled to reach it.
      for (final e in find.byType(Scrollable).evaluate()) {
        expect(((e as StatefulElement).state as ScrollableState).position.maxScrollExtent, 0);
      }
    });
  }
}
