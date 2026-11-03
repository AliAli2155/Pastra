import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/pastra_ai.dart';
import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/game_controller.dart';
import '../../online/invite_link.dart';
import '../../online/leaderboard.dart';
import '../../online/social_service.dart';
import '../../game/progression.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/shop_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../ege/widgets.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/fullscreen_button.dart';
import '../widgets/level_badge.dart';
import '../widgets/menu_tiles.dart';
import '../widgets/playing_card.dart';
import '../widgets/rules_editor.dart';
import '../widgets/wallet_bar.dart';
import 'game_screen.dart';
import 'friends_screen.dart';
import 'level_path_screen.dart';
import 'online_screen.dart';
import 'play_screen.dart';
import 'progress_views.dart';
import 'quests_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'store_screen.dart';
import 'tournament_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final settings = SettingsScope.read(context);
      // Days in a row (achievements).
      final fresh = settings.touchDay();
      if (fresh.isNotEmpty) {
        final s = Strings.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.achUnlocked}: ${fresh.map(s.achTitle).join(', ')}')),
        );
      }
      // Players with friends: their code and "online" for their friends.
      if (settings.friends.isNotEmpty || settings.playerTag != null) {
        SocialService.instance.start(settings);
      }
      // Opened with an invite link: straight to that table.
      final invite = InviteLink.takePending();
      if (invite != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => OnlineScreen(joinCode: invite)),
        );
        return;
      }
      // The daily bonus greets the player once a day.
      if (Economy.enabled) await showDailyBonusIfReady(context);
      // A season that ended: the final place and the badge.
      final badge = await Leaderboard.finishPendingSeason(settings);
      if (badge != null && mounted) await showSeasonResult(context, badge);
    });
  }

  void _openStore() => _open(const StoreScreen());

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
    final choice = await showDialog<String>(
      context: ctx,
      builder: (sheet) {
        final s = Strings.of(sheet);
        final social = SocialStrings(SettingsScope.of(sheet).language);
        final training = TextButton.icon(
          onPressed: () => Navigator.of(sheet).pop('training'),
          icon: const Icon(Icons.school_rounded, color: PastraColors.gold),
          label: Text(
            '${social.training} · ${social.trainingHint}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        );
        Widget quick(double? h) => SizedBox(
              height: h,
              child: MenuTile(
                icon: Icons.bolt_rounded,
                title: s.quickGame,
                subtitle: s.quickGameHint,
                colors: TileColors.green,
                onTap: () => Navigator.of(sheet).pop('quick'),
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
                onTap: () => Navigator.of(sheet).pop('cup'),
              ),
            );
        return _CenteredDialog(
          maxWidth: 640,
          child: LayoutBuilder(
            builder: (context, box) {
              final screen = MediaQuery.sizeOf(context);
              // Side by side when there is room, else one under the other.
              final side = box.maxWidth >= 480;
              final h = side ? min(200.0, screen.height * 0.5) : 96.0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (side)
                      Row(
                        children: <Widget>[
                          Expanded(child: quick(h)),
                          const SizedBox(width: 14),
                          Expanded(child: cup(h)),
                        ],
                      )
                    else ...<Widget>[quick(h), const SizedBox(height: 12), cup(h)],
                    const SizedBox(height: 6),
                    training,
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (choice == null || !ctx.mounted) return;
    if (choice == 'cup') {
      await Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const TournamentScreen()));
    } else if (choice == 'training') {
      await _training(ctx);
    } else {
      await _newGame(ctx);
    }
  }

  /// Training: an easy computer, the guided tour again and hints.
  Future<void> _training(BuildContext ctx) async {
    final settings = SettingsScope.read(ctx);
    await settings.clearSavedGame();
    if (!ctx.mounted) return;
    final controller = GameController.newGame(settings, players: 2, level: AiLevel.easy);
    await Navigator.of(ctx).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller, training: true)),
    );
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

  /// "Play": a brand-new player first gets the guided first game (and is
  /// asked their name after it); everybody else picks how to play.
  void _openPlay() {
    final settings = SettingsScope.read(context);
    if (!settings.tutorialDone && !settings.hasSavedGame) {
      final controller = GameController.newGame(settings, players: 2, level: AiLevel.easy);
      _open(GameScreen(controller: controller));
      return;
    }
    _openPlayScreen();
  }

  void _openPlayScreen() => _open(
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

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PlayerCard(
          name: settings.playerTag != null ? settings.handleName : name,
          tag: settings.playerTag,
          xp: settings.xp,
          frame: settings.avatarFrame,
          title: ProgressStrings(settings.language).title(settings.title),
          stats: settings.gamesPlayed > 0 ? s.stats(settings.gamesWon, settings.gamesPlayed) : null,
          onTap: () => _open(const LevelPathScreen()),
        ),
        const SizedBox(height: 10),
        _QuestsBar(onTap: () => _open(const QuestsScreen())),
      ],
    );

    final entries = <_MenuEntry>[
      if (Economy.enabled)
        _MenuEntry(Icons.storefront_rounded, ShopStrings(settings.language).store, _openStore),
      _MenuEntry(Icons.menu_book_rounded, s.rules, () => _open(const RulesScreen())),
      _MenuEntry(Icons.insights_rounded, s.statistics, () => _open(const StatsScreen())),
      _MenuEntry(Icons.tune_rounded, s.settings, () => _open(const SettingsScreen())),
    ];

    return Scaffold(
      body: Felt(
        ambient: true,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // A big window: everything is drawn a little larger.
                    final zoom = min(box.maxWidth / 1000, box.maxHeight / 600).clamp(1.0, 1.35).toDouble();
                    final w = box.maxWidth / zoom;
                    final h = box.maxHeight / zoom;
                    final wide = w > h;
                    // A phone held sideways is low.
                    final compact = h < 460;
                    final hero = _Hero(compact: compact, details: details);
                    final menu = _Menu(compact: compact, onPlay: _openPlay, entries: entries);
                    final Widget layout;
                    if (!wide) {
                      layout = Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(24, Economy.enabled ? 60 : 24, 24, 80),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[hero, const SizedBox(height: 28), menu],
                            ),
                          ),
                        ),
                      );
                    } else {
                      // Landscape (phones held sideways, tablets, computers):
                      // the stage and the title on the left, the menu on the
                      // right.
                      layout = Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 11,
                                // Bounded (no scrolling) so the hero shrinks to fit.
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                    }
                    if (zoom == 1.0) return layout;
                    return Transform.scale(
                      scale: zoom,
                      child: SizedBox(width: w, height: h, child: layout),
                    );
                  },
                ),
              ),
            ),
            // Chips and diamonds in the top-left corner (opens the store).
            if (Economy.enabled)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(padding: const EdgeInsets.all(8), child: WalletBar(onTap: _openStore)),
                ),
              ),
            // Top right: friends and (web) full screen.
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _CornerButton(
                        icon: Icons.people_alt_rounded,
                        tooltip: SocialStrings(settings.language).friends,
                        onTap: () => _open(const FriendsScreen()),
                      ),
                      const SizedBox(width: 6),
                      const FullscreenButton(size: 30),
                    ],
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

