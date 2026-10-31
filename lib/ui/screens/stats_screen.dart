import 'package:flutter/material.dart';

import '../../engine/pastra_ai.dart';
import '../../game/achievements.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/social_strings.dart';
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
                child: Column(
                  children: <Widget>[
                    _Highlights(stats: st),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: <Widget>[for (final t in tiles) t],
                    ),
                  ],
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

/// The four numbers players care about most, big: win rate, best streak,
/// most pastras in a game and the favourite table.
class _Highlights extends StatelessWidget {
  const _Highlights({required this.stats});

  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = Strings.of(context);
    final t = SocialStrings(settings.language);
    final p = ProgressStrings(settings.language);
    final favName = stats.favoriteTable;
    final fav = TableTheme.values.where((x) => x.name == favName).firstOrNull;
    Widget card({required Widget top, required String value, required String label}) => Container(
          width: 200,
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF1E5A43), Color(0xFF0B2A1E)],
            ),
            border: Border.all(color: PastraColors.gold.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: <Widget>[
              Expanded(child: Center(child: top)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        );
    return Column(
      children: <Widget>[
        Text(t.highlights, style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: <Widget>[
            card(
              top: SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: stats.winRate / 100),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        color: PastraColors.gold,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    Center(
                      child: Text('${stats.winRate}%', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              value: '${stats.wins} / ${stats.games}',
              label: s.statWinRate,
            ),
            card(
              top: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF8A5B), size: 52),
              value: '${stats.bestStreak}',
              label: s.statBestStreak,
            ),
            card(
              top: const Icon(Icons.auto_awesome, color: PastraColors.gold, size: 50),
              value: '${stats.bestGamePastras}',
              label: t.bestGamePastras,
            ),
            card(
              top: fav == null
                  ? const Icon(Icons.table_restaurant_rounded, color: Colors.white38, size: 50)
                  : DecoratedBox(
                      decoration: fav.decoration.copyWith(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const SizedBox(width: 80, height: 52),
                    ),
              value: fav == null ? '–' : p.table(fav),
              label: t.favTable,
            ),
          ],
        ),
      ],
    );
  }
}
