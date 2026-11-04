import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/pastra_ai.dart';
import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/game_controller.dart';
import '../../game/progression.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/shop_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../../online/invite_link.dart';
import '../../online/leaderboard.dart';
import '../../online/social_service.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/fullscreen_button.dart';
import '../widgets/rules_editor.dart';
import '../widgets/suit_icon.dart';
import '../widgets/wallet_bar.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'level_path_screen.dart';
import 'online_screen.dart';
import 'progress_views.dart';
import 'quests_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'store_screen.dart';
import 'tournament_screen.dart';

/// The lobby: one screen with everything. The player and the wallet at the
/// top, the big "Play" card on the left and the other ways to play and the
/// small tiles on the right (one under the other on a phone held upright).
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

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  void _openStore() => _open(const StoreScreen());

  /// Continues the saved offline game.
  Future<void> _continue() async {
    final settings = SettingsScope.read(context);
    final controller = GameController.fromSaved(settings);
    if (controller == null) {
      await settings.clearSavedGame();
      if (mounted) setState(() {});
      return;
    }
    await _open(GameScreen(controller: controller));
  }

  /// Training: an easy computer, the guided tour again and hints.
  Future<void> _training() async {
    final settings = SettingsScope.read(context);
    await settings.clearSavedGame();
    if (!mounted) return;
    final controller = GameController.newGame(settings, players: 2, level: AiLevel.easy);
    await _open(GameScreen(controller: controller, training: true));
  }

  /// A quick game against the computer: players and level first.
  Future<void> _quickGame() async {
    final current = SettingsScope.read(context);
    final choice = await showDialog<NewGameChoice>(
      context: context,
      builder: (_) => PremiumDialog(
        child: NewGameSheet(initialPlayers: current.players, initialLevel: current.level),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.training) {
      await _training();
      return;
    }
    final settings = SettingsScope.read(context);
    settings.players = choice.players;
    settings.level = choice.level;
    await settings.clearSavedGame();
    if (!mounted) return;
    final controller = GameController.newGame(settings, players: choice.players, level: choice.level);
    await _open(GameScreen(controller: controller));
  }

  /// "Play": a brand-new player first gets the guided first game (and is
  /// asked their name after it); everybody else picks players and level.
  void _play() {
    final settings = SettingsScope.read(context);
    if (!settings.tutorialDone && !settings.hasSavedGame) {
      final controller = GameController.newGame(settings, players: 2, level: AiLevel.easy);
      _open(GameScreen(controller: controller));
      return;
    }
    _quickGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Felt(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // A big window: everything is drawn a little larger.
              final zoom = min(box.maxWidth / 1000, box.maxHeight / 600).clamp(1.0, 1.35).toDouble();
              final w = box.maxWidth / zoom;
              final h = box.maxHeight / zoom;
              final layout = _layout(context, w, h);
              if (zoom == 1.0) return layout;
              return Center(
                child: Transform.scale(scale: zoom, child: SizedBox(width: w, height: h, child: layout)),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, double w, double h) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    // A phone held sideways is low.
    final compact = h < 460;
    final wide = w > h && w >= 640;
    final saved = settings.hasSavedGame;

    final hero = _HeroCard(
      compact: compact,
      onPlay: _play,
      onContinue: saved ? _continue : null,
    );
    final tiles = <_Tile>[
      if (Economy.enabled) _Tile(Icons.storefront_rounded, ShopStrings(settings.language).store, _openStore),
      _Tile(Icons.people_alt_rounded, SocialStrings(settings.language).friends, () => _open(const FriendsScreen())),
      _Tile(Icons.insights_rounded, s.statistics, () => _open(const StatsScreen())),
      _Tile(Icons.menu_book_rounded, s.rules, () => _open(const RulesScreen())),
      _Tile(Icons.tune_rounded, s.settings, () => _open(const SettingsScreen())),
    ];
    final menu = _SideMenu(
      compact: compact,
      tiles: tiles,
      onOnline: () => _open(const OnlineScreen()),
      onTournament: () => _open(const TournamentScreen()),
      onQuests: () => _open(const QuestsScreen()),
    );
    final top = _TopBar(
      compact: compact,
      stacked: w < 560,
      onProfile: () => _open(const LevelPathScreen()),
      onStore: _openStore,
    );

    if (wide) {
      final pad = compact ? 14.0 : 24.0;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, compact ? 8 : 16, pad, compact ? 10 : 22),
            child: Column(
              children: <Widget>[
                top,
                SizedBox(height: compact ? 10 : 22),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: hero),
                      SizedBox(width: compact ? 12 : 22),
                      // The menu fills the hero's height (both columns end on
                      // the same line); a very low window scrolls instead.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) => box.maxHeight >= (compact ? 250 : 320)
                              ? _SideMenu(
                                  compact: compact,
                                  fill: true,
                                  tiles: tiles,
                                  onOnline: () => _open(const OnlineScreen()),
                                  onTournament: () => _open(const TournamentScreen()),
                                  onQuests: () => _open(const QuestsScreen()),
                                )
                              : SingleChildScrollView(child: menu),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Upright: everything in one column that scrolls.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              top,
              const SizedBox(height: 16),
              SizedBox(height: min(320.0, max(260.0, h * 0.4)), child: hero),
              const SizedBox(height: 14),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}

/// A small tile of the lobby.
class _Tile {
  const _Tile(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The player (opens the level path) and the wallet (opens the store).
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.compact,
    required this.stacked,
    required this.onProfile,
    required this.onStore,
  });

  final bool compact;

  /// Narrow screens: the wallet goes under the player.
  final bool stacked;
  final VoidCallback onProfile;
  final VoidCallback onStore;

  @override
  Widget build(BuildContext context) {
    final profile = _Profile(compact: compact, onTap: onProfile);
    final wallet = Economy.enabled ? WalletBar(onTap: onStore, compact: compact) : const SizedBox.shrink();
    const fullscreen = FullscreenButton(size: 28);
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: profile)),
              fullscreen,
            ],
          ),
          if (Economy.enabled) ...<Widget>[
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: wallet),
          ],
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: profile)),
        const SizedBox(width: 12),
        wallet,
        const SizedBox(width: 6),
        fullscreen,
      ],
    );
  }
}

