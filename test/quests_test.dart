import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/game/quests.dart';
import 'package:pastra/game/seasons.dart';
import 'package:pastra/l10n/progress_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('daily quests', () {
    test('three quests a day, one of each difficulty, unique ids', () {
      expect(Quests.all.map((q) => q.id).toSet(), hasLength(Quests.all.length));
      for (var seed = 0; seed < 200; seed++) {
        final ids = Quests.pick(seed);
        expect(ids, hasLength(3));
        expect(ids.map((id) => Quests.byId(id)!.tier).toList(), QuestTier.values);
      }
    });

    test('different players and days get different quests', () {
      final days = <String>{for (var d = 0; d < 30; d++) Quests.pick(Quests.seed(12345, 20000 + d)).join()};
      expect(days.length, greaterThan(10));
      final players = <String>{for (var p = 0; p < 30; p++) Quests.pick(Quests.seed(p * 7777, 20000)).join()};
      expect(players.length, greaterThan(10));
      // The same player on the same day always gets the same quests.
      expect(Quests.pick(Quests.seed(42, 20001)), Quests.pick(Quests.seed(42, 20001)));
    });

    test('progress from game events', () {
      QuestDef q(String id) => Quests.byId(id)!;
      const win = QuestEvent(gameOver: true, won: true, level: AiLevel.hard);
      const loss = QuestEvent(gameOver: true);
      expect(Quests.advance(q('play_2'), 0, loss), 1);
      expect(Quests.advance(q('win_1'), 0, loss), 0);
      expect(Quests.advance(q('win_1'), 0, win), 1);
      expect(Quests.advance(q('hard_1'), 0, win), 1);
      expect(Quests.advance(q('hard_1'), 0, const QuestEvent(gameOver: true, won: true, online: true)), 0);
      expect(Quests.advance(q('pastra_5'), 3, const QuestEvent(pastras: 4)), 5);
      expect(Quests.advance(q('round_30'), 0, const QuestEvent(rounds: 1, roundScore: 29)), 0);
      expect(Quests.advance(q('round_30'), 0, const QuestEvent(rounds: 1, roundScore: 31)), 30);
      expect(Quests.advance(q('team_win'), 0, const QuestEvent(gameOver: true, won: true, players: 4)), 1);
      expect(Quests.advance(q('online_win'), 0, const QuestEvent(gameOver: true, won: true, online: true)), 1);
      expect(Quests.advance(q('streak_2'), 1, loss), 0);
      expect(Quests.advance(q('streak_2'), 1, win), 2);
      // A finished quest stays finished.
      expect(Quests.advance(q('streak_2'), 2, loss), 2);
    });

    test('settings: progress, collect, bonus, reroll', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await AppSettings.load();
      final quests = settings.quests;
      expect(quests, hasLength(3));
      expect(settings.questsReady, 0);

      // Swap the first quest once.
      final first = quests.first.def.id;
      expect(settings.rerollQuest(first), isTrue);
      expect(settings.quests.first.def.id, isNot(first));
      expect(settings.quests.first.def.tier, QuestTier.easy);
      expect(settings.canRerollQuest, isFalse);

      // Finish everything with lots of big events.
      for (var i = 0; i < 6; i++) {
        settings.questEvent(const QuestEvent(
          pastras: 5,
          jackPastras: 1,
          rounds: 6,
          roundScore: 40,
          goodCards: true,
          gameOver: true,
          won: true,
          online: true,
          players: 4,
        ));
        settings.questEvent(const QuestEvent(gameOver: true, won: true, level: AiLevel.hard));
      }
      expect(settings.quests.every((q) => q.done), isTrue);
      expect(settings.questsReady, 3);
      final xp = settings.xp;
      for (final q in settings.quests) {
        expect(settings.claimQuest(q.def.id), q.def.xp);
        expect(settings.claimQuest(q.def.id), isNull);
      }
      expect(settings.stats.questsDone, 3);
      expect(settings.questBonusReady, isTrue);
      expect(settings.claimQuestBonus(), isTrue);
      expect(settings.claimQuestBonus(), isFalse);
      expect(settings.stats.perfectDays, 1);
      expect(settings.questsReady, 0);
      expect(settings.xp, greaterThan(xp));
      expect(settings.unlockEarned(), contains('daily_all'));
    });
  });

  group('level path', () {
    test('frames and titles follow the level', () {
      expect(Progression.bestFrame(1), AvatarFrame.none);
      expect(Progression.bestFrame(3), AvatarFrame.bronze);
      expect(Progression.bestFrame(30), AvatarFrame.legend);
      expect(Progression.titleFor(1), PlayerTitle.novice);
      expect(Progression.titleFor(12), PlayerTitle.expert);
      expect(Progression.titleFor(30), PlayerTitle.king);
      expect(Progression.rewardsAt(1).isEmpty, isTrue);
      expect(Progression.rewardsAt(3).frames, <AvatarFrame>[AvatarFrame.bronze]);
    });

    test('a locked frame cannot be chosen', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'xp': 0});
      final settings = await AppSettings.load();
      settings.avatarFrame = AvatarFrame.legend;
      expect(settings.avatarFrame, AvatarFrame.none);
      settings.addXp(Progression.xpForLevel(6));
      expect(settings.avatarFrame, AvatarFrame.silver);
      settings.avatarFrame = AvatarFrame.bronze;
      expect(settings.avatarFrame, AvatarFrame.bronze);
    });
  });

  group('seasons', () {
    test('ids, ends and tiers', () {
      expect(Seasons.idOf(DateTime.utc(2026, 10, 31, 23)), '202610');
      expect(Seasons.endOf('202612'), DateTime.utc(2027, 1));
      expect(Seasons.isValid('202613'), isFalse);
      expect(Seasons.tierFor(1), SeasonTier.champion);
      expect(Seasons.tierFor(3), SeasonTier.top3);
      expect(Seasons.tierFor(10), SeasonTier.top10);
      expect(Seasons.tierFor(100), SeasonTier.top100);
      expect(Seasons.tierFor(0), SeasonTier.player);
      expect(ProgressStrings('en').seasonName('202610'), 'October 2026');
      expect(ProgressStrings('tr').seasonName('202601'), 'Ocak 2026');
    });

    test('a new month keeps the old season for its ranking', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'season': '202001',
        'seasonXp': 500,
        'seasonGames': 4,
        'seasonWins': 2,
      });
      final settings = await AppSettings.load();
      expect(settings.season, Seasons.current());
      expect(settings.seasonXp, 0);
      expect(settings.seasonsPending, <String>['202001']);
      settings.addXp(50);
      expect(settings.seasonXp, 50);
      final badge = settings.finishSeason('202001', 7)!;
      expect(badge.tier, SeasonTier.top10);
      expect(settings.seasonsPending, isEmpty);
      expect(settings.seasonBadges.single.rank, 7);
      expect(settings.stats.seasonTop10, 1);
      // The season reward does not count for the new season.
      expect(settings.seasonXp, 50);
      expect(settings.achievements.containsKey('season_top10'), isTrue);
    });
  });

  test('progress texts exist in every language', () {
    final en = ProgressStrings.keysOf('en');
    expect(en, isNotEmpty);
    for (final lang in AppSettings.languages) {
      expect(ProgressStrings.keysOf(lang), en, reason: lang);
      for (final q in Quests.all) {
        expect(ProgressStrings(lang).quest(q), isNot(contains('{')), reason: '$lang ${q.id}');
      }
    }
  });
}
