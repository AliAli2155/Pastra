import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/online/social_service.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/friends_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Fx.forceLow();
  SocialService.enabled = false;

  testWidgets('without friends the code card and the hint are one centred column', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      SettingsScope(settings: settings, child: const MaterialApp(home: FriendsScreen())),
    );
    await tester.pumpAndSettle();

    final code = tester.getRect(find.text('Your player code'));
    final hint = tester.getRect(find.textContaining('the people you meet show up here'));
    // The hint sits under the code card, both in the middle of the screen.
    expect(hint.top, greaterThan(code.bottom));
    expect(hint.center.dx, closeTo(480, 2));
  });
}