/// The player's initial, name, level, title and the bar to the next level.
class _Profile extends StatelessWidget {
  const _Profile({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final plain = settings.playerName.isEmpty ? s.you : settings.playerName;
    final name = settings.playerTag != null ? settings.handleName : plain;
    final level = Progression.levelOf(settings.xp);
    final p = Progression.progress(settings.xp);
    final fraction = level >= Progression.maxLevel
        ? 1.0
        : (p.needed == 0 ? 0.0 : (p.into / p.needed).clamp(0.0, 1.0).toDouble());
    final title = ProgressStrings(settings.language).title(settings.title);
    return Pressable(
      onTap: onTap,
      radius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(2, 2, 14, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlayerAvatar(name: name, frame: settings.avatarFrame, size: compact ? 40 : 46),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: PastraColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.levelN(level),
                        style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: PastraColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(color: PastraColors.goldLight, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          width: compact ? 90 : 120,
                          height: 4,
                          child: LinearProgressIndicator(
                            value: fraction,
                            backgroundColor: const Color(0xFF2E333B),
                            valueColor: const AlwaysStoppedAnimation<Color>(PastraColors.gold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big card on the left: the name of the game over a drawing of the
/// card table, the gold "Play" button and "Continue" when a game is saved.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.compact, required this.onPlay, required this.onContinue});

  final bool compact;
  final VoidCallback onPlay;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final r = BorderRadius.circular(22);
    final buttonHeight = compact ? 50.0 : 56.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0E5A45), Color(0xFF083A2D)],
        ),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final pad = compact ? 20.0 : 30.0;
            final tableW = w * 0.74;
            final tableH = min(h * 0.7, tableW * 0.62);
            return Stack(
              children: <Widget>[
                Positioned(
                  right: -w * 0.14,
                  top: (h - tableH) * 0.42,
                  width: tableW,
                  height: tableH,
                  child: const RepaintBoundary(child: _TableArt()),
                ),
                Positioned(
                  left: pad,
                  top: pad,
                  right: w * 0.32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.appSubtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: PremiumText.eyebrow),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          s.appTitle,
                          maxLines: 1,
                          style: PremiumText.display.copyWith(fontSize: compact ? 46 : 62),
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: pad,
                  bottom: pad,
                  end: pad,
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: GoldButton(
                          label: s.play,
                          icon: Icons.play_arrow_rounded,
                          onPressed: onPlay,
                          height: buttonHeight,
                          fontSize: compact ? 18 : 20,
                        ),
                      ),
                      if (onContinue != null) ...<Widget>[
                        const SizedBox(width: 10),
                        Flexible(
                          child: GlassButton(
                            label: s.continueGame,
                            icon: Icons.history_rounded,
                            onPressed: onContinue,
                            height: buttonHeight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The drawing on the hero card: an oval table with a wooden rim and two
/// cards on it. Still (nothing moves).
class _TableArt extends StatelessWidget {
  const _TableArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final cardW = h * 0.3;
        final cardH = cardW * 1.43;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.1),
                    radius: 0.8,
                    colors: <Color>[Color(0xFF13946F), Color(0xFF0B6A50), Color(0xFF074634)],
                    stops: <double>[0.0, 0.6, 1.0],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 36, offset: const Offset(0, 26)),
                    // The gold edge, then the wooden rim over it.
                    const BoxShadow(color: PastraColors.gold, spreadRadius: 14),
                    const BoxShadow(color: Color(0xFF3A2A14), spreadRadius: 12),
                  ],
                ),
              ),
            ),
            Positioned(
              left: w * 0.5 - cardW * 1.2,
              top: h * 0.5 - cardH * 0.45,
              child: Transform.rotate(angle: -0.24, child: _MiniCard(width: cardW, height: cardH, faceUp: true)),
            ),
            Positioned(
              left: w * 0.5 - cardW * 0.1,
              top: h * 0.5 - cardH * 0.55,
              child: Transform.rotate(angle: 0.17, child: _MiniCard(width: cardW, height: cardH, faceUp: false)),
            ),
          ],
        );
      },
    );
  }
}

