import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('level curve', () {
    expect(Progression.levelOf(0), 1);
    expect(Progression.levelOf(79), 1);
    expect(Progression.levelOf(Progression.xpForLevel(2)), 2);
    expect(Progression.levelOf(Progression.xpForLevel(2) - 1), 1);
    expect(Progression.levelOf(Progression.xpForLevel(Progression.maxLevel)), Progression.maxLevel);
    expect(Progression.levelOf(100000000), Progression.maxLevel);
    for (var l = 2; l <= Progression.maxLevel; l++) {
      expect(Progression.xpForLevel(l), greaterThan(Progression.xpForLevel(l - 1)));
    }
    final p = Progression.progress(100);
    expect(p.into, 20);
    expect(p.needed, Progression.xpToNext(2));
  });

  test('xp amounts', () {
    expect(Progression.gameXp(won: false, level: AiLevel.hard), 20);
    expect(Progression.gameXp(won: true, level: AiLevel.easy), 60);
    expect(Progression.gameXp(won: true, level: AiLevel.hard), 100);
    expect(Progression.gameXp(won: true, level: AiLevel.hard), greaterThan(Progression.gameXp(won: true, level: AiLevel.medium)));
    expect(Progression.roundXp(pastras: 2, jackPastras: 1), 35);
  });

  test('every colour unlocks within the level range, defaults at level 1', () {
    for (final t in TableTheme.values) {
      expect(Progression.levelFor(t), inInclusiveRange(1, Progression.maxLevel));
    }
    for (final b in CardBackStyle.values) {
      expect(Progression.levelForBack(b), inInclusiveRange(1, Progression.maxLevel));
    }
    expect(Progression.levelFor(TableTheme.green), 1);
    expect(Progression.levelForBack(CardBackStyle.aegean), 1);
    expect(Progression.unlocksBetween(1, 2), isTrue);
    expect(Progression.unlocksBetween(2, 3), isFalse);
  });

  test('locked colours cannot be chosen until the level is reached', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    expect(settings.playerLevel, 1);
    settings.tableTheme = TableTheme.night;
    expect(settings.tableTheme, TableTheme.green);
    settings.cardBack = CardBackStyle.gold;
    expect(settings.cardBack, CardBackStyle.aegean);
    final lv = settings.addXp(Progression.xpForLevel(Progression.maxLevel));
    expect(lv.before, 1);
    expect(lv.after, Progression.maxLevel);
    settings.tableTheme = TableTheme.night;
    settings.cardBack = CardBackStyle.gold;
    expect(settings.tableTheme, TableTheme.night);
    expect(settings.cardBack, CardBackStyle.gold);
    Look.table = TableTheme.green;
    Look.back = CardBackStyle.aegean;
  });

  test('old stats are turned into starting xp', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'gamesPlayed': 10, 'gamesWon': 5});
    final settings = await AppSettings.load();
    expect(settings.xp, Progression.backfill(games: 10, wins: 5, pastras: 0));
    expect(settings.playerLevel, greaterThan(1));
  });
}
