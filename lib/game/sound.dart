import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'sound_stub.dart' if (dart.library.js_interop) 'sound_web.dart' as web;

/// Sound effects. Card sounds are real recordings from Kenney's "Casino
/// Audio", the others from "Interface Sounds" and "Music Jingles" (all CC0,
/// kenney.nl), trimmed by tool/make_sounds.py and tool/make_sounds_extra.py
/// into assets/sounds.
enum Sfx {
  play(<String>['play_1.mp3', 'play_2.mp3', 'play_3.mp3', 'play_4.mp3']),
  deal(<String>['deal_1.mp3', 'deal_2.mp3', 'deal_3.mp3', 'deal_4.mp3', 'deal_5.wav', 'deal_6.wav']),
  capture(<String>['capture_1.mp3', 'capture_2.mp3', 'capture_3.wav', 'capture_4.wav']),
  shuffle(<String>['shuffle_1.mp3']),
  pastra(<String>['pastra_1.mp3']),
  jackPastra(<String>['jackpastra_1.m4a']),
  turn(<String>['turn_1.mp3']),
  tick(<String>['tick_1.mp3']),
  win(<String>['win_1.mp3']),
  lose(<String>['lose_1.mp3']),
  levelUp(<String>['levelup_1.m4a']),
  coins(<String>['coins_1.wav', 'coins_2.wav']);

  const Sfx(this.files);

  /// The recordings in assets/sounds; one is picked at random so repeated
  /// sounds do not feel mechanical.
  final List<String> files;
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

  /// On the web the sounds go through the Web Audio engine of index.html
  /// (reliable on iPhone Safari, where audio players stop after a while).
  bool _web = false;

  static List<String> get _files => <String>[
        for (final sfx in Sfx.values)
          for (final f in sfx.files) 'sounds/$f',
      ];

  /// Loads every recording. Call once at start; safe to call again.
  Future<void> preload() => _loading ??= _load();

  Future<void> _load() async {
    if (kIsWeb && web.webSoundAvailable()) {
      _web = true;
      web.webSoundLoad(_files);
      return;
    }
    for (final sfx in Sfx.values) {
      for (final f in sfx.files) {
        final file = 'sounds/$f';
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
      final files = sfx.files;
      final file = 'sounds/${files.length > 1 ? files[_rng.nextInt(files.length)] : files.first}';
      final v = (volume * master).clamp(0.0, 1.0).toDouble();
      if (_web) {
        web.webSoundPlay(file, v);
        return;
      }
      final players = _pool[file];
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

/// The background music: one quiet loop (assets/sounds/music_1.m4a, made by
/// tool/make_music.py), off unless the player turns it up in the settings.
/// It pauses while the app is in the background.
class Music {
  Music._();

  static final Music instance = Music._();

  static const String file = 'sounds/music_1.m4a';

  /// Music is a background: full volume on the slider is this loud.
  static const double _scale = 0.45;

  double _volume = 0;
  bool _hidden = false;
  AudioPlayer? _player;
  AppLifecycleListener? _lifecycle;

  /// The "Music" volume setting (0 = off).
  double get volume => _volume;

  set volume(double value) {
    _volume = value.clamp(0.0, 1.0).toDouble();
    _apply();
  }

  void _apply() {
    final v = _hidden ? 0.0 : _volume * _scale;
    try {
      if (kIsWeb && web.webSoundAvailable()) {
        web.webMusic(file, v);
        return;
      }
      if (v <= 0) {
        unawaited(_player?.pause().catchError((Object _) {}));
        return;
      }
      _lifecycle ??= AppLifecycleListener(
        onHide: () {
          _hidden = true;
          _apply();
        },
        onShow: () {
          _hidden = false;
          _apply();
        },
      );
      unawaited(_start(v));
    } catch (_) {
      // No audio on this device / in tests.
    }
  }

  Future<void> _start(double v) async {
    try {
      var p = _player;
      if (p == null) {
        p = _player = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setSource(AssetSource(file));
      }
      await p.setVolume(v);
      if (p.state != PlayerState.playing) await p.resume();
    } catch (_) {}
  }
}
