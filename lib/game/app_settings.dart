import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/pastra_ai.dart';
import '../engine/rules.dart';
import '../ui/theme.dart';
import 'progression.dart';
import 'sound.dart';

/// Lifetime statistics of the local player.
class GameStats {
  int games = 0;
  int wins = 0;
  int streak = 0;
  int bestStreak = 0;
  int rounds = 0;
  int bestRound = 0;
  int pastras = 0;
  int jackPastras = 0;
  int games1v1 = 0;
  int wins1v1 = 0;
  int games2v2 = 0;
  int wins2v2 = 0;

  /// Indexed by [AiLevel.index].
  List<int> gamesByLevel = <int>[0, 0, 0];
  List<int> winsByLevel = <int>[0, 0, 0];

  GameStats();

  int get winRate => games == 0 ? 0 : (wins * 100 / games).round();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'games': games,
        'wins': wins,
        'streak': streak,
        'bestStreak': bestStreak,
        'rounds': rounds,
        'bestRound': bestRound,
        'pastras': pastras,
        'jackPastras': jackPastras,
        'games1v1': games1v1,
        'wins1v1': wins1v1,
        'games2v2': games2v2,
        'wins2v2': wins2v2,
        'gamesByLevel': gamesByLevel,
        'winsByLevel': winsByLevel,
      };

  factory GameStats.fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    List<int> l(String k) {
      final v = j[k];
      if (v is! List || v.length != 3) return <int>[0, 0, 0];
      return v.map((e) => (e as num).toInt()).toList();
    }

    return GameStats()
      ..games = i('games')
      ..wins = i('wins')
      ..streak = i('streak')
      ..bestStreak = i('bestStreak')
      ..rounds = i('rounds')
      ..bestRound = i('bestRound')
      ..pastras = i('pastras')
      ..jackPastras = i('jackPastras')
      ..games1v1 = i('games1v1')
      ..wins1v1 = i('wins1v1')
      ..games2v2 = i('games2v2')
      ..wins2v2 = i('wins2v2')
      ..gamesByLevel = l('gamesByLevel')
      ..winsByLevel = l('winsByLevel');
  }
}

