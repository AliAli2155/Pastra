import 'package:flutter/widgets.dart';

import '../engine/pastra_ai.dart';
import '../engine/rules.dart';
import '../game/app_settings.dart';

/// All user-visible text, in Greek and English.
class Strings {
  final bool el;

  const Strings(this.el);

  static Strings of(BuildContext context) => Strings(SettingsScope.of(context).isGreek);

  String _t(String greek, String english) => el ? greek : english;

  // ------------------------------------------------------------- general
  String get appTitle => _t('Πάστρα', 'Pastra');
  String get appSubtitle => _t('Το ελληνικό παιχνίδι της τράπουλας', 'The Greek fishing card game');
  String get continueGame => _t('Συνέχεια', 'Continue');
  String get newGame => _t('Νέο παιχνίδι', 'New game');
  String get rules => _t('Κανόνες', 'Rules');
  String get settings => _t('Ρυθμίσεις', 'Settings');
  String get onlineSoon => _t('Online — σύντομα', 'Online — coming soon');
  String get cancel => _t('Άκυρο', 'Cancel');
  String get ok => _t('Εντάξει', 'OK');
  String stats(int won, int played) => _t('Νίκες $won από $played', 'Won $won of $played');

  // ------------------------------------------------------------ new game
  String get gameType => _t('Τύπος παιχνιδιού', 'Game type');
  String get mode1v1 => _t('1 εναντίον 1', '1 vs 1');
  String get mode2v2 => _t('2 εναντίον 2', '2 vs 2');
  String get mode1v1Hint => _t('Εσύ απέναντι στον υπολογιστή', 'You against the computer');
  String get mode2v2Hint =>
      _t('Ζευγάρια: ο συμπαίκτης κάθεται απέναντί σου', 'Teams: your partner sits opposite you');
  String get difficulty => _t('Δυσκολία', 'Difficulty');
  String level(AiLevel value) {
    if (value == AiLevel.easy) return _t('Εύκολο', 'Easy');
    if (value == AiLevel.medium) return _t('Μέτριο', 'Medium');
    return _t('Δύσκολο', 'Hard');
  }

  String get start => _t('Ξεκίνα', 'Start');
  String targetInfo(GameVariant variant, int target, int perDeal) => _t(
      '${variantName(variant)} · μέχρι τους $target πόντους · $perDeal φύλλα',
      '${variantName(variant)} · up to $target points · $perDeal cards');

  String variantName(GameVariant v) =>
      v == GameVariant.pile ? _t('Στοίβα', 'Pile') : _t('Αθροίσματα', 'Sums');

  String variantHint(GameVariant v) => v == GameVariant.pile
      ? _t('Τα φύλλα πέφτουν το ένα πάνω στο άλλο και φαίνεται μόνο το πάνω. Ίδιο φύλλο ή βαλές μαζεύει όλη τη στοίβα.',
          'Cards go on one pile and only the top one shows. A matching card or a jack takes the whole pile.')
      : _t('Κυπριακή πάστρα: τα φύλλα μένουν ανοιχτά δίπλα-δίπλα και μαζεύεις και με αθροίσματα.',
          'Cypriot pastra: the cards lie open side by side and you also capture by sums.');

  // ---------------------------------------------------------------- game
  String get you => _t('Εσύ', 'You');
  String get us => _t('Εμείς', 'Us');
  String get them => _t('Αυτοί', 'Them');
  String get partner => _t('Συμπαίκτης', 'Partner');

  String botName(int index) {
    const greek = ['Γιώργος', 'Νίκος', 'Μαρία', 'Ελένη'];
    const english = ['Giorgos', 'Nikos', 'Maria', 'Eleni'];
    final i = index < 0 ? 0 : index % greek.length;
    return el ? greek[i] : english[i];
  }

