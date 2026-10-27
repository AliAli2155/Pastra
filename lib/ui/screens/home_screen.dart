import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/pastra_ai.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/playing_card.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

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

  void _continue() {
    final settings = SettingsScope.read(context);
    final controller = GameController.fromSaved(settings);
    if (controller == null) {
      settings.clearSavedGame();
      setState(() {});
      return;
    }
    _open(GameScreen(controller: controller));
  }

  Future<void> _newGame() async {
    final current = SettingsScope.read(context);
    final choice = await showModalBottomSheet<NewGameChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PastraColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NewGameSheet(initialPlayers: current.players, initialLevel: current.level),
    );
    if (choice == null || !mounted) return;
    final settings = SettingsScope.read(context);
    settings.players = choice.players;
    settings.level = choice.level;
    await settings.clearSavedGame();
    if (!mounted) return;
    final controller = GameController.newGame(settings, players: choice.players, level: choice.level);
    await _open(GameScreen(controller: controller));
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
        if (settings.hasSavedGame) ...<Widget>[
          _MenuButton(
            icon: Icons.play_arrow_rounded,
            label: s.continueGame,
            primary: true,
            onTap: _continue,
          ),
          const SizedBox(height: 10),
        ],
        _MenuButton(
          icon: Icons.add_rounded,
          label: s.newGame,
          primary: !settings.hasSavedGame,
          onTap: _newGame,
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
        const SizedBox(height: 10),
        _MenuButton(icon: Icons.public, label: s.onlineSoon, onTap: null),
      ],
    );
    return Scaffold(
      body: Container(
        decoration: feltDecoration,
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
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
