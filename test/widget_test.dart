import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/app.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/ui/widgets/playing_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home screen in Greek', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'el', 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();
    expect(find.text('Πάστρα'), findsWidgets);
    expect(find.text('Παίξε'), findsOneWidget);
    expect(find.text('Κανόνες'), findsOneWidget);
  });

  testWidgets('starting a 1v1 game shows the table and the hand', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false, 'tutorialDone': true});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline'));
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
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
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

  testWidgets('the first game starts with the tutorial', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    // The sheet closes, then the game screen opens on the next frames.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Your cards'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text("Let's play!"));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(settings.tutorialDone, isTrue);
    expect(find.text('Your turn'), findsOneWidget);
  });
}