/// A card for the drawing: the ace of spades, or a back.
class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.width, required this.height, required this.faceUp});

  final double width;
  final double height;
  final bool faceUp;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(width * 0.1);
    final shadow = <BoxShadow>[
      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
    ];
    if (!faceUp) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PastraColors.cardBack,
          borderRadius: r,
          border: Border.all(color: PastraColors.gold, width: 2),
          boxShadow: shadow,
        ),
        child: Text(
          'Π',
          style: TextStyle(color: PastraColors.gold, fontSize: width * 0.42, fontWeight: FontWeight.w800, height: 1),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: PastraColors.cream, borderRadius: r, boxShadow: shadow),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: width * 0.1,
            top: width * 0.08,
            child: Column(
              children: <Widget>[
                Text(
                  'A',
                  style: TextStyle(
                    color: PastraColors.cardBlack,
                    fontSize: width * 0.3,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                SuitIcon(suit: Cards.spades, size: width * 0.18, color: PastraColors.cardBlack),
              ],
            ),
          ),
          Center(child: SuitIcon(suit: Cards.spades, size: width * 0.46, color: PastraColors.cardBlack)),
        ],
      ),
    );
  }
}

/// The right side of the lobby: online, tournament, daily quests and the
/// small tiles.
class _SideMenu extends StatelessWidget {
  const _SideMenu({
    required this.compact,
    required this.tiles,
    this.fill = false,
    required this.onOnline,
    required this.onTournament,
    required this.onQuests,
  });

