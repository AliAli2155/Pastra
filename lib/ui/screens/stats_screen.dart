import 'package:flutter/material.dart';

import '../../engine/pastra_ai.dart';
import '../../game/achievements.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/social_strings.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
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
      _Tile(Icons.local_fire_department_outlined, s.statStreak, '${st.streak}'),
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
    final p = ProgressStrings(settings.language);

    Widget statsBody(BuildContext context) {
      if (empty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const IconSquare(icon: Icons.insights_rounded, color: PastraColors.teal, size: 64),
                const SizedBox(height: 16),
                Text(s.noStats, textAlign: TextAlign.center, style: PremiumText.body.copyWith(color: PastraColors.text2)),
              ],
            ),
          ),
        );
      }
      return TabBody(
        maxWidth: 980,
        children: <Widget>[
          _Highlights(stats: st),
          SectionPanel(
            title: s.statistics,
            icon: Icons.bar_chart_rounded,
            accent: PastraColors.teal,
            child: ResponsiveGrid(minItemWidth: 190, children: tiles),
          ),
        ],
      );
    }

    Widget achievementsBody(BuildContext context) => TabBody(
          maxWidth: 980,
          children: <Widget>[
            SectionPanel(
              title: s.achievements,
              icon: Icons.military_tech_rounded,
              trailing: Text(
                s.achCount(unlocked.length, kAchievements.length),
                style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              child: ResponsiveGrid(
                minItemWidth: 260,
                children: <Widget>[
                  for (final a in kAchievements)
                    _Badge(
                      achievement: a,
                      unlocked: unlocked.containsKey(a.id),
                      progress: a.isCounter ? a.progress!(st) : null,
                    ),
                ],
              ),
            ),
          ],
        );

    return Scaffold(
      appBar: GameAppBar(
        icon: Icons.insights_rounded,
        title: Text(s.statistics),
        actions: <Widget>[
          IconButton(
            tooltip: s.resetStats,
            onPressed: empty && unlocked.isEmpty ? null : () => _confirmReset(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          bottom: false,
          child: SideTabs(
            initial: initialTab,
            tabs: <PageTab>[
              PageTab(icon: Icons.insights_rounded, label: s.statistics, builder: statsBody),
              PageTab(icon: Icons.military_tech_rounded, label: s.achievements, builder: achievementsBody),
              PageTab(icon: Icons.calendar_month_rounded, label: p.season, builder: (_) => const SeasonView()),
            ],
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
      padding: const EdgeInsets.all(12),
      decoration: unlocked ? glassDecoration(radius: 14, selected: true) : glassDecoration(radius: 14),
      child: Row(
        children: <Widget>[
          IconSquare(
            icon: unlocked ? achievement.icon : Icons.lock_outline_rounded,
            color: unlocked ? PastraColors.gold : PastraColors.muted,
            size: 44,
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
                    fontWeight: FontWeight.w700,
                    color: unlocked ? PastraColors.goldLight : PastraColors.text,
                  ),
                ),
                Text(s.achDesc(achievement.id), style: PremiumText.secondary.copyWith(fontSize: 12)),
                if (p != null && goal > 1 && !unlocked) ...<Widget>[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (p / goal).clamp(0.0, 1.0),
                      minHeight: 6,
                      color: PastraColors.gold,
                      backgroundColor: const Color(0xFF2E333B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${p.clamp(0, goal)} / $goal', style: const TextStyle(fontSize: 11, color: PastraColors.muted)),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: glassDecoration(radius: 14),
      child: Row(
        children: <Widget>[
          IconSquare(icon: icon, color: PastraColors.gold, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: PastraColors.text)),
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: PremiumText.secondary.copyWith(fontSize: 12)),
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
          height: 140,
          padding: const EdgeInsets.all(12),
          decoration: panelDecoration(radius: 18, highlight: true, shadow: false),
          child: Column(
            children: <Widget>[
              Expanded(child: Center(child: top)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: PastraColors.text, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: PremiumText.secondary.copyWith(fontSize: 12),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(t.highlights, style: PremiumText.eyebrow),
        const SizedBox(height: 10),
        ResponsiveGrid(
          minItemWidth: 150,
          maxColumns: 4,
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
                        backgroundColor: const Color(0xFF2E333B),
                      ),
                    ),
                    Center(
                      child: Text('${stats.winRate}%', style: const TextStyle(color: PastraColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              value: '${stats.wins} / ${stats.games}',
              label: s.statWinRate,
            ),
            card(
              top: const Icon(Icons.local_fire_department_rounded, color: PastraColors.coral, size: 52),
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
