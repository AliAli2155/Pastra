import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/app.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/online/social_service.dart';
import 'package:pastra/ui/widgets/invite_banner.dart';
import 'package:pastra/ui/widgets/playing_card.dart';
import 'package:pastra/ui/widgets/wallet_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // The daily bonus dialog would cover the home screen.
  dailyBonusAutoShow = false;
  // No Firebase in the tests.
  inviteListenerEnabled = false;
  SocialService.enabled = false;

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
    await tester.tap(find.text('Quick game'));
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

  testWidgets('offline offers a quick game and the tournament', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false, 'tutorialDone': true});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Quick game'), findsOneWidget);
    expect(find.text('Tournament'), findsOneWidget);

    await tester.tap(find.text('Tournament'));
    await tester.pumpAndSettle();
    // The round names are column headers (the current one is also in the status panel).
    expect(find.text('Quarterfinal'), findsWidgets);
    expect(find.text('Semifinal'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('Play match'), findsOneWidget);
    expect(settings.tournamentJson, isNotNull);
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

  testWidgets('a new player gets the tutorial first, then is asked their name', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(PastraApp(settings: settings));
    await tester.pumpAndSettle();

    // "Play" opens the guided first game directly.
    await tester.tap(find.text('Play'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Your cards'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text("Let's play!"));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text("What's your name?"), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ali');
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(settings.tutorialDone, isTrue);
    expect(settings.playerName, 'Ali');
    expect(find.text('Your turn'), findsOneWidget);
  });

  for (final size in <Size>[const Size(844, 390), const Size(390, 760)]) {
    testWidgets('daily quests and level path fit on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false, 'xp': 900});
      final settings = await AppSettings.load();
      await tester.pumpWidget(PastraApp(settings: settings));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Daily quests'));
      await tester.tap(find.text('Daily quests'));
      await tester.pumpAndSettle();
      expect(find.text('Daily chest'), findsOneWidget);
      expect(find.text('Collect'), findsNWidgets(3));
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(settings.playerLevel >= 5 ? 'Card player' : 'Novice'));
      await tester.tap(find.text(settings.playerLevel >= 5 ? 'Card player' : 'Novice'));
      await tester.pumpAndSettle();
      // The gold title is drawn twice (outline and fill).
      expect(find.text('Level path'), findsWidgets);
      expect(find.text('You are here'), findsOneWidget);
    });
  }
}
