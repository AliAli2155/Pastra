import '../engine/pastra_ai.dart';
import '../ui/theme.dart';

/// A room of online tables with the same entry fee (stake), like the
/// salons of Okey and Pişti apps. Everybody at the table pays the stake when
/// the game starts; the winners share the pot minus the table fee.
class Salon {
  const Salon(this.id, this.stake, this.minLevel);

  final String id;

  /// Chips each player pays to sit down (0 = a friendly table).
  final int stake;

  /// Player level needed to sit down.
  final int minLevel;

  bool get free => stake == 0;
}

/// How rare a store item is: sets its price range and the colour of its
/// label.
enum Rarity { common, rare, epic, legendary }

/// Where an item can be had: bought on its own, or only with VIP or in a
/// pack ([Bundle]).
enum ItemSource { store, vip, bundle }

/// Something in the store bought with chips or diamonds.
class ShopItem {
  const ShopItem._(
    this.id, {
    this.table,
    this.back,
    this.chips = 0,
    this.diamonds = 0,
    this.rarity = Rarity.common,
    this.source = ItemSource.store,
  });

  const ShopItem.table(String id, TableTheme t,
      {int chips = 0, int diamonds = 0, Rarity rarity = Rarity.common, ItemSource source = ItemSource.store})
      : this._(id, table: t, chips: chips, diamonds: diamonds, rarity: rarity, source: source);

  const ShopItem.back(String id, CardBackStyle b,
      {int chips = 0, int diamonds = 0, Rarity rarity = Rarity.common, ItemSource source = ItemSource.store})
      : this._(id, back: b, chips: chips, diamonds: diamonds, rarity: rarity, source: source);

  final String id;
  final TableTheme? table;
  final CardBackStyle? back;

  /// The price: chips or diamonds (one of them is 0; both for an item that
  /// only comes with VIP or in a pack).
  final int chips;
  final int diamonds;
  final Rarity rarity;
  final ItemSource source;

  /// Can be bought on its own with chips or diamonds.
  bool get forSale => source == ItemSource.store;
}

/// A pack of several things for real money: chips, diamonds, items and
/// days of VIP. [once]: only one per player (a starter offer).
class Bundle {
  const Bundle(
    this.id, {
    required this.usd,
    this.chips = 0,
    this.diamonds = 0,
    this.items = const <String>[],
    this.vipDays = 0,
    this.once = false,
    this.discountPercent = 0,
  });

  /// The product id in the stores / at the payment provider.
  final String id;
  final double usd;
  final int chips;
  final int diamonds;

  /// Ids of [ShopItem]s in it.
  final List<String> items;
  final int vipDays;
  final bool once;

  /// How much cheaper it is than its parts bought one by one.
  final int discountPercent;
}

/// VIP for some days: doubled bonuses, more chips per win, the VIP table
/// and card back, a badge (see [Economy.vipPerks]).
class VipPlan {
  const VipPlan(this.id, {required this.days, required this.usd, this.diamonds = 0, this.best = false});

  final String id;
  final int days;
  final double usd;

  /// Diamonds given at once with the plan.
  final int diamonds;

  /// Shown as "best value".
  final bool best;
}

/// A pack sold for real money (needs Google Play / App Store billing; see
/// docs/MONETIZATION.md). [usd] is the suggested price tier.
class MoneyPack {
  const MoneyPack(this.id, {this.chips = 0, this.diamonds = 0, required this.usd, this.bonusPercent = 0});

  /// The product id in the stores.
  final String id;
  final int chips;
  final int diamonds;
  final double usd;
  final int bonusPercent;
}

/// Diamonds turned into chips inside the game.
class Exchange {
  const Exchange(this.diamonds, this.chips);

  final int diamonds;
  final int chips;
}

/// The chip economy: prices, rewards and fees. Pure Dart, no storage
/// ([AppSettings] keeps the balances).
///
/// Chips are virtual: they can be won and bought but never cashed out or
/// sent to other players (that would make the game gambling under the store
/// rules and the law).
class Economy {
  Economy._();