/// One of the smaller buttons of the menu.
class _MenuEntry {
  const _MenuEntry(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The left half of the home screen: the stage with the cards on the table,
/// the title and the player.
class _Hero extends StatelessWidget {
  const _Hero({required this.compact, required this.details});

  final bool compact;
  final Widget details;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _HeroStage(width: compact ? 270 : 340, height: compact ? 128 : 170),
        SizedBox(height: compact ? 2 : 6),
        GoldText(s.appTitle, size: compact ? 44 : 60, letterSpacing: 3, depth: compact ? 3 : 4),
        const SizedBox(height: 6),
        const SizedBox(width: 190, child: MeanderBand(height: 10)),
        if (!compact) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            s.appSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.white70, letterSpacing: 0.4),
          ),
        ],
        SizedBox(height: compact ? 10 : 16),
        details,
      ],
    );
  }
}

/// Three cards floating above a table seen from a low angle. They turn
/// towards the mouse (or a finger) and rock gently by themselves.
class _HeroStage extends StatelessWidget {
  const _HeroStage({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cardWidth = height * 0.5;
    final cardHeight = cardWidth * 1.42;
    final cards = <int>[
      Cards.twoOfClubs,
      Cards.make(Cards.hearts, Cards.jack),
      Cards.tenOfDiamonds,
    ];
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * 0.52,
            child: CustomPaint(painter: _TablePainter(Look.table)),
          ),
          Positioned.fill(
            // It turns towards the pointer, but does not rock by itself: a
            // card fan turning in 3D all the time makes slow devices stutter.
            child: Tilt3D(
              maxAngle: 0.3,
              child: _CardFan(width: width, cardWidth: cardWidth, cardHeight: cardHeight, cards: cards),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cards fan out once when the home screen opens.
class _CardFan extends StatelessWidget {
  const _CardFan({required this.width, required this.cardWidth, required this.cardHeight, required this.cards});

  final double width;
  final double cardWidth;
  final double cardHeight;
  final List<int> cards;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutBack,
      builder: (context, t, _) {
        // The middle card is drawn last, on top.
        const order = <int>[0, 2, 1];
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // A soft gold glow behind the cards.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.6,
                    colors: <Color>[PastraColors.gold.withValues(alpha: 0.2), Colors.transparent],
                  ),
                ),
              ),
            ),
            for (final i in order)
              Positioned(
                left: width / 2 - cardWidth / 2 + (i - 1) * cardWidth * 0.68 * t,
                top: i == 1 ? 0.0 : cardHeight * 0.08 * t,
                width: cardWidth,
                height: cardHeight,
                child: Transform.rotate(
                  angle: (i - 1) * 0.3 * t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cardWidth * 0.09),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 10)),
                        if (i == 1) BoxShadow(color: PastraColors.gold.withValues(alpha: 0.35), blurRadius: 22),
                      ],
                    ),
                    child: PlayingCardView(card: cards[i], faceUp: true),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An oval table in the colour the player chose: a gold rim, the cloth and
