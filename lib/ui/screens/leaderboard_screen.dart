import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/seasons.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/strings.dart';
import '../../online/leaderboard.dart';
import '../../online/online_service.dart';
import '../theme.dart';
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.leaderboard),
          actions: <Widget>[IconButton(icon: const Icon(Icons.refresh), onPressed: _reload)],
          bottom: TabBar(
            indicatorColor: PastraColors.gold,
            labelColor: PastraColors.gold,
            unselectedLabelColor: Colors.white70,
            tabs: <Widget>[
              Tab(text: p.seasonName(settings.season)),
              Tab(text: p.allTimeTab),
            ],
          ),
        ),
        body: Felt(
          child: SafeArea(
            top: false,
            child: TabBarView(
              children: <Widget>[
                _Board(
                  future: _season,
                  header: p.seasonEnds(p.duration(Seasons.timeLeft(DateTime.now()))),
                  season: true,
                ),
                _Board(future: _all),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.future, this.header, this.season = false});

  final Future<List<LeaderEntry>>? future;
  final String? header;
  final bool season;

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
          return Center(
            child: Text(t.error('network'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
          );
        }
        final rows = snap.data ?? const <LeaderEntry>[];
        final me = OnlineService.uid;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (header != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      header!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      t.leaderboardEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Row(rank: i + 1, entry: rows[i], mine: rows[i].uid == me, t: t, s: s),
                  ),
              ],
            ),
          ),
        );
      },
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
    final medal = switch (rank) {
      1 => const Color(0xFFFFD54F),
      2 => const Color(0xFFCFD8DC),
      3 => const Color(0xFFD7A06B),
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PastraColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mine ? PastraColors.gold : Colors.white24, width: mine ? 2 : 1),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: medal != null
                ? Icon(Icons.emoji_events, color: medal)
                : Text('$rank', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          PlayerAvatar(name: entry.name.isEmpty ? t.defaultName : entry.name, frame: entry.frame, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.name.isEmpty ? t.defaultName : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mine ? PastraColors.gold : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${s.levelN(entry.level)} · ${entry.wins}/${entry.games}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${entry.xp} XP',
            style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