  /// The whole chip system (wallet, salons, cup fees, store, daily bonus) is
  /// hidden until the app is in Google Play / the App Store. Build the store
  /// versions with `--dart-define=PASTRA_ECONOMY=true` to turn it on.
  static const bool enabled = bool.fromEnvironment('PASTRA_ECONOMY');

  static const int startChips = 2500;
  static const int startDiamonds = 10;

  // ---- online tables

  static const List<Salon> salons = <Salon>[
    Salon('friendly', 0, 1),
    Salon('rookie', 100, 1),
    Salon('amateur', 500, 3),
    Salon('pro', 2500, 6),
    Salon('master', 10000, 10),
    Salon('vip', 50000, 15),
  ];

  static Salon salonFor(int stake) =>
      salons.firstWhere((s) => s.stake == stake, orElse: () => salons.first);

  /// The house keeps this share of every pot (it takes chips out of the
  /// game so they keep their value).
  static const int tableFeePercent = 10;

  /// What each winner gets back: the pot is everybody's stake, the winning
  /// team shares it (1v1: one winner of two stakes; 2v2: two winners of four).
  static int payout(int stake) => stake * 2 * (100 - tableFeePercent) ~/ 100;

  // ---- free chips

  /// Daily bonus for day 1..7 of a streak (day 7 also gives diamonds).
  static const List<int> dailyChips = <int>[500, 750, 1000, 1500, 2000, 3000, 5000];
  static const int day7Diamonds = 5;

  /// The day of the streak (1..7) a streak count falls on.
  static int streakDay(int streak) => ((streak - 1) % 7) + 1;

  static int dailyReward(int streak) => dailyChips[streakDay(streak) - 1];
  static int dailyDiamonds(int streak) => streakDay(streak) == 7 ? day7Diamonds : 0;