/// the shadows of the cards.
class _TablePainter extends CustomPainter {
  const _TablePainter(this.table);

  final TableTheme table;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final oval = Rect.fromLTWH(w * 0.04, h * 0.06, w * 0.92, h * 0.86);
    // The shadow on the floor.
    canvas.drawOval(
      oval.shift(Offset(0, h * 0.12)).inflate(4),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    // The rim.
    canvas.drawOval(
      oval,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFE6A0), Color(0xFFB9821E), Color(0xFF5A3A08)],
        ).createShader(oval),
    );
    // The cloth.
    final cloth = oval.deflate(h * 0.07);
    canvas.drawOval(
      cloth,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 0.95,
          colors: <Color>[table.light, table.mid, table.dark],
          stops: const <double>[0.0, 0.6, 1.0],
        ).createShader(cloth),
    );
    canvas.drawOval(
      cloth.deflate(h * 0.045),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = PastraColors.gold.withValues(alpha: 0.45),
    );
    // The shadows of the three cards.
    final shade = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * (0.5 + (i - 1) * 0.17), h * 0.5), width: w * 0.17, height: h * 0.1),
        shade,
      );
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) => old.table != table;
}

/// The play button and the other buttons of the home screen. They are dealt
/// in one after the other.
class _Menu extends StatelessWidget {
  const _Menu({required this.compact, required this.onPlay, required this.entries});

