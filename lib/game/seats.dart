import 'dart:math';

import '../engine/pastra_ai.dart';
import '../l10n/translations.dart';

/// Who sits on a seat. `remote` is a real person playing online.
enum SeatKind { human, bot, remote }

class SeatInfo {
  final SeatKind kind;
  final AiLevel level;

  /// Index of the bot's display name (see `Strings.botName`), -1 for humans.
  final int botIndex;

  /// Display name of an online player (null: use the usual naming).
  final String? name;

  /// An online player's avatar picture and frame (`AvatarPic` /
  /// `AvatarFrame` names, empty when unknown). Bots and the local player get
  /// theirs on the screen.
  final String pic;
  final String frame;

  /// An online player's card back (`CardBackStyle` name, empty when unknown):
  /// their cards show it on every screen.
  final String back;

  const SeatInfo({
    required this.kind,
    this.level = AiLevel.medium,
    this.botIndex = -1,
    this.name,
    this.pic = '',
    this.frame = '',
    this.back = '',
  });

  const SeatInfo.human()
      : kind = SeatKind.human,
        level = AiLevel.medium,
        botIndex = -1,
        name = null,
        pic = '',
        frame = '',
        back = '';

  const SeatInfo.bot(this.level, this.botIndex)
      : kind = SeatKind.bot,
        name = null,
        pic = '',
        frame = '',
        back = '';

  const SeatInfo.remote(this.name, {this.pic = '', this.frame = '', this.back = ''})
      : kind = SeatKind.remote,
        level = AiLevel.medium,
        botIndex = -1;

  bool get isHuman => kind == SeatKind.human;

  bool get isBot => kind == SeatKind.bot;

  bool get isRemote => kind == SeatKind.remote;

  /// Seat 0 is always the local player. In 2v2 seat 2 is the partner.
  static List<SeatInfo> lineup(int players, AiLevel level) {
    final names = randomBotNames(players - 1);
    if (players == 2) {
      return <SeatInfo>[const SeatInfo.human(), SeatInfo.bot(level, names[0])];
    }
    // A partner who plays too badly spoils the game: at least medium.
    final partnerLevel = level.atLeast(AiLevel.medium) ? level : AiLevel.medium;
    return <SeatInfo>[
      const SeatInfo.human(),
      SeatInfo.bot(level, names[0]),
      SeatInfo.bot(partnerLevel, names[1]),
      SeatInfo.bot(level, names[2]),
    ];
  }

  /// [count] different random indices into the list of bot names.
  static List<int> randomBotNames(int count) {
    final pool = List<int>.generate(kBotNames['en']!.length, (i) => i)..shuffle(Random());
    return pool.take(count).toList();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        'level': level.name,
        'botIndex': botIndex,
      };

  factory SeatInfo.fromJson(Map<String, dynamic> j) {
    final kindName = j['kind'] as String? ?? SeatKind.bot.name;
    final levelName = j['level'] as String? ?? AiLevel.medium.name;
    return SeatInfo(
      kind: SeatKind.values.firstWhere((k) => k.name == kindName, orElse: () => SeatKind.bot),
      level: AiLevel.values.firstWhere((l) => l.name == levelName, orElse: () => AiLevel.medium),
      botIndex: (j['botIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
