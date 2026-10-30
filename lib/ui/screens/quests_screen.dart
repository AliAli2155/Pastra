import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/quests.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/wallet_bar.dart';

/// Today's three quests: progress, collect, swap one, the bonus for all.
class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The countdown, and new quests at midnight while the screen is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  /// A toast for the XP and for achievements unlocked by collecting.
  void _afterClaim(int xp, int levelBefore) {
    final settings = SettingsScope.read(context);
    final s = Strings.of(context);
    final parts = <String>['+$xp XP'];
    if (settings.playerLevel > levelBefore) parts.add(s.levelN(settings.playerLevel));
    for (final id in settings.unlockEarned()) {
      parts.add('${s.achUnlocked}: ${s.achTitle(id)}');
    }
    _toast(parts.join(' · '));
  }

  void _claim(QuestState q) {
    final settings = SettingsScope.read(context);
    final before = settings.playerLevel;
    final xp = settings.claimQuest(q.def.id);
    if (xp != null) _afterClaim(xp, before);
  }

  void _claimBonus() {
    final settings = SettingsScope.read(context);
    final before = settings.playerLevel;
    if (settings.claimQuestBonus()) _afterClaim(Quests.allBonusXp, before);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final quests = settings.quests;
    final doneCount = quests.where((q) => q.claimed).length;
    return Scaffold(
      appBar: AppBar(title: Text(p.quests)),
      body: Felt(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.schedule, color: PastraColors.gold, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.questsNew(p.duration(Quests.untilTomorrow(DateTime.now()))),
                            style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        Text(p.questsCount(doneCount), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(p.questsHint, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        for (final q in quests)
                          _QuestCard(
                            quest: q,
                            p: p,
                            canReroll: settings.canRerollQuest && q.progress == 0 && !q.done,
                            onClaim: () => _claim(q),
                            onReroll: () => settings.rerollQuest(q.def.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _BonusCard(
                      p: p,
                      ready: settings.questBonusReady,
                      claimed: settings.questBonusClaimed,
                      onClaim: _claimBonus,
                    ),
                    if (settings.canRerollQuest) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(p.rerollHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _tierColor(QuestTier t) => switch (t) {
      QuestTier.easy => const Color(0xFF5BD69A),
      QuestTier.medium => const Color(0xFF4CA8FF),
      QuestTier.hard => const Color(0xFFFF7A59),
    };

IconData _kindIcon(String kind) => switch (kind) {
      'play' || 'rounds' => Icons.style_rounded,
      'win' || 'win1' => Icons.emoji_events_rounded,
      'pastra' => Icons.auto_awesome,
      'jack' => Icons.stars_rounded,
      'team' || 'teamWin' => Icons.groups_rounded,
      'online' || 'onlineWin' => Icons.public,
      'hard' => Icons.psychology_alt_rounded,
      'round' => Icons.trending_up_rounded,
      'good' => Icons.diamond_outlined,
      'streak' => Icons.local_fire_department_rounded,
      _ => Icons.flag_rounded,
    };

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.p,
    required this.canReroll,
    required this.onClaim,
    required this.onReroll,
  });

  final QuestState quest;
  final ProgressStrings p;
  final bool canReroll;
  final VoidCallback onClaim;
  final VoidCallback onReroll;

  @override
  Widget build(BuildContext context) {
    final def = quest.def;
    final tier = _tierColor(def.tier);
    final fraction = (quest.progress / def.goal).clamp(0.0, 1.0);
    final ready = quest.done && !quest.claimed;
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: quest.claimed ? 0.18 : 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ready ? PastraColors.gold : tier.withValues(alpha: quest.claimed ? 0.25 : 0.6),
          width: ready ? 2 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: tier.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(p.tier(def.tier), style: TextStyle(color: tier, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              if (canReroll)
                IconButton(
                  tooltip: p.reroll,
                  visualDensity: VisualDensity.compact,
                  onPressed: onReroll,
                  icon: const Icon(Icons.autorenew_rounded, color: Colors.white70, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: quest.done ? PastraColors.gold : Colors.white.withValues(alpha: 0.08),
                ),
                child: Icon(
                  quest.claimed ? Icons.check_rounded : _kindIcon(def.kind),
                  color: quest.done ? Colors.black : Colors.white70,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.quest(def),
                  style: TextStyle(
                    color: quest.claimed ? Colors.white54 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: quest.claimed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              color: quest.done ? PastraColors.gold : tier,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text('${quest.progress} / ${def.goal}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const Spacer(),
              _Reward(xp: def.xp, chips: Economy.enabled ? Quests.chipsFor(def) : 0),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: quest.claimed
                ? OutlinedButton(onPressed: null, child: Text(p.claimed))
                : FilledButton(onPressed: ready ? onClaim : null, child: Text(p.claim)),
          ),
        ],
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.xp, this.chips = 0, this.diamonds = 0, this.color = PastraColors.gold});

  final Color color;
  final int xp;
  final int chips;
  final int diamonds;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('+$xp XP', style: style),
        if (chips > 0) ...<Widget>[
          const SizedBox(width: 8),
          const ChipIcon(size: 14),
          const SizedBox(width: 3),
          Text('+$chips', style: style),
        ],
        if (diamonds > 0) ...<Widget>[
          const SizedBox(width: 8),
          const DiamondIcon(size: 14),
          const SizedBox(width: 3),
          Text('+$diamonds', style: style),
        ],
      ],
    );
  }
}

/// The chest for collecting all three quests of the day.
class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.p, required this.ready, required this.claimed, required this.onClaim});

  final ProgressStrings p;
  final bool ready;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 624),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: ready
              ? const <Color>[Color(0xFFFFD86B), Color(0xFFD9A21E)]
              : <Color>[Colors.black.withValues(alpha: 0.32), Colors.black.withValues(alpha: 0.22)],
        ),
        border: Border.all(color: PastraColors.gold.withValues(alpha: ready ? 1 : 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            claimed ? Icons.verified_rounded : Icons.redeem_rounded,
            color: ready ? Colors.black : PastraColors.gold,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  claimed ? p.allBonusDone : p.allBonus,
                  style: TextStyle(
                    color: ready ? Colors.black : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                if (!claimed)
                  _Reward(
                    xp: Quests.allBonusXp,
                    chips: Economy.enabled ? Quests.allBonusChips : 0,
                    diamonds: Economy.enabled ? Quests.allBonusDiamonds : 0,
                    color: ready ? Colors.black87 : PastraColors.gold,
                  ),
              ],
            ),
          ),
          if (!claimed)
            FilledButton(
              style: ready ? FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: PastraColors.gold) : null,
              onPressed: ready ? onClaim : null,
              child: Text(p.claim),
            ),
        ],
      ),
    );
  }
}