  final bool compact;
  final VoidCallback onPlay;
  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final gap = compact ? 8.0 : 12.0;
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      final a = entries[i];
      final b = i + 1 < entries.length ? entries[i + 1] : null;
      rows.add(SizedBox(height: gap));
      rows.add(
        Row(
          children: <Widget>[
            Expanded(child: DealIn(order: 1 + i, child: _MenuTablet(entry: a, compact: compact))),
            if (b != null) ...<Widget>[
              SizedBox(width: gap),
              Expanded(child: DealIn(order: 2 + i, child: _MenuTablet(entry: b, compact: compact))),
            ],
          ],
        ),
      );
    }
    return FocusTraversalGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DealIn(order: 0, child: _PlayButton(compact: compact, label: s.play, onTap: onPlay)),
          ...rows,
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.compact, required this.label, required this.onTap});

  final bool compact;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BevelButton(
      height: compact ? 62 : 78,
      radius: 22,
      shimmer: true,
      autofocus: true,
      fontSize: compact ? 24 : 30,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.play_arrow_rounded, size: compact ? 36 : 46),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: const TextStyle(letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTablet extends StatelessWidget {
  const _MenuTablet({required this.entry, required this.compact});

  final _MenuEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(entry.label, maxLines: 1),
    );
    return BevelButton(
      gold: false,
      height: compact ? 54 : 88,
      radius: 18,
      fontSize: 17,
      onPressed: entry.onTap,
      child: compact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(entry.icon, size: 24, color: PastraColors.gold),
                const SizedBox(width: 8),
                Flexible(child: label),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(entry.icon, size: 32, color: PastraColors.gold),
                const SizedBox(height: 4),
                label,
              ],
            ),
    );
  }
}

/// The player's plaque on the home screen: initial, name, level and stats.
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.name,
    required this.xp,
    required this.onTap,
    required this.frame,
    required this.title,
    this.stats,
    this.tag,
  });

  /// The player code after the name ("#1270"), once given.
  final String? tag;

  final String name;
  final int xp;
  final AvatarFrame frame;
  final String title;
  final String? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      scale: 1.015,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: 360,
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: tabletDecoration(radius: 18),
            child: Row(
              children: <Widget>[
                PlayerAvatar(name: name, frame: frame, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(text: name),
                                  if (tag != null)
                                    TextSpan(text: ' #$tag', style: const TextStyle(color: PastraColors.gold, fontSize: 13)),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PastraColors.gold.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              title,
                              style: const TextStyle(color: PastraColors.gold, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LevelBadge(xp: xp, width: 232),
                      if (stats != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(stats!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
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
            // The rules of the game (target, cards per deal, …): changed here,
            // not in the general settings.
            const RulesButton(),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.4)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Today's quests under the player card: progress and a dot when something
/// can be collected.
class _QuestsBar extends StatelessWidget {
  const _QuestsBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final quests = settings.quests;
    final ready = settings.questsReady;
    final done = quests.where((q) => q.claimed).length;
    return HoverLift(
      scale: 1.015,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: 360,
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: tabletDecoration(radius: 16, glow: ready > 0),
            child: Row(
              children: <Widget>[
                Badge(
                  isLabelVisible: ready > 0,
                  label: Text('$ready'),
                  child: const Icon(Icons.task_alt_rounded, color: PastraColors.gold, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(p.quests, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          for (final q in quests)
                            Expanded(
                              child: Container(
                                height: 6,
                                margin: const EdgeInsetsDirectional.only(end: 4),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Colors.white12),
                                child: FractionallySizedBox(
                                  alignment: AlignmentDirectional.centerStart,
                                  widthFactor: (q.progress / q.def.goal).clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: q.done ? PastraColors.gold : Colors.white54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(p.questsCount(done), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small round button in a corner of the home screen.
class _CornerButton extends StatelessWidget {
  const _CornerButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PastraColors.nightMid.withValues(alpha: 0.7),
        shape: CircleBorder(side: BorderSide(color: PastraColors.gold.withValues(alpha: 0.5))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(9), child: Icon(icon, color: PastraColors.goldLight, size: 22)),
        ),
      ),
    );
  }
}
