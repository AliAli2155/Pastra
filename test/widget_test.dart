import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/app.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/ui/widgets/playing_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home screen in Greek', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'el'});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();
    expect(find.text('Πάστρα'), findsWidgets);
    expect(find.text('Νέο παιχνίδι'), findsOneWidget);
    expect(find.text('Κανόνες'), findsOneWidget);
  });

  testWidgets('starting a 1v1 game shows the table and the hand', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en'});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    // The four opening cards are put on the pile one by one.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 4 on the pile + 6 in my hand + 6 opponent cards + 36 in the deck.
    expect(find.byType(PlayingCardView), findsNWidgets(52));
    expect(find.text('Your turn'), findsOneWidget);
  });

  testWidgets('settings screen switches the language', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en'});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ελληνικά'));
    await tester.pumpAndSettle();
    expect(settings.language, 'el');
    expect(find.text('Ρυθμίσεις'), findsOneWidget);
  });
}
