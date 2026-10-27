import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/pastra_ai.dart';
import '../engine/rules.dart';

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
  static const String _kSaved = 'savedGame';

  static const List<String> languages = ['el', 'en'];

  String _language = 'el';
  PastraRules _rules = const PastraRules();
  AiLevel _level = AiLevel.medium;
  int _players = 2;
  String _playerName = '';
  bool _fastAnimations = false;
  bool _haptics = true;
  int _turnSeconds = 15;
  int _gamesPlayed = 0;
  int _gamesWon = 0;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings._(prefs);
    settings._read();
    return settings;
  }

  void _read() {
    final system = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final lang = _prefs.getString(_kLanguage);
    _language = languages.contains(lang) ? lang! : (system == 'el' ? 'el' : 'en');

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
    _gamesPlayed = _prefs.getInt(_kPlayed) ?? 0;
    _gamesWon = _prefs.getInt(_kWon) ?? 0;
  }

  String get language => _language;
  bool get isGreek => _language == 'el';
  PastraRules get rules => _rules;
  AiLevel get level => _level;
  int get players => _players;
  String get playerName => _playerName;
  bool get fastAnimations => _fastAnimations;
  bool get haptics => _haptics;
  int get turnSeconds => _turnSeconds;
  int get gamesPlayed => _gamesPlayed;
  int get gamesWon => _gamesWon;

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

  void recordGame({required bool won}) {
    _gamesPlayed++;
    if (won) _gamesWon++;
    _prefs.setInt(_kPlayed, _gamesPlayed);
    _prefs.setInt(_kWon, _gamesWon);
  }

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
