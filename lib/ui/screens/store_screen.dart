import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/shop_strings.dart';
import '../../l10n/strings.dart';
import '../../online/online_service.dart';
import '../ege/table_stage.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/playing_card.dart';
import '../widgets/wallet_bar.dart';

/// The store: daily bonus and free chips, tables and card backs, diamonds
/// to chips and the packs sold for real money. Every section fits on a
/// phone held sideways without scrolling.
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key, this.initialTab = 0});

  final int initialTab;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final tables = Economy.items.where((i) => i.table != null).toList();
    final backs = Economy.items.where((i) => i.back != null).toList();
    return Scaffold(
      appBar: GameAppBar(
        icon: Icons.storefront_rounded,
        title: Text(shop.store, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: const <Widget>[
          Padding(padding: EdgeInsets.only(right: 12), child: Center(child: WalletBar(onTap: null, compact: true))),
        ],
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          bottom: false,
          // Sections on the left (pills at the top on a narrow screen).
          child: SideTabs(
            initial: initialTab,
            tabs: <PageTab>[
              PageTab(icon: Icons.redeem_rounded, label: shop.dailyBonus, builder: (_) => const _BonusTab()),
              PageTab(
                icon: Icons.table_restaurant_rounded,
                label: shop.tables,
                builder: (_) => _Section(
                  title: shop.tables,
                  icon: Icons.table_restaurant_rounded,
                  child: _ItemGrid(items: tables),
                ),
              ),
              PageTab(
                icon: Icons.style_rounded,
                label: shop.backs,
                builder: (_) => _Section(
                  title: shop.backs,
                  icon: Icons.style_rounded,
                  accent: PastraColors.coral,
                  child: _ItemGrid(items: backs),
                ),
              ),
              PageTab(
                icon: Icons.swap_horiz_rounded,
                label: shop.exchange,
                builder: (_) => _Section(
                  title: shop.exchange,
                  icon: Icons.swap_horiz_rounded,
                  accent: PastraColors.teal,
                  child: const _Exchanges(),
                ),
              ),
              PageTab(
                icon: Icons.toll_rounded,
                label: shop.chipPacks,
                builder: (_) => _Section(
                  title: shop.chipPacks,
                  icon: Icons.toll_rounded,
                  child: const _Packs(diamonds: false),
                ),
              ),
              PageTab(
                icon: Icons.diamond_rounded,
                label: shop.diamondPacks,
                builder: (_) => _Section(
                  title: shop.diamondPacks,
                  icon: Icons.diamond_rounded,
                  accent: PastraColors.teal,
                  child: const _Packs(diamonds: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One store section: a titled panel, centred and as wide as the grid in it
/// needs.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child, this.accent = PastraColors.gold});

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TabBody(
      maxWidth: 880,
      children: <Widget>[SectionPanel(title: title, icon: icon, accent: accent, child: child)],
    );
  }
}

/// Lays out tiles in rows of equal tiles, centred; [columns] at most per row
/// (fewer on a narrow screen).
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.count, required this.height, required this.builder, this.columns = 4});

  final int count;
  final double height;
  final int columns;
  final Widget Function(int i) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = StoreScreen._gap;
        final w = box.maxWidth;
        final fit = w >= 600 ? columns : (w >= 420 ? min(columns, 3) : min(columns, 2));
        final perRow = min(fit, count);
        final width = min(220.0, (w - gap * (perRow - 1)) / perRow);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (var i = 0; i < count; i++) SizedBox(width: width, height: height, child: builder(i)),
          ],
        );
      },
    );
  }
}

// ---- daily bonus and free chips

class _BonusTab extends StatelessWidget {
  const _BonusTab();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final wide = TabScope.wideOf(context);
    final daily = SectionPanel(
      title: shop.dailyBonus,
      icon: Icons.redeem_rounded,
      accent: PastraColors.coral,
      expand: wide,
      child: const Center(child: DailyBonusCard()),
    );
    const free = _FreeChipsPanel();
    final notes = Column(
      children: <Widget>[
        Text(shop.howToEarn, textAlign: TextAlign.center, style: PremiumText.secondary),
        const SizedBox(height: 4),
        Text(shop.noCash, textAlign: TextAlign.center, style: const TextStyle(color: PastraColors.muted, fontSize: 12)),
      ],
    );
    if (wide) {
      // Two panels side by side, the same height, and the notes under them.
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                children: <Widget>[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(flex: 3, child: daily),
                        const SizedBox(width: 14),
                        const Expanded(flex: 2, child: free),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  notes,
                ],
              ),
            ),
          ),
        ],
      );
    }
    return TabBody(
      maxWidth: 880,
      children: <Widget>[
        if (wide)
          // Two panels side by side, the same height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(flex: 3, child: daily),
                const SizedBox(width: 14),
                const Expanded(flex: 2, child: free),
              ],
            ),
          )
        else ...<Widget>[daily, free],
        notes,
      ],
    );
  }
}

