import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// Sound effects. Card sounds are real recordings from Kenney's "Casino
/// Audio", the others from "Interface Sounds" and "Music Jingles" (all CC0,
/// kenney.nl), trimmed by tool/make_sounds.py into assets/sounds.
enum Sfx {
  play(4),
  deal(4),
  capture(2),
  shuffle(1),
  pastra(1),
  turn(1),
  tick(1),
  win(1),
  lose(1);

  const Sfx(this.variants);

  /// Number of recordings (`<name>_1.mp3` … `<name>_<n>.mp3`); one is picked
  /// at random so repeated sounds do not feel mechanical.
  final int variants;
}

/// Plays [Sfx] through a few reusable players so quick sounds can overlap.
/// Sound problems are never allowed to disturb the game.
class SoundFx {
  SoundFx._();

  static final SoundFx instance = SoundFx._();

  /// Mirrors the "Sound effects" setting.
  bool enabled = true;

  static const int _voices = 5;
  final List<AudioPlayer> _players = <AudioPlayer>[];
  final Random _rng = Random();
  int _next = 0;

  void play(Sfx sfx, {double volume = 1.0}) {
    if (!enabled) return;
    try {
      if (_players.isEmpty) {
        for (var i = 0; i < _voices; i++) {
          final p = AudioPlayer();
          p.setReleaseMode(ReleaseMode.stop).catchError((Object _) {});
          _players.add(p);
        }
      }
      final player = _players[_next];
      _next = (_next + 1) % _voices;
      final n = sfx.variants > 1 ? _rng.nextInt(sfx.variants) + 1 : 1;
      player.play(AssetSource('sounds/${sfx.name}_$n.mp3'), volume: volume).catchError((Object _) {});
    } catch (_) {
      // No audio on this device / in tests: stay silent.
    }
  }
}