  String get yourTurn => _t('Σειρά σου', 'Your turn');
  String playing(String name) => _t('Παίζει: $name', '$name to play');
  String get thinking => _t('σκέφτεται…', 'thinking…');
  String get tapAgain => _t('Σύρε το στη μέση ή πάτα το ξανά', 'Drag it to the middle or tap it again');
  String get dragHint => _t('Σύρε ένα φύλλο στη μέση', 'Drag a card to the middle');
  String get dropToPlay => _t('Άφησέ το για να το παίξεις', 'Release to play it');
  String get rotatePhone => _t('Γύρισε το κινητό οριζόντια', 'Turn your phone sideways');
  String get kapakAlti => _t('κάτω φύλλο', 'bottom card');
  String takes(int n) => n == 1 ? _t('Μαζεύεις 1 φύλλο', 'You take 1 card') : _t('Μαζεύεις $n φύλλα', 'You take $n cards');
  String get staysOnTable => _t('Το φύλλο μένει στο τραπέζι', 'The card stays on the table');
  String get goesOnPile => _t('Το φύλλο πάει πάνω στη στοίβα', 'The card goes on the pile');
  String get takesPile => _t('Μαζεύεις τη στοίβα', 'You take the pile');
  String get jackTakesPile => _t('Ο βαλές μαζεύει τη στοίβα', 'The jack takes the pile');
  String get jackSweeps => _t('Ο βαλές μαζεύει όλο το τραπέζι', 'The jack takes the whole table');
  String get pastraBanner => _t('ΠΑΣΤΡΑ!', 'PASTRA!');
  String plusPoints(int n) => '+$n';
  String deck(int n) => _t('Τράπουλα $n', 'Deck $n');
  String round(int n) => _t('Γύρος $n', 'Round $n');
  String target(int n) => _t('στους $n', 'to $n');
  String cards(int n) => n == 1 ? _t('1 φύλλο', '1 card') : _t('$n φύλλα', '$n cards');
  String pastras(int n) => n == 1 ? _t('1 πάστρα', '1 pastra') : _t('$n πάστρες', '$n pastras');
  String leftoversTo(String name) => _t('Τα φύλλα του τραπεζιού → $name', 'Table cards → $name');
  String get lastDeal => _t('Τελευταία μοιρασιά', 'Last deal');
  String get leaveTitle => _t('Έξοδος από το παιχνίδι;', 'Leave the game?');
  String get leaveBody => _t('Η παρτίδα αποθηκεύεται· μπορείς να συνεχίσεις αργότερα.',
      'The game is saved, you can continue later.');
  String get leave => _t('Έξοδος', 'Leave');

  // ------------------------------------------------------- round summary
  String roundOver(int n) => _t('Τέλος γύρου $n', 'End of round $n');
  String get mostCards => _t('Περισσότερα φύλλα', 'Most cards');
  String get aces => _t('Άσσοι', 'Aces');
  String get jacks => _t('Βαλέδες', 'Jacks');
  String get honours => _t('Άσσοι, φιγούρες, δεκάρια', 'Aces, faces, tens');
  String get twoOfClubs => _t('2 σπαθί', '2 of clubs');
  String get tenOfDiamonds => _t('10 καρό', '10 of diamonds');
  String get pastraRow => _t('Πάστρες', 'Pastras');
  String get roundTotal => _t('Σύνολο γύρου', 'Round total');
  String get gameScore => _t('Σκορ παιχνιδιού', 'Game score');
  String get nextRound => _t('Επόμενος γύρος', 'Next round');
  String get youWon => _t('Κέρδισες!', 'You won!');
  String get youLost => _t('Έχασες', 'You lost');
  String get teamWon => _t('Κερδίσατε!', 'Your team won!');
  String get teamLost => _t('Χάσατε', 'Your team lost');
  String get playAgain => _t('Ξανά', 'Play again');
  String get mainMenu => _t('Αρχικό μενού', 'Main menu');