  /// A calendar day as a number (local time), to compare days.
  static int dayNumber(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

  /// The streak after claiming on [today]; null when today was already
  /// claimed, or when [today] is before the last claim (the clock was turned
  /// back: no second bonus for an old day).
  static int? nextStreak({required int lastDay, required int streak, required int today}) {
    if (today <= lastDay) return null;
    return lastDay == today - 1 ? streak + 1 : 1;
  }

  /// Free chips every few hours; more when the player is (almost) broke.
  static const Duration freeChipsEvery = Duration(hours: 3);
  static const int freeChips = 300;
  static const int rescueChips = 1000;
  static const int rescueBelow = 100;

  static int freeChipsFor(int balance) => balance < rescueBelow ? rescueChips : freeChips;

  // ---- earning while playing

  /// A won game against the computer (offline).
  static int offlineWin(AiLevel level) => switch (level) {
        AiLevel.easy => 20,
        AiLevel.medium => 40,
        AiLevel.hard => 80,
      };

  static int levelUpChips(int newLevel) => 250 * newLevel;
  static const int levelUpDiamonds = 3;

  // ---- online cups

  /// Entry fee of a scheduled cup (friends cups are free).
  static int cupFee(String cupId) => switch (cupId) {
        'q' => 200,
        'c' => 500,
        't' => 500,
        _ => 0,
      };

  /// Chips for the cup result: the fee back for one won match, twice the
  /// fee for the final, four times for the title.
  static int cupPrize(int fee, {required int wins, required bool champion}) {
    if (fee <= 0) return 0;
    if (champion) return fee * 4;
    if (wins >= 2) return fee * 2;
    if (wins == 1) return fee;
    return 0;
  }

  // ---- store

  /// Every table and card back of the store, from common to legendary.
  /// A theme in [TableTheme] / [CardBackStyle] without a level in
  /// [Progression] must be here (or everybody would have it for free).
  static const List<ShopItem> items = <ShopItem>[
    // Tables.
    ShopItem.table('t_jade', TableTheme.jade, chips: 30000),
    ShopItem.table('t_forest', TableTheme.forest, chips: 35000),
    ShopItem.table('t_ocean', TableTheme.ocean, chips: 40000),
    ShopItem.table('t_sand', TableTheme.sand, chips: 45000),
    ShopItem.table('t_marble', TableTheme.marble, chips: 50000, rarity: Rarity.rare),
    ShopItem.table('t_rose', TableTheme.rose, chips: 60000, rarity: Rarity.rare),
    ShopItem.table('t_leather', TableTheme.leather, chips: 70000, rarity: Rarity.rare),
    ShopItem.table('t_royal', TableTheme.royal, diamonds: 80, rarity: Rarity.rare),
    ShopItem.table('t_sapphire', TableTheme.sapphire, diamonds: 90, rarity: Rarity.rare),
    ShopItem.table('t_amethyst', TableTheme.amethyst, chips: 90000, rarity: Rarity.rare),
    ShopItem.table('t_velvet', TableTheme.velvet, diamonds: 100, rarity: Rarity.rare),
    ShopItem.table('t_lagoon', TableTheme.lagoon, diamonds: 100, rarity: Rarity.rare),
    ShopItem.table('t_sunset', TableTheme.sunset, diamonds: 120, rarity: Rarity.epic),
    ShopItem.table('t_aurora', TableTheme.aurora, diamonds: 150, rarity: Rarity.epic),
    ShopItem.table('t_midnight', TableTheme.midnight, diamonds: 180, rarity: Rarity.epic),
    ShopItem.table('t_glacier', TableTheme.glacier, diamonds: 200, rarity: Rarity.epic),
    ShopItem.table('t_volcano', TableTheme.volcano, diamonds: 220, rarity: Rarity.epic),
    ShopItem.table('t_crimson', TableTheme.crimson, chips: 250000, rarity: Rarity.epic),
    ShopItem.table('t_gilded', TableTheme.gilded, diamonds: 400, rarity: Rarity.legendary),
    ShopItem.table('t_olympus', TableTheme.olympus, rarity: Rarity.legendary, source: ItemSource.bundle),
    ShopItem.table('t_vip', TableTheme.vip, rarity: Rarity.legendary, source: ItemSource.vip),
    // Card backs.
    ShopItem.back('b_sky', CardBackStyle.sky, chips: 20000),
    ShopItem.back('b_mint', CardBackStyle.mint, chips: 20000),
    ShopItem.back('b_emerald', CardBackStyle.emerald, chips: 25000),
    ShopItem.back('b_coral', CardBackStyle.coral, chips: 25000),
    ShopItem.back('b_copper', CardBackStyle.copper, chips: 30000),
    ShopItem.back('b_onyx', CardBackStyle.onyx, chips: 35000),
    ShopItem.back('b_jade', CardBackStyle.jade, chips: 60000, rarity: Rarity.rare),
    ShopItem.back('b_ruby', CardBackStyle.ruby, diamonds: 60, rarity: Rarity.rare),
    ShopItem.back('b_bordeaux', CardBackStyle.bordeaux, diamonds: 70, rarity: Rarity.rare),
    ShopItem.back('b_sapphire', CardBackStyle.sapphire, diamonds: 70, rarity: Rarity.rare),
    ShopItem.back('b_amethyst', CardBackStyle.amethyst, diamonds: 70, rarity: Rarity.rare),
    ShopItem.back('b_pearl', CardBackStyle.pearl, chips: 70000, rarity: Rarity.rare),
    ShopItem.back('b_galaxy', CardBackStyle.galaxy, diamonds: 90, rarity: Rarity.rare),
    ShopItem.back('b_diamond', CardBackStyle.diamond, diamonds: 100, rarity: Rarity.rare),
    ShopItem.back('b_ivory', CardBackStyle.ivory, diamonds: 110, rarity: Rarity.epic),
    ShopItem.back('b_sunburst', CardBackStyle.sunburst, diamonds: 140, rarity: Rarity.epic),
    ShopItem.back('b_obsidian', CardBackStyle.obsidian, diamonds: 150, rarity: Rarity.epic),
    ShopItem.back('b_aurora', CardBackStyle.aurora, diamonds: 160, rarity: Rarity.epic),
    ShopItem.back('b_phoenix', CardBackStyle.phoenix, diamonds: 350, rarity: Rarity.legendary),
    ShopItem.back('b_olympus', CardBackStyle.olympus, rarity: Rarity.legendary, source: ItemSource.bundle),
    ShopItem.back('b_vip', CardBackStyle.vip, rarity: Rarity.legendary, source: ItemSource.vip),
  ];

  static ShopItem? itemById(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  // ---- VIP and packs (sold for real money once the server is up)

  static const List<VipPlan> vipPlans = <VipPlan>[
    VipPlan('vip_week', days: 7, usd: 2.99, diamonds: 20),
    VipPlan('vip_month', days: 30, usd: 9.99, diamonds: 100, best: true),
    VipPlan('vip_season', days: 90, usd: 24.99, diamonds: 350),
  ];

  /// What VIP gives while it lasts.
  static const int vipDailyMultiplier = 2;
  static const int vipFreeChipsMultiplier = 2;
  static const Duration vipFreeChipsEvery = Duration(hours: 2);
  static const int vipWinBonusPercent = 20;
  static const List<String> vipItems = <String>['t_vip', 'b_vip'];

  static const List<Bundle> bundles = <Bundle>[
    Bundle('bundle_starter', usd: 1.99, chips: 25000, diamonds: 50, items: <String>['t_jade'], once: true, discountPercent: 70),
    Bundle(
      'bundle_collector',
      usd: 9.99,
      diamonds: 100,
      items: <String>['b_sapphire', 'b_jade', 'b_amethyst', 'b_pearl'],
      discountPercent: 50,
    ),
    Bundle(
      'bundle_royal',
      usd: 14.99,
      chips: 150000,
      diamonds: 300,
      items: <String>['t_gilded', 'b_phoenix'],
      discountPercent: 60,
    ),
    Bundle(
      'bundle_legend',
      usd: 39.99,
      chips: 500000,
      diamonds: 1000,
      items: <String>['t_olympus', 'b_olympus'],
      vipDays: 30,
      discountPercent: 65,
    ),
  ];

  /// The pack an item only comes in.
  static Bundle? bundleWith(String itemId) {
    for (final b in bundles) {
      if (b.items.contains(itemId)) return b;
    }
    return null;
  }

  static ShopItem? itemForTable(TableTheme t) {
    for (final i in items) {
      if (i.table == t) return i;
    }
    return null;
  }

  static ShopItem? itemForBack(CardBackStyle b) {
    for (final i in items) {
      if (i.back == b) return i;
    }
    return null;
  }

  static const List<Exchange> exchanges = <Exchange>[
    Exchange(10, 5000),
    Exchange(50, 30000),
    Exchange(200, 150000),
  ];

  static const List<MoneyPack> chipPacks = <MoneyPack>[
    MoneyPack('chips_tiny', chips: 4000, usd: 0.49),
    MoneyPack('chips_small', chips: 10000, usd: 0.99),
    MoneyPack('chips_medium', chips: 60000, usd: 4.99, bonusPercent: 20),
    MoneyPack('chips_large', chips: 150000, usd: 9.99, bonusPercent: 50),
    MoneyPack('chips_huge', chips: 400000, usd: 19.99, bonusPercent: 100),
    MoneyPack('chips_mega', chips: 1200000, usd: 49.99, bonusPercent: 140),
    MoneyPack('chips_giga', chips: 3000000, usd: 99.99, bonusPercent: 200),
  ];

  static const List<MoneyPack> diamondPacks = <MoneyPack>[
    MoneyPack('diamonds_small', diamonds: 50, usd: 0.99),
    MoneyPack('diamonds_medium', diamonds: 300, usd: 4.99, bonusPercent: 20),
    MoneyPack('diamonds_large', diamonds: 700, usd: 9.99, bonusPercent: 40),
    MoneyPack('diamonds_huge', diamonds: 1600, usd: 19.99, bonusPercent: 60),
    MoneyPack('diamonds_mega', diamonds: 4500, usd: 49.99, bonusPercent: 80),
  ];

  /// 12345 → "12.3K", 2500000 → "2.5M" (short labels on buttons).
  static String short(int n) {
    String one(double v) {
      final s = v.toStringAsFixed(v >= 100 || v == v.roundToDouble() ? 0 : 1);
      return s;
    }

    if (n.abs() >= 1000000) return '${one(n / 1000000)}M';
    if (n.abs() >= 10000) return '${one(n / 1000)}K';
    return group(n);
  }

  /// 1234567 → "1.234.567".
  static String group(int n) {
    final neg = n < 0;
    final digits = n.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    return neg ? '-$out' : out.toString();
  }
}
