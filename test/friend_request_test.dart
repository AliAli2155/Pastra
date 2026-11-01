import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/online/social_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlayerStatus _p(String uid, [String name = 'Ali']) => PlayerStatus(uid: uid, name: name, tag: '2155');

void main() {
  group('friend requests', () {
    test('a request is listed once per player', () {
      var list = const <PlayerStatus>[];
      list = SocialService.withRequest(list, _p('a'));
      list = SocialService.withRequest(list, _p('b', 'Bea'));
      list = SocialService.withRequest(list, _p('a'));
      expect(list.map((r) => r.uid).toList(), <String>['a', 'b']);
    });

    test('answering removes only that request', () {
      final list = <PlayerStatus>[_p('a'), _p('b', 'Bea')];
      expect(SocialService.withoutRequest(list, 'a').map((r) => r.uid), <String>['b']);
      expect(SocialService.withoutRequest(list, 'zzz'), hasLength(2));
      expect(SocialService.withoutRequest(list, null), hasLength(2));
    });

    test('a request does not add a friend until it is accepted', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await AppSettings.load();
      expect(settings.friends, isEmpty);
      final r = _p('a');
      settings.addFriend(uid: r.uid, name: r.name, tag: r.tag);
      expect(settings.friends.single.uid, 'a');
      expect(settings.friends.single.favorite, isTrue);
      // Accepting twice keeps a single entry.
      settings.addFriend(uid: r.uid, name: 'Ali B', tag: r.tag);
      expect(settings.friends, hasLength(1));
      expect(settings.friends.single.name, 'Ali B');
    });
  });
}
