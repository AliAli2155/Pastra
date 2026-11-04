import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/seasons.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/strings.dart';
import '../../online/leaderboard.dart';
import '../../online/online_service.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/avatar.dart';

/// The best players by XP.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Future<void>? _submitted;
  Future<List<LeaderEntry>>? _season;
  Future<List<LeaderEntry>>? _all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_submitted == null) _load();
  }

  void _load() {
    final settings = SettingsScope.read(context);
    // Our own row first, so a new XP total shows up in the list.
    _submitted = Leaderboard.submit(settings, fallbackName: Strings.of(context).you);
    final season = settings.season;
    _season = _submitted!.then((_) => Leaderboard.season(season));
    _all = _submitted!.then((_) => Leaderboard.top());
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = OnlineStrings(settings.language);
    final p = ProgressStrings(settings.language);
    return Scaffold(
      appBar: GameAppBar(
        icon: Icons.leaderboard_rounded,
        title: Text(t.leaderboard),
        actions: <Widget>[IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _reload)],
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          bottom: false,
          child: SideTabs(
            tabs: <PageTab>[
              PageTab(
                icon: Icons.calendar_month_rounded,
                label: p.seasonName(settings.season),
                builder: (_) => _Board(
                  future: _season,
                  header: p.seasonEnds(p.duration(Seasons.timeLeft(DateTime.now()))),
                ),
              ),
              PageTab(icon: Icons.public_rounded, label: p.allTimeTab, builder: (_) => _Board(future: _all)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One list: the first three on a podium, everybody else in rows under it.
class _Board extends StatelessWidget {
  const _Board({required this.future, this.header});

  final Future<List<LeaderEntry>>? future;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final s = Strings.of(context);
    return FutureBuilder<List<LeaderEntry>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text(t.error('network'), style: PremiumText.body.copyWith(color: PastraColors.text2)));
        }
        final rows = snap.data ?? const <LeaderEntry>[];
        final me = OnlineService.uid;
        return TabBody(
          maxWidth: 760,
          children: <Widget>[
            if (header != null) Text(header!, style: PremiumText.eyebrow),
            if (rows.isEmpty)
              SectionPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.leaderboardEmpty,
                    textAlign: TextAlign.center,
                    style: PremiumText.body.copyWith(color: PastraColors.text2),
                  ),
                ),
              )
            else
              _Podium(top: rows.take(3).toList(), me: me, t: t),
            for (var i = 3; i < rows.length; i++)
              _Row(rank: i + 1, entry: rows[i], mine: rows[i].uid == me, t: t, s: s),
          ],
        );
      },
    );
  }
}

Color? _medal(int rank) => switch (rank) {
      1 => PastraColors.gold,
      2 => const Color(0xFFCFD8DC),
      3 => const Color(0xFFD7A06B),
      _ => null,
    };

/// The first three side by side: the winner in the middle, a little higher.
class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.me, required this.t});

  final List<LeaderEntry> top;
  final String? me;
  final OnlineStrings t;

  @override
  Widget build(BuildContext context) {
    // Order on the podium: 2nd, 1st, 3rd.
    final order = <int>[if (top.length > 1) 1, 0, if (top.length > 2) 2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (var k = 0; k < order.length; k++) ...<Widget>[
          if (k > 0) const SizedBox(width: 10),
          Expanded(child: _Step(rank: order[k] + 1, entry: top[order[k]], mine: top[order[k]].uid == me, t: t)),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.rank, required this.entry, required this.mine, required this.t});

  final int rank;
  final LeaderEntry entry;
  final bool mine;
  final OnlineStrings t;

  @override
  Widget build(BuildContext context) {
    final medal = _medal(rank)!;
    final name = entry.name.isEmpty ? t.defaultName : entry.name;
    final first = rank == 1;
    return Container(
      padding: EdgeInsets.fromLTRB(10, first ? 18 : 14, 10, 14),
      decoration: panelDecoration(radius: 18, highlight: first || mine, shadow: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.emoji_events_rounded, color: medal, size: first ? 30 : 24),
          const SizedBox(height: 8),
          PlayerAvatar(name: name, frame: entry.frame, size: first ? 60 : 50),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mine ? PastraColors.goldLight : PastraColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (entry.tag.isNotEmpty)
            Text('#${entry.tag}', style: const TextStyle(color: PastraColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            '${entry.xp} XP',
            style: TextStyle(color: medal, fontSize: first ? 20 : 17, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: first ? 16 : 0),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.mine, required this.t, required this.s});

  final int rank;
  final LeaderEntry entry;
  final bool mine;
  final OnlineStrings t;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final name = entry.name.isEmpty ? t.defaultName : entry.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: glassDecoration(radius: 14, selected: mine),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PastraColors.text2, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          PlayerAvatar(name: name, frame: entry.frame, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: name),
                      if (entry.tag.isNotEmpty)
                        TextSpan(
                          text: ' #${entry.tag}',
                          style: const TextStyle(color: PastraColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mine ? PastraColors.goldLight : PastraColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('${s.levelN(entry.level)} · ${s.stats(entry.wins, entry.games)}', style: PremiumText.secondary),
              ],
            ),
          ),
          Text(
            '${entry.xp} XP',
            style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
