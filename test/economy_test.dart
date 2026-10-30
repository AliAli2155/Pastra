import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/economy.dart';
import 'package:pastra/l10n/shop_strings.dart';
import 'package:pastra/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('pot: each winner gets two stakes minus the table fee', () {
    expect(Economy.payout(100), 180);
    expect(Economy.payout(2500), 4500);
    expect(Economy.payout(0), 0);
  });

  test('salons get dearer and need higher levels', () {
    for (var i = 1; i < Economy.salons.length; i++) {
      expect(Economy.salons[i].stake, greaterThan(Economy.salons[i - 1].stake));
      expect(Economy.salons[i].minLevel, greaterThanOrEqualTo(Economy.salons[i - 1].minLevel));
    }
    expect(Economy.salons.first.free, isTrue);
    expect(Economy.salonFor(500).id, 'amateur');
    expect(Economy.salonFor(12345).id, 'friendly');
  });

  test('daily streak: grows on following days, restarts after a gap', () {
    expect(Economy.nextStreak(lastDay: -1, streak: 0, today: 100), 1);
    expect(Economy.nextStreak(lastDay: 99, streak: 3, today: 100), 4);
    expect(Economy.nextStreak(lastDay: 97, streak: 3, today: 100), 1);
    expect(Economy.nextStreak(lastDay: 100, streak: 3, today: 100), isNull);
    expect(Economy.streakDay(7), 7);
    expect(Economy.streakDay(8), 1);
    expect(Economy.dailyReward(1), Economy.dailyChips.first);
    expect(Economy.dailyDiamonds(7), Economy.day7Diamonds);
    expect(Economy.dailyDiamonds(6), 0);
    final day = Economy.dayNumber(DateTime(2026, 10, 30, 23, 59));
    expect(Economy.dayNumber(DateTime(2026, 10, 31, 0, 1)), day + 1);
  });

  test('free chips: more when almost broke', () {
    expect(Economy.freeChipsFor(50), Economy.rescueChips);
    expect(Economy.freeChipsFor(5000), Economy.freeChips);
  });

  test('cup prizes', () {
    expect(Economy.cupPrize(500, wins: 0, champion: false), 0);
    expect(Economy.cupPrize(500, wins: 1, champion: false), 500);
    expect(Economy.cupPrize(500, wins: 2, champion: false), 1000);
    expect(Economy.cupPrize(500, wins: 3, champion: true), 2000);
    expect(Economy.cupPrize(0, wins: 3, champion: true), 0);
    expect(Economy.cupFee('f'), 0);
    expect(Economy.offlineWin(AiLevel.hard), greaterThan(Economy.offlineWin(AiLevel.easy)));
  });

  test('store items have unique ids and one price', () {
    expect(Economy.items.map((i) => i.id).toSet(), hasLength(Economy.items.length));
    for (final i in Economy.items) {
      expect((i.chips > 0) != (i.diamonds > 0), isTrue, reason: i.id);
      expect((i.table != null) != (i.back != null), isTrue, reason: i.id);
    }
    expect(Economy.itemForTable(TableTheme.green), isNull);
    expect(Economy.itemForTable(TableTheme.royal)?.id, 't_royal');
  });

  test('number labels', () {
    expect(Economy.group(1234567), '1.234.567');
    expect(Economy.group(999), '999');
    expect(Economy.group(-2500), '-2.500');
    expect(Economy.short(2500), '2.500');
    expect(Economy.short(50000), '50K');
    expect(Economy.short(12500), '12.5K');
    expect(Economy.short(2500000), '2.5M');
  });

  test('store texts exist in every language', () {
    final en = ShopStrings.keysOf('en');
    expect(en, isNotEmpty);
    for (final lang in AppSettings.languages) {
      expect(ShopStrings.keysOf(lang), en, reason: lang);
    }
    for (final salon in Economy.salons) {
      expect(ShopStrings('tr').salonName(salon), isNot(startsWith('salon_')));
    }
  });

  test('wallet: start balance, daily bonus once a day, buying, level rewards', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'sound': false});
    final settings = await AppSettings.load();
    expect(settings.chips, Economy.startChips);
    expect(settings.diamonds, Economy.startDiamonds);

    final now = DateTime(2026, 10, 30, 12);
    final first = settings.claimDaily(now);
    expect(first?.day, 1);
    expect(settings.claimDaily(now.add(const Duration(hours: 1))), isNull);
    expect(settings.claimDaily(now.add(const Duration(days: 1)))?.day, 2);
    expect(settings.chips, Economy.startChips + Economy.dailyChips[0] + Economy.dailyChips[1]);

    expect(settings.claimFreeChips(now), Economy.freeChips);
    expect(settings.claimFreeChips(now.add(const Duration(hours: 1))), 0);

    // A store table: locked until bought, then usable.
    final royal = Economy.itemForTable(TableTheme.royal)!;
    expect(settings.isUnlocked(TableTheme.royal), isFalse);
    expect(settings.buy(royal), isFalse); // not enough diamonds
    settings.addWallet(diamonds: royal.diamonds);
    expect(settings.buy(royal), isTrue);
    expect(settings.isUnlocked(TableTheme.royal), isTrue);
    expect(settings.buy(royal), isFalse); // owned already

    expect(settings.spend(chips: settings.chips + 1), isFalse);
    final before = settings.chips;
    final diamonds = settings.diamonds;
    final lv = settings.addXp(200); // level 1 → 3
    expect(lv.after, 3);
    // Level rewards only while the chip system is on (store versions).
    final on = Economy.enabled ? 1 : 0;
    expect(settings.chips, before + on * (Economy.levelUpChips(2) + Economy.levelUpChips(3)));
    expect(settings.diamonds, diamonds + on * 2 * Economy.levelUpDiamonds);

    // Kept after a restart.
    final again = await AppSettings.load();
    expect(again.chips, settings.chips);
    expect(again.owns(royal.id), isTrue);
  });
}
