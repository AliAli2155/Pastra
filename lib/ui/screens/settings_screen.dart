import 'package:flutter/material.dart';

import '../../engine/rules.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/playing_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _name = TextEditingController();
  bool _nameLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameLoaded) {
      _name.text = SettingsScope.read(context).playerName;
      _nameLoaded = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final rules = settings.rules;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: PastraColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        );

    Widget label(String text, {String? hint}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              if (hint != null)
                Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: Container(
        decoration: feltDecoration,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: _listPadding(context),
            children: <Widget>[
              section(s.language),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final code in AppSettings.languages)
                    ChoiceChip(
                      label: Text(Strings.languageName(code)),
                      selected: settings.language == code,
                      onSelected: (_) => settings.language = code,
                      selectedColor: PastraColors.gold,
                      labelStyle: TextStyle(
                        color: settings.language == code ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.black.withValues(alpha: 0.25),
                      showCheckmark: false,
                    ),
                ],
              ),
              label(s.yourName),
              TextField(
                controller: _name,
                maxLength: 16,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: s.you,
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.25),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => settings.playerName = v,
              ),
              section(s.appearance),
              label(s.tableColor),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final t in TableTheme.values)
                    _Swatch(
                      selected: settings.tableTheme == t,
                      onTap: () => settings.tableTheme = t,
                      child: DecoratedBox(
                        decoration: t.decoration.copyWith(borderRadius: BorderRadius.circular(12)),
                        child: const SizedBox(width: 64, height: 44),
                      ),
                    ),
                ],
              ),
              label(s.cardBackLabel),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final b in CardBackStyle.values)
                    _Swatch(
                      selected: settings.cardBack == b,
                      onTap: () => settings.cardBack = b,
                      child: SizedBox(
                        width: 44,
                        height: 62,
                        child: PlayingCardView(card: 0, faceUp: false, backStyle: b),
                      ),
                    ),
                ],
              ),
              section(s.gameRules),
              label(s.variant, hint: s.variantHint(rules.variant)),
              SegmentedButton<GameVariant>(
                showSelectedIcon: false,
                segments: <ButtonSegment<GameVariant>>[
                  for (final v in GameVariant.values)
                    ButtonSegment<GameVariant>(value: v, label: Text(s.variantName(v))),
                ],
                selected: <GameVariant>{rules.variant},
                onSelectionChanged: (v) => settings.rules = PastraRules.defaultsFor(v.first),
              ),
              label(s.targetScore),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: <ButtonSegment<int>>[
                  for (final t in PastraRules.targetOptions)
                    ButtonSegment<int>(value: t, label: Text('$t')),
                ],
                selected: <int>{rules.targetScore},
                onSelectionChanged: (v) => settings.rules = rules.copyWith(targetScore: v.first),
              ),
              label(s.cardsPerDeal),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: <ButtonSegment<int>>[
                  for (final d in PastraRules.dealOptions)
                    ButtonSegment<int>(value: d, label: Text('$d')),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  s.rulesApplyToNewGames,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => settings.rules = PastraRules.defaultsFor(rules.variant),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(s.resetRules),
                ),
              ),
              section(s.gameplay),
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(s.fastAnimations),
                value: settings.fastAnimations,
                onChanged: (v) => settings.fastAnimations = v,
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(s.haptics),
                value: settings.haptics,
                onChanged: (v) => settings.haptics = v,
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(s.sound),
                value: settings.sound,
                onChanged: (v) => settings.sound = v,
              ),
              section(s.about),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${s.aboutBody}\n${s.credits}', style: const TextStyle(color: Colors.white70, height: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Side padding that keeps the list readable on a wide (landscape) screen.
EdgeInsets _listPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final side = w > 792 ? (w - 760) / 2 : 16.0;
  return EdgeInsets.fromLTRB(side, 8, side, 32);
}

/// A tappable preview with a gold ring when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? PastraColors.gold : Colors.white24, width: selected ? 3 : 1),
        ),
        child: child,
      ),
    );
  }
}
