import 'dart:convert';

import 'package:flutter/material.dart';

import '../../engine/game_state.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../game/tournament.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(s.tournament)),
      body: Container(
        decoration: feltDecoration,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight && box.maxWidth >= 640;
              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Center(child: bracket)),
                      const SizedBox(width: 16),
                      SizedBox(width: 280, child: Center(child: SingleChildScrollView(child: panel))),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    Expanded(child: Center(child: bracket)),
                    const SizedBox(height: 12),
                    panel,
                  ],
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
          style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w800),
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
                      ? Colors.white38
                      : lost
                          ? Colors.white38
                          : (isMe ? PastraColors.gold : Colors.white),
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
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? PastraColors.gold : Colors.white12, width: current ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[line(slots[0]), const Divider(height: 1, color: Colors.white12), line(slots[1])],
      ),
    );
  }

  Widget _statusPanel(Strings s) {
    final children = <Widget>[];
    if (t.finished) {
      children.add(Icon(t.won ? Icons.emoji_events : Icons.sentiment_neutral, color: PastraColors.gold, size: 38));
      children.add(const SizedBox(height: 4));
      children.add(Text(
        t.won ? s.championMsg : s.eliminatedMsg(s.tournamentRound(t.lostRound)),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
      ));
      if (t.bonusXp > 0) {
        children.add(const SizedBox(height: 4));
        children.add(Text(
          s.tournamentBonus(t.bonusXp),
          style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w700),
        ));
      }
      children.add(const SizedBox(height: 12));
      children.add(SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _startNew, child: Text(s.newTournament)),
      ));
    } else {
      children.add(Text(
        s.tournamentRound(t.round),
        style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w700),
      ));
      children.add(const SizedBox(height: 2));
      children.add(Text(
        '${_name(s, t.humanSlot)}  ${s.vsName(_name(s, t.opponentSlot))}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
      ));
      children.add(const SizedBox(height: 2));
      children.add(Text(
        s.level(t.opponentLevel),
        style: const TextStyle(color: Colors.white60, fontSize: 13),
      ));
      children.add(const SizedBox(height: 12));
      children.add(SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _playMatch, child: Text(s.playMatch)),
      ));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: PastraColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
