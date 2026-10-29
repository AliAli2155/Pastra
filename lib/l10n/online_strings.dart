/// Texts of the online mode. English, Greek and Turkish; any other language
/// shows English.
class OnlineStrings {
  final String lang;

  const OnlineStrings(this.lang);

  String _t(String key, [Map<String, Object> args = const <String, Object>{}]) {
    var text = _texts[lang]?[key] ?? _texts['en']![key] ?? key;
    args.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
    return text;
  }

  String get online => _t('online');
  String get createRoom => _t('createRoom');
  String get joinRoom => _t('joinRoom');
  String get yourName => _t('yourName');
  String get roomCode => _t('roomCode');
  String get codeHint => _t('codeHint');
  String get join => _t('join');
  String get create1v1 => _t('create1v1');
  String get create2v2 => _t('create2v2');
  String get shareCode => _t('shareCode');
  String get waiting => _t('waiting');
  String get botFills => _t('botFills');
  String get host => _t('host');
  String get you => _t('you');
  String get start => _t('start');
  String get waitForHost => _t('waitForHost');
  String get connecting => _t('connecting');
  String get hostLeft => _t('hostLeft');
  String get back => _t('back');
  String get notConfigured => _t('notConfigured');
  String get notConfiguredHint => _t('notConfiguredHint');
  String get defaultName => _t('defaultName');
  String get openTables => _t('openTables');
  String get cup => _t('cup');
  String get cupHint => _t('cupHint');
  String nextCup(String time) => _t('nextCup', <String, Object>{'time': time});
  String startsIn(String time) => _t('startsIn', <String, Object>{'time': time});
  String get cupRegister => _t('cupRegister');
  String get cupUnregister => _t('cupUnregister');
  String get cupRegistered => _t('cupRegistered');
  String cupPlayers(int n) => _t('cupPlayers', <String, Object>{'n': n});
  String get cupWaiting => _t('cupWaiting');
  String get cupStarting => _t('cupStarting');
  String cupOpponentWait(String name) => _t('cupOpponentWait', <String, Object>{'name': name});
  String get cupNext => _t('cupNext');
  String get cupLive => _t('cupLive');
  String get leaderboard => _t('leaderboard');
  String get leaderboardEmpty => _t('leaderboardEmpty');
  String get quickMatch => _t('quickMatch');
  String get quickMatchHint => _t('quickMatchHint');
  String get noTables => _t('noTables');
  String get showInTables => _t('showInTables');
  String get publicRoom => _t('publicRoom');
  String get privateRoom => _t('privateRoom');
  String get searching => _t('searching');
  String get playVsBot => _t('playVsBot');
  String tableOf(String name) => _t('tableOf', <String, Object>{'name': name});
  String team(int n) => _t('team', <String, Object>{'n': n});
  String seat(int n) => _t('seat', <String, Object>{'n': n});

  String error(String code) {
    switch (code) {
      case 'notFound':
        return _t('errNotFound');
      case 'started':
        return _t('errStarted');
      case 'full':
        return _t('errFull');
      default:
        return _t('errNetwork');
    }
  }

