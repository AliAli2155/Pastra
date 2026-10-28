import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/pastra_ai.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/level_badge.dart';
import '../widgets/playing_card.dart';
import 'game_screen.dart';
import 'online_screen.dart';
import 'play_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'tournament_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  /// Continues the saved offline game (from the Play screen).
  Future<void> _continue(BuildContext ctx) async {
    final settings = SettingsScope.read(ctx);
    final controller = GameController.fromSaved(settings);
    if (controller == null) {
      await settings.clearSavedGame();
      return;
    }
    await Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller)));
  }

  /// Offline: a quick game or the tournament.
  Future<void> _offline(BuildContext ctx) async {
    final choice = await showDialog<bool>(
      context: ctx,
      builder: (sheet) {
        final s = Strings.of(sheet);
        Widget option(IconData icon, String title, String hint, bool tournament) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: PastraColors.gold,
                foregroundColor: Colors.black,
                child: Icon(icon),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              subtitle: Text(hint, style: const TextStyle(color: Colors.white60)),
              onTap: () => Navigator.of(sheet).pop(tournament),
            );
        return _CenteredDialog(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                option(Icons.bolt, s.quickGame, s.quickGameHint, false),
                option(Icons.emoji_events, s.tournament, s.tournamentHint, true),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !ctx.mounted) return;
    if (choice) {
      await Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const TournamentScreen()));
    } else {
      await _newGame(ctx);
    }
  }

  /// Offline: pick players and level, then play against the computer.
  Future<void> _newGame(BuildContext ctx) async {
    final current = SettingsScope.read(ctx);
    final choice = await showDialog<NewGameChoice>(
      context: ctx,
      builder: (_) => _CenteredDialog(
        child: NewGameSheet(initialPlayers: current.players, initialLevel: current.level),
      ),
    );
    if (choice == null || !ctx.mounted) return;
    final settings = SettingsScope.read(ctx);
    settings.players = choice.players;
    settings.level = choice.level;
    await settings.clearSavedGame();
    if (!ctx.mounted) return;
    final controller = GameController.newGame(settings, players: choice.players, level: choice.level);
    await Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller)));
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _Logo(),
        const SizedBox(height: 14),
        Text(
          s.appTitle,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          s.appSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Colors.white70),
        ),
        const SizedBox(height: 14),
        LevelBadge(xp: settings.xp),
        if (settings.gamesPlayed > 0) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            s.stats(settings.gamesWon, settings.gamesPlayed),
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ],
    );
    final menu = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MenuButton(
          icon: Icons.sports_esports_rounded,
          label: s.play,
          primary: true,
          onTap: () => _open(
            PlayScreen(
              onOffline: _offline,
              onContinue: _continue,
              onOnline: (ctx) => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const OnlineScreen())),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _MenuButton(
          icon: Icons.menu_book_outlined,
          label: s.rules,
          onTap: () => _open(const RulesScreen()),
        ),
        const SizedBox(height: 10),
        _MenuButton(
          icon: Icons.bar_chart_rounded,
          label: s.statistics,
          onTap: () => _open(const StatsScreen()),
        ),
        const SizedBox(height: 10),
        _MenuButton(
          icon: Icons.settings_outlined,
          label: s.settings,
          onTap: () => _open(const SettingsScreen()),
        ),
      ],
    );
    return Scaffold(
      body: Container(
        decoration: feltDecoration,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight;
              if (!wide) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[title, const SizedBox(height: 28), menu],
                      ),
                    ),
                  ),
                );
              }
              // Landscape: title on the left, menu on the right.
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: FittedBox(fit: BoxFit.scaleDown, child: title),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: min(380.0, box.maxWidth * 0.45),
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(8, 16, 24, 16),
                            child: menu,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
            // About: plain text in the bottom-left corner (home screen only).
            Positioned.fill(
              child: IgnorePointer(
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.about,
                            style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(s.aboutBody, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final cards = <int>[
      Cards.twoOfClubs,
      Cards.make(Cards.hearts, Cards.jack),
      Cards.tenOfDiamonds,
    ];
    return SizedBox(
      width: 230,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: 75 + (i - 1) * 52.0,
              top: i == 1 ? 12.0 : 22.0,
              width: 80,
              height: 114,
              child: Transform.rotate(
                angle: (i - 1) * 0.26,
                child: PlayingCardView(card: cards[i], faceUp: true),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = primary
        ? PastraColors.gold
        : Colors.black.withValues(alpha: enabled ? 0.28 : 0.15);
    final fg = primary ? Colors.black : (enabled ? Colors.white : Colors.white38);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: <Widget>[
                Icon(icon, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
                if (enabled) Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the player picked in the new-game sheet.
class NewGameChoice {
  final int players;
  final AiLevel level;

  const NewGameChoice(this.players, this.level);
}

class NewGameSheet extends StatefulWidget {
  const NewGameSheet({super.key, required this.initialPlayers, required this.initialLevel});

  final int initialPlayers;
  final AiLevel initialLevel;

  @override
  State<NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<NewGameSheet> {
  late int _players;
  late AiLevel _level;

  @override
  void initState() {
    super.initState();
    _players = widget.initialPlayers;
    _level = widget.initialLevel;
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final rules = SettingsScope.of(context).rules;
    const labelStyle = TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              s.newGame,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(s.gameType, style: labelStyle),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(value: 2, label: Text(s.mode1v1), icon: const Icon(Icons.person_outline)),
                ButtonSegment<int>(value: 4, label: Text(s.mode2v2), icon: const Icon(Icons.groups_outlined)),
              ],
              selected: <int>{_players},
              onSelectionChanged: (v) => setState(() => _players = v.first),
            ),
            const SizedBox(height: 6),
            Text(
              _players == 2 ? s.mode1v1Hint : s.mode2v2Hint,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Text(s.difficulty, style: labelStyle),
            const SizedBox(height: 8),
            SegmentedButton<AiLevel>(
              showSelectedIcon: false,
              segments: <ButtonSegment<AiLevel>>[
                for (final l in AiLevel.values) ButtonSegment<AiLevel>(value: l, label: Text(s.level(l))),
              ],
              selected: <AiLevel>{_level},
              onSelectionChanged: (v) => setState(() => _level = v.first),
            ),
            const SizedBox(height: 16),
            Text(
              s.targetInfo(rules.variant, rules.targetScore, rules.cardsPerDeal),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(NewGameChoice(_players, _level)),
              child: Text(s.start),
            ),
          ],
        ),
      ),
    );
  }
}


/// A choice shown in the middle of the screen (not as a bottom sheet).
class _CenteredDialog extends StatelessWidget {
  const _CenteredDialog({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PastraColors.panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: child,
      ),
    );
  }
}