/// Free chips every few hours (more when the player is almost broke).
class _FreeChipsPanel extends StatefulWidget {
  const _FreeChipsPanel();

  @override
  State<_FreeChipsPanel> createState() => _FreeChipsPanelState();
}

class _FreeChipsPanelState extends State<_FreeChipsPanel> {
  Timer? _tick;
  int? _got;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _left(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  /// A slow tick, only while the clock counts down.
  void _keepTicking(bool waiting) {
    if (waiting && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!waiting && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final now = OnlineService.rewardTime;
    final at = settings.freeChipsAt(now);
    final ready = !now.isBefore(at);
    _keepTicking(!ready);
    final amount = Economy.freeChipsFor(settings.chips);
    final got = _got;
    return SectionPanel(
      title: shop.freeChips,
      icon: Icons.toll_rounded,
      expand: TabScope.wideOf(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(child: _CoinPile(tier: ready ? 2 : 1, size: 40, dim: !ready && got == null)),
          const SizedBox(height: 8),
          Center(
            child: got != null
                ? _Pop(key: ValueKey<int>(got), child: Amount(chips: got, size: 24, color: PastraColors.gold, sign: true))
                : Amount(chips: amount, size: 22, color: ready ? PastraColors.goldLight : PastraColors.text2),
          ),
          const SizedBox(height: 12),
          if (ready)
            GoldButton(
              label: shop.claim,
              icon: Icons.card_giftcard_rounded,
              height: 46,
              fontSize: 17,
              onPressed: () {
                final got = settings.claimFreeChips(OnlineService.rewardTime);
                if (got > 0) setState(() => _got = got);
              },
            )
          else
            Container(
              height: 46,
              alignment: Alignment.center,
              decoration: glassDecoration(radius: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.schedule_rounded, size: 18, color: PastraColors.text2),
                  const SizedBox(width: 8),
                  Text(
                    shop.freeIn(_left(at.difference(now))),
                    style: const TextStyle(
                      color: PastraColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---- tables and card backs

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.items});

  final List<ShopItem> items;

  @override
  Widget build(BuildContext context) {
    return _TileGrid(count: items.length, height: 146, builder: (i) => _ItemTile(item: items[i]));
  }
}

String _itemName(ShopItem item, String lang) {
  final p = ProgressStrings(lang);
  return item.table != null ? p.table(item.table!) : p.back(item.back!);
}

bool _inUse(AppSettings settings, ShopItem item) =>
    item.table != null ? settings.tableTheme == item.table : settings.cardBack == item.back;

void _use(AppSettings settings, ShopItem item) {
  if (item.table != null) {
    settings.tableTheme = item.table!;
  } else {
    settings.cardBack = item.back!;
  }
}

bool _affordable(AppSettings settings, ShopItem item) =>
    item.chips <= settings.chips && item.diamonds <= settings.diamonds;

/// A table or card back: its picture, its name and its price (or "in use").
/// A tap buys it (after asking) or puts it to use.
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final owned = settings.owns(item.id);
    final inUse = owned && _inUse(settings, item);
    final Widget state;
    if (inUse) {
      state = _StatePill(icon: Icons.check_rounded, text: shop.inUse, gold: true);
    } else if (owned) {
      state = _StatePill(icon: Icons.touch_app_rounded, text: shop.use);
    } else {
      state = _Price(chips: item.chips, diamonds: item.diamonds, affordable: _affordable(settings, item));
    }
    return Pressable(
      radius: BorderRadius.circular(16),
      onTap: inUse
          ? () {}
          : () {
              if (owned) {
                _use(settings, item);
              } else {
                showDialog<void>(context: context, builder: (_) => _BuyDialog(item: item));
              }
            },
      decoration: BoxDecoration(
        color: inUse ? PastraColors.gold.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: inUse ? PastraColors.gold : Colors.white.withValues(alpha: 0.12), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _ItemPreview(item: item)),
            const SizedBox(height: 6),
            Text(
              _itemName(item, settings.language),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: PastraColors.text, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Center(child: state),
          ],
        ),
      ),
    );
  }
}

/// How the item looks: a small table with two cards on it, or two cards
/// with the back.
class _ItemPreview extends StatelessWidget {
  const _ItemPreview({required this.item});

  final ShopItem item;

  static final int _ace = Cards.make(Cards.spades, Cards.ace);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        final w = box.maxWidth;
        if (item.table != null) {
          final cardH = h * 0.62;
          final cardW = cardH / 1.42;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(max(4.0, h * 0.07)),
                  child: CustomPaint(painter: StageFeltPainter(table: item.table!, rim: max(3.0, h * 0.06))),
                ),
              ),
              Transform.translate(
                offset: Offset(-cardW * 0.42, 0),
                child: Transform.rotate(
                  angle: -0.12,
                  child: SizedBox(width: cardW, height: cardH, child: PlayingCardView(card: _ace, faceUp: true)),
                ),
              ),
              Transform.translate(
                offset: Offset(cardW * 0.42, 0),
                child: Transform.rotate(
                  angle: 0.1,
                  child: SizedBox(width: cardW, height: cardH, child: PlayingCardView(card: 0, faceUp: false)),
                ),
              ),
            ],
          );
        }
        final cardH = min(h * 0.96, w * 0.62);
        final cardW = cardH / 1.42;
        Widget card(double dx, double angle) => Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.rotate(
                angle: angle,
                child: SizedBox(
                  width: cardW,
                  height: cardH,
                  child: PlayingCardView(card: 0, faceUp: false, backStyle: item.back),
                ),
              ),
            );
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[card(-cardW * 0.36, -0.16), card(cardW * 0.36, 0.12)],
        );
      },
    );
  }
}

