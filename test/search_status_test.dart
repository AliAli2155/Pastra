import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/l10n/online_strings.dart';
import 'package:pastra/ui/premium/premium.dart';
import 'package:pastra/ui/screens/online_screen.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 360, child: child)),
        ),
      );

  testWidgets('searching: a clock and a quiet button to play the computer', (tester) async {
    const t = OnlineStrings('en');
    await tester.pumpWidget(host(SearchStatus(label: t.searching, hint: t.nobodyYetHint, seconds: 7, botLabel: t.playVsBot, onBot: () {})));
    expect(find.text('0:07'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GoldButton), findsNothing);
  });

  for (final lang in AppSettings.languages) {
    testWidgets('nobody came: the computer is offered ($lang)', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = OnlineStrings(lang);
      var played = false;
      await tester.pumpWidget(host(SearchStatus(
        label: t.nobodyYet,
        hint: t.nobodyYetHint,
        seconds: 25,
        offerBot: true,
        botLabel: t.playVsBot,
        onBot: () => played = true,
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('0:25'), findsOneWidget);
      // No endless spinner any more.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byType(GoldButton));
      expect(played, isTrue);
    });
  }

  testWidgets('a tournament match offers no computer', (tester) async {
    const t = OnlineStrings('en');
    await tester.pumpWidget(host(SearchStatus(label: 'Waiting for Eleni', hint: t.nobodyYetHint)));
    expect(find.byType(GoldButton), findsNothing);
    expect(find.text(t.playVsBot), findsNothing);
  });
}
