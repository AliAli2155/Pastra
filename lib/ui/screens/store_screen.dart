import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../l10n/shop_strings.dart';
import '../theme.dart';
import '../widgets/menu_tiles.dart';
import '../widgets/playing_card.dart';
import '../widgets/wallet_bar.dart';

/// The store: daily bonus, free chips, tables and card backs, diamonds to
/// chips and the packs sold for real money.
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    return Scaffold(
      appBar: AppBar(
        title: Text(shop.store, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: const <Widget>[
          Padding(padding: EdgeInsets.only(right: 12), child: Center(child: WalletBar(onTap: null, compact: true))),
        ],
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 760;
              final daily = MenuPanel(title: shop.dailyBonus, child: const DailyBonusCard());
              const free = _FreeChipsPanel();
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 3, child: daily),
                              const SizedBox(width: 14),
                              const Expanded(flex: 2, child: free),
                            ],
                          )
                        else ...<Widget>[
                          daily,
                          const SizedBox(height: 14),
                          free,
                        ],
                        const SizedBox(height: 14),
                        MenuPanel(title: shop.cosmetics, child: const _Cosmetics()),
                        const SizedBox(height: 14),
                        MenuPanel(title: shop.exchange, child: const _Exchanges()),
                        const SizedBox(height: 14),
                        MenuPanel(
                          title: shop.chipPacks,
                          child: _Packs(packs: Economy.chipPacks, shop: shop),
                        ),
                        const SizedBox(height: 14),
                        MenuPanel(
                          title: shop.diamondPacks,
                          child: _Packs(packs: Economy.diamondPacks, shop: shop),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          shop.howToEarn,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          shop.noCash,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _left(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final now = DateTime.now();
    final ready = !now.isBefore(settings.freeChipsAt);
    final amount = Economy.freeChipsFor(settings.chips);
    return MenuPanel(
      title: shop.freeChips,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 4),
          Center(child: ChipIcon(size: ready ? 56 : 44)),
          const SizedBox(height: 10),
          Center(
            child: _got != null
                ? Amount(chips: _got, size: 24, color: PastraColors.gold, sign: true)
                : Amount(chips: amount, size: 22, color: ready ? PastraColors.gold : Colors.white70),
          ),
          const SizedBox(height: 12),
          if (ready)
            FilledButton.icon(
              icon: const Icon(Icons.card_giftcard_rounded),
              label: Text(shop.claim),
              onPressed: () {
                final got = settings.claimFreeChips(DateTime.now());
                if (got > 0) setState(() => _got = got);
              },
            )
          else
            Text(
              shop.freeIn(_left(settings.freeChipsAt.difference(now))),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

/// Store tables and card backs: buy, then use.
class _Cosmetics extends StatelessWidget {
  const _Cosmetics();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final item in Economy.items) _ItemCard(item: item, settings: settings, shop: shop),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.settings, required this.shop});

  final ShopItem item;
  final AppSettings settings;
  final ShopStrings shop;

  bool get _inUse => item.table != null ? settings.tableTheme == item.table : settings.cardBack == item.back;

  void _use() {
    if (item.table != null) {
      settings.tableTheme = item.table!;
    } else {
      settings.cardBack = item.back!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = settings.owns(item.id);
    final affordable = item.chips <= settings.chips && item.diamonds <= settings.diamonds;
    final preview = item.table != null
        ? DecoratedBox(
            decoration: item.table!.decoration.copyWith(borderRadius: BorderRadius.circular(12)),
            child: const SizedBox(width: 120, height: 76),
          )
        : SizedBox(width: 54, height: 76, child: PlayingCardView(card: 0, faceUp: false, backStyle: item.back));
    final Widget action;
    if (owned) {
      action = _inUse
          ? Text(shop.inUse, style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800))
          : OutlinedButton(onPressed: _use, child: Text(shop.use));
    } else {
      action = FilledButton(
        onPressed: affordable
            ? () {
                if (settings.buy(item)) {
                  _use();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(shop.bought)));
                }
              }
            : null,
        child: item.chips > 0
            ? Amount(chips: item.chips, size: 14, color: affordable ? Colors.black : Colors.white54)
            : Amount(diamonds: item.diamonds, size: 14, color: affordable ? Colors.black : Colors.white54),
      );
    }
    return HoverLift(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _inUse ? PastraColors.gold : Colors.white24, width: _inUse ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: 80, child: Center(child: preview)),
            const SizedBox(height: 10),
            SizedBox(height: 40, child: Center(child: action)),
          ],
        ),
      ),
    );
  }
}

/// Diamonds turned into chips.
class _Exchanges extends StatelessWidget {
  const _Exchanges();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final e in Economy.exchanges)
          SizedBox(
            width: 200,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                side: const BorderSide(color: diamondColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: e.diamonds <= settings.diamonds ? () => settings.exchange(e) : null,
              child: FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Amount(diamonds: e.diamonds, size: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
                    ),
                    Amount(chips: e.chips, size: 16, color: PastraColors.gold),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Packs for real money. The purchase needs the store versions of the app
/// (Google Play Billing / App Store in-app purchases); until then a tap
/// explains that.
class _Packs extends StatelessWidget {
  const _Packs({required this.packs, required this.shop});

  final List<MoneyPack> packs;
  final ShopStrings shop;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final p in packs)
          HoverLift(
            child: Material(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(shop.soon))),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: 18,
                        child: p.bonusPercent > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD32F2F),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  shop.bonus(p.bonusPercent),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      p.chips > 0 ? const ChipIcon(size: 40) : const DiamondIcon(size: 40),
                      const SizedBox(height: 6),
                      FittedBox(
                        child: Text(
                          Economy.group(p.chips > 0 ? p.chips : p.diamonds),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(color: PastraColors.gold, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '\$${p.usd.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