/// The price on a tile: gold when the player can pay it, dim with a lock
/// when not.
class _Price extends StatelessWidget {
  const _Price({this.chips = 0, this.diamonds = 0, required this.affordable});

  final int chips;
  final int diamonds;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    final color = affordable ? PastraColors.goldInk : PastraColors.text2;
    final pill = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: affordable
          ? BoxDecoration(gradient: goldGradient, borderRadius: BorderRadius.circular(15))
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!affordable) ...<Widget>[
            const Icon(Icons.lock_rounded, size: 13, color: PastraColors.text2),
            const SizedBox(width: 5),
          ],
          chips > 0 ? Amount(chips: chips, size: 14, color: color) : Amount(diamonds: diamonds, size: 14, color: color),
        ],
      ),
    );
    // Smaller rather than cut on a narrow tile.
    return FittedBox(fit: BoxFit.scaleDown, child: pill);
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.icon, required this.text, this.gold = false});

  final IconData icon;
  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final color = gold ? PastraColors.gold : PastraColors.text;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: glassDecoration(radius: 15, selected: gold),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks before a table or card back is bought: its picture, the price and
/// what is left afterwards (or what is still missing).
class _BuyDialog extends StatelessWidget {
  const _BuyDialog({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final s = Strings.of(context);
    final can = _affordable(settings, item);
    final byChips = item.chips > 0;
    final have = byChips ? settings.chips : settings.diamonds;
    final price = byChips ? item.chips : item.diamonds;
    Widget amount(int n, {Color color = PastraColors.text, double size = 18}) =>
        byChips ? Amount(chips: n, size: size, color: color) : Amount(diamonds: n, size: size, color: color);
    Widget row(String label, Widget value) => Row(
          children: <Widget>[
            Expanded(child: Text(label, style: PremiumText.secondary.copyWith(fontSize: 14))),
            value,
          ],
        );
    return PremiumDialog(
      maxWidth: 440,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              item.table != null ? s.tableColor : s.cardBackLabel,
              textAlign: TextAlign.center,
              style: PremiumText.eyebrow,
            ),
            const SizedBox(height: 4),
            Text(
              shop.buyTitle(_itemName(item, settings.language)),
              textAlign: TextAlign.center,
              style: PremiumText.title.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 14),
            SizedBox(height: 130, child: _ItemPreview(item: item)),
            const SizedBox(height: 16),
            row(shop.youPay, amount(price, color: PastraColors.goldLight)),
            const SizedBox(height: 8),
            if (can)
              row(shop.afterBuy, amount(have - price))
            else
              row(shop.needMore, amount(price - have, color: PastraColors.coral)),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: GlassButton(
                    label: can ? s.cancel : s.ok,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                if (can) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: GoldButton(
                      label: shop.buy,
                      icon: Icons.shopping_bag_rounded,
                      height: 48,
                      fontSize: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.of(context).pop();
                        if (settings.buy(item)) {
                          _use(settings, item);
                          messenger.showSnackBar(SnackBar(content: Text(shop.boughtUse)));
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- diamonds to chips

class _Exchanges extends StatelessWidget {
  const _Exchanges();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    const list = Economy.exchanges;
    return _TileGrid(
      count: list.length,
      height: 230,
      columns: 3,
      builder: (i) {
        final e = list[i];
        final can = e.diamonds <= settings.diamonds;
        return _OfferTile(
          onTap: () => showDialog<void>(context: context, builder: (_) => _ExchangeDialog(exchange: e)),
          top: Amount(diamonds: e.diamonds, size: 18, color: PastraColors.text),
          art: _CoinPile(tier: i + 2, size: 34),
          amount: Amount(chips: e.chips, size: 20, color: PastraColors.goldLight),
          button: _ActionPill(text: shop.exchangeDo, enabled: can),
        );
      },
    );
  }
}

class _ExchangeDialog extends StatelessWidget {
  const _ExchangeDialog({required this.exchange});

  final Exchange exchange;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final s = Strings.of(context);
    final e = exchange;
    final can = e.diamonds <= settings.diamonds;
    Widget row(String label, Widget value) => Row(
          children: <Widget>[
            Expanded(child: Text(label, style: PremiumText.secondary.copyWith(fontSize: 14))),
            value,
          ],
        );
    return PremiumDialog(
      maxWidth: 420,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(shop.exchangeTitle, textAlign: TextAlign.center, style: PremiumText.title.copyWith(fontSize: 22)),
            const SizedBox(height: 16),
            row(shop.youPay, Amount(diamonds: e.diamonds, size: 18)),
            const SizedBox(height: 8),
            row(shop.youGet, Amount(chips: e.chips, size: 18, color: PastraColors.goldLight)),
            if (!can) ...<Widget>[
              const SizedBox(height: 8),
              row(shop.needMore, Amount(diamonds: e.diamonds - settings.diamonds, size: 18, color: PastraColors.coral)),
            ],
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: GlassButton(
                    label: can ? s.cancel : s.ok,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                if (can) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: GoldButton(
                      label: shop.exchangeDo,
                      icon: Icons.swap_horiz_rounded,
                      height: 48,
                      fontSize: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.of(context).pop();
                        if (settings.exchange(e)) {
                          messenger.showSnackBar(SnackBar(content: Text(shop.exchanged(Economy.group(e.chips)))));
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- packs for real money

/// Packs for real money. Buying needs the store versions of the app (or a
/// payment provider on the web); until then a tap tells that it is coming.
class _Packs extends StatelessWidget {
  const _Packs({required this.diamonds});

  final bool diamonds;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final packs = diamonds ? Economy.diamondPacks : Economy.chipPacks;
    return _TileGrid(
      count: packs.length,
      height: 230,
      builder: (i) {
        final p = packs[i];
        return _OfferTile(
          onTap: () => showDialog<void>(context: context, builder: (_) => const _SoonDialog()),
          ribbon: p.bonusPercent > 0 ? shop.bonus(p.bonusPercent) : null,
          art: diamonds ? _GemPile(tier: i + 1, size: 30) : _CoinPile(tier: i + 1, size: 34),
          amount: Text(
            Economy.group(p.chips > 0 ? p.chips : p.diamonds),
            style: TextStyle(
              color: diamonds ? diamondColor : PastraColors.goldLight,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          button: _ActionPill(text: '\$${p.usd.toStringAsFixed(2)}', enabled: true),
        );
      },
    );
  }
}

class _SoonDialog extends StatelessWidget {
  const _SoonDialog();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    return PremiumDialog(
      maxWidth: 420,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Center(child: IconSquare(icon: Icons.shopping_bag_rounded, color: PastraColors.gold, size: 52)),
            const SizedBox(height: 12),
            Text(shop.soonTitle, textAlign: TextAlign.center, style: PremiumText.title.copyWith(fontSize: 24)),
            const SizedBox(height: 8),
            Text(shop.soon, textAlign: TextAlign.center, style: PremiumText.secondary.copyWith(fontSize: 14)),
            const SizedBox(height: 6),
            Text(shop.howToEarn, textAlign: TextAlign.center, style: PremiumText.secondary),
            const SizedBox(height: 18),
            GoldButton(
              label: Strings.of(context).ok,
              height: 48,
              fontSize: 17,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- shared pieces

/// A tile with an offer: an optional ribbon, a picture, an amount and a
/// button-like pill.
class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.onTap,
    required this.art,
    required this.amount,
    required this.button,
    this.top,
    this.ribbon,
  });

  final VoidCallback onTap;
  final Widget art;
  final Widget amount;
  final Widget button;
  final Widget? top;
  final String? ribbon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      radius: BorderRadius.circular(16),
      onTap: onTap,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 24,
              child: Center(
                child: ribbon != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(color: PastraColors.coral, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          ribbon!,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      )
                    : (top ?? const SizedBox.shrink()),
              ),
            ),
            if (top != null && ribbon == null) const Icon(Icons.arrow_downward_rounded, size: 16, color: PastraColors.text2),
            Expanded(child: Center(child: art)),
            Center(child: FittedBox(child: amount)),
            const SizedBox(height: 10),
            button,
          ],
        ),
      ),
    );
  }
}

/// A full-width pill that looks like a button (the whole tile is the button).
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.text, required this.enabled});

  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: enabled
          ? BoxDecoration(gradient: goldGradient, borderRadius: BorderRadius.circular(12))
          : BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: TextStyle(
              color: enabled ? PastraColors.goldInk : PastraColors.text2,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pieces laid in a small heap, centred: [spots] are (x, y) in piece sizes,
/// back to front.
Widget _heap({required List<List<double>> spots, required double size, required Widget Function(double size) piece}) {
  final xs = spots.map((p) => p[0]);
  final ys = spots.map((p) => p[1]);
  final cx = (xs.reduce(min) + xs.reduce(max)) / 2;
  final cy = (ys.reduce(min) + ys.reduce(max)) / 2;
  final width = (xs.reduce(max) - xs.reduce(min) + 1) * size;
  final height = (ys.reduce(max) - ys.reduce(min) + 1) * size;
  final order = spots.toList()..sort((a, b) => a[1].compareTo(b[1]));
  return SizedBox(
    width: width,
    height: height,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        for (final p in order) Transform.translate(offset: Offset((p[0] - cx) * size, (p[1] - cy) * size), child: piece(size)),
      ],
    ),
  );
}

/// A pile of chips: more and bigger for a bigger pack ([tier] 1..5).
class _CoinPile extends StatelessWidget {
  const _CoinPile({required this.tier, required this.size, this.dim = false});

  final int tier;
  final double size;
  final bool dim;

  static const List<List<double>> _spots = <List<double>>[
    <double>[0, 0],
    <double>[0.55, 0.1],
    <double>[-0.55, 0.1],
    <double>[0.28, -0.4],
    <double>[-0.28, -0.4],
  ];

  @override
  Widget build(BuildContext context) {
    final n = tier.clamp(1, _spots.length);
    final pile = _heap(
      spots: _spots.take(n).toList(),
      size: size * (1 + 0.08 * (n - 1)),
      piece: (s) => ChipIcon(size: s),
    );
    return dim ? Opacity(opacity: 0.45, child: pile) : pile;
  }
}

/// A heap of diamonds for the diamond packs ([tier] 1..3).
class _GemPile extends StatelessWidget {
  const _GemPile({required this.tier, required this.size});

  final int tier;
  final double size;

  static const List<List<double>> _spots = <List<double>>[
    <double>[0, 0.12],
    <double>[0.62, 0],
    <double>[-0.62, 0],
  ];

  @override
  Widget build(BuildContext context) {
    final n = tier.clamp(1, _spots.length);
    return _heap(
      spots: _spots.take(n).toList(),
      size: size * (1.2 + 0.1 * (n - 1)),
      piece: (s) => DiamondIcon(size: s),
    );
  }
}

/// Grows its child in once (a new amount).
class _Pop extends StatelessWidget {
  const _Pop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
    );
  }
}