/// User preferences, statistics and the saved game, stored with
/// shared_preferences.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kLanguage = 'language';
  static const String _kRules = 'rules';
  static const String _kLevel = 'aiLevel';
  static const String _kPlayers = 'players';
  static const String _kName = 'playerName';
  static const String _kFast = 'fastAnimations';
  static const String _kHaptics = 'haptics';
  static const String _kTurnSeconds = 'turnSeconds';

  /// Time per move (0 = no limit).
  static const List<int> turnSecondsOptions = [0, 10, 15, 20, 30];
  static const String _kPlayed = 'gamesPlayed';
  static const String _kWon = 'gamesWon';
  static const String _kStats = 'stats';
  static const String _kSound = 'sound';
  static const String _kVolume = 'volume';
  static const String _kTable = 'tableTheme';
  static const String _kBack = 'cardBack';
  static const String _kTutorial = 'tutorialDone';
  static const String _kAchievements = 'achievements';
  static const String _kSaved = 'savedGame';
  static const String _kXp = 'xp';
  static const String _kTournament = 'tournament';
  static const String _kLeaderboard = 'showOnLeaderboard';
  static const String _kCupPaid = 'cupBonusKeys';

  /// Supported languages. The app always starts in English; the language the
  /// user picks is remembered.
  static const List<String> languages = [
    'el', 'en', 'tr', 'de', 'fr', 'es', 'it', 'pt', 'ru', 'bg', 'ar', 'zh',
  ];

  String _language = 'en';
  PastraRules _rules = const PastraRules();
  AiLevel _level = AiLevel.medium;
  int _players = 2;
  String _playerName = '';
  bool _fastAnimations = false;
  bool _haptics = true;
  int _turnSeconds = 15;
  double _volume = 1.0;
  bool _tutorialDone = false;
  int _xp = 0;
  bool _showOnLeaderboard = true;

  /// Unlocked achievement id → when (milliseconds since epoch).
  Map<String, int> _achievements = <String, int>{};
  GameStats _stats = GameStats();

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings._(prefs);
    settings._read();
    return settings;
  }

  void _read() {
    final lang = _prefs.getString(_kLanguage);
    _language = languages.contains(lang) ? lang! : 'en';

    final rulesJson = _prefs.getString(_kRules);
    if (rulesJson != null) {
      try {
        final saved = jsonDecode(rulesJson) as Map<String, dynamic>;
        // Settings saved before the pile game existed: start from the new
        // defaults (the pile game with 6 cards).
        _rules = saved.containsKey('variant') ? PastraRules.fromJson(saved) : const PastraRules();
      } catch (_) {
        _rules = const PastraRules();
      }
    }
    final level = _prefs.getInt(_kLevel);
    if (level != null && level >= 0 && level < AiLevel.values.length) {
      _level = AiLevel.values[level];
    }
    final players = _prefs.getInt(_kPlayers);
    _players = players == 4 ? 4 : 2;
    _playerName = _prefs.getString(_kName) ?? '';
    _fastAnimations = _prefs.getBool(_kFast) ?? false;
    _haptics = _prefs.getBool(_kHaptics) ?? true;
    final turn = _prefs.getInt(_kTurnSeconds);
    _turnSeconds = turn != null && turnSecondsOptions.contains(turn) ? turn : 15;
    // Older versions only had an on/off switch.
    _volume = (_prefs.getDouble(_kVolume) ?? ((_prefs.getBool(_kSound) ?? true) ? 1.0 : 0.0)).clamp(0.0, 1.0).toDouble();
    _tutorialDone = _prefs.getBool(_kTutorial) ?? false;
    Look.table = TableTheme.values.firstWhere(
      (t) => t.name == _prefs.getString(_kTable),
      orElse: () => TableTheme.green,
    );
    Look.back = CardBackStyle.values.firstWhere(
      (b) => b.name == _prefs.getString(_kBack),
      orElse: () => CardBackStyle.aegean,
    );
    final achJson = _prefs.getString(_kAchievements);
    if (achJson != null) {
      try {
        _achievements = (jsonDecode(achJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry<String, int>(k, (v as num).toInt()));
      } catch (_) {
        _achievements = <String, int>{};
      }
    }
    SoundFx.instance.master = _volume;
    final statsJson = _prefs.getString(_kStats);
    if (statsJson != null) {
      try {
        _stats = GameStats.fromJson(jsonDecode(statsJson) as Map<String, dynamic>);
      } catch (_) {
        _stats = GameStats();
      }
    } else {
      // Older versions only counted games and wins.
      _stats = GameStats()
        ..games = _prefs.getInt(_kPlayed) ?? 0
        ..wins = _prefs.getInt(_kWon) ?? 0;
    }
    _showOnLeaderboard = _prefs.getBool(_kLeaderboard) ?? true;
    final xp = _prefs.getInt(_kXp);
    if (xp != null) {
      _xp = xp < 0 ? 0 : xp;
    } else {
      // Stats from before levels existed count towards the first level.
      _xp = Progression.backfill(games: _stats.games, wins: _stats.wins, pastras: _stats.pastras);
      _prefs.setInt(_kXp, _xp);
    }
    // A colour that is still locked (e.g. an old save) falls back to the default.
    if (Progression.levelFor(Look.table) > playerLevel) Look.table = TableTheme.green;
    if (Progression.levelForBack(Look.back) > playerLevel) Look.back = CardBackStyle.aegean;
  }

  String get language => _language;
  bool get isGreek => _language == 'el';
  /// Sound effects volume, 0..1.
  double get volume => _volume;

  bool get sound => _volume > 0;
  bool get tutorialDone => _tutorialDone;
  TableTheme get tableTheme => Look.table;
  CardBackStyle get cardBack => Look.back;
  Map<String, int> get achievements => Map<String, int>.unmodifiable(_achievements);

  set tutorialDone(bool value) {
    _tutorialDone = value;
    _prefs.setBool(_kTutorial, value);
    notifyListeners();
  }

  /// The last 1v1/2v2 and target choice for a kind of online cup ("2:101").
  String? cupChoice(String kind) => _prefs.getString('cupChoice_$kind');

  void setCupChoice(String kind, String value) => _prefs.setString('cupChoice_$kind', value);

  /// Online cups (their keys) whose XP bonus was given (the last few).
  bool cupBonusPaid(String key) => (_prefs.getStringList(_kCupPaid) ?? const <String>[]).contains(key);

  void markCupBonusPaid(String key) {
    final list = <String>[...(_prefs.getStringList(_kCupPaid) ?? const <String>[]), key];
    _prefs.setStringList(_kCupPaid, list.length > 20 ? list.sublist(list.length - 20) : list);
  }

  /// Whether the player's name and XP are published on the online leaderboard.
  bool get showOnLeaderboard => _showOnLeaderboard;

  set showOnLeaderboard(bool value) {
    _showOnLeaderboard = value;
    _prefs.setBool(_kLeaderboard, value);
    notifyListeners();
  }

  /// Experience points and the level they give.
  int get xp => _xp;
  int get playerLevel => Progression.levelOf(_xp);

  bool isUnlocked(TableTheme t) => Progression.levelFor(t) <= playerLevel;
  bool isBackUnlocked(CardBackStyle b) => Progression.levelForBack(b) <= playerLevel;

  /// Adds experience points; returns the level before and after. Does not
  /// notify (called during games; screens read the value when they build).
  ({int before, int after}) addXp(int amount) {
    final before = playerLevel;
    if (amount > 0) {
      _xp += amount;
      _prefs.setInt(_kXp, _xp);
    }
    return (before: before, after: playerLevel);
  }

  set tableTheme(TableTheme value) {
    if (!isUnlocked(value)) return;
    Look.table = value;
    _prefs.setString(_kTable, value.name);
    notifyListeners();
  }

  set cardBack(CardBackStyle value) {
    if (!isBackUnlocked(value)) return;
    Look.back = value;
    _prefs.setString(_kBack, value.name);
    notifyListeners();
  }

  /// Marks [ids] as unlocked; returns the ones that are new.
  List<String> unlockAchievements(Iterable<String> ids) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fresh = <String>[];
    for (final id in ids) {
      if (_achievements.containsKey(id)) continue;
      _achievements[id] = now;
      fresh.add(id);
    }
    if (fresh.isNotEmpty) _prefs.setString(_kAchievements, jsonEncode(_achievements));
    return fresh;
  }
  GameStats get stats => _stats;
  PastraRules get rules => _rules;
  AiLevel get level => _level;
  int get players => _players;
  String get playerName => _playerName;
  bool get fastAnimations => _fastAnimations;
  bool get haptics => _haptics;
  int get turnSeconds => _turnSeconds;
  int get gamesPlayed => _stats.games;
  int get gamesWon => _stats.wins;

  set language(String value) {
    if (!languages.contains(value) || value == _language) return;
    _language = value;
    _prefs.setString(_kLanguage, value);
    notifyListeners();
  }

  set rules(PastraRules value) {
    _rules = value;
    _prefs.setString(_kRules, jsonEncode(value.toJson()));
    notifyListeners();
  }

  set level(AiLevel value) {
    _level = value;
    _prefs.setInt(_kLevel, value.index);
    notifyListeners();
  }

  set players(int value) {
    _players = value == 4 ? 4 : 2;
    _prefs.setInt(_kPlayers, _players);
    notifyListeners();
  }

  set playerName(String value) {
    _playerName = value.trim();
    _prefs.setString(_kName, _playerName);
    notifyListeners();
  }

  set fastAnimations(bool value) {
    _fastAnimations = value;
    _prefs.setBool(_kFast, value);
    notifyListeners();
  }

  set turnSeconds(int value) {
    _turnSeconds = turnSecondsOptions.contains(value) ? value : 15;
    _prefs.setInt(_kTurnSeconds, _turnSeconds);
    notifyListeners();
  }

  set haptics(bool value) {
    _haptics = value;
    _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  set volume(double value) {
    _volume = value.clamp(0.0, 1.0).toDouble();
    SoundFx.instance.master = _volume;
    _prefs.setDouble(_kVolume, _volume);
    notifyListeners();
  }

  void _saveStats() => _prefs.setString(_kStats, jsonEncode(_stats.toJson()));

  /// A finished round: our team's round score and the pastras the local
  /// player made in it.
  void recordRound({required int score, required int pastras, required int jackPastras}) {
    _stats
      ..rounds += 1
      ..pastras += pastras
      ..jackPastras += jackPastras;
    if (score > _stats.bestRound) _stats.bestRound = score;
    _saveStats();
  }

  void resetStats() {
    _stats = GameStats();
    _saveStats();
    _achievements = <String, int>{};
    _prefs.remove(_kAchievements);
    notifyListeners();
  }

  void recordGame({required bool won, required int players, required AiLevel level}) {
    final st = _stats;
    st.games++;
    st.gamesByLevel[level.index]++;
    if (players == 4) {
      st.games2v2++;
    } else {
      st.games1v1++;
    }
    if (won) {
      st.wins++;
      st.winsByLevel[level.index]++;
      if (players == 4) {
        st.wins2v2++;
      } else {
        st.wins1v1++;
      }
      st.streak++;
      if (st.streak > st.bestStreak) st.bestStreak = st.streak;
    } else {
      st.streak = 0;
    }
    _saveStats();
  }

  /// The running offline tournament (JSON), if any.
  String? get tournamentJson => _prefs.getString(_kTournament);

  Future<void> saveTournament(String json) => _prefs.setString(_kTournament, json);

  Future<void> clearTournament() => _prefs.remove(_kTournament);

  // The saved game is written after every move; this does not notify
  // listeners on purpose (it would rebuild the whole app each move).
  String? get savedGame => _prefs.getString(_kSaved);

  bool get hasSavedGame => _prefs.containsKey(_kSaved);

  Future<void> saveGame(String json) => _prefs.setString(_kSaved, json);

  Future<void> clearSavedGame() => _prefs.remove(_kSaved);
}

/// Makes [AppSettings] available to the widget tree and rebuilds dependants
/// when it changes.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing');
    return scope!.notifier!;
  }

  /// Read without subscribing to changes (for callbacks).
  static AppSettings read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope missing');
    return scope!.notifier!;
  }
}
