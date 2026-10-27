import '../engine/pastra_ai.dart';

/// Who sits on a seat. `remote` is reserved for online play (next phase).
enum SeatKind { human, bot, remote }

class SeatInfo {
  final SeatKind kind;
  final AiLevel level;

  /// Index of the bot's display name (see `Strings.botName`), -1 for humans.
  final int botIndex;

  const SeatInfo({required this.kind, this.level = AiLevel.medium, this.botIndex = -1});

  const SeatInfo.human()
      : kind = SeatKind.human,
        level = AiLevel.medium,
        botIndex = -1;

  const SeatInfo.bot(this.level, this.botIndex) : kind = SeatKind.bot;

  bool get isHuman => kind == SeatKind.human;

  bool get isBot => kind == SeatKind.bot;

  /// Seat 0 is always the local player. In 2v2 seat 2 is the partner.
  static List<SeatInfo> lineup(int players, AiLevel level) {
    if (players == 2) {
      return <SeatInfo>[const SeatInfo.human(), SeatInfo.bot(level, 0)];
    }
    final partnerLevel = level == AiLevel.easy ? AiLevel.medium : level;
    return <SeatInfo>[
      const SeatInfo.human(),
      SeatInfo.bot(level, 1),
      SeatInfo.bot(partnerLevel, 2),
      SeatInfo.bot(level, 3),
    ];
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
