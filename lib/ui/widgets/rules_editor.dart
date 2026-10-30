import 'package:flutter/material.dart';

import '../../engine/rules.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';

/// The rules of the next game (variant, target, cards per deal, jack
/// options) and the time per move. Shown from the Play area (new offline
/// game, new online room), not in the general settings.
class RulesEditor extends StatelessWidget {
  const RulesEditor({super.key});

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
        const SizedBox(height: 8),
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
            onPressed: () => settings.rules = PastraRules.defaultsFor(rules.variant),
            icon: const Icon(Icons.restart_alt),
            label: Text(s.resetRules),
          ),
        ),
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
      return Dialog(
        backgroundColor: PastraColors.panel,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.4)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
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
              const Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: RulesEditor(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(s.ok)),
              ),
            ],
          ),
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
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => showRulesDialog(context) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PastraColors.gold.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.tune_rounded, size: 18, color: PastraColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.targetInfo(rules.variant, rules.targetScore, rules.cardsPerDeal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                s.gameRules,
                style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: PastraColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}
