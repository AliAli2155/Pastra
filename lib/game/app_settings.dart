import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/pastra_ai.dart';
import '../engine/rules.dart';
import '../ui/theme.dart';
import 'achievements.dart';
import 'economy.dart';
import 'friends.dart';
import 'progression.dart';
import 'quests.dart';
import 'seasons.dart';
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
  int onlineGames = 0;
  int onlineWins = 0;

  /// Daily quests collected, days with all quests collected.
  int questsDone = 0;
  int perfectDays = 0;

  /// Most days in a row the game was opened.
  int loginBest = 0;

  /// Seasons finished in the top 10.
  int seasonTop10 = 0;

  /// Most pastras of the local player in one game.
  int bestGamePastras = 0;

  /// Finished games per table colour (the favourite table).
  Map<String, int> tableGames = <String, int>{};

  /// The table colour played on most (null before the first game).
  String? get favoriteTable {
    String? best;
    var n = 0;
    tableGames.forEach((k, v) {
      if (v > n) {
        n = v;
        best = k;
      }
    });
    return best;
  }

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
        'onlineGames': onlineGames,
        'onlineWins': onlineWins,
        'questsDone': questsDone,
        'perfectDays': perfectDays,
        'loginBest': loginBest,
        'seasonTop10': seasonTop10,
        'bestGamePastras': bestGamePastras,
        'tableGames': tableGames,
        'gamesByLevel': gamesByLevel,
        'winsByLevel': winsByLevel,
      };

  static Map<String, int> _counts(Object? v) {
    if (v is! Map) return <String, int>{};
    return <String, int>{
      for (final e in v.entries)
        if (e.value is num) '${e.key}': (e.value as num).toInt(),
    };
  }

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
      ..onlineGames = i('onlineGames')
      ..onlineWins = i('onlineWins')
      ..questsDone = i('questsDone')
      ..perfectDays = i('perfectDays')
      ..loginBest = i('loginBest')
      ..seasonTop10 = i('seasonTop10')
      ..bestGamePastras = i('bestGamePastras')
      ..tableGames = _counts(j['tableGames'])
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
  static const String _kChips = 'chips';
  static const String _kDiamonds = 'diamonds';
  static const String _kDailyDay = 'dailyDay';
  static const String _kDailyStreak = 'dailyStreak';
  static const String _kFreeAt = 'freeChipsAt';
  static const String _kOwned = 'ownedItems';
  static const String _kSalon = 'salon';
  static const String _kCupFees = 'cupFeeKeys';
  static const String _kSeed = 'playerSeed';
  static const String _kQuestDay = 'questDay';
  static const String _kQuestIds = 'questIds';
  static const String _kQuestProgress = 'questProgress';
  static const String _kQuestClaimed = 'questClaimed';
  static const String _kQuestReroll = 'questRerolled';
  static const String _kQuestBonus = 'questBonus';
  static const String _kLoginDay = 'loginDay';
  static const String _kLoginStreak = 'loginStreak';
  static const String _kFrame = 'avatarFrame';
  static const String _kSeason = 'season';
  static const String _kSeasonXp = 'seasonXp';
  static const String _kSeasonWins = 'seasonWins';
  static const String _kSeasonGames = 'seasonGames';
  static const String _kSeasonPending = 'seasonPending';
  static const String _kSeasonBadges = 'seasonBadges';
  static const String _kFriends = 'friends';
  static const String _kTag = 'playerTag';
  static const String _kHandleKey = 'handleKey';

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
  int _chips = Economy.startChips;
  int _diamonds = Economy.startDiamonds;
  Set<String> _owned = <String>{};

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
    final chips = _prefs.getInt(_kChips);
    if (chips == null) {
      // First start with chips (also players from before chips existed).
      _prefs.setInt(_kChips, _chips);
      _prefs.setInt(_kDiamonds, _diamonds);
    } else {
      _chips = chips < 0 ? 0 : chips;
      _diamonds = (_prefs.getInt(_kDiamonds) ?? 0).clamp(0, 999999999);
    }
    _owned = (_prefs.getStringList(_kOwned) ?? const <String>[]).toSet();
    // A colour that is still locked (e.g. an old save) falls back to the default.
    if (!isUnlocked(Look.table)) Look.table = TableTheme.green;
    if (!isBackUnlocked(Look.back)) Look.back = CardBackStyle.aegean;
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

  /// Level colours unlock with the level; store colours when bought.
  bool isUnlocked(TableTheme t) {
    final item = Economy.itemForTable(t);
    return item != null ? owns(item.id) : Progression.levelFor(t) <= playerLevel;
  }

  bool isBackUnlocked(CardBackStyle b) {
    final item = Economy.itemForBack(b);
    return item != null ? owns(item.id) : Progression.levelForBack(b) <= playerLevel;
  }

  /// Adds experience points; returns the level before and after. Every new
  /// level also gives chips and diamonds. Does not notify (called during
  /// games; screens read the value when they build).
  ({int before, int after}) addXp(int amount, {bool season = true}) {
    final before = playerLevel;
    if (amount > 0) {
      _xp += amount;
      _prefs.setInt(_kXp, _xp);
      if (season) {
        _rollSeason();
        _prefs.setInt(_kSeasonXp, seasonXp + amount);
      }
    }
    final after = playerLevel;
    for (var l = before + 1; Economy.enabled && l <= after; l++) {
      _chips += Economy.levelUpChips(l);
      _diamonds += Economy.levelUpDiamonds;
    }
    if (Economy.enabled && after > before) _saveWallet();
    return (before: before, after: after);
  }

  // ---- chips and diamonds (see Economy)

  int get chips => _chips;
  int get diamonds => _diamonds;

  void _saveWallet() {
    _prefs.setInt(_kChips, _chips);
    _prefs.setInt(_kDiamonds, _diamonds);
  }

  /// Tells the screens that the balances changed (not during a game move).
  void walletChanged() => notifyListeners();

  /// Adds (or with a negative amount removes) chips and diamonds.
  /// [notify] = false during a game.
  void addWallet({int chips = 0, int diamonds = 0, bool notify = true}) {
    _chips = (_chips + chips).clamp(0, 999999999999);
    _diamonds = (_diamonds + diamonds).clamp(0, 999999999);
    _saveWallet();
    if (notify) notifyListeners();
  }

  /// Pays [chips] / [diamonds] if the balance allows it.
  bool spend({int chips = 0, int diamonds = 0, bool notify = true}) {
    if (chips > _chips || diamonds > _diamonds) return false;
    addWallet(chips: -chips, diamonds: -diamonds, notify: notify);
    return true;
  }

  bool owns(String itemId) => _owned.contains(itemId);

  /// Buys a store item; false when it is owned already or too expensive.
  bool buy(ShopItem item) {
    if (owns(item.id) || !spend(chips: item.chips, diamonds: item.diamonds, notify: false)) return false;
    _owned.add(item.id);
    _prefs.setStringList(_kOwned, _owned.toList());
    notifyListeners();
    return true;
  }

  /// Diamonds → chips.
  bool exchange(Exchange e) {
    if (!spend(diamonds: e.diamonds, notify: false)) return false;
    addWallet(chips: e.chips);
    return true;
  }

  /// The daily bonus streak (days in a row it was claimed).
  int get dailyStreak => _prefs.getInt(_kDailyStreak) ?? 0;

  /// The streak claiming today would give (null = already claimed today).
  int? dailyNext(DateTime now) => Economy.nextStreak(
        lastDay: _prefs.getInt(_kDailyDay) ?? -1,
        streak: dailyStreak,
        today: Economy.dayNumber(now),
      );

  /// Claims today's bonus; returns what it gave (null = claimed already).
  ({int chips, int diamonds, int day})? claimDaily(DateTime now) {
    final streak = dailyNext(now);
    if (streak == null) return null;
    _prefs.setInt(_kDailyDay, Economy.dayNumber(now));
    _prefs.setInt(_kDailyStreak, streak);
    final chips = Economy.dailyReward(streak);
    final diamonds = Economy.dailyDiamonds(streak);
    addWallet(chips: chips, diamonds: diamonds);
    return (chips: chips, diamonds: diamonds, day: Economy.streakDay(streak));
  }

  /// When the next free chips can be taken.
  DateTime get freeChipsAt => DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_kFreeAt) ?? 0);

  /// Takes the free chips; returns how many (0 = not yet).
  int claimFreeChips(DateTime now) {
    if (now.isBefore(freeChipsAt)) return 0;
    final amount = Economy.freeChipsFor(_chips);
    _prefs.setInt(_kFreeAt, now.add(Economy.freeChipsEvery).millisecondsSinceEpoch);
    addWallet(chips: amount);
    return amount;
  }

  /// The salon (stake) picked for online tables.
  int get salonStake {
    final stake = _prefs.getInt(_kSalon) ?? Economy.salons[1].stake;
    return Economy.salons.any((s) => s.stake == stake) ? stake : Economy.salons[1].stake;
  }

  set salonStake(int value) {
    _prefs.setInt(_kSalon, value);
    notifyListeners();
  }

  /// Whether the player may sit at a table of this salon.
  bool canSit(Salon salon) => playerLevel >= salon.minLevel && _chips >= salon.stake;

  /// Online cups whose entry fee was paid (to give it back on leaving).
  bool cupFeePaid(String key) => (_prefs.getStringList(_kCupFees) ?? const <String>[]).contains(key);

  void setCupFeePaid(String key, bool paid) {
    final list = <String>[...(_prefs.getStringList(_kCupFees) ?? const <String>[])]..remove(key);
    if (paid) list.add(key);
    _prefs.setStringList(_kCupFees, list.length > 20 ? list.sublist(list.length - 20) : list);
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

  void recordGame({
    required bool won,
    required int players,
    required AiLevel level,
    bool online = false,
    int pastras = 0,
  }) {
    final st = _stats;
    st.games++;
    if (pastras > st.bestGamePastras) st.bestGamePastras = pastras;
    st.tableGames[Look.table.name] = (st.tableGames[Look.table.name] ?? 0) + 1;
    if (online) {
      st.onlineGames++;
      if (won) st.onlineWins++;
    }
    _rollSeason();
    _prefs.setInt(_kSeasonGames, seasonGames + 1);
    if (won) _prefs.setInt(_kSeasonWins, seasonWins + 1);
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

  // ---- daily quests (see Quests)

  /// A random number of this player (installation): their quests differ
  /// from everybody else's.
  int get _playerSeed {
    var seed = _prefs.getInt(_kSeed);
    if (seed == null) {
      seed = Random().nextInt(0x7fffffff);
      _prefs.setInt(_kSeed, seed);
    }
    return seed;
  }

  int get _today => Economy.dayNumber(DateTime.now());

  /// Starts the day's quests when the day changed.
  void _ensureQuests() {
    final today = _today;
    if (_prefs.getInt(_kQuestDay) == today && (_prefs.getStringList(_kQuestIds)?.length ?? 0) == 3) return;
    _prefs.setInt(_kQuestDay, today);
    _prefs.setStringList(_kQuestIds, Quests.pick(Quests.seed(_playerSeed, today)));
    _prefs.setString(_kQuestProgress, '{}');
    _prefs.setStringList(_kQuestClaimed, const <String>[]);
    _prefs.setBool(_kQuestReroll, false);
    _prefs.setBool(_kQuestBonus, false);
  }

  Map<String, int> get _questProgress {
    try {
      return (jsonDecode(_prefs.getString(_kQuestProgress) ?? '{}') as Map<String, dynamic>)
          .map((k, v) => MapEntry<String, int>(k, (v as num).toInt()));
    } catch (_) {
      return <String, int>{};
    }
  }

  /// Today's three quests.
  List<QuestState> get quests {
    _ensureQuests();
    final progress = _questProgress;
    final claimed = _prefs.getStringList(_kQuestClaimed) ?? const <String>[];
    return <QuestState>[
      for (final id in _prefs.getStringList(_kQuestIds)!)
        if (Quests.byId(id) case final def?) QuestState(def, progress[id] ?? 0, claimed.contains(id)),
    ];
  }

  /// Quests (and the bonus) waiting to be collected.
  int get questsReady {
    final list = quests;
    var n = list.where((q) => q.done && !q.claimed).length;
    if (questBonusReady) n++;
    return n;
  }

  bool get questBonusReady => quests.every((q) => q.claimed) && !(_prefs.getBool(_kQuestBonus) ?? false);
  bool get questBonusClaimed => _prefs.getBool(_kQuestBonus) ?? false;

  /// One quest a day can be swapped for another of the same difficulty.
  bool get canRerollQuest => !(_prefs.getBool(_kQuestReroll) ?? false);

  /// Something happened in a game; returns the quests completed by it.
  List<String> questEvent(QuestEvent e) {
    final list = quests;
    final progress = _questProgress;
    final done = <String>[];
    for (final q in list) {
      final before = progress[q.def.id] ?? 0;
      final after = Quests.advance(q.def, before, e);
      if (after == before) continue;
      progress[q.def.id] = after;
      if (before < q.def.goal && after >= q.def.goal) done.add(q.def.id);
    }
    _prefs.setString(_kQuestProgress, jsonEncode(progress));
    return done;
  }

  /// Collects a finished quest: XP (and chips). Returns the XP, or null.
  int? claimQuest(String id) {
    final q = quests.where((x) => x.def.id == id).firstOrNull;
    if (q == null || !q.done || q.claimed) return null;
    _prefs.setStringList(_kQuestClaimed, <String>[...(_prefs.getStringList(_kQuestClaimed) ?? const <String>[]), id]);
    _stats.questsDone++;
    _saveStats();
    addXp(q.def.xp);
    if (Economy.enabled) addWallet(chips: Quests.chipsFor(q.def), notify: false);
    notifyListeners();
    return q.def.xp;
  }

  /// Collects the bonus for all three quests of the day.
  bool claimQuestBonus() {
    if (!questBonusReady) return false;
    _prefs.setBool(_kQuestBonus, true);
    _stats.perfectDays++;
    _saveStats();
    addXp(Quests.allBonusXp);
    if (Economy.enabled) addWallet(chips: Quests.allBonusChips, diamonds: Quests.allBonusDiamonds, notify: false);
    notifyListeners();
    return true;
  }

  /// Swaps an unfinished quest for another one of the same difficulty.
  bool rerollQuest(String id) {
    if (!canRerollQuest) return false;
    final ids = <String>[...(_prefs.getStringList(_kQuestIds) ?? const <String>[])];
    final i = ids.indexOf(id);
    if (i < 0 || (_questProgress[id] ?? 0) > 0) return false;
    final next = Quests.reroll(ids, id, Quests.seed(_playerSeed, _today) + 1);
    if (next == null) return false;
    ids[i] = next;
    _prefs.setStringList(_kQuestIds, ids);
    _prefs.setBool(_kQuestReroll, true);
    notifyListeners();
    return true;
  }

  // ---- days in a row

  int get loginStreak => _prefs.getInt(_kLoginStreak) ?? 0;

  /// Counts the days in a row the game was opened; returns new achievements.
  List<String> touchDay() {
    final today = _today;
    final last = _prefs.getInt(_kLoginDay);
    if (last == today) return const <String>[];
    final streak = last == today - 1 ? loginStreak + 1 : 1;
    _prefs.setInt(_kLoginDay, today);
    _prefs.setInt(_kLoginStreak, streak);
    if (streak > _stats.loginBest) {
      _stats.loginBest = streak;
      _saveStats();
    }
    return unlockEarned();
  }

  /// Unlocks the counter achievements reached outside a game.
  List<String> unlockEarned() => unlockAchievements(earnedAchievements(_stats));

  // ---- friends (people met online)

  List<Friend> get friends {
    try {
      final raw = jsonDecode(_prefs.getString(_kFriends) ?? '[]') as List<dynamic>;
      return <Friend>[
        for (final j in raw)
          if (Friend.fromJson(j) case final f?) f,
      ];
    } catch (_) {
      return <Friend>[];
    }
  }

  void _saveFriends(List<Friend> list) {
    _prefs.setString(_kFriends, jsonEncode(<Object>[for (final f in list) f.toJson()]));
    notifyListeners();
  }

  /// The people of an online game (uid → name), newest first.
  void addRecentPlayers(Map<String, String> people) {
    if (people.isEmpty) return;
    _saveFriends(Friend.merge(friends, people, DateTime.now().millisecondsSinceEpoch));
  }

  void setFavorite(String uid, bool favorite) {
    _saveFriends(<Friend>[for (final f in friends) f.uid == uid ? f.copyWith(favorite: favorite) : f]);
  }

  void removeFriend(String uid) => _saveFriends(<Friend>[for (final f in friends) if (f.uid != uid) f]);

  /// Adds somebody found by their code (a favourite at once).
  void addFriend({required String uid, required String name, required String tag}) {
    final list = friends;
    final i = list.indexWhere((f) => f.uid == uid);
    if (i >= 0) {
      list[i] = list[i].copyWith(name: name, tag: tag, favorite: true);
    } else {
      list.insert(0, Friend(uid: uid, name: name, tag: tag, lastPlayed: DateTime.now().millisecondsSinceEpoch, favorite: true, games: 0));
    }
    _saveFriends(list);
  }

  /// A friend's current name and code (read from the database).
  void updateFriendInfo(String uid, {required String name, required String tag}) {
    final list = friends;
    final i = list.indexWhere((f) => f.uid == uid);
    if (i < 0 || (list[i].name == name && list[i].tag == tag) || name.isEmpty) return;
    list[i] = list[i].copyWith(name: name, tag: tag);
    _saveFriends(list);
  }

  // ---- the player's own code ("Player #1270")

  /// The 4-digit tag after the name (null until it was given online).
  String? get playerTag => _prefs.getString(_kTag);

  /// The database key the tag is registered under (name~tag).
  String? get handleKey => _prefs.getString(_kHandleKey);

  void setHandle({required String tag, required String key}) {
    _prefs.setString(_kTag, tag);
    _prefs.setString(_kHandleKey, key);
    notifyListeners();
  }

  // ---- avatar frame and title

  bool isFrameUnlocked(AvatarFrame f) => Progression.levelForFrame(f) <= playerLevel;

  /// The chosen frame; without a choice the best one unlocked.
  AvatarFrame get avatarFrame {
    final name = _prefs.getString(_kFrame);
    final chosen = AvatarFrame.values.where((f) => f.name == name).firstOrNull;
    if (chosen != null && isFrameUnlocked(chosen)) return chosen;
    return Progression.bestFrame(playerLevel);
  }

  set avatarFrame(AvatarFrame f) {
    if (!isFrameUnlocked(f)) return;
    _prefs.setString(_kFrame, f.name);
    notifyListeners();
  }

  PlayerTitle get title => Progression.titleFor(playerLevel);

  // ---- seasons (see Seasons)

  /// Starts a new season's counters when the month changed; the old season
  /// waits for its final ranking.
  void _rollSeason() {
    final now = Seasons.current();
    final stored = _prefs.getString(_kSeason);
    if (stored == now) return;
    if (stored != null && (_prefs.getInt(_kSeasonGames) ?? 0) > 0) {
      _prefs.setStringList(_kSeasonPending, <String>[...seasonsPending, stored]);
    }
    _prefs.setString(_kSeason, now);
    _prefs.setInt(_kSeasonXp, 0);
    _prefs.setInt(_kSeasonWins, 0);
    _prefs.setInt(_kSeasonGames, 0);
  }

  String get season {
    _rollSeason();
    return _prefs.getString(_kSeason)!;
  }

  int get seasonXp {
    _rollSeason();
    return _prefs.getInt(_kSeasonXp) ?? 0;
  }

  int get seasonWins {
    _rollSeason();
    return _prefs.getInt(_kSeasonWins) ?? 0;
  }

  int get seasonGames {
    _rollSeason();
    return _prefs.getInt(_kSeasonGames) ?? 0;
  }

  /// Finished seasons whose final place is not known yet.
  List<String> get seasonsPending {
    final list = _prefs.getStringList(_kSeasonPending) ?? const <String>[];
    return <String>[for (final s in list) if (Seasons.isValid(s)) s];
  }

  List<SeasonBadge> get seasonBadges {
    try {
      final raw = jsonDecode(_prefs.getString(_kSeasonBadges) ?? '[]') as List<dynamic>;
      return <SeasonBadge>[
        for (final j in raw)
          if (SeasonBadge.fromJson(j) case final b?) b,
      ];
    } catch (_) {
      return <SeasonBadge>[];
    }
  }

  /// The final place of a finished season: badge, XP reward, achievements.
  /// Returns the badge (null when [season] was not waiting).
  SeasonBadge? finishSeason(String season, int rank) {
    if (!seasonsPending.contains(season)) return null;
    _prefs.setStringList(_kSeasonPending, <String>[for (final s in seasonsPending) if (s != season) s]);
    final badge = SeasonBadge(season: season, rank: rank, tier: Seasons.tierFor(rank));
    final badges = <SeasonBadge>[...seasonBadges, badge];
    _prefs.setString(_kSeasonBadges, jsonEncode(<Object>[for (final b in badges) b.toJson()]));
    if (rank >= 1 && rank <= 10) {
      _stats.seasonTop10++;
      _saveStats();
    }
    addXp(Seasons.rewardXp(badge.tier), season: false);
    unlockEarned();
    notifyListeners();
    return badge;
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
