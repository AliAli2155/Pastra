import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/game/avatar_pic.dart';
import 'package:pastra/game/friends.dart';
import 'package:pastra/game/progression.dart';
import 'package:pastra/game/seats.dart';
import 'package:pastra/ui/widgets/avatar.dart';

void main() {
  test('a friend keeps their picture and frame', () {
    const f = Friend(uid: 'u1', name: 'Eleni', lastPlayed: 5, pic: 'boat', frame: 'gold');
    final back = Friend.fromJson(f.toJson())!;
    expect(back.pic, 'boat');
    expect(back.frame, 'gold');
    // Older saved lists have neither.
    final old = Friend.fromJson(<String, Object>{'u': 'u2', 'n': 'Nikos', 't': 1})!;
    expect(old.pic, '');
    expect(AvatarPic.byName(old.pic), AvatarPic.letter);
    expect(avatarFrameByName(old.frame), AvatarFrame.none);
  });

  test('bots always get the same picture, never the initial', () {
    for (var i = 0; i < 40; i++) {
      expect(botPic(i), isNot(AvatarPic.letter));
      expect(botPic(i), botPic(i));
    }
    expect(<AvatarPic>{for (var i = 0; i < 8; i++) botPic(i)}.length, 8);
    expect(botFrame(AiLevel.beginner), AvatarFrame.none);
    expect(botFrame(AiLevel.master), AvatarFrame.gold);
  });

  test('an online seat carries the player\'s avatar', () {
    const seat = SeatInfo.remote('Maria', pic: 'cat', frame: 'ruby');
    expect(AvatarPic.byName(seat.pic), AvatarPic.cat);
    expect(avatarFrameByName(seat.frame), AvatarFrame.ruby);
  });
}
