import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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

/// Plays [Sfx] with as little delay as possible.
///
/// Every recording is loaded once, up front ([preload]), into a few players
/// of its own. Playing a sound then only rewinds and starts an already
/// loaded player — before, each sound loaded its file again when it was
/// played, which made sounds come late or not at all (a new sound cancelled
/// one that was still loading). On Android the players use the low-latency
/// mode (SoundPool). Sound problems never disturb the game.
class SoundFx {
  SoundFx._();

  static final SoundFx instance = SoundFx._();

  /// Mirrors the "Sound effects" volume setting (0 = silent, 1 = full).
  double master = 1.0;

  /// Players per recording, so the same sound can overlap itself.
  static const int _voices = 2;

  final Map<String, List<AudioPlayer>> _pool = <String, List<AudioPlayer>>{};
  final Map<String, int> _next = <String, int>{};
  final Random _rng = Random();
  Future<void>? _loading;

  static bool get _lowLatency => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Loads every recording. Call once at start; safe to call again.
  Future<void> preload() => _loading ??= _load();

  Future<void> _load() async {
    for (final sfx in Sfx.values) {
      for (var n = 1; n <= sfx.variants; n++) {
        final file = 'sounds/${sfx.name}_$n.mp3';
        final players = <AudioPlayer>[];
        for (var v = 0; v < _voices; v++) {
          try {
            final p = AudioPlayer();
            if (_lowLatency) await p.setPlayerMode(PlayerMode.lowLatency);
            await p.setReleaseMode(ReleaseMode.stop);
            await p.setSource(AssetSource(file));
            players.add(p);
          } catch (_) {
            // No audio on this device / in tests.
          }
        }
        if (players.isNotEmpty) _pool[file] = players;
      }
    }
  }

  void play(Sfx sfx, {double volume = 1.0}) {
    if (master <= 0) return;
    try {
      // First sound before anything was loaded: start loading now.
      preload();
      final n = sfx.variants > 1 ? _rng.nextInt(sfx.variants) + 1 : 1;
      final file = 'sounds/${sfx.name}_$n.mp3';
      final players = _pool[file];
      final v = (volume * master).clamp(0.0, 1.0).toDouble();
      if (players == null || players.isEmpty) {
        // Not loaded yet (the very first sounds): play it directly once.
        final p = AudioPlayer();
        p.play(AssetSource(file), volume: v).catchError((Object _) {});
        return;
      }
      final i = _next[file] ?? 0;
      _next[file] = (i + 1) % players.length;
      final p = players[i];
      unawaited(_restart(p, v));
    } catch (_) {
      // No audio on this device / in tests: stay silent.
    }
  }

  Future<void> _restart(AudioPlayer p, double volume) async {
    try {
      await p.setVolume(volume);
      // (Stop instead of seek: the low-latency mode cannot seek.)
      if (p.state == PlayerState.playing) await p.stop();
      await p.resume();
    } catch (_) {}
  }
}
