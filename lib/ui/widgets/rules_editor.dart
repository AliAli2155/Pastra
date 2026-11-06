import 'package:flutter/material.dart';

import '../../engine/rules.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';

/// The rules of the next game (variant, target, cards per deal, jack
/// options) and the time per move. Shown from the Play area (new offline
/// game, new online room), not in the general settings.
class RulesEditor extends StatelessWidget {
  const RulesEditor({super.key, this.wide = false});

  /// Two columns side by side (the scoring rules left, the jack options and
  /// the time right) instead of one long column.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final rules = settings.rules;

    Widget label(String text, {String? hint}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              if (hint != null) Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        );

    final scoring = <Widget>[
      label(s.variant, hint: s.variantHint(rules.variant)),
      SegmentedButton<GameVariant>(
        showSelectedIcon: false,
        segments: <ButtonSegment<GameVariant>>[
          for (final v in GameVariant.values) ButtonSegment<GameVariant>(value: v, label: Text(s.variantName(v))),
        ],
        selected: <GameVariant>{rules.variant},
        onSelectionChanged: (v) => settings.rules = PastraRules.defaultsFor(v.first),
      ),
      label(s.targetScore),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: <ButtonSegment<int>>[
          for (final t in PastraRules.targetOptions) ButtonSegment<int>(value: t, label: Text('$t')),
        ],
        selected: <int>{rules.targetScore},
        onSelectionChanged: (v) => settings.rules = rules.copyWith(targetScore: v.first),
      ),
      label(s.cardsPerDeal),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: <ButtonSegment<int>>[
          for (final d in PastraRules.dealOptions) ButtonSegment<int>(value: d, label: Text('$d')),
        ],
        selected: <int>{rules.cardsPerDeal},
        onSelectionChanged: (v) => settings.rules = rules.copyWith(cardsPerDeal: v.first),
      ),
      label(s.jackOnJack),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: <ButtonSegment<int>>[
          for (final p in rules.jackOnJackOptions)
            ButtonSegment<int>(value: p, label: Text(p == 0 ? s.nothing : '+$p')),
        ],
        selected: <int>{rules.jackOnJackPoints},
        onSelectionChanged: (v) => settings.rules = rules.copyWith(jackOnJackPoints: v.first),
      ),
    ];

    final more = <Widget>[
      SizedBox(height: wide ? 4 : 8),
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(rules.isPile ? s.jackOnLoneCardIsPastra : s.jackSweepIsPastra),
        subtitle: Text(rules.isPile ? s.jackOnLoneCardIsPastraHint : s.jackSweepIsPastraHint),
        value: rules.jackSweepIsPastra,
        onChanged: (v) => settings.rules = rules.copyWith(jackSweepIsPastra: v),
      ),
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(s.pastraOnLastCard),
        subtitle: Text(s.pastraOnLastCardHint),
        value: rules.pastraOnLastCard,
        onChanged: (v) => settings.rules = rules.copyWith(pastraOnLastCard: v),
      ),
      label(s.turnTime, hint: s.turnTimeHint),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: <ButtonSegment<int>>[
          for (final t in AppSettings.turnSecondsOptions)
            ButtonSegment<int>(value: t, label: Text(t == 0 ? s.noLimit : s.seconds(t))),
        ],
        selected: <int>{settings.turnSeconds},
        onSelectionChanged: (v) => settings.turnSeconds = v.first,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Text(s.rulesApplyToNewGames, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          // Everything in this dialog goes back to the start, the time too.
          onPressed: () {
            settings.rules = PastraRules.defaultsFor(rules.variant);
            settings.turnSeconds = AppSettings.defaultTurnSeconds;
          },
          icon: const Icon(Icons.restart_alt),
          label: Text(s.resetRules),
        ),
      ),
    ];

    Widget column(List<Widget> children) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
    if (!wide) return column(<Widget>[...scoring, ...more]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: column(scoring)),
        const SizedBox(width: 20),
        Expanded(child: column(more)),
      ],
    );
  }
}

/// Opens the game rules in a dialog.
Future<void> showRulesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialog) {
      final s = Strings.of(dialog);
      final screen = MediaQuery.sizeOf(dialog);
      // Wide screens get two columns. Those and low ones (a phone held
      // sideways) show everything at once: the dialog is scaled down to fit
      // instead of scrolling. Only a narrow upright phone scrolls.
      final wide = screen.width >= 720;
      final fit = wide || screen.height < 480;
      final editor = Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: RulesEditor(wide: wide),
      );
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: <Widget>[
                const Icon(Icons.tune_rounded, color: PastraColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.gameRules,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: s.ok,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(dialog).pop(),
                ),
              ],
            ),
          ),
          if (fit) editor else Flexible(child: SingleChildScrollView(child: editor)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(s.ok)),
          ),
        ],
      );
      return Dialog(
        // Opaque: the quick game dialog may be open underneath.
        backgroundColor: PastraColors.nightMid,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.4)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 860 : 560),
          child: fit
              ? LayoutBuilder(
                  builder: (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(width: box.maxWidth, child: body),
                  ),
                )
              : body,
        ),
      );
    },
  );
}

/// A small button with the current rules ("Pile · up to 151 points · 6
/// cards") that opens [showRulesDialog].
class RulesButton extends StatelessWidget {
  const RulesButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final rules = SettingsScope.of(context).rules;
    return Material(
      color: PastraColors.glass,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => showRulesDialog(context) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          // Very narrow (an upright phone): the summary keeps the room and the
          // gold "Game rules" word is left out (the arrow still shows it opens).
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: <Widget>[
                const Icon(Icons.tune_rounded, size: 18, color: PastraColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.targetInfo(rules.variant, rules.targetScore, rules.cardsPerDeal),
                    // A narrow phone: a second line rather than "…".
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PastraColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                if (box.maxWidth >= 340)
                  Text(
                    s.gameRules,
                    style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: PastraColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
