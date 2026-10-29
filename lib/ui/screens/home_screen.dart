import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/pastra_ai.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/level_badge.dart';
import '../widgets/menu_tiles.dart';
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
        Widget quick(double? h) => SizedBox(
              height: h,
              child: MenuTile(
                icon: Icons.bolt_rounded,
                title: s.quickGame,
                subtitle: s.quickGameHint,
                colors: TileColors.green,
                onTap: () => Navigator.of(sheet).pop(false),
              ),
            );
        Widget cup(double? h) => SizedBox(
              height: h,
              child: MenuTile(
                icon: Icons.emoji_events_rounded,
                title: s.tournament,
                subtitle: s.tournamentHint,
                colors: TileColors.gold,
                darkText: true,
                onTap: () => Navigator.of(sheet).pop(true),
              ),
            );
        return _CenteredDialog(
          maxWidth: 640,
          child: LayoutBuilder(
            builder: (context, box) {
              final screen = MediaQuery.sizeOf(context);
              // Side by side when there is room, else one under the other.
              final side = box.maxWidth >= 480;
              final h = side ? min(220.0, screen.height * 0.62) : 96.0;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: side
                    ? Row(
                        children: <Widget>[
                          Expanded(child: quick(h)),
                          const SizedBox(width: 14),
                          Expanded(child: cup(h)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[quick(h), const SizedBox(height: 12), cup(h)],
                      ),
              );
            },
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
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 80),
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
                        // Bounded (no scrolling) so the title shrinks to fit; the
                        // bottom is kept free for the About text in the corner.
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 64),
                          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: title)),
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
    const labelStyle = TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700);
    final players = Row(
      children: <Widget>[
        Expanded(
          child: ChoiceCard(
            icon: Icons.person,
            label: s.mode1v1,
            hint: s.mode1v1Hint,
            selected: _players == 2,
            onTap: () => setState(() => _players = 2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceCard(
            icon: Icons.groups,
            label: s.mode2v2,
            hint: s.mode2v2Hint,
            selected: _players == 4,
            onTap: () => setState(() => _players = 4),
          ),
        ),
      ],
    );
    final levels = Row(
      children: <Widget>[
        for (final l in AiLevel.values) ...<Widget>[
          if (l != AiLevel.values.first) const SizedBox(width: 10),
          Expanded(
            child: ChoiceCard(
              label: s.level(l),
              selected: _level == l,
              onTap: () => setState(() => _level = l),
            ),
          ),
        ],
      ],
    );
    // A phone held sideways is low: no title, less space between the rows.
    final compact = MediaQuery.sizeOf(context).height < 430;
    final gap = compact ? 8.0 : 14.0;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, compact ? 14 : 18, 20, compact ? 14 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!compact) ...<Widget>[
              Text(
                s.newGame,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              SizedBox(height: gap),
            ],
            Text(s.gameType, style: labelStyle),
            const SizedBox(height: 6),
            players,
            SizedBox(height: gap),
            Text(s.difficulty, style: labelStyle),
            const SizedBox(height: 6),
            levels,
            SizedBox(height: gap),
            Text(
              s.targetInfo(rules.variant, rules.targetScore, rules.cardsPerDeal),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            SizedBox(height: gap),
            BigButton(
              icon: Icons.play_arrow_rounded,
              label: s.start,
              onPressed: () => Navigator.of(context).pop(NewGameChoice(_players, _level)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A choice shown in the middle of the screen (not as a bottom sheet).
class _CenteredDialog extends StatelessWidget {
  const _CenteredDialog({required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PastraColors.panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