  // ------------------------------------------------------------ settings
  String get language => _t('Γλώσσα', 'Language');
  String get greek => 'Ελληνικά';
  String get english => 'English';
  String get yourName => _t('Το όνομά σου', 'Your name');
  String get gameRules => _t('Κανόνες παιχνιδιού', 'Game rules');
  String get targetScore => _t('Στόχος πόντων', 'Target score');
  String get cardsPerDeal => _t('Φύλλα ανά μοιρασιά', 'Cards per deal');
  String get jackSweepIsPastra => _t('Ο βαλές μετράει πάστρα', 'Jack sweep counts as pastra');
  String get jackSweepIsPastraHint =>
      _t('Όταν ο βαλές μαζεύει όλο το τραπέζι', 'When a jack takes the whole table');
  String get jackOnJack => _t('Βαλές πάνω σε μόνο βαλέ', 'Jack on a lone jack');
  String get jackOnLoneCardIsPastra => _t('Βαλές σε μόνο φύλλο = πάστρα', 'Jack on a lone card is a pastra');
  String get jackOnLoneCardIsPastraHint => _t('Ο βαλές που μαζεύει ένα μόνο φύλλο παίρνει κι αυτός 10 πόντους',
      'A jack taking a single card also scores 10 points');
  String get variant => _t('Παραλλαγή', 'Variant');
  String get nothing => _t('Τίποτα', 'Nothing');
  String get pastraOnLastCard => _t('Πάστρα με το τελευταίο φύλλο', 'Pastra with the last card');
  String get pastraOnLastCardHint =>
      _t('Μετράει και με το τελευταίο φύλλο του γύρου', 'Also counts with the final card of a round');
  String get gameplay => _t('Παιχνίδι', 'Gameplay');
  String get fastAnimations => _t('Γρήγορες κινήσεις', 'Fast animations');
  String get haptics => _t('Δόνηση', 'Haptics');
  String get turnTime => _t('Χρόνος για κάθε κίνηση', 'Time for each move');
  String get turnTimeHint => _t('Όταν τελειώσει, παίζεται αυτόματα ένα φύλλο', 'When it runs out a card is played for you');
  String get noLimit => _t('Χωρίς', 'Off');
  String seconds(int n) => _t('$n δ', '$n s');
  String get resetRules => _t('Επαναφορά κανόνων', 'Reset rules');
  String get rulesApplyToNewGames =>
      _t('Οι αλλαγές κανόνων ισχύουν στο επόμενο νέο παιχνίδι.', 'Rule changes apply to the next new game.');
  String points(int n) => _t('$n πόντοι', '$n points');
  String get about => _t('Σχετικά', 'About');
  String get aboutBody => _t('Πάστρα 1.0 · Made by A. Ali', 'Pastra 1.0 · Made by A. Ali');

  // --------------------------------------------------------------- rules
  /// (title, body) sections of the rules screen.
  List<List<String>> rulesSections(GameVariant v) => v == GameVariant.pile
      ? (el ? _pileRulesEl : _pileRulesEn)
      : (el ? _rulesEl : _rulesEn);