  final bool compact;

  /// Fill the height it is given: the rows and the tiles share it equally.
  final bool fill;
  final List<_Tile> tiles;
  final VoidCallback onOnline;
  final VoidCallback onTournament;
  final VoidCallback onQuests;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final done = settings.quests.where((q) => q.claimed).length;
    final rowHeight = fill ? double.infinity : (compact ? 60.0 : 76.0);
    final gap = compact ? 8.0 : 12.0;
    final rows = <Widget>[
        ModeRow(
          icon: Icons.public_rounded,
          accent: PastraColors.teal,
          title: s.playOnline,
          subtitle: s.playOnlineHint,
          height: rowHeight,
          onTap: onOnline,
        ),
        ModeRow(
          icon: Icons.emoji_events_rounded,
          accent: PastraColors.gold,
          title: s.tournament,
          subtitle: s.tournamentHint,
          height: rowHeight,
          onTap: onTournament,
        ),
        ModeRow(
          icon: Icons.redeem_rounded,
          accent: PastraColors.coral,
          title: p.quests,
          subtitle: p.questsCount(done),
          badge: settings.questsReady,
          height: rowHeight,
          onTap: onQuests,
        ),
        Row(
          crossAxisAlignment: fill ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < tiles.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: LobbyTile(
                  icon: tiles[i].icon,
                  label: tiles[i].label,
                  onTap: tiles[i].onTap,
                  height: fill ? double.infinity : (compact ? 56 : 64),
                ),
              ),
            ],
          ],
        ),
    ];
    return Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          if (fill) Expanded(child: rows[i]) else rows[i],
        ],
      ],
    );
  }
}

/// What the player picked for a quick game (or training instead).
class NewGameChoice {
  const NewGameChoice(this.players, this.level, {this.training = false});

  final int players;
  final AiLevel level;
  final bool training;
}

/// The quick game set-up: game type, difficulty, the rules and "Start".
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
    final social = SocialStrings(SettingsScope.of(context).language);
    // A phone held sideways is low: less space between the rows.
    final compact = MediaQuery.sizeOf(context).height < 430;
    final gap = compact ? 10.0 : 16.0;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, compact ? 14 : 22, 24, compact ? 10 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(s.playOffline, maxLines: 1, overflow: TextOverflow.ellipsis, style: PremiumText.eyebrow),
                      const SizedBox(height: 2),
                      Text(
                        s.quickGame,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumText.title.copyWith(fontSize: compact ? 23 : 28),
                      ),
                    ],
                  ),
                ),
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: gap),
            Text(s.gameType, style: PremiumText.label),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: ChoicePill(
                    icon: Icons.person_rounded,
                    label: s.mode1v1,
                    hint: s.mode1v1Hint,
                    selected: _players == 2,
                    onTap: () => setState(() => _players = 2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoicePill(
                    icon: Icons.groups_rounded,
                    label: s.mode2v2,
                    hint: s.mode2v2Hint,
                    selected: _players == 4,
                    onTap: () => setState(() => _players = 4),
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            Text(s.difficulty, style: PremiumText.label),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (final l in AiLevel.values) ...<Widget>[
                  if (l != AiLevel.values.first) const SizedBox(width: 10),
                  Expanded(
                    child: ChoicePill(
                      label: s.level(l),
                      selected: _level == l,
                      onTap: () => setState(() => _level = l),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: gap),
            // The rules of the game (target, cards per deal, …): changed here,
            // not in the general settings.
            const RulesButton(),
            SizedBox(height: gap),
            GoldButton(
              label: s.start,
              icon: Icons.play_arrow_rounded,
              height: compact ? 50 : 56,
              onPressed: () => Navigator.of(context).pop(NewGameChoice(_players, _level)),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(const NewGameChoice(2, AiLevel.easy, training: true)),
                icon: const Icon(Icons.school_rounded, size: 18),
                label: Text(
                  '${social.training} · ${social.trainingHint}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
