import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/avatar_pic.dart';
import '../../game/game_controller.dart';
import '../../game/match_history.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'game_screen.dart';

/// The last 20 games: won or lost, the score, who was at the table, when,
/// and a rematch against the same bots.
class MatchHistoryView extends StatelessWidget {
  const MatchHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = Strings.of(context);
    final history = settings.history;
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const IconSquare(icon: Icons.history_rounded, color: PastraColors.teal, size: 64),
              const SizedBox(height: 16),
              Text(s.noHistory, textAlign: TextAlign.center, style: PremiumText.body.copyWith(color: PastraColors.text2)),
            ],
          ),
        ),
      );
    }
    final wins = history.where((r) => r.won).length;
    return TabBody(
      maxWidth: 720,
      children: <Widget>[
        // The form of the last games: one dot per game, newest on the left.
        Row(
          children: <Widget>[
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: <Widget>[
                  for (final r in history)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: r.won ? PastraColors.teal : PastraColors.coral.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${s.statWins}: $wins / ${history.length}', style: PremiumText.label),
          ],
        ),
        for (final r in history) MatchRow(record: r),
      ],
    );
  }
}

/// One game of the history.
class MatchRow extends StatelessWidget {
  const MatchRow({super.key, required this.record});

  final MatchRecord record;

  Future<void> _rematch(BuildContext context) async {
    final settings = SettingsScope.read(context);
    final controller = GameController.rematch(settings, record);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = Strings.of(context);
    final social = SocialStrings(settings.language);
    final online = OnlineStrings(settings.language);
    final r = record;
    final accent = r.won ? PastraColors.teal : PastraColors.coral;
    final t = DateTime.fromMillisecondsSinceEpoch(r.time);
    final clock = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final mode = switch (r.mode) {
      MatchMode.online => s.playOnline,
      MatchMode.tournament => s.tournament,
      MatchMode.offline => s.level(r.level),
    };
    String nameOf(MatchPlayer p) => p.isBot ? s.botName(p.botIndex) : (p.name.isEmpty ? online.defaultName : p.name);
    Widget avatarOf(MatchPlayer p, double size) => PlayerAvatar(
          name: nameOf(p),
          size: size,
          pic: p.isBot ? botPic(p.botIndex) : AvatarPic.byName(p.pic),
          frame: p.isBot ? botFrame(p.level) : avatarFrameByName(p.frame),
        );
    final opponents = r.opponents;
    final partner = r.partner;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      // Won: a teal tint from the left, lost: coral.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: <Color>[accent.withValues(alpha: 0.16), PastraColors.glass],
          stops: const <double>[0, 0.45],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          // The opponents' avatars, overlapping in 2v2.
          SizedBox(
            width: opponents.length > 1 ? 58 : 40,
            height: 40,
            child: Stack(
              children: <Widget>[
                for (var i = 0; i < opponents.length; i++)
                  Positioned(left: i * 18.0, top: 0, child: avatarOf(opponents[i], 40)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  opponents.map(nameOf).join(' & '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PastraColors.text, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    if (partner != null) ...<Widget>[
                      const Icon(Icons.handshake_outlined, size: 13, color: PastraColors.teal),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          nameOf(partner),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PremiumText.secondary.copyWith(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        '$mode · ${social.when(t, DateTime.now())} $clock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumText.secondary.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // The final score, ours first.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${r.ours} – ${r.theirs}',
                style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              if (r.pastras > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.auto_awesome, size: 11, color: PastraColors.goldLight),
                    const SizedBox(width: 3),
                    Text(
                      '${r.pastras}',
                      style: PremiumText.secondary.copyWith(fontSize: 11, color: PastraColors.goldLight),
                    ),
                  ],
                ),
            ],
          ),
          if (r.canRematch) ...<Widget>[
            const SizedBox(width: 6),
            GlassIconButton(
              icon: Icons.replay_rounded,
              tooltip: s.rematch,
              onPressed: () => _rematch(context),
            ),
          ],
        ],
      ),
    );
  }
}