  static const List<List<String>> _pileRulesEl = [
    [
      'Το παιχνίδι',
      'Η Πάστρα παίζεται με μία τράπουλα 52 φύλλων, από δύο παίκτες ή από τέσσερις σε ζευγάρια '
          '(ο συμπαίκτης κάθεται απέναντι και τα φύλλα σας μετράνε μαζί). Τα φύλλα πέφτουν σε μία '
          'στοίβα στη μέση· σκοπός είναι να μαζεύεις τη στοίβα και να κάνεις πάστρες.',
    ],
    [
      'Μοίρασμα',
      'Το κάτω φύλλο της τράπουλας γυρίζει ανοιχτό και μένει κάτω από την τράπουλα όλο τον γύρο '
          '(«kapak altı»): είναι το τελευταίο φύλλο που μοιράζεται, άρα το παίρνει αυτός που '
          'μοιράζει, και όλοι ξέρουν ότι το έχει.\n'
          'Κάθε παίκτης παίρνει 6 φύλλα (ή 4, από τις ρυθμίσεις). Τέσσερα φύλλα ανοίγουν στη μέση '
          'δίπλα-δίπλα· το δεξί είναι το πάνω φύλλο. Πάνω δεν μπορεί να ανοίξει βαλές: μπαίνει '
          'ανοιχτός κάτω από την τράπουλα και ανοίγει άλλο φύλλο. Μόλις παιχτεί το πρώτο φύλλο, τα '
          'τέσσερα μαζεύονται σε στοίβα και από εκεί και πέρα φαίνεται μόνο το πάνω. Όταν αδειάσουν '
          'τα χέρια μοιράζονται ξανά φύλλα· στη στοίβα δεν ανοίγουν άλλα.',
    ],
    [
      'Πώς μαζεύεις',
      'Στη σειρά σου ρίχνεις ένα φύλλο πάνω στη στοίβα.\n'
          '• Αν είναι ίδιο με το πάνω φύλλο (7 σε 7, ντάμα σε ντάμα), μαζεύεις όλη τη στοίβα.\n'
          '• Ο βαλές μαζεύει πάντα όλη τη στοίβα.\n'
          '• Αλλιώς το φύλλο σου μένει από πάνω και σκεπάζει τα άλλα.\n'
          'Τα φύλλα κάτω από το πάνω δεν φαίνονται: πρέπει να θυμάσαι τι έχει πέσει.',
    ],
    [
      'Πάστρα',
      'Όταν στη στοίβα υπάρχει ένα μόνο φύλλο και το μαζέψεις με ίδιο φύλλο, κάνεις πάστρα (ξερή): '
          '10 πόντοι. Βαλές πάνω σε μόνο βαλέ: 20 πόντοι (ρυθμίζεται: 10 / 20 / 25). Ο βαλές που '
          'μαζεύει ένα μόνο άλλο φύλλο δεν είναι πάστρα, ούτε το τελευταίο φύλλο του γύρου '
          '(ρυθμίζονται).',
    ],
    [
      'Τέλος γύρου',
      'Όταν τελειώσει η τράπουλα και τα χέρια, ό,τι έχει μείνει στη στοίβα το παίρνει όποιος '
          'μάζεψε τελευταίος (αυτό δεν είναι πάστρα).',
    ],
    [
      'Πόντοι',
      '• Περισσότερα φύλλα: 3 (στην ισοπαλία 26–26 κανείς)\n'
          '• Κάθε άσσος, ρήγας, ντάμα, βαλές και δεκάρι: 1\n'
          '• 10 καρό (καλό δεκάρι): 1 ακόμα, σύνολο 2\n'
          '• 2 σπαθί (καλό δυάρι): 1\n'
          '• Κάθε πάστρα: 10 · βαλές σε βαλέ: 20\n'
          'Κάθε γύρος μοιράζει 25 πόντους συν τις πάστρες.',
    ],
    [
      'Νίκη',
      'Κερδίζει όποιος φτάσει πρώτος τους 151 πόντους (ή όσους ορίσεις στις ρυθμίσεις). Αν και οι '
          'δύο πλευρές τους περάσουν στον ίδιο γύρο με ισοπαλία, παίζεται κι άλλος γύρος. Τη μοιρασιά '
          'την κάνει κάθε φορά ο επόμενος παίκτης.',
    ],
    [
      'Στην εφαρμογή',
      'Σύρε ένα φύλλο από το χέρι σου στη μέση για να το παίξεις. Όσο το σέρνεις (ή αν το πατήσεις '
          'μία φορά) φωτίζεται το πάνω φύλλο αν το μαζεύει· δεύτερο πάτημα το παίζει κι αυτό. Στις '
          'ρυθμίσεις μπορείς να διαλέξεις και την κυπριακή πάστρα με αθροίσματα.',
    ],
  ];

