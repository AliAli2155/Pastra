import 'rules.dart';

enum GamePhase { playing, roundOver, gameOver }

/// One team's result for a finished round.
class TeamRoundScore {
  final int cards;
  final int aces;
  final int jacks;

  /// Aces, kings, queens, jacks and tens (pile game: 1 point each).
  final int honours;
  final bool twoOfClubs;
  final bool tenOfDiamonds;
  final int pastras;
  final int pastraPoints;
  final bool mostCards;
  final int total;

  const TeamRoundScore({
    required this.cards,
    required this.aces,
    required this.jacks,
    this.honours = 0,
    required this.twoOfClubs,
    required this.tenOfDiamonds,
    required this.pastras,
    required this.pastraPoints,
    required this.mostCards,
    required this.total,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cards': cards,
        'aces': aces,
        'jacks': jacks,
        'honours': honours,
        'twoOfClubs': twoOfClubs,
        'tenOfDiamonds': tenOfDiamonds,
        'pastras': pastras,
        'pastraPoints': pastraPoints,
        'mostCards': mostCards,
        'total': total,
      };

  factory TeamRoundScore.fromJson(Map<String, dynamic> j) => TeamRoundScore(
        cards: (j['cards'] as num).toInt(),
        aces: (j['aces'] as num).toInt(),
        jacks: (j['jacks'] as num).toInt(),
        honours: (j['honours'] as num?)?.toInt() ?? 0,
        twoOfClubs: j['twoOfClubs'] as bool,
        tenOfDiamonds: j['tenOfDiamonds'] as bool,
        pastras: (j['pastras'] as num).toInt(),
        pastraPoints: (j['pastraPoints'] as num).toInt(),
        mostCards: j['mostCards'] as bool,
        total: (j['total'] as num).toInt(),
      );
}

class RoundResult {
  /// Index 0 = team of seat 0 (the local player), 1 = the other team.
  final List<TeamRoundScore> teams;

  const RoundResult(this.teams);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'teams': teams.map((t) => t.toJson()).toList(),
      };

