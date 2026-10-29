import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/pastra_ai.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/fullscreen_button.dart';
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

  void _openPlay() => _open(
        PlayScreen(
          onOffline: _offline,
          onContinue: _continue,
          onOnline: (ctx) => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const OnlineScreen())),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final name = settings.playerName.isEmpty ? s.you : settings.playerName;

    final hero = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _Logo(),
        const SizedBox(height: 10),
        GoldText(s.appTitle, size: 64, letterSpacing: 2),
        const SizedBox(height: 4),
        Text(
          s.appSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 0.4),
        ),
        const SizedBox(height: 18),
        _PlayerCard(
          name: name,
          xp: settings.xp,
          stats: settings.gamesPlayed > 0 ? s.stats(settings.gamesWon, settings.gamesPlayed) : null,
          onTap: () => _open(const StatsScreen()),
        ),
      ],
    );

    final menu = FocusTraversalGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SlideIn(
            order: 0,
            child: _MenuButton(
              icon: Icons.play_arrow_rounded,
              label: s.play,
              primary: true,
              autofocus: true,
              onTap: _openPlay,
            ),
          ),
          const SizedBox(height: 12),
          _SlideIn(
            order: 1,
            child: _MenuButton(icon: Icons.menu_book_rounded, label: s.rules, onTap: () => _open(const RulesScreen())),
          ),
          const SizedBox(height: 10),
          _SlideIn(
            order: 2,
            child: _MenuButton(icon: Icons.insights_rounded, label: s.statistics, onTap: () => _open(const StatsScreen())),
          ),
          const SizedBox(height: 10),
          _SlideIn(
            order: 3,
            child: _MenuButton(icon: Icons.tune_rounded, label: s.settings, onTap: () => _open(const SettingsScreen())),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Felt(
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: IgnorePointer(child: _SuitWatermark())),
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth > box.maxHeight;
                    if (!wide) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[hero, const SizedBox(height: 28), menu],
                            ),
                          ),
                        ),
                      );
                    }
                    // Landscape (phones held sideways, tablets, computers):
                    // the title on the left, the menu on the right.
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: 11,
                              // Bounded (no scrolling) so the hero shrinks to
                              // fit; the bottom stays free for the About text.
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
                                child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: hero)),
                              ),
                            ),
                            Expanded(
                              flex: 9,
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(8, 16, 28, 16),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 420),
                                    child: menu,
                                  ),
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
            // Full screen button in the top-right corner (web version).
            const Positioned(
              top: 0,
              right: 0,
              child: SafeArea(child: Padding(padding: EdgeInsets.all(6), child: FullscreenButton(size: 30))),
            ),
            // About: plain text in the bottom-left corner (home screen only).
            Positioned.fill(
              child: IgnorePointer(
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.about,
                            style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(s.aboutBody, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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

/// Three cards that fan out when the home screen opens (a single short
/// animation, not an endless one).
class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = <int>[
      Cards.twoOfClubs,
      Cards.make(Cards.hearts, Cards.jack),
      Cards.tenOfDiamonds,
    ];
    return SizedBox(
      width: 250,
      height: 160,
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, _) {
          final t = Curves.easeOutBack.transform(_float.value);
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Soft gold glow behind the cards.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[PastraColors.gold.withValues(alpha: 0.22), Colors.transparent],
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < cards.length; i++)
                Positioned(
                  left: 85 + (i - 1) * 56.0 * t,
                  top: i == 1 ? 6.0 : 6.0 + 12 * t,
                  width: 82,
                  height: 117,
                  child: Transform.rotate(
                    angle: (i - 1) * 0.27 * t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: PlayingCardView(card: cards[i], faceUp: true),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Slides in from the right and fades in once, a little after the ones
/// above it ([order]).
class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = 0.12 * order;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + 90 * order),
      builder: (context, t, child) {
        // Each button waits its turn, then moves in.
        final p = Curves.easeOutCubic.transform(((t - delay) / (1 - delay)).clamp(0.0, 1.0));
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(40 * (1 - p), 0), child: child),
        );
      },
      child: child,
    );
  }
}

/// Large, very faint card suits in the corners of the home screen.
class _SuitWatermark extends StatelessWidget {
  const _SuitWatermark();

  @override
  Widget build(BuildContext context) {
    final c = Colors.white.withValues(alpha: 0.035);
    Widget suit(String text, double size, double angle) => Transform.rotate(
          angle: angle,
          child: Text(text, style: TextStyle(fontSize: size, color: c, height: 1)),
        );
    return Stack(
      children: <Widget>[
        Positioned(left: -40, top: -50, child: suit('♠', 260, -0.3)),
        Positioned(right: -30, top: -40, child: suit('♥', 200, 0.25)),
        Positioned(right: 40, bottom: -70, child: suit('♦', 240, -0.15)),
        Positioned(left: 120, bottom: -90, child: suit('♣', 220, 0.2)),
      ],
    );
  }
}

/// The player's card on the home screen: initial, name, level and stats.
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.name, required this.xp, required this.onTap, this.stats});

  final String name;
  final int xp;
  final String? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          width: 360,
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withValues(alpha: 0.32),
            border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF2E7D5B), Color(0xFF0A4A30)],
                  ),
                ),
                child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    LevelBadge(xp: xp, width: 250),
                    if (stats != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(stats!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big home-screen button. The main one is gold with a soft glow; on a
/// computer the buttons lift a little under the mouse.
class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool autofocus;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final fg = primary ? Colors.black : Colors.white;
    final radius = BorderRadius.circular(18);
    return AnimatedScale(
      scale: _hover ? 1.025 : 1,
      duration: const Duration(milliseconds: 140),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: primary ? 66 : 56,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: primary
              ? const LinearGradient(colors: <Color>[Color(0xFFFFD873), Color(0xFFF2C14E), Color(0xFFD09A2C)])
              : LinearGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: _hover ? 0.14 : 0.09),
                    Colors.white.withValues(alpha: _hover ? 0.07 : 0.03),
                  ],
                ),
          border: Border.all(
            color: primary ? const Color(0xFFFFE9A8) : Colors.white.withValues(alpha: _hover ? 0.35 : 0.16),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            if (primary)
              BoxShadow(color: PastraColors.gold.withValues(alpha: _hover ? 0.55 : 0.35), blurRadius: _hover ? 26 : 18),
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            autofocus: widget.autofocus,
            onTap: widget.onTap,
            onHover: (v) => setState(() => _hover = v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Icon(widget.icon, color: fg, size: primary ? 34 : 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: primary ? 24 : 19,
                          fontWeight: primary ? FontWeight.w900 : FontWeight.w700,
                          color: fg,
                          letterSpacing: primary ? 0.6 : 0.2,
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: 0.7), size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