  static const List<List<String>> _pileRulesEn = [
    [
      'The game',
      'Pastra is played with one 52-card deck by two players, or by four in teams of two (your '
          'partner sits opposite you and your cards count together). The cards are played onto one '
          'pile in the middle; the aim is to take the pile and to make pastras.',
    ],
    [
      'Dealing',
      'The bottom card of the deck is turned face up and stays under the deck for the whole round '
          '("kapak altı"): it is the last card dealt, so the dealer gets it and everybody knows it.\n'
          'Each player gets 6 cards (or 4, see settings). Four cards are laid face up side by side in '
          'the middle; the rightmost one is the top card. A jack may not open on top: it goes face up '
          'under the deck and another card is opened. As soon as the first card is played the four '
          'are gathered into a pile and from then on only the top card shows. When the hands are '
          'empty new cards are dealt; no more cards go to the pile.',
    ],
    [
      'Capturing',
      'On your turn you play one card onto the pile.\n'
          '• If it has the same rank as the top card (7 on 7, queen on queen), you take the whole '
          'pile.\n'
          '• A jack always takes the whole pile.\n'
          '• Otherwise your card stays on top and covers the others.\n'
          'The cards under the top one are hidden: you have to remember what has been played.',
    ],
    [
      'Pastra',
      'When the pile is a single card and you take it with a card of the same rank, it is a pastra '
          '(xeri): 10 points. A jack on a lone jack: 20 points (adjustable: 10 / 20 / 25). A jack '
          'taking a single other card is not a pastra, nor is the last card of the round '
          '(adjustable).',
    ],
    [
      'End of a round',
      'When the deck and the hands are finished, whatever is left on the pile goes to whoever '
          'captured last (this is not a pastra).',
    ],
    [
      'Points',
      '• Most cards: 3 (nobody on a 26–26 tie)\n'
          '• Each ace, king, queen, jack and ten: 1\n'
          '• 10 of diamonds (the good ten): 1 more, 2 in total\n'
          '• 2 of clubs (the good two): 1\n'
          '• Each pastra: 10 · jack on jack: 20\n'
          'Every round is worth 25 points plus the pastras.',
    ],
    [
      'Winning',
      'The first side to reach 151 points (or the target set in the settings) wins. If both sides '
          'pass it in the same round with a tie, another round is played. The deal moves to the next '
          'player each round.',
    ],
    [
      'In the app',
      'Drag a card from your hand to the middle to play it. While you drag it (or after one tap) '
          'the top card lights up if it captures; a second tap plays it too. In the settings you can '
          'also pick the Cypriot pastra with sums.',
    ],
  ];

