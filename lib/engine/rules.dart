import 'cards.dart';

/// Which game is played.
enum GameVariant {
  /// Classic pile game (Greek "Ξερή"): the played cards form one pile, only
  /// the top card is visible. A card of the same rank as the top card, or a
  /// jack, takes the whole pile. Taking a lone card is a pastra.
  pile,

  /// Cypriot capture-by-sum game: table cards lie open side by side and a
  /// numeral takes equal cards and groups adding up to its value.
  sums,
}

/// Adjustable rules (see docs/ARASTIRMA.md). The defaults are the pile game
/// with Greek Xeri scoring.
class PastraRules {
  final GameVariant variant;

  /// First team to reach this total (and lead) wins the game.
  final int targetScore;

  /// Cards dealt to each player per deal: 4 or 6.
  final int cardsPerDeal;

  /// Bonus for a pastra (pile: taking a lone card with the same rank;
  /// sums: clearing the table with a non-jack).
  final int pastraPoints;

  /// Whether a jack also scores a pastra (pile: a jack on a lone non-jack
  /// card; sums: a jack sweeping the table).
  final bool jackSweepIsPastra;

  /// Bonus when a jack captures a lone jack (0 = nothing special).
  final int jackOnJackPoints;

  /// Whether the very last card of a round may still score a pastra.
  final bool pastraOnLastCard;

  const PastraRules({
    this.variant = GameVariant.pile,
    this.targetScore = 151,
    this.cardsPerDeal = 6,
    this.pastraPoints = 10,
    this.jackSweepIsPastra = false,
    this.jackOnJackPoints = 20,
    this.pastraOnLastCard = false,
  });

  /// Defaults of the pile game (Greek Xeri).
  static const PastraRules pileDefaults = PastraRules();

  /// Defaults of the Cypriot capture-by-sum game.
  static const PastraRules sumsDefaults = PastraRules(
    variant: GameVariant.sums,
    targetScore: 101,
    cardsPerDeal: 4,
    jackOnJackPoints: 10,
    pastraOnLastCard: true,
  );

  static PastraRules defaultsFor(GameVariant variant) =>
      variant == GameVariant.pile ? pileDefaults : sumsDefaults;

  static const List<int> targetOptions = [51, 101, 151, 251];
  static const List<int> dealOptions = [4, 6];

  bool get isPile => variant == GameVariant.pile;

  List<int> get jackOnJackOptions => isPile ? const [10, 20, 25] : const [0, 10, 20];

  /// Points a captured card is worth at the end of a round.
  int pointsOf(int card) => isPile ? Cards.xeriPoints(card) : Cards.points(card);

  /// Round bonus for 2♣ (pile: 1, sums: 2).
  int get twoOfClubsBonus => isPile ? 1 : 2;

  /// Round bonus for 10♦ on top of what its rank gives (pile: +1, sums: 3).
  int get tenOfDiamondsBonus => isPile ? 1 : 3;

  static const int mostCardsBonus = 3;

  PastraRules copyWith({
    GameVariant? variant,
    int? targetScore,
    int? cardsPerDeal,
    int? pastraPoints,
    bool? jackSweepIsPastra,
    int? jackOnJackPoints,
    bool? pastraOnLastCard,
  }) {
    return PastraRules(
      variant: variant ?? this.variant,
      targetScore: targetScore ?? this.targetScore,
      cardsPerDeal: cardsPerDeal ?? this.cardsPerDeal,
      pastraPoints: pastraPoints ?? this.pastraPoints,
      jackSweepIsPastra: jackSweepIsPastra ?? this.jackSweepIsPastra,
      jackOnJackPoints: jackOnJackPoints ?? this.jackOnJackPoints,
      pastraOnLastCard: pastraOnLastCard ?? this.pastraOnLastCard,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'variant': variant.name,
        'targetScore': targetScore,
        'cardsPerDeal': cardsPerDeal,
        'pastraPoints': pastraPoints,
        'jackSweepIsPastra': jackSweepIsPastra,
        'jackOnJackPoints': jackOnJackPoints,
        'pastraOnLastCard': pastraOnLastCard,
      };

  /// Rules saved before the pile game existed have no 'variant': they were
  /// the capture-by-sum game, so [missingVariant] defaults to that.
  factory PastraRules.fromJson(
    Map<String, dynamic> json, {
    GameVariant missingVariant = GameVariant.sums,
  }) {
    final name = json['variant'];
    final variant = GameVariant.values.firstWhere(
      (v) => v.name == name,
      orElse: () => missingVariant,
    );
    final d = defaultsFor(variant);
    int readInt(String key, int fallback) {
      final v = json[key];
      return v is num ? v.toInt() : fallback;
    }

    bool readBool(String key, bool fallback) {
      final v = json[key];
      return v is bool ? v : fallback;
    }

    final deal = readInt('cardsPerDeal', d.cardsPerDeal);
    final target = readInt('targetScore', d.targetScore);
    final jackOnJack = readInt('jackOnJackPoints', d.jackOnJackPoints);
    return PastraRules(
      variant: variant,
      targetScore: targetOptions.contains(target) ? target : d.targetScore,
      cardsPerDeal: dealOptions.contains(deal) ? deal : d.cardsPerDeal,
      pastraPoints: readInt('pastraPoints', d.pastraPoints),
      jackSweepIsPastra: readBool('jackSweepIsPastra', d.jackSweepIsPastra),
      jackOnJackPoints: d.jackOnJackOptions.contains(jackOnJack) ? jackOnJack : d.jackOnJackPoints,
      pastraOnLastCard: readBool('pastraOnLastCard', d.pastraOnLastCard),
    );
  }
}
