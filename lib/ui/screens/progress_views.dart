import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/progression.dart';
import '../../game/seasons.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/shop_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/playing_card.dart';
import 'leaderboard_screen.dart';

/// Levels 1–30 and what each one unlocks; the current level is marked.
class LevelPathView extends StatefulWidget {
  const LevelPathView({super.key});

  @override
  State<LevelPathView> createState() => _LevelPathViewState();
}

class _LevelPathViewState extends State<LevelPathView> {
  static const double _rowH = 92;
  ScrollController? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll ??= ScrollController(
      initialScrollOffset: max(0, (SettingsScope.read(context).playerLevel - 2) * _rowH),
    );
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final level = settings.playerLevel;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemExtent: _rowH,
          itemCount: Progression.maxLevel,
          itemBuilder: (context, i) => _LevelRow(
            level: i + 1,
            current: level,
            xp: settings.xp,
            name: settings.playerName,
          ),
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level, required this.current, required this.xp, required this.name});

  final int level;
  final int current;
  final int xp;
  final String name;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final reached = level <= current;
    final here = level == current;
    final r = Progression.rewardsAt(level);
    final items = <Widget>[
      for (final t in r.tables)
        _Reward(
          label: p.reward('table'),
          child: DecoratedBox(
            decoration: t.decoration.copyWith(borderRadius: BorderRadius.circular(6)),
            child: const SizedBox(width: 40, height: 28),
          ),
        ),
      for (final b in r.backs)
        _Reward(
          label: p.reward('back'),
          child: SizedBox(width: 22, height: 31, child: PlayingCardView(card: 0, faceUp: false, backStyle: b)),
        ),
      for (final f in r.frames)
        _Reward(
          label: p.frame(f),
          child: PlayerAvatar(name: name.isEmpty ? '?' : name, frame: f, size: 32),
        ),
      for (final t in r.titles)
        _Reward(
          label: p.reward('title'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PastraColors.gold.withValues(alpha: 0.7)),
            ),
            child: Text(p.title(t), style: const TextStyle(color: PastraColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
      if (Economy.enabled && level > 1)
        _Reward(
          label: ShopStrings(settings.language).chips,
          child: Text(
            '+${Economy.short(Economy.levelUpChips(level))}',
            style: const TextStyle(color: PastraColors.gold, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
    ];
    final progress = Progression.progress(xp);
    return Row(
      children: <Widget>[
        // The path: a line through the level circles.
        SizedBox(
          width: 56,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned(
                top: level == 1 ? _LevelPathViewState._rowH / 2 : 0,
                bottom: level == Progression.maxLevel ? _LevelPathViewState._rowH / 2 : 0,
                child: Container(width: 4, color: level < current ? PastraColors.gold : Colors.white12),
              ),
              Container(
                width: here ? 46 : 38,
                height: here ? 46 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached ? PastraColors.gold : const Color(0xFF15372A),
                  border: Border.all(color: here ? Colors.white : Colors.white24, width: here ? 3 : 1.5),
                  boxShadow: here ? <BoxShadow>[BoxShadow(color: PastraColors.gold.withValues(alpha: 0.6), blurRadius: 14)] : null,
                ),
                child: Text(
                  '$level',
                  style: TextStyle(
                    color: reached ? Colors.black : Colors.white60,
                    fontSize: here ? 18 : 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: here ? 0.4 : 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: here ? PastraColors.gold : Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: <Widget>[
                if (here)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(p.youAreHere, style: const TextStyle(color: PastraColors.gold, fontSize: 12, fontWeight: FontWeight.w900)),
                        if (progress.needed > 0)
                          Text('${progress.into} / ${progress.needed} XP', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                Expanded(
                  child: items.isEmpty
                      ? Text(p.noReward, style: const TextStyle(color: Colors.white38, fontSize: 12))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: <Widget>[for (final w in items) Padding(padding: const EdgeInsetsDirectional.only(end: 14), child: w)]),
                        ),
                ),
                Icon(
                  reached ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: reached ? PastraColors.gold : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(height: 34, child: Center(child: child)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

Color seasonTierColor(SeasonTier t) => switch (t) {
      SeasonTier.champion => const Color(0xFFFFD54F),
      SeasonTier.top3 => const Color(0xFFCFD8DC),
      SeasonTier.top10 => const Color(0xFFD7A06B),
      SeasonTier.top100 => const Color(0xFF5BD69A),
      SeasonTier.player => Colors.white70,
    };

/// This month's season and the badges of the finished ones.
class SeasonView extends StatelessWidget {
  const SeasonView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final s = Strings.of(context);
    final badges = settings.seasonBadges.reversed.toList();
    Widget stat(String value, String label) => Column(
          children: <Widget>[
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: <Color>[Color(0xFF1B5E44), Color(0xFF0B3325)]),
                  border: Border.all(color: PastraColors.gold.withValues(alpha: 0.6)),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.calendar_month_rounded, color: PastraColors.gold, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${p.season}: ${p.seasonName(settings.season)}',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                p.seasonEnds(p.duration(Seasons.timeLeft(DateTime.now()))),
                                style: const TextStyle(color: PastraColors.gold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()),
                          ),
                          icon: const Icon(Icons.leaderboard_rounded, size: 18),
                          label: Text(p.ranking),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        stat('${settings.seasonXp}', p.seasonXp),
                        stat('${settings.seasonWins}', s.statWins),
                        stat('${settings.seasonGames}', s.statGames),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(p.seasonHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 18),
              Text(p.seasonBadges, style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (badges.isEmpty)
                Text(p.noBadges, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 14))
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: <Widget>[for (final b in badges) SeasonBadgeTile(badge: b)],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SeasonBadgeTile extends StatelessWidget {
  const SeasonBadgeTile({super.key, required this.badge});

  final SeasonBadge badge;

  @override
  Widget build(BuildContext context) {
    final p = ProgressStrings(SettingsScope.of(context).language);
    final color = seasonTierColor(badge.tier);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            badge.tier == SeasonTier.player ? Icons.military_tech_outlined : Icons.emoji_events_rounded,
            color: color,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(p.seasonName(badge.season), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(
                  badge.rank > 0 ? '${p.seasonTier(badge.tier)} · #${badge.rank}' : p.seasonTier(badge.tier),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The message at the end of a season (shown once on the home screen).
Future<void> showSeasonResult(BuildContext context, SeasonBadge badge) {
  final p = ProgressStrings(SettingsScope.read(context).language);
  final color = seasonTierColor(badge.tier);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.emoji_events_rounded, color: color, size: 56),
      title: Text(p.seasonOver(p.seasonName(badge.season)), textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(badge.rank > 0 ? p.seasonPlace(badge.rank) : p.seasonPlayed, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          SeasonBadgeTile(badge: badge),
          const SizedBox(height: 10),
          Text(
            p.seasonReward(Seasons.rewardXp(badge.tier)),
            style: const TextStyle(color: PastraColors.gold, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      actions: <Widget>[
        FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
      ],
    ),
  );
}