  static const List<List<String>> _rulesEl = [
    [
      'Το παιχνίδι',
      'Η Πάστρα παίζεται με μία τράπουλα 52 φύλλων, από δύο παίκτες ή από τέσσερις σε ζευγάρια '
          '(ο συμπαίκτης κάθεται απέναντι και τα φύλλα σας μετράνε μαζί). Σκοπός είναι να '
          'μαζέψεις φύλλα από το τραπέζι.',
    ],
    [
      'Μοίρασμα',
      'Κάθε παίκτης παίρνει 4 φύλλα (ή 6, από τις ρυθμίσεις) και 4 φύλλα ανοίγουν στο τραπέζι. '
          'Αν ανοίξει βαλές, μπαίνει πίσω στην τράπουλα και ανοίγει άλλο φύλλο. Όταν αδειάσουν τα '
          'χέρια, μοιράζονται ξανά φύλλα· στο τραπέζι δεν ανοίγουν άλλα.',
    ],
    [
      'Πώς μαζεύεις',
      'Στη σειρά σου ρίχνεις ένα φύλλο.\n'
          '• Άσσος έως 10: μαζεύει τα ίδια φύλλα και κάθε ομάδα φύλλων που κάνει το ίδιο άθροισμα '
          '(ο άσσος μετράει 1). Π.χ. το 8 μαζεύει 8, 5+3 και 6+Α+Α μαζί.\n'
          '• Ντάμα και ρήγας μαζεύουν μόνο ντάμα και ρήγα· δεν μπαίνουν σε αθροίσματα.\n'
          '• Ο βαλές μαζεύει όλο το τραπέζι.\n'
          'Αν το φύλλο σου μπορεί να μαζέψει, μαζεύει όσα περισσότερα γίνεται. Αλλιώς μένει '
          'ανοιχτό στο τραπέζι.',
    ],
    [
      'Πάστρα',
      'Όταν καθαρίσεις όλο το τραπέζι με φύλλο που δεν είναι βαλές, κάνεις πάστρα: 10 πόντοι. '
          'Ο βαλές πάνω σε μόνο βαλέ δίνει 10 πόντους (ρυθμίζεται: 0 / 10 / 20).',
    ],
    [
      'Τέλος γύρου',
      'Όταν τελειώσει η τράπουλα και τα χέρια, τα φύλλα που μένουν στο τραπέζι τα παίρνει όποιος '
          'μάζεψε τελευταίος (αυτό δεν είναι πάστρα).',
    ],
    [
      'Πόντοι',
      '• Περισσότερα φύλλα: 3 (στην ισοπαλία 26–26 κανείς)\n'
          '• Κάθε άσσος: 1 · κάθε βαλές: 1\n'
          '• 2 σπαθί (καλό δυάρι): 2\n'
          '• 10 καρό (καλό δεκάρι): 3\n'
          '• Κάθε πάστρα: 10\n'
          'Κάθε γύρος μοιράζει 16 πόντους συν τις πάστρες.',
    ],
    [
      'Νίκη',
      'Κερδίζει όποιος φτάσει πρώτος τους 101 πόντους (ή όσους ορίσεις). Αν και οι δύο πλευρές τους '
          'περάσουν στον ίδιο γύρο με ισοπαλία, παίζεται κι άλλος γύρος. Τη μοιρασιά την κάνει κάθε '
          'φορά ο επόμενος παίκτης.',
    ],
    [
      'Στην εφαρμογή',
      'Πάτα ένα φύλλο για να δεις τι θα μαζέψει (φωτίζονται τα φύλλα του τραπεζιού) και πάτα το '
          'ξανά για να το παίξεις.',
    ],
  ];

  static const List<List<String>> _rulesEn = [
    [
      'The game',
      'Pastra is played with one 52-card deck by two players, or by four in teams of two '
          '(your partner sits opposite you and your cards count together). The aim is to capture '
          'cards from the table.',
    ],
    [
      'Dealing',
      'Each player gets 4 cards (or 6, see settings) and 4 cards are laid face up on the table. '
          'A jack turned up for the table goes back into the deck and is replaced. When the hands '
          'are empty new cards are dealt; no more cards go to the table.',
    ],
    [
      'Capturing',
      'On your turn you play one card.\n'
          '• Ace to 10: takes the equal cards and every group of cards adding up to the same value '
          '(the ace counts 1). E.g. an 8 takes 8, 5+3 and 6+A+A together.\n'
          '• Queens and kings take only queens and kings; they are never added up.\n'
          '• A jack takes the whole table.\n'
          'If your card can capture, it takes as many cards as possible. Otherwise it stays face up '
          'on the table.',
    ],
    [
      'Pastra',
      'Clearing the whole table with a card other than a jack is a pastra: 10 points. A jack on a '
          'lone jack gives 10 points (adjustable: 0 / 10 / 20).',
    ],
    [
      'End of a round',
      'When the deck and the hands are finished, the cards left on the table go to whoever '
          'captured last (this is not a pastra).',
    ],
    [
      'Points',
      '• Most cards: 3 (nobody on a 26–26 tie)\n'
          '• Each ace: 1 · each jack: 1\n'
          '• 2 of clubs (the good two): 2\n'
          '• 10 of diamonds (the good ten): 3\n'
          '• Each pastra: 10\n'
          'Every round is worth 16 points plus the pastras.',
    ],
    [
      'Winning',
      'The first side to reach 101 points (or the target you set) wins. If both sides pass it in the same '
          'round with a tie, another round is played. The deal moves to the next player each round.',
    ],
    [
      'In the app',
      'Tap a card to see what it would capture (the table cards light up), then tap it again to '
          'play it.',
    ],
  ];
}
