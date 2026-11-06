import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/avatar_pic.dart';
import '../../game/economy.dart';
import '../../game/progression.dart';
import '../../game/sound.dart';
import '../../online/leaderboard.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../fx/fx.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
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
    return Scaffold(
      appBar: GameAppBar(icon: Icons.tune_rounded, title: Text(s.settings)),
      body: Felt(
        child: SafeArea(
          top: false,
          bottom: false,
          // Sections on the left (pills at the top on a narrow screen).
          child: SideTabs(
            tabs: <PageTab>[
              PageTab(icon: Icons.person_rounded, label: s.yourName, builder: _profile),
              PageTab(icon: Icons.palette_rounded, label: s.appearance, builder: _appearance),
              PageTab(icon: Icons.sports_esports_rounded, label: s.gameplay, builder: _gameplay),
              PageTab(icon: Icons.translate_rounded, label: s.language, builder: _languages),
              PageTab(icon: Icons.info_outline_rounded, label: s.about, builder: _about),
            ],
          ),
        ),
      ),
    );
  }

  /// The player: avatar, level, name and the leaderboard switch.
  Widget _profile(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final name = settings.playerName.isEmpty ? s.you : settings.playerName;
    return TabBody(
      children: <Widget>[
        SectionPanel(
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: <Widget>[
                PlayerAvatar(name: name, frame: settings.avatarFrame, pic: settings.avatarPic, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumText.title.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ProgressStrings(settings.language).title(settings.title),
                        style: const TextStyle(color: PastraColors.goldLight, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      LevelBadge(xp: settings.xp, width: (box.maxWidth - 80).clamp(140.0, 320.0).toDouble()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SectionPanel(
          title: s.yourName,
          icon: Icons.edit_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _name,
                maxLength: 16,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: s.you),
                onChanged: (v) => settings.playerName = v,
              ),
              SettingRow(
                icon: Icons.leaderboard_rounded,
                label: s.leaderboardShow,
                trailing: Switch(
                  value: settings.showOnLeaderboard,
                  onChanged: (v) {
                    settings.showOnLeaderboard = v;
                    if (v) {
                      Leaderboard.submit(settings);
                    } else {
                      Leaderboard.remove();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Table colour, card back and avatar frame (locked ones show their level).
  Widget _appearance(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    return TabBody(
      children: <Widget>[
        SectionPanel(
          title: s.tableColor,
          icon: Icons.table_restaurant_rounded,
          accent: PastraColors.teal,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              // Store colours only once bought (the store shows the rest).
              for (final t in (TableTheme.values.toList()..sort((a, b) => Progression.levelFor(a).compareTo(Progression.levelFor(b)))))
                if (Economy.itemForTable(t) == null || settings.isUnlocked(t))
                  _Swatch(
                    selected: settings.tableTheme == t,
                    lockedLevel: settings.isUnlocked(t) ? null : Progression.levelFor(t),
                    onTap: () => settings.tableTheme = t,
                    child: DecoratedBox(
                      decoration: t.decoration.copyWith(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PastraColors.wood, width: 3),
                      ),
                      child: const SizedBox(width: 80, height: 54),
                    ),
                  ),
            ],
          ),
        ),
        SectionPanel(
          title: s.cardBackLabel,
          icon: Icons.style_rounded,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (final b in (CardBackStyle.values.toList()..sort((x, y) => Progression.levelForBack(x).compareTo(Progression.levelForBack(y)))))
                if (Economy.itemForBack(b) == null || settings.isBackUnlocked(b))
                  _Swatch(
                    selected: settings.cardBack == b,
                    lockedLevel: settings.isBackUnlocked(b) ? null : Progression.levelForBack(b),
                    onTap: () => settings.cardBack = b,
                    child: SizedBox(
                      width: 48,
                      height: 68,
                      child: PlayingCardView(card: 0, faceUp: false, backStyle: b),
                    ),
                  ),
            ],
          ),
        ),
        SectionPanel(
          title: p.avatarPic,
          icon: Icons.face_rounded,
          accent: PastraColors.teal,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (final pic in AvatarPic.values)
                _Swatch(
                  selected: settings.avatarPic == pic,
                  lockedLevel: settings.isPicUnlocked(pic) ? null : pic.level,
                  onTap: () => settings.avatarPic = pic,
                  child: PlayerAvatar(
                    name: settings.playerName.isEmpty ? s.you : settings.playerName,
                    frame: settings.avatarFrame,
                    pic: pic,
                    size: 48,
                  ),
                ),
            ],
          ),
        ),
        SectionPanel(
          title: p.avatarFrame,
          icon: Icons.account_circle_rounded,
          accent: PastraColors.coral,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              for (final f in AvatarFrame.values)
                Tooltip(
                  message: p.frame(f),
                  child: _Swatch(
                    selected: settings.avatarFrame == f,
                    lockedLevel: settings.isFrameUnlocked(f) ? null : Progression.levelForFrame(f),
                    onTap: () => settings.avatarFrame = f,
                    child: PlayerAvatar(
                      name: settings.playerName.isEmpty ? s.you : settings.playerName,
                      frame: f,
                      pic: settings.avatarPic,
                      size: 48,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Animations, vibration, sound and the graphics quality.
  Widget _gameplay(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final social = SocialStrings(settings.language);
    return TabBody(
      children: <Widget>[
        SectionPanel(
          title: s.gameplay,
          icon: Icons.sports_esports_rounded,
          accent: PastraColors.teal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SettingRow(
                icon: Icons.fast_forward_rounded,
                label: s.fastAnimations,
                trailing: Switch(value: settings.fastAnimations, onChanged: (v) => settings.fastAnimations = v),
              ),
              SettingRow(
                icon: Icons.vibration_rounded,
                label: s.haptics,
                trailing: Switch(value: settings.haptics, onChanged: (v) => settings.haptics = v),
              ),
              SettingRow(
                icon: settings.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                label: s.sound,
                trailing: Text('${(settings.volume * 100).round()}%', style: PremiumText.label),
              ),
              Slider(
                value: settings.volume,
                divisions: 20,
                onChanged: (v) => settings.volume = v,
                onChangeEnd: (_) => SoundFx.instance.play(Sfx.play),
              ),
            ],
          ),
        ),
        // Graphics quality: automatic lowers the effects by itself on a
        // device that keeps missing frames.
        SectionPanel(
          title: social.graphics,
          icon: Icons.speed_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(social.graphicsHint, style: PremiumText.secondary),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  for (final m in <(FxMode, String)>[
                    (FxMode.auto, social.graphicsAuto),
                    (FxMode.high, social.graphicsHigh),
                    (FxMode.low, social.graphicsLow),
                  ]) ...<Widget>[
                    if (m.$1 != FxMode.auto) const SizedBox(width: 10),
                    Expanded(
                      child: ChoicePill(
                        label: m.$2,
                        selected: settings.fxMode == m.$1,
                        onTap: () => settings.fxMode = m.$1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The twelve languages as a grid of pills.
  Widget _languages(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    return TabBody(
      children: <Widget>[
        SectionPanel(
          title: s.language,
          icon: Icons.translate_rounded,
          accent: PastraColors.teal,
          child: LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 520 ? 3 : 2;
              final width = (box.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                key: ValueKey<int>(_fontPass),
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final code in _languagesAlphabetical)
                    SizedBox(
                      width: width,
                      child: ChoicePill(
                        label: Strings.languageName(code),
                        selected: settings.language == code,
                        onTap: () => settings.language = code,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _about(BuildContext context) {
    final s = Strings.of(context);
    return TabBody(
      children: <Widget>[
        SectionPanel(
          title: s.about,
          icon: Icons.info_outline_rounded,
          accent: PastraColors.teal,
          child: Text(
            '${s.aboutBody}\n${s.credits}',
            style: PremiumText.secondary.copyWith(height: 1.6, fontSize: 14),
          ),
        ),
      ],
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
          color: selected ? PastraColors.gold.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? PastraColors.gold : Colors.white.withValues(alpha: 0.12),
            width: selected ? 2.5 : 1,
          ),
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
