import '../engine/pastra_ai.dart';
import 'seats.dart';

/// Someone else at the table of a finished game: a bot (by its name index
/// and level) or an online player (name, avatar picture and frame).
class MatchPlayer {
  const MatchPlayer({this.name = '', this.botIndex = -1, this.level = AiLevel.medium, this.pic = '', this.frame = ''});

  /// An online player's name; empty for a bot.
  final String name;

  /// A bot's name index (see `Strings.botName`), -1 for a person.
  final int botIndex;
  final AiLevel level;
  final String pic;
  final String frame;

  bool get isBot => botIndex >= 0;

  factory MatchPlayer.of(SeatInfo seat) => seat.isBot
      ? MatchPlayer(botIndex: seat.botIndex, level: seat.level)
      : MatchPlayer(name: seat.name ?? '', pic: seat.pic, frame: seat.frame);

  Map<String, Object> toJson() => <String, Object>{
        if (name.isNotEmpty) 'n': name,
        if (botIndex >= 0) 'b': botIndex,
        if (botIndex >= 0) 'l': level.name,
        if (pic.isNotEmpty) 'p': pic,
        if (frame.isNotEmpty) 'r': frame,
      };

  static MatchPlayer fromJson(Object? j) {
    if (j is! Map) return const MatchPlayer();
    return MatchPlayer(
      name: j['n'] is String ? j['n'] as String : '',
      botIndex: (j['b'] as num?)?.toInt() ?? -1,
      level: AiLevel.values.where((l) => l.name == j['l']).firstOrNull ?? AiLevel.medium,
      pic: j['p'] is String ? j['p'] as String : '',
      frame: j['r'] is String ? j['r'] as String : '',
    );
  }
}

enum MatchMode { offline, online, tournament }

/// One finished game in the match history.
class MatchRecord {
  const MatchRecord({
    required this.time,
    required this.won,
    required this.ours,
    required this.theirs,
    required this.mode,
    required this.others,
    this.level = AiLevel.medium,
    this.pastras = 0,
    this.rounds = 1,
  });

  /// When it ended (milliseconds since the epoch).
  final int time;
  final bool won;

  /// Final scores: our side and the other side.
  final int ours;
  final int theirs;
  final MatchMode mode;

  /// The difficulty of the bots (offline).
  final AiLevel level;

  /// The other seats in seat order: one opponent in 1v1; opponent, partner,
  /// opponent in 2v2.
  final List<MatchPlayer> others;
  final int pastras;
  final int rounds;

  /// The number of players at the table.
  int get players => others.length + 1;

  /// The partner in 2v2 (null in 1v1).
  MatchPlayer? get partner => others.length == 3 ? others[1] : null;

  /// The opponents.
  List<MatchPlayer> get opponents => others.length == 3 ? <MatchPlayer>[others[0], others[2]] : others;

  /// An offline game can be played again with the same bots.
  bool get canRematch => mode == MatchMode.offline && others.every((p) => p.isBot);

  /// The seats of a rematch: the same bots, at the same level.
  List<SeatInfo> rematchSeats() => <SeatInfo>[
        const SeatInfo.human(),
        for (final p in others) SeatInfo.bot(p.level, p.botIndex),
      ];

  Map<String, Object> toJson() => <String, Object>{
        't': time,
        'w': won,
        's': <int>[ours, theirs],
        'm': mode.name,
        'l': level.name,
        'o': <Object>[for (final p in others) p.toJson()],
        'p': pastras,
        'r': rounds,
      };

  static MatchRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = j['t'];
    final s = j['s'];
    final o = j['o'];
    if (t is! num || s is! List || s.length != 2 || o is! List || o.isEmpty) return null;
    return MatchRecord(
      time: t.toInt(),
      won: j['w'] == true,
      ours: (s[0] as num?)?.toInt() ?? 0,
      theirs: (s[1] as num?)?.toInt() ?? 0,
      mode: MatchMode.values.where((m) => m.name == j['m']).firstOrNull ?? MatchMode.offline,
      level: AiLevel.values.where((l) => l.name == j['l']).firstOrNull ?? AiLevel.medium,
      others: <MatchPlayer>[for (final p in o) MatchPlayer.fromJson(p)],
      pastras: (j['p'] as num?)?.toInt() ?? 0,
      rounds: (j['r'] as num?)?.toInt() ?? 1,
    );
  }

  /// [list] with [record] in front, at most [max] games.
  static List<MatchRecord> add(List<MatchRecord> list, MatchRecord record, {int max = 20}) =>
      <MatchRecord>[record, ...list].take(max).toList();
}
