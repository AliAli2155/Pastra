import 'dart:convert';

import 'package:flutter/material.dart';

import '../../engine/game_state.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../game/tournament.dart';
import '../../l10n/strings.dart';
import '../../online/leaderboard.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../premium/premium.dart';
import '../widgets/avatar.dart';
import 'game_screen.dart';

/// The offline tournament: the bracket, and a button for the next match.
class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  Tournament? _t;

  Tournament get t => _t!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t != null) return;
    final settings = SettingsScope.read(context);
    final raw = settings.tournamentJson;
    Tournament? loaded;
    if (raw != null) {
      try {
        loaded = Tournament.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        loaded = null;
      }
    }
    _t = loaded ?? Tournament.create();
    if (loaded == null) _save();
  }

  void _save() => SettingsScope.read(context).saveTournament(jsonEncode(t.toJson()));

  void _startNew() {
    setState(() => _t = Tournament.create());
    _save();
  }

  Future<void> _playMatch() async {
    final settings = SettingsScope.read(context);
    final controller = GameController.tournamentMatch(
      settings,
      level: t.opponentLevel,
      botIndex: t.bots[t.opponentSlot],
    );
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller)));
    if (!mounted) return;
    // Left the game early: nothing changes, the match is played again later.
    if (controller.state.phase != GamePhase.gameOver) return;
    setState(() {
      t.reportHumanMatch(controller.state.winner == 0);
      if (t.finished && !t.bonusPaid) {
        t.bonusPaid = true;
        settings.addXp(t.bonusXp);
        Leaderboard.submit(settings, fallbackName: Strings.of(context).you);
      }
    });
    _save();
  }

  String _name(Strings s, int slot) {
    if (t.bots[slot] >= 0) return s.botName(t.bots[slot]);
    final own = SettingsScope.read(context).playerName;
    return own.isEmpty ? s.you : own;
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final bracket = FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 560,
        height: 330,
        child: Row(
          children: <Widget>[
            for (var r = 0; r < Tournament.rounds; r++) ...<Widget>[
              if (r > 0) const SizedBox(width: 12),
              Expanded(child: _roundColumn(s, r)),
            ],
          ],
        ),
      ),
    );
    final panel = _statusPanel(s);
    final board = SectionPanel(
      title: s.tournament,
      icon: Icons.account_tree_rounded,
      accent: PastraColors.teal,
      child: bracket,
    );
    return Scaffold(
      appBar: GameAppBar(icon: Icons.emoji_events_rounded, title: Text(s.tournament)),
      body: Felt(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              // Wide: the next match as a big card on the left, the bracket
              // on the right. Upright: the card on top.
              final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 640;
              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: box.maxWidth >= 1000 ? 360 : 300, child: panel),
                      const SizedBox(width: 16),
                      Expanded(child: Center(child: SingleChildScrollView(child: board))),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[panel, const SizedBox(height: 12), board],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _roundColumn(Strings s, int r) {
    final matches = Tournament.size ~/ (2 << r);
    return Column(
      children: <Widget>[
        Text(
          s.tournamentRound(r),
          style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              for (var p = 0; p < matches; p++) _matchCard(s, r, p),
            ],
          ),
        ),
      ],
    );
  }

  Widget _matchCard(Strings s, int r, int p) {
    final has = t.bracket.length > r;
    final slots = <int?>[has ? t.bracket[r][2 * p] : null, has ? t.bracket[r][2 * p + 1] : null];
    final winners = t.bracket.length > r + 1 ? t.bracket[r + 1] : const <int>[];
    final current = !t.finished && r == t.round && slots.contains(t.humanSlot);

    Widget line(int? slot) {
      final isMe = slot == t.humanSlot;
      final won = slot != null && winners.contains(slot);
      final lost = slot != null && winners.isNotEmpty && !won;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                slot == null ? '?' : _name(s, slot),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isMe || won ? FontWeight.w800 : FontWeight.w500,
                  color: slot == null
                      ? PastraColors.muted
                      : lost
                          ? PastraColors.muted
                          : (isMe ? PastraColors.goldLight : PastraColors.text),
                  decoration: lost ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (won) const Icon(Icons.check_circle, size: 14, color: PastraColors.gold),
          ],
        ),
      );
    }

    return Container(
      decoration: glassDecoration(radius: 10, selected: current),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[line(slots[0]), const Divider(height: 1, color: Colors.white12), line(slots[1])],
      ),
    );
  }

  /// The next match (me against the opponent) with the gold button, or
  /// the result once the tournament is over: an emerald card.
  Widget _statusPanel(Strings s) {
    final List<Widget> children;
    if (t.finished) {
      children = <Widget>[
        const Spacer(),
        Icon(t.won ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded, color: PastraColors.gold, size: 64),
        const SizedBox(height: 10),
        Text(
          t.won ? s.championMsg : s.eliminatedMsg(s.tournamentRound(t.lostRound)),
          textAlign: TextAlign.center,
          style: PremiumText.title.copyWith(fontSize: 22),
        ),
        if (t.bonusXp > 0) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            s.tournamentBonus(t.bonusXp),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PastraColors.goldLight, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
        const Spacer(),
        GoldButton(icon: Icons.refresh_rounded, label: s.newTournament, onPressed: _startNew),
      ];
    } else {
      Widget player(int slot, {required bool me}) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PlayerAvatar(name: _name(s, slot), size: 58),
              const SizedBox(height: 8),
              Text(
                _name(s, slot),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: me ? PastraColors.goldLight : PastraColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
      children = <Widget>[
        Text(s.tournamentRound(t.round), textAlign: TextAlign.center, style: PremiumText.eyebrow),
        const Spacer(),
        Row(
          children: <Widget>[
            Expanded(child: player(t.humanSlot, me: true)),
            const Text(
              'VS',
              style: TextStyle(color: PastraColors.gold, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            Expanded(child: player(t.opponentSlot, me: false)),
          ],
        ),
        const SizedBox(height: 10),
        Text(s.level(t.opponentLevel), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFBFE3D6), fontSize: 13)),
        const Spacer(),
        GoldButton(icon: Icons.play_arrow_rounded, label: s.playMatch, onPressed: _playMatch),
      ];
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F6A51), Color(0xFF0A4637), Color(0xFF072C23)],
          stops: <double>[0.0, 0.6, 1.0],
        ),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
      ),
      child: LayoutBuilder(
        // Spacers only when the card has a fixed height (beside the bracket).
        builder: (context, box) => box.hasBoundedHeight
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final c in children) c is Spacer ? const SizedBox(height: 16) : c,
                ],
              ),
      ),
    );
  }
}