  static const Map<String, Map<String, String>> _texts = <String, Map<String, String>>{
    'en': <String, String>{
      'online': 'Play online',
      'createRoom': 'Create a room',
      'joinRoom': 'Join a room',
      'yourName': 'Your name',
      'roomCode': 'Room code',
      'codeHint': '4-digit code',
      'join': 'Join',
      'create1v1': 'Create 1v1 room',
      'create2v2': 'Create 2v2 room',
      'shareCode': 'Share this code with your friends',
      'waiting': 'Waiting for a player…',
      'botFills': 'Empty seats are played by the computer',
      'host': 'host',
      'you': 'you',
      'start': 'Start the game',
      'waitForHost': 'Waiting for the host to start…',
      'connecting': 'Connecting…',
      'hostLeft': 'The host left the game.',
      'back': 'Back',
      'notConfigured': 'Online play is not set up yet',
      'notConfiguredHint': 'The Firebase project is missing. See docs/ONLINE_KURULUM.md.',
      'defaultName': 'Player',
      'openTables': 'Open tables',
      'cup': 'Tournament',
      'cupHint': 'Every 30 minutes · 8 players',
      'nextCup': 'Next tournament: {time}',
      'startsIn': 'Starts in {time}',
      'cupRegister': 'Join the tournament',
      'cupUnregister': 'Leave the tournament',
      'cupRegistered': "You're in! Be on this screen when it starts.",
      'cupPlayers': '{n} of 8 players · empty seats get bots · matches to 51',
      'cupWaiting': 'Waiting for the other matches…',
      'cupStarting': 'Your match is starting…',
      'cupOpponentWait': 'Waiting for {name}…',
      'cupNext': 'Next tournament',
      'cupLive': 'Tournament in progress',
      'leaderboard': 'Leaderboard',
      'leaderboardEmpty': 'Nobody is on the leaderboard yet. Play a game!',
      'quickMatch': 'Quick match',
      'quickMatchHint': 'Join a 1v1 table or start one and wait',
      'noTables': 'No open tables right now. Create one and wait for players!',
      'showInTables': 'Show my room in open tables',
      'publicRoom': 'Public',
      'privateRoom': 'Private',
      'searching': 'Looking for an opponent…',
      'playVsBot': 'Play against the computer instead',
      'tableOf': "{name}'s table",
      'team': 'Team {n}',
      'seat': 'Seat {n}',
      'errNotFound': 'Room not found. Check the code.',
      'errStarted': 'That game has already started.',
      'errFull': 'The room is full.',
      'errNetwork': 'Could not connect. Check your internet.',
    },
    'el': <String, String>{
      'online': 'Παίξε online',
      'createRoom': 'Δημιουργία δωματίου',
      'joinRoom': 'Είσοδος σε δωμάτιο',
      'yourName': 'Το όνομά σου',
      'roomCode': 'Κωδικός δωματίου',
      'codeHint': 'Κωδικός 4 ψηφίων',
      'join': 'Είσοδος',
      'create1v1': 'Δωμάτιο 1v1',
      'create2v2': 'Δωμάτιο 2v2',
      'shareCode': 'Στείλε αυτόν τον κωδικό στους φίλους σου',
      'waiting': 'Αναμονή παίκτη…',
      'botFills': 'Οι κενές θέσεις παίζονται από τον υπολογιστή',
      'host': 'οικοδεσπότης',
      'you': 'εσύ',
      'start': 'Έναρξη παιχνιδιού',
      'waitForHost': 'Αναμονή για την έναρξη…',
      'connecting': 'Σύνδεση…',
      'hostLeft': 'Ο οικοδεσπότης έφυγε από το παιχνίδι.',
      'back': 'Πίσω',
      'notConfigured': 'Το online δεν έχει ρυθμιστεί ακόμα',
      'notConfiguredHint': 'Λείπει το έργο Firebase. Δες docs/ONLINE_KURULUM.md.',
      'defaultName': 'Παίκτης',
      'openTables': 'Ανοιχτά τραπέζια',
      'cup': 'Τουρνουά',
      'cupHint': 'Κάθε 30 λεπτά · 8 παίκτες',
      'nextCup': 'Επόμενο τουρνουά: {time}',
      'startsIn': 'Ξεκινά σε {time}',
      'cupRegister': 'Δήλωσε συμμετοχή',
      'cupUnregister': 'Αποχώρηση από το τουρνουά',
      'cupRegistered': 'Είσαι μέσα! Να είσαι σε αυτή την οθόνη όταν ξεκινήσει.',
      'cupPlayers': '{n} από 8 παίκτες · οι κενές θέσεις παίρνουν bot · αγώνες στους 51',
      'cupWaiting': 'Αναμονή για τους άλλους αγώνες…',
      'cupStarting': 'Ο αγώνας σου ξεκινά…',
      'cupOpponentWait': 'Αναμονή για {name}…',
      'cupNext': 'Επόμενο τουρνουά',
      'cupLive': 'Το τουρνουά είναι σε εξέλιξη',
      'leaderboard': 'Κατάταξη',
      'leaderboardEmpty': 'Κανείς δεν είναι ακόμα στην κατάταξη. Παίξε ένα παιχνίδι!',
      'quickMatch': 'Γρήγορος αγώνας',
      'quickMatchHint': 'Μπες σε τραπέζι 1v1 ή φτιάξε ένα και περίμενε',
      'noTables': 'Δεν υπάρχουν ανοιχτά τραπέζια. Φτιάξε ένα και περίμενε παίκτες!',
      'showInTables': 'Εμφάνιση του δωματίου στα ανοιχτά τραπέζια',
      'publicRoom': 'Δημόσιο',
      'privateRoom': 'Ιδιωτικό',
      'searching': 'Αναζήτηση αντιπάλου…',
      'playVsBot': 'Παίξε με τον υπολογιστή',
      'tableOf': 'Τραπέζι: {name}',
      'team': 'Ομάδα {n}',
      'seat': 'Θέση {n}',
      'errNotFound': 'Το δωμάτιο δεν βρέθηκε. Έλεγξε τον κωδικό.',
      'errStarted': 'Το παιχνίδι έχει ήδη ξεκινήσει.',
      'errFull': 'Το δωμάτιο είναι γεμάτο.',
      'errNetwork': 'Αδυναμία σύνδεσης. Έλεγξε το internet.',
    },
    'tr': <String, String>{
      'online': 'Online oyna',
      'createRoom': 'Oda oluştur',
      'joinRoom': 'Odaya katıl',
      'yourName': 'Adın',
      'roomCode': 'Oda kodu',
      'codeHint': '4 haneli kod',
      'join': 'Katıl',
      'create1v1': '1v1 oda oluştur',
      'create2v2': '2v2 oda oluştur',
      'shareCode': 'Bu kodu arkadaşlarına gönder',
      'waiting': 'Oyuncu bekleniyor…',
      'botFills': 'Boş koltukları bilgisayar oynar',
      'host': 'kurucu',
      'you': 'sen',
      'start': 'Oyunu başlat',
      'waitForHost': 'Kurucunun başlatması bekleniyor…',
      'connecting': 'Bağlanıyor…',
      'hostLeft': 'Kurucu oyundan ayrıldı.',
      'back': 'Geri',
      'notConfigured': 'Online oyun henüz kurulmadı',
      'notConfiguredHint': 'Firebase projesi eksik. docs/ONLINE_KURULUM.md dosyasına bak.',
      'defaultName': 'Oyuncu',
      'openTables': 'Açık masalar',
      'cup': 'Turnuva',
      'cupHint': 'Her 30 dakikada · 8 oyuncu',
      'nextCup': 'Sonraki turnuva: {time}',
      'startsIn': '{time} sonra başlıyor',
      'cupRegister': 'Turnuvaya katıl',
      'cupUnregister': 'Kaydımı sil',
      'cupRegistered': 'Kaydın alındı! Başlarken bu ekranda ol.',
      'cupPlayers': '{n}/8 oyuncu · boş yerlere bot gelir · maçlar 51 puana',
      'cupWaiting': 'Diğer maçlar bekleniyor…',
      'cupStarting': 'Maçın başlıyor…',
      'cupOpponentWait': '{name} bekleniyor…',
      'cupNext': 'Sonraki turnuva',
      'cupLive': 'Turnuva sürüyor',
      'leaderboard': 'Sıralama',
      'leaderboardEmpty': 'Sıralamada henüz kimse yok. Bir oyun oyna!',
      'quickMatch': 'Hızlı eşleşme',
      'quickMatchHint': '1v1 masaya katıl ya da masa kurup bekle',
      'noTables': 'Şu an açık masa yok. Bir masa kur ve oyuncu bekle!',
      'showInTables': 'Odamı açık masalarda göster',
      'publicRoom': 'Herkese açık',
      'privateRoom': 'Özel',
      'searching': 'Rakip aranıyor…',
      'playVsBot': 'Bunun yerine bilgisayarla oyna',
      'tableOf': '{name} masası',
      'team': 'Takım {n}',
      'seat': 'Koltuk {n}',
      'errNotFound': 'Oda bulunamadı. Kodu kontrol et.',
      'errStarted': 'Bu oyun zaten başladı.',
      'errFull': 'Oda dolu.',
      'errNetwork': 'Bağlanılamadı. İnternetini kontrol et.',
    },
  };
}
