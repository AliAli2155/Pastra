/// Card helpers. A card is an `int` id in 0..51:
///
///     id = suit * 13 + (rank - 1)
///
/// Suits: 0 = ♣ clubs (σπαθί), 1 = ♦ diamonds (καρό), 2 = ♥ hearts (κούπα),
/// 3 = ♠ spades (μπαστούνι).
/// Ranks: 1 = ace, 2..10 = numerals, 11 = jack, 12 = queen, 13 = king.
///
/// Plain ints keep the game state trivially serialisable (save game, online play).
class Cards {
  Cards._();

  static const int deckSize = 52;

  static const int clubs = 0;
  static const int diamonds = 1;
  static const int hearts = 2;
  static const int spades = 3;

  static const int ace = 1;
  static const int jack = 11;
  static const int queen = 12;
  static const int king = 13;

  /// 2♣ — "καλό δυάρι".
  static const int twoOfClubs = 1;

  /// 10♦ — "καλό δεκάρι".
  static const int tenOfDiamonds = 22;

  static const List<String> suitSymbols = ['♣', '♦', '♥', '♠'];

  static int rank(int card) => card % 13 + 1;

  static int suit(int card) => card ~/ 13;

  static int make(int suit, int rank) => suit * 13 + rank - 1;

  static bool isJack(int card) => rank(card) == jack;

  /// Ace..10: these can be added together when capturing.
  static bool isNumeral(int card) => rank(card) <= 10;

  static bool isRed(int card) {
    final s = suit(card);
    return s == diamonds || s == hearts;
  }

  /// Card points (both games): each ace and jack 1, 2♣ 2, 10♦ 3. Kings,
  /// queens and tens are worth nothing. On top of that comes 3 for the most cards.
  static int points(int card) {
    if (card == tenOfDiamonds) return 3;
    if (card == twoOfClubs) return 2;
    final r = rank(card);
    if (r == ace || r == jack) return 1;
    return 0;
  }

  static String rankLabel(int card) {
    switch (rank(card)) {
      case ace:
        return 'A';
      case jack:
        return 'J';
      case queen:
        return 'Q';
      case king:
        return 'K';
      default:
        return '${rank(card)}';
    }
  }

  static String label(int card) => '${rankLabel(card)}${suitSymbols[suit(card)]}';
}
