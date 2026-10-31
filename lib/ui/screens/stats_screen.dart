import 'package:flutter/material.dart';

import '../../engine/pastra_ai.dart';
import '../../game/achievements.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../../l10n/progress_strings.dart';
import '../theme.dart';
import 'progress_views.dart';

/// Lifetime statistics and achievements of the local player.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  Future<void> _confirmReset(BuildContext context) async {
    final s = Strings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.resetStatsConfirm),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok == true && context.mounted) SettingsScope.read(context).resetStats();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final st = SettingsScope.of(context).stats;
    String ratio(int wins, int games) => games == 0 ? '–' : '$wins / $games';

    final tiles = <_Tile>[
      _Tile(Icons.casino_outlined, s.statGames, '${st.games}'),
      _Tile(Icons.emoji_events_outlined, s.statWins, '${st.wins}'),
      _Tile(Icons.percent, s.statWinRate, st.games == 0 ? '–' : '${st.winRate}%'),
      _Tile(Icons.local_fire_department_outlined, s.statStreak, '${st.streak}'),
      _Tile(Icons.whatshot_outlined, s.statBestStreak, '${st.bestStreak}'),
      _Tile(Icons.auto_awesome, s.statPastras, '${st.pastras}'),
      _Tile(Icons.stars_outlined, s.statJackPastras, '${st.jackPastras}'),
      _Tile(Icons.trending_up, s.statBestRound, '${st.bestRound}'),
      _Tile(Icons.repeat, s.statRounds, '${st.rounds}'),
      _Tile(Icons.person_outline, s.stat1v1, ratio(st.wins1v1, st.games1v1)),
      _Tile(Icons.groups_outlined, s.stat2v2, ratio(st.wins2v2, st.games2v2)),
      for (final level in AiLevel.values)
        _Tile(
          Icons.smart_toy_outlined,
          '${s.statByLevel}: ${s.level(level)}',
          ratio(st.winsByLevel[level.index], st.gamesByLevel[level.index]),
        ),
    ];

    final settings = SettingsScope.of(context);
    final unlocked = settings.achievements;
    final empty = st.games == 0 && st.rounds == 0;
    final statsBody = empty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                s.noStats,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: <Widget>[for (final t in tiles) t],
                ),
              ),
            ),
          );
    final achievementsBody = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: <Widget>[
              Text(
                s.achCount(unlocked.length, kAchievements.length),
                style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final a in kAchievements)
                    _Badge(
                      achievement: a,
                      unlocked: unlocked.containsKey(a.id),
                      progress: a.isCounter ? a.progress!(st) : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final p = ProgressStrings(settings.language);
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.statistics),
          actions: <Widget>[
            IconButton(
              tooltip: s.resetStats,
              onPressed: empty && unlocked.isEmpty ? null : () => _confirmReset(context),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
          bottom: TabBar(
            indicatorColor: PastraColors.gold,
            labelColor: PastraColors.gold,
            unselectedLabelColor: Colors.white70,
            isScrollable: MediaQuery.sizeOf(context).width < 520,
            tabAlignment: MediaQuery.sizeOf(context).width < 520 ? TabAlignment.start : null,
            tabs: <Widget>[
              Tab(text: s.statistics),
              Tab(text: s.achievements),
              Tab(text: p.season),
            ],
          ),
        ),
        body: Felt(
          child: SafeArea(
            top: false,
            child: TabBarView(children: <Widget>[statsBody, achievementsBody, const SeasonView()]),
          ),
        ),
      ),
    );
  }
}

/// One achievement: gold when unlocked, a progress bar for counters.
class _Badge extends StatelessWidget {
  const _Badge({required this.achievement, required this.unlocked, this.progress});

  final Achievement achievement;
  final bool unlocked;
  final int? progress;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final goal = achievement.goal;
    final p = progress;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: unlocked ? 0.35 : 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? PastraColors.gold.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? PastraColors.gold : Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_outline,
              size: 24,
              color: unlocked ? Colors.black : Colors.white38,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.achTitle(achievement.id),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: unlocked ? Colors.white : Colors.white70,
                  ),
                ),
                Text(
                  s.achDesc(achievement.id),
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
                if (p != null && goal > 1 && !unlocked) ...<Widget>[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (p / goal).clamp(0.0, 1.0),
                      minHeight: 6,
                      color: PastraColors.gold,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${p.clamp(0, goal)} / $goal', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: PastraColors.gold, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
