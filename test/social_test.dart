import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/cards.dart';
import 'package:pastra/engine/game_state.dart';
import 'package:pastra/engine/move_review.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/friends.dart';
import 'package:pastra/l10n/social_strings.dart';
import 'package:pastra/online/invite_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameState _pile({required List<int> table, required List<int> hand}) {
  final s = GameState(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 1);
  s.table = List<int>.of(table);
  s.hands = <List<int>>[List<int>.of(hand), <int>[Cards.make(Cards.spades, 4)]];
  s.deck = <int>[for (var c = 0; c < 10; c++) if (!table.contains(c) && !hand.contains(c)) c];
  s.current = 0;
  return s;
}

void main() {
  group('game review', () {
    final seven = Cards.make(Cards.hearts, 7);
    final sevenB = Cards.make(Cards.clubs, 7);
    final three = Cards.make(Cards.hearts, 3);
    final jack = Cards.make(Cards.hearts, Cards.jack);
    final aceS = Cards.make(Cards.spades, Cards.ace);
    final kingD = Cards.make(Cards.diamonds, Cards.king);

    test('a missed pastra is found', () {
      final s = _pile(table: <int>[sevenB], hand: <int>[seven, three]);
      final miss = MoveReview.review(s, three);
      expect(miss, isNotNull);
      expect(miss!.kind, MissKind.pastra);
      expect(miss.better, seven);
      expect(MoveReview.review(s, seven), isNull);
    });

    test('a good capture left on the table is found; keeping a jack is fine', () {
      final s = _pile(table: <int>[aceS, kingD, sevenB], hand: <int>[seven, three]);
      final miss = MoveReview.review(s, three);
      expect(miss?.kind, MissKind.capture);
      expect(miss?.cards, 3);
      // Only a jack could take a small pile: no complaint.
      final small = _pile(table: <int>[kingD, Cards.make(Cards.clubs, 9)], hand: <int>[jack, three]);
      expect(MoveReview.review(small, three), isNull);
    });
  });

  group('friends', () {
    test('recent players are merged, newest first, favourites kept', () {
      var list = Friend.merge(const <Friend>[], <String, String>{'a': 'Ali', 'b': 'Bea'}, 1000);
      expect(list.map((f) => f.uid).toSet(), <String>{'a', 'b'});
      list = Friend.merge(list, <String, String>{'a': 'Ali K'}, 2000);
      expect(list.first.uid, 'a');
      expect(list.first.name, 'Ali K');
      expect(list.first.games, 2);
      list = <Friend>[for (final f in list) f.uid == 'b' ? f.copyWith(favorite: true) : f];
      for (var i = 0; i < 40; i++) {
        list = Friend.merge(list, <String, String>{'x$i': 'X'}, 3000 + i, maxRecent: 5);
      }
      expect(list.where((f) => !f.favorite).length, 5);
      expect(list.any((f) => f.uid == 'b'), isTrue);
    });

    test('settings keep the list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await AppSettings.load();
      settings.addRecentPlayers(<String, String>{'u1': 'Nikos'});
      settings.setFavorite('u1', true);
      expect(settings.friends.single.favorite, isTrue);
      settings.removeFriend('u1');
      expect(settings.friends, isEmpty);
    });
  });

  test('invite links carry the room code', () {
    expect(InviteLink.forCode('1234'), endsWith('#/oda/1234'));
    expect(InviteLink.codeIn('https://aliali2155.github.io/Pastra/#/oda/4821'), '4821');
    expect(InviteLink.codeIn('https://x/#/room/0001/'), '0001');
    expect(InviteLink.codeIn('https://x/#/oda/12'), isNull);
  });

  test('social texts exist in every language', () {
    final en = SocialStrings.keysOf('en');
    for (final lang in AppSettings.languages) {
      expect(SocialStrings.keysOf(lang), en, reason: lang);
      for (final id in SocialStrings.messages) {
        expect(SocialStrings(lang).chat('m:$id'), isNotEmpty);
      }
    }
    expect(SocialStrings('en').chat('e:🔥'), '🔥');
    expect(SocialStrings('en').chat('m:rude'), isEmpty);
  });

  test('statistics: most pastras in a game and the favourite table', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    expect(settings.stats.favoriteTable, isNull);
    settings.recordGame(won: true, players: 2, level: AiLevel.medium, pastras: 3);
    settings.recordGame(won: false, players: 2, level: AiLevel.medium, pastras: 1);
    expect(settings.stats.bestGamePastras, 3);
    expect(settings.stats.favoriteTable, 'green');
  });

  test('player codes: "Ali #2155" is read and keyed the same way however it is typed', () {
    expect(PlayerHandle.parse('Ali #2155'), ('Ali', '2155'));
    expect(PlayerHandle.parse('ali#2155'), ('ali', '2155'));
    expect(PlayerHandle.parse('Ali Veli # 0042'), ('Ali Veli', '0042'));
    expect(PlayerHandle.parse('Ali 2155'), ('Ali', '2155'));
    expect(PlayerHandle.parse('Ali'), isNull);
    expect(PlayerHandle.parse('#2155'), isNull);
    expect(PlayerHandle.keyOf('Ali', '2155'), PlayerHandle.keyOf(' ALI ', '2155'));
    expect(PlayerHandle.keyOf('a.b#c', '1000'), isNot(contains('.')));
    expect(PlayerHandle.keyOf('a.b#c', '1000'), isNot(contains('#')));
    expect(PlayerHandle.format('Ali', '2155'), 'Ali #2155');
    final f = Friend.fromJson(const Friend(uid: 'u', name: 'Ali', lastPlayed: 1, tag: '2155').toJson())!;
    expect(f.handle, 'Ali #2155');
  });
}
