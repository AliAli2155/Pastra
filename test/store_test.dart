import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/economy.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/store_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Fx.forceLow();

  test('turning the clock back gives no second daily bonus', () {
    expect(Economy.nextStreak(lastDay: 100, streak: 3, today: 99), isNull);
    expect(Economy.nextStreak(lastDay: 100, streak: 3, today: 40), isNull);
  });

  test('free chips: a clock that was ahead does not lock them for long', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'chips': 500});
    final settings = await AppSettings.load();
    final now = DateTime(2026, 11, 9, 12);
    // Collected while the device clock was two days ahead.
    expect(settings.claimFreeChips(now.add(const Duration(days: 2))), greaterThan(0));
    // Back at the right time: at most one wait.
    expect(settings.freeChipsAt(now), now.add(Economy.freeChipsEvery));
    expect(settings.claimFreeChips(now), 0);
    expect(settings.claimFreeChips(now.add(Economy.freeChipsEvery)), greaterThan(0));
  });

  Future<AppSettings> open(WidgetTester tester, Size size, {int chips = 100000}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'language': 'en',
      'sound': false,
      'chips': chips,
      'diamonds': 20,
    });
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      SettingsScope(settings: settings, child: const MaterialApp(home: StoreScreen())),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  const tabs = <String>[
    'Daily bonus',
    'VIP',
    'Offers',
    'Tables',
    'Card backs',
    'Diamonds → chips',
    'Chip packs',
    'Diamond packs',
  ];

  for (final size in <Size>[const Size(844, 390), const Size(390, 760), const Size(1280, 720)]) {
    testWidgets('every section opens without overflow on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await open(tester, size);
      for (final tab in tabs) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }

  test('every theme without a level is sold (or comes with VIP / a pack)', () {
    for (final t in TableTheme.values) {
      if (Progression.tableLevel.containsKey(t)) continue;
      expect(Economy.itemForTable(t), isNotNull, reason: t.name);
    }
    for (final b in CardBackStyle.values) {
      if (Progression.backLevel.containsKey(b)) continue;
      expect(Economy.itemForBack(b), isNotNull, reason: b.name);
    }
    for (final bundle in Economy.bundles) {
      for (final id in bundle.items) {
        expect(Economy.itemById(id), isNotNull, reason: id);
      }
    }
    for (final id in Economy.vipItems) {
      expect(Economy.itemById(id)?.source, ItemSource.vip, reason: id);
    }
  });

  testWidgets('a VIP table cannot be bought with chips; the dialog leads to VIP', (tester) async {
    final settings = await open(tester, const Size(960, 540));
    final vip = Economy.itemById('t_vip')!;
    expect(settings.buy(vip), isFalse);
    await tester.tap(find.text('Tables').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('VIP gold'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIP gold'));
    await tester.pumpAndSettle();
    expect(find.text('Comes with VIP'), findsOneWidget);
    await tester.tap(find.text('See VIP'));
    await tester.pumpAndSettle();
    expect(find.text('Pastra VIP'), findsOneWidget);
  });

  testWidgets('a table is bought after asking and is put on at once', (tester) async {
    final settings = await open(tester, const Size(960, 540));
    final ocean = Economy.items.firstWhere((i) => i.table == TableTheme.ocean);
    await tester.tap(find.text('Tables').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    expect(find.text('Buy Ocean?'), findsOneWidget);
    // Nothing is paid before the answer.
    expect(settings.chips, 100000);

    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(settings.owns(ocean.id), isTrue);
    expect(settings.tableTheme, TableTheme.ocean);
    expect(settings.chips, 100000 - ocean.chips);
    expect(find.text('In use'), findsOneWidget);
  });

  testWidgets('too dear: the dialog tells what is missing and sells nothing', (tester) async {
    final settings = await open(tester, const Size(960, 540), chips: 1000);
    await tester.tap(find.text('Tables').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    expect(find.text('You still need'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(settings.chips, 1000);
    expect(settings.owns('t_ocean'), isFalse);
  });
}
