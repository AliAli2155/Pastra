import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/app.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/online/social_service.dart';
import 'package:pastra/ui/premium/premium.dart';
import 'package:pastra/ui/widgets/invite_banner.dart';
import 'package:pastra/ui/widgets/wallet_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Normal graphics quality here (no `Fx.forceLow`): the lobby's entrance and
/// the dialog animations play, and must stop by themselves.
void main() {
  dailyBonusAutoShow = false;
  inviteListenerEnabled = false;
  SocialService.enabled = false;

  double opacityAbove(WidgetTester tester, Finder finder) =>
      tester.widget<Opacity>(find.ancestor(of: finder, matching: find.byType(Opacity)).first).opacity;

  testWidgets('the lobby comes in once and then stands still', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false, 'tutorialDone': true});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 100));

    // On its way: the hero card is still fading in, the tiles have not come.
    expect(opacityAbove(tester, find.text('Play')), lessThan(1));
    expect(opacityAbove(tester, find.text('Settings')), 0);

    // pumpAndSettle only returns when nothing moves any more.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(opacityAbove(tester, find.text('Play')), 1);
    expect(opacityAbove(tester, find.text('Settings')), 1);
  });

  testWidgets('a dialog grows in and the sections of a page fade in', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false, 'tutorialDone': true});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 40));
    final pop = tester.widget<ScaleTransition>(
      find.descendant(of: find.byType(DialogPop), matching: find.byType(ScaleTransition)).first,
    );
    expect(pop.scale.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(pop.scale.value, 1);
    expect(find.text('Quick game'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Quick game'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pump(const Duration(milliseconds: 60));
    // The new section is on its way in.
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.text('Ελληνικά'), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('Ελληνικά'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
