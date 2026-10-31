import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/seasons.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import 'leaderboard_screen.dart';

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
