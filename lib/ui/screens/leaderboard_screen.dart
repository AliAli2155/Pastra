import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../../online/leaderboard.dart';
import '../../online/online_service.dart';
import '../theme.dart';

/// The best players by XP.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Future<List<LeaderEntry>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<LeaderEntry>> _load() async {
    final settings = SettingsScope.read(context);
    // Our own row first, so a new XP total shows up in the list.
    await Leaderboard.submit(settings, fallbackName: Strings.of(context).you);
    return Leaderboard.top();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.leaderboard),
        actions: <Widget>[IconButton(icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<LeaderEntry>>(
            future: _future,
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
              if (rows.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      t.leaderboardEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                );
              }
              final me = OnlineService.uid;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _Row(rank: i + 1, entry: rows[i], mine: rows[i].uid == me, t: t, s: s),
                  ),
                ),
              );
            },
          ),
        ),
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
