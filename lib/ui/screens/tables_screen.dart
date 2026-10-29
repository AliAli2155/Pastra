import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../../online/lobby.dart';
import '../theme.dart';

/// The open tables of the lobby. Tapping one closes this screen and returns
/// the room code, the caller joins it.
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.openTables)),
      body: Felt(
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<OpenTable>>(
            stream: Lobby.watch(),
            builder: (context, snap) {
              final tables = snap.data;
              if (tables == null) {
                return Center(
                  child: snap.hasError
                      ? Text(t.error('network'), style: const TextStyle(color: Colors.white70, fontSize: 16))
                      : const CircularProgressIndicator(),
                );
              }
              if (tables.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      t.noTables,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tables.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _TableTile(table: tables[i], t: t, s: s),
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

class _TableTile extends StatelessWidget {
  const _TableTile({required this.table, required this.t, required this.s});

  final OpenTable table;
  final OnlineStrings t;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final name = table.name.isEmpty ? t.defaultName : table.name;
    return Material(
      color: PastraColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pop(table.code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: PastraColors.gold,
                foregroundColor: Colors.black,
                child: Icon(table.players == 4 ? Icons.groups : Icons.person),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      t.tableOf(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${table.players == 4 ? s.mode2v2 : s.mode1v1} · ${s.level(table.level)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                '${table.joined}/${table.players}',
                style: const TextStyle(color: PastraColors.gold, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
