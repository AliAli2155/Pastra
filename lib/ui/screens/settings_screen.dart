import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/progression.dart';
import '../../game/sound.dart';
import '../../online/leaderboard.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/level_badge.dart';
import '../widgets/playing_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _name = TextEditingController();
  bool _nameLoaded = false;

  /// Web: the language list is drawn again once the fonts for Arabic and
  /// Chinese have arrived (text drawn before stays garbled).
  int _fontPass = 0;
  final List<Timer> _fontTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      for (final ms in const <int>[800, 2500]) {
        _fontTimers.add(Timer(Duration(milliseconds: ms), () {
          if (mounted) setState(() => _fontPass++);
        }));
      }
    }
  }

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
    for (final t in _fontTimers) {
      t.cancel();
    }
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);

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
      body: Felt(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: _listPadding(context),
            children: <Widget>[
              section(s.language),
              Wrap(
                key: ValueKey<int>(_fontPass),
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final code in _languagesAlphabetical)
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
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(s.leaderboardShow),
                value: settings.showOnLeaderboard,
                onChanged: (v) {
                  settings.showOnLeaderboard = v;
                  if (v) {
                    Leaderboard.submit(settings, fallbackName: s.you);
                  } else {
                    Leaderboard.remove();
                  }
                },
              ),
              section(s.appearance),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: LevelBadge(xp: settings.xp, width: 280)),
              label(s.tableColor),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  // Store colours only once bought (the store shows the rest).
                  for (final t in TableTheme.values)
                    if (Economy.itemForTable(t) == null || settings.isUnlocked(t))
                    _Swatch(
                      selected: settings.tableTheme == t,
                      lockedLevel: settings.isUnlocked(t) ? null : Progression.levelFor(t),
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
                    if (Economy.itemForBack(b) == null || settings.isBackUnlocked(b))
                    _Swatch(
                      selected: settings.cardBack == b,
                      lockedLevel: settings.isBackUnlocked(b) ? null : Progression.levelForBack(b),
                      onTap: () => settings.cardBack = b,
                      child: SizedBox(
                        width: 44,
                        height: 62,
                        child: PlayingCardView(card: 0, faceUp: false, backStyle: b),
                      ),
                    ),
                ],
              ),
              label(ProgressStrings(settings.language).avatarFrame),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final f in AvatarFrame.values)
                    Tooltip(
                      message: ProgressStrings(settings.language).frame(f),
                      child: _Swatch(
                        selected: settings.avatarFrame == f,
                        lockedLevel: settings.isFrameUnlocked(f) ? null : Progression.levelForFrame(f),
                        onTap: () => settings.avatarFrame = f,
                        child: PlayerAvatar(
                          name: settings.playerName.isEmpty ? s.you : settings.playerName,
                          frame: f,
                          size: 46,
                        ),
                      ),
                    ),
                ],
              ),
              section(s.gameplay),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: <Widget>[
                    Icon(settings.volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.sound, style: const TextStyle(fontSize: 16))),
                    Text('${(settings.volume * 100).round()}%', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Slider(
                value: settings.volume,
                divisions: 20,
                activeColor: PastraColors.gold,
                onChanged: (v) => settings.volume = v,
                onChangeEnd: (_) => SoundFx.instance.play(Sfx.play),
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

/// English names, used only to order the language chips alphabetically.
const Map<String, String> _englishLanguageNames = <String, String>{
  'ar': 'Arabic',
  'bg': 'Bulgarian',
  'zh': 'Chinese',
  'en': 'English',
  'fr': 'French',
  'de': 'German',
  'el': 'Greek',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'es': 'Spanish',
  'tr': 'Turkish',
};

final List<String> _languagesAlphabetical = AppSettings.languages.toList()
  ..sort((a, b) => (_englishLanguageNames[a] ?? a).compareTo(_englishLanguageNames[b] ?? b));

/// Side padding that keeps the list readable on a wide (landscape) screen.
EdgeInsets _listPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final side = w > 792 ? (w - 760) / 2 : 16.0;
  return EdgeInsets.fromLTRB(side, 8, side, 32);
}

/// A tappable preview with a gold ring when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.selected, required this.onTap, required this.child, this.lockedLevel});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  /// Level that unlocks this colour (null = available).
  final int? lockedLevel;

  @override
  Widget build(BuildContext context) {
    final locked = lockedLevel != null;
    return GestureDetector(
      onTap: locked
          ? () {
              final s = Strings.of(context);
              final messenger = ScaffoldMessenger.of(context);
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(SnackBar(content: Text(s.unlocksAt(lockedLevel!)), duration: const Duration(seconds: 2)));
            }
          : onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? PastraColors.gold : Colors.white24, width: selected ? 3 : 1),
        ),
        child: locked
            ? Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Opacity(opacity: 0.35, child: child),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.lock, size: 18, color: Colors.white),
                      Text(
                        '$lockedLevel',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              )
            : child,
      ),
    );
  }
}
