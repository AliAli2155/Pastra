import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notes screens and dialogs opening and closing (for the [FreezeLog]).
class FreezeRouteObserver extends NavigatorObserver {
  static String _what(Route<dynamic> route) =>
      '${route is PopupRoute ? 'dialog' : 'screen'}${route.settings.name == null ? '' : ' ${route.settings.name}'}';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => FreezeLog.note('${_what(route)} opened');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => FreezeLog.note('${_what(route)} closed');
}

/// One time the app stood still.
@immutable
class Freeze {
  const Freeze({required this.at, required this.ms, required this.notes, this.frame = ''});

  factory Freeze.fromJson(Map<String, dynamic> j) => Freeze(
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
        ms: (j['ms'] as num?)?.toInt() ?? 0,
        notes: <String>[
          for (final n in (j['notes'] as List?) ?? const <Object?>[])
            if (n is String) n,
        ],
        frame: j['frame'] is String ? j['frame'] as String : '',
      );

  /// When it started.
  final DateTime at;

  /// How long nothing moved.
  final int ms;

  /// What happened just before, oldest first ("-1.2 s bot thinks").
  final List<String> notes;

  /// The slowest frame around it ("build 40 ms, raster 900 ms"), if one was
  /// reported.
  final String frame;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'at': at.millisecondsSinceEpoch,
        'ms': ms,
        'notes': notes,
        if (frame.isNotEmpty) 'frame': frame,
      };
}

/// Preview builds: notices when the app stands still for [threshold] or
/// longer and keeps what happened just before, so that a freeze on a real
/// phone can be read later (Settings > About, "Copy").
///
/// A timer ticks every 100 ms; when a tick comes much later than due, the
/// page was busy and nothing could move. This sees every kind of freeze
/// (a heavy frame, a font, a long computation), not only slow frames. The
/// game and the app leave short [note]s of what they do. Time while the app
/// is hidden (another tab, the phone locked) is not counted.
class FreezeLog {
  FreezeLog._();

  static const Duration threshold = Duration(milliseconds: 500);
  static const Duration tick = Duration(milliseconds: 100);

  /// Freezes kept (the newest).
  static const int keep = 30;

  /// Notes shown with a freeze: the ones of the last few seconds before it.
  static const Duration noteWindow = Duration(seconds: 6);

  static const String _key = 'freezeLog';

  /// The freezes found so far, newest first.
  static final ValueNotifier<List<Freeze>> entries = ValueNotifier<List<Freeze>>(const <Freeze>[]);

  static bool _on = false;
  static SharedPreferences? _prefs;
  static Timer? _timer;
  static AppLifecycleListener? _lifecycle;
  static final Stopwatch _clock = Stopwatch();
  static int Function() _now = () => _clock.elapsedMilliseconds;
  static int _last = 0;
  static bool _visible = true;
  static bool _skipNext = false;

  /// The start (loading, the first screen) is not counted.
  static int _quietUntil = 0;
  static final List<(int, String)> _notes = <(int, String)>[];
  static final List<(int, String)> _frames = <(int, String)>[];

  /// Whether freezes are being recorded (preview builds).
  static bool get enabled => _on;

  /// Starts watching (once, at start-up of a preview build).
  static Future<void> start() async {
    if (_on) return;
    _on = true;
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw != null) {
        entries.value = <Freeze>[
          for (final e in jsonDecode(raw) as List)
            if (e is Map) Freeze.fromJson(Map<String, dynamic>.from(e)),
        ];
      }
    } catch (_) {
      // A broken list starts empty.
    }
    _clock.start();
    _last = _now();
    _quietUntil = _last + 4000;
    _timer = Timer.periodic(tick, (_) => check());
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    note('app started');
  }

  /// Something happened that may explain a freeze right after it.
  static void note(String what) {
    if (!_on) return;
    _notes.add((_now(), what));
    if (_notes.length > 24) _notes.removeAt(0);
  }

  static void _onLifecycle(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (visible == _visible) return;
    _visible = visible;
    // The first tick back comes late because the page was hidden.
    _skipNext = true;
    note(visible ? 'app visible again' : 'app hidden');
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      if (t.totalSpan < const Duration(milliseconds: 150)) continue;
      _frames.add((_now(), 'frame ${t.totalSpan.inMilliseconds} ms (build ${t.buildDuration.inMilliseconds}, raster ${t.rasterDuration.inMilliseconds})'));
      if (_frames.length > 8) _frames.removeAt(0);
    }
  }

  /// One tick of the watch (public for the tests).
  @visibleForTesting
  static void check() {
    final now = _now();
    final late = now - _last - tick.inMilliseconds;
    _last = now;
    if (_skipNext || !_visible) {
      _skipNext = false;
      return;
    }
    if (late < threshold.inMilliseconds || now < _quietUntil) return;
    // Still alive at the last tick; nothing moved from then on.
    _record(now - late, late);
  }

  static void _record(int start, int ms) {
    String ago(int t) => '${((t - start) / 1000).toStringAsFixed(1)} s';
    final notes = <String>[
      for (final (t, what) in _notes)
        if (t >= start - noteWindow.inMilliseconds) '${ago(t)} $what',
    ];
    var frame = '';
    for (final (t, what) in _frames) {
      if ((t - start).abs() < 3000) frame = what;
    }
    final freeze = Freeze(
      at: DateTime.now().subtract(Duration(milliseconds: _now() - start)),
      ms: ms,
      notes: notes.length > 8 ? notes.sublist(notes.length - 8) : notes,
      frame: frame,
    );
    final list = <Freeze>[freeze, ...entries.value];
    entries.value = list.length > keep ? list.sublist(0, keep) : list;
    _save();
  }

  static void _save() {
    try {
      unawaited(_prefs?.setString(_key, jsonEncode(<Map<String, dynamic>>[for (final f in entries.value) f.toJson()])));
    } catch (_) {}
  }

  static void clear() {
    entries.value = const <Freeze>[];
    _save();
  }

  /// The whole list as text, to send to the developer: [device] says which
  /// browser or phone it was.
  static String report({required String device, required String build}) {
    final b = StringBuffer()
      ..writeln('Pastra freeze log ($build)')
      ..writeln(device);
    var i = 0;
    for (final f in entries.value) {
      i++;
      final at = f.at.toIso8601String().substring(0, 19).replaceFirst('T', ' ');
      b.writeln('$i) $at  ${(f.ms / 1000).toStringAsFixed(1)} s${f.frame.isEmpty ? '' : '  [${f.frame}]'}');
      for (final n in f.notes) {
        b.writeln('     $n');
      }
    }
    if (i == 0) b.writeln('(no freezes)');
    return b.toString();
  }

  /// Tests: a clock of their own, a fresh start.
  @visibleForTesting
  static void startForTest(int Function() now) {
    _timer?.cancel();
    _lifecycle?.dispose();
    _on = true;
    _now = now;
    _last = now();
    _visible = true;
    _skipNext = false;
    _quietUntil = 0;
    _notes.clear();
    _frames.clear();
    entries.value = const <Freeze>[];
  }

  /// Tests: the app goes into the background or comes back.
  @visibleForTesting
  static void lifecycleForTest(AppLifecycleState state) => _onLifecycle(state);

  @visibleForTesting
  static void stopForTest() {
    _timer?.cancel();
    _lifecycle?.dispose();
    _on = false;
    _now = () => _clock.elapsedMilliseconds;
  }
}
