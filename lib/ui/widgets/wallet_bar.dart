import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../l10n/shop_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';

const Color chipColor = Color(0xFFFFC94A);
const Color diamondColor = Color(0xFF7FD8F5);

/// A small round chip (the in-game coin).
class ChipIcon extends StatelessWidget {
  const ChipIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _ChipPainter());
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFB8860B));
    canvas.drawCircle(c, r * 0.9, Paint()..color = chipColor);
    // The white edge marks of a casino chip.
    final mark = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.28
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 4; i++) {
      final a = i * 3.14159 / 2;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.76), a - 0.22, 0.44, false, mark);
    }
    canvas.drawCircle(c, r * 0.5, Paint()..color = const Color(0xFFD99A1E));
    canvas.drawCircle(
      c,
      r * 0.5,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) => false;
}

class DiamondIcon extends StatelessWidget {
  const DiamondIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Icon(Icons.diamond_rounded, size: size, color: diamondColor);
}

/// An amount with its icon: "🪙 12.500".
class Amount extends StatelessWidget {
  const Amount({super.key, this.chips, this.diamonds, this.size = 16, this.color = Colors.white, this.sign = false});

  final int? chips;
  final int? diamonds;
  final double size;
  final Color color;

  /// Show "+" in front of positive amounts.
  final bool sign;

  @override
  Widget build(BuildContext context) {
    final value = chips ?? diamonds ?? 0;
    final text = '${sign && value > 0 ? '+' : ''}${Economy.group(value)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (chips != null) ChipIcon(size: size + 2) else DiamondIcon(size: size + 2),
        SizedBox(width: size * 0.3),
        Text(text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

/// The player's chips and diamonds; tapping opens the store.
class WalletBar extends StatelessWidget {
  const WalletBar({super.key, required this.onTap, this.compact = false});

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final size = compact ? 14.0 : 16.0;
    return Tooltip(
      message: shop.store,
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: StadiumBorder(side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.6))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 5 : 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Amount(chips: settings.chips, size: size),
                SizedBox(width: compact ? 10 : 14),
                Amount(diamonds: settings.diamonds, size: size),
                if (onTap != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(color: PastraColors.gold, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.add_rounded, size: size + 2, color: Colors.black),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 7 days of the daily bonus and the "collect" button.
class DailyBonusCard extends StatefulWidget {
  const DailyBonusCard({super.key, this.onClaimed});

  /// Called after collecting (the dialog closes itself with it).
  final VoidCallback? onClaimed;

  @override
  State<DailyBonusCard> createState() => _DailyBonusCardState();
}

class _DailyBonusCardState extends State<DailyBonusCard> {
  ({int chips, int diamonds, int day})? _claimed;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final shop = ShopStrings(settings.language);
    final next = settings.dailyNext(DateTime.now());
    // The day to highlight: the one to collect, or the one just collected.
    final today = next != null ? Economy.streakDay(next) : Economy.streakDay(settings.dailyStreak < 1 ? 1 : settings.dailyStreak);
    final narrow = MediaQuery.sizeOf(context).width < 420;
    Widget day(int d) {
      final done = next == null ? d <= today : d < today;
      final current = d == today;
      final diamonds = d == 7 ? Economy.day7Diamonds : 0;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: current
                ? PastraColors.gold.withValues(alpha: 0.25)
                : (done ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: current ? PastraColors.gold : Colors.white24, width: current ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                child: Text(
                  shop.dailyDay(d),
                  style: TextStyle(color: current ? PastraColors.gold : Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 4),
              done && !current
                  ? const Icon(Icons.check_circle_rounded, color: Colors.white54, size: 22)
                  : ChipIcon(size: narrow ? 18 : 22),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  Economy.short(Economy.dailyChips[d - 1]),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
              if (diamonds > 0)
                FittedBox(child: Amount(diamonds: diamonds, size: 11)),
            ],
          ),
        ),
      );
    }

    final claimed = _claimed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(children: <Widget>[for (var d = 1; d <= 7; d++) day(d)]),
        const SizedBox(height: 12),
        if (claimed != null)
          Center(
            child: Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: <Widget>[
                Amount(chips: claimed.chips, size: 22, color: PastraColors.gold, sign: true),
                if (claimed.diamonds > 0) Amount(diamonds: claimed.diamonds, size: 22, color: diamondColor, sign: true),
              ],
            ),
          )
        else if (next != null)
          FilledButton.icon(
            icon: const Icon(Icons.redeem_rounded),
            label: Text('${shop.claim}  +${Economy.group(Economy.dailyReward(next))}'),
            onPressed: () {
              final got = settings.claimDaily(DateTime.now());
              if (got == null) return;
              setState(() => _claimed = got);
              widget.onClaimed?.call();
            },
          )
        else
          Text(shop.dailyDone, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text(shop.dailyBack, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

/// Whether the home screen opens the daily bonus by itself (off in widget
/// tests).
bool dailyBonusAutoShow = true;

/// Shows the daily bonus when it can be collected (once per app start).
Future<void> showDailyBonusIfReady(BuildContext context) async {
  if (_shownThisRun || !dailyBonusAutoShow) return;
  final settings = SettingsScope.read(context);
  if (settings.dailyNext(DateTime.now()) == null) return;
  _shownThisRun = true;
  await showDialog<void>(
    context: context,
    builder: (dialog) {
      final shop = ShopStrings(settings.language);
      return Dialog(
        backgroundColor: PastraColors.panel,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.6)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: GoldText(shop.dailyBonus, size: 28)),
                const SizedBox(height: 14),
                DailyBonusCard(
                  onClaimed: () => Future<void>.delayed(const Duration(milliseconds: 1100), () {
                    if (dialog.mounted) Navigator.of(dialog).pop();
                  }),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialog).pop(),
                    child: Text(Strings.of(dialog).ok),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

bool _shownThisRun = false;
