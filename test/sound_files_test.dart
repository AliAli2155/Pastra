import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/sound.dart';

void main() {
  test('every sound effect and the music have their file', () {
    final files = <String>[
      for (final sfx in Sfx.values) ...sfx.files.map((f) => 'sounds/$f'),
      Music.file,
    ];
    for (final f in files) {
      expect(File('assets/$f').existsSync(), isTrue, reason: f);
    }
    for (final sfx in Sfx.values) {
      expect(sfx.files, isNotEmpty, reason: sfx.name);
    }
  });

  test('music volume stays between 0 and 1 and is off by default', () {
    expect(Music.instance.volume, 0);
    Music.instance.volume = 3;
    expect(Music.instance.volume, 1);
    Music.instance.volume = -1;
    expect(Music.instance.volume, 0);
  });
}