  factory RoundResult.fromJson(Map<String, dynamic> j) => RoundResult(
        (j['teams'] as List)
            .map((e) => TeamRoundScore.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Complete, serialisable state of a game. Seats go round the table:
/// 0 = local player, then the next players in turn order. Team = seat % 2,
/// so in 2v2 partners sit opposite each other (0 & 2 vs 1 & 3).
class GameState {
  PastraRules rules;
  int numPlayers;
  int seed;
  int round;
  int dealer;
  int current;

  /// Seat that captured last (-1: nobody yet this round). Gets the leftovers.
  int lastCapturer;

  /// How many deals were made in this round (1 = the opening deal).
  int dealNumber;

  List<List<int>> hands;
  List<int> table;

  /// Undealt cards. The top of the deck is the end of the list.
  List<int> deck;

  /// Captured cards per team.
  List<List<int>> piles;

  /// Cards that made a pastra, per team (shown crosswise on the pile).
  List<List<int>> pastraCards;

  /// Pastra bonus points per team in the current round.
  List<int> pastraPoints;

  /// Per team: the seat that captured first this round (-1 = nobody yet).
  /// The team's captured cards lie in front of that player.
  List<int> pileSeat;

  /// Game totals per team.
  List<int> scores;

  /// Pile game: cards everybody has seen while they are still in the deck —
  /// the "kapak altı", the bottom card of the deck that lies face up under
  /// it (and a jack that was put under the deck at the opening). The last
  /// card of the deck goes to the dealer, so these end up in the dealer's
  /// hand, still known to all.
  List<int> exposed;

  GamePhase phase;

  /// Winning team when [phase] is [GamePhase.gameOver], otherwise -1.
  int winner;

  RoundResult? lastResult;

  GameState({
    required this.rules,
    required this.numPlayers,
    required this.seed,
    this.round = 1,
    this.dealer = 0,
    this.current = 0,
    this.lastCapturer = -1,
    this.dealNumber = 0,
    List<List<int>>? hands,
    List<int>? table,
    List<int>? deck,
    List<List<int>>? piles,
    List<List<int>>? pastraCards,
    List<int>? pastraPoints,
    List<int>? pileSeat,
    List<int>? scores,
    List<int>? exposed,
    this.phase = GamePhase.playing,
    this.winner = -1,
    this.lastResult,
  })  : hands = hands ?? List<List<int>>.generate(numPlayers, (_) => <int>[]),
        table = table ?? <int>[],
        deck = deck ?? <int>[],
        piles = piles ?? <List<int>>[<int>[], <int>[]],
        pastraCards = pastraCards ?? <List<int>>[<int>[], <int>[]],
        pastraPoints = pastraPoints ?? <int>[0, 0],
        pileSeat = pileSeat ?? <int>[-1, -1],
        scores = scores ?? <int>[0, 0],
        exposed = exposed ?? <int>[];

  static int teamOf(int seat) => seat % 2;

  int get cardsInHands {
    var total = 0;
    for (final h in hands) {
      total += h.length;
    }
    return total;
  }

  bool get handsEmpty => cardsInHands == 0;

  GameState copy() => GameState(
        rules: rules,
        numPlayers: numPlayers,
        seed: seed,
        round: round,
        dealer: dealer,
        current: current,
        lastCapturer: lastCapturer,
        dealNumber: dealNumber,
        hands: hands.map((h) => List<int>.of(h)).toList(),
        table: List<int>.of(table),
        deck: List<int>.of(deck),
        piles: piles.map((p) => List<int>.of(p)).toList(),
        pastraCards: pastraCards.map((p) => List<int>.of(p)).toList(),
        pastraPoints: List<int>.of(pastraPoints),
        pileSeat: List<int>.of(pileSeat),
        scores: List<int>.of(scores),
        exposed: List<int>.of(exposed),
        phase: phase,
        winner: winner,
        lastResult: lastResult,
      );

  /// What [seat] is allowed to see: other hands and the deck become -1.
  /// An online server would send this to each client.
  GameState redactedFor(int seat) {
    final c = copy();
    for (var i = 0; i < c.hands.length; i++) {
      if (i != seat) c.hands[i] = <int>[for (final x in c.hands[i]) exposed.contains(x) ? x : -1];
    }
    c.deck = <int>[for (final x in c.deck) exposed.contains(x) ? x : -1];
    c.seed = 0;
    return c;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'rules': rules.toJson(),
        'numPlayers': numPlayers,
        'seed': seed,
        'round': round,
        'dealer': dealer,
        'current': current,
        'lastCapturer': lastCapturer,
        'dealNumber': dealNumber,
        'hands': hands,
        'table': table,
        'deck': deck,
        'piles': piles,
        'pastraCards': pastraCards,
        'pastraPoints': pastraPoints,
        'pileSeat': pileSeat,
        'scores': scores,
        'exposed': exposed,
        'phase': phase.name,
        'winner': winner,
        'lastResult': lastResult?.toJson(),
      };

  factory GameState.fromJson(Map<String, dynamic> j) {
    List<int> ints(dynamic v) => (v as List).map((e) => (e as num).toInt()).toList();
    List<List<int>> intLists(dynamic v) => (v as List).map(ints).toList();
    final phaseName = j['phase'] as String? ?? GamePhase.playing.name;
    final lr = j['lastResult'];
    return GameState(
      rules: PastraRules.fromJson(Map<String, dynamic>.from(j['rules'] as Map)),
      numPlayers: (j['numPlayers'] as num).toInt(),
      seed: (j['seed'] as num).toInt(),
      round: (j['round'] as num).toInt(),
      dealer: (j['dealer'] as num).toInt(),
      current: (j['current'] as num).toInt(),
      lastCapturer: (j['lastCapturer'] as num).toInt(),
      dealNumber: (j['dealNumber'] as num).toInt(),
      hands: intLists(j['hands']),
      table: ints(j['table']),
      deck: ints(j['deck']),
      piles: intLists(j['piles']),
      pastraCards: intLists(j['pastraCards']),
      pastraPoints: ints(j['pastraPoints']),
      pileSeat: j['pileSeat'] == null ? <int>[-1, -1] : ints(j['pileSeat']),
      scores: ints(j['scores']),
      exposed: j['exposed'] == null ? <int>[] : ints(j['exposed']),
      phase: GamePhase.values.firstWhere(
        (p) => p.name == phaseName,
        orElse: () => GamePhase.playing,
      ),
      winner: (j['winner'] as num).toInt(),
      lastResult: lr == null ? null : RoundResult.fromJson(Map<String, dynamic>.from(lr as Map)),
    );
  }
}
