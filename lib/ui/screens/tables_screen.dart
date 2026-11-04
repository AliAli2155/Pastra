import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../../online/lobby.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/wallet_bar.dart';

/// The open tables of the lobby. Tapping one closes this screen and returns
/// the room code, the caller joins it.
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final s = Strings.of(context);
    return Scaffold(
      appBar: GameAppBar(
        icon: Icons.table_restaurant_rounded,title: Text(t.openTables)),
      body: Felt(
        child: SafeArea(
          top: false,
          bottom: false,
          child: StreamBuilder<List<OpenTable>>(
            stream: Lobby.watch(),
            builder: (context, snap) {
              final tables = snap.data;
              if (tables == null) {
                return Center(
                  child: snap.hasError
                      ? Text(t.error('network'), style: PremiumText.body.copyWith(color: PastraColors.text2))
                      : const CircularProgressIndicator(),
                );
              }
              if (tables.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const IconSquare(icon: Icons.table_restaurant_rounded, color: PastraColors.teal, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          t.noTables,
                          textAlign: TextAlign.center,
                          style: PremiumText.body.copyWith(color: PastraColors.text2),
                        ),
                        const SizedBox(height: 18),
                        // Back to "Play online", where a room is created.
                        GlassButton(
                          icon: Icons.add_rounded,
                          label: t.createRoom,
                          height: 48,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                );
              }
              // A card per table, as many in a row as fit.
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ResponsiveGrid(
                      minItemWidth: 250,
                      maxColumns: 4,
                      children: <Widget>[for (final table in tables) _TableCard(table: table, t: t, s: s)],
                    ),
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

/// One open table: a small table with its seats (gold = taken), the host,
/// the game and a button to sit down.
class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.t, required this.s});

  final OpenTable table;
  final OnlineStrings t;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final name = table.name.isEmpty ? t.defaultName : table.name;
    void sit() => Navigator.of(context).pop(table.code);
    return Pressable(
      onTap: sit,
      radius: BorderRadius.circular(18),
      decoration: panelDecoration(radius: 18, shadow: false),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 74,
              child: Center(child: _MiniTable(seats: table.players, taken: table.joined)),
            ),
            const SizedBox(height: 12),
            Text(
              t.tableOf(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: PastraColors.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${table.players == 4 ? s.mode2v2 : s.mode1v1} · ${s.level(table.level)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PremiumText.secondary,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (table.stake > 0) Amount(chips: table.stake, size: 14),
                const Spacer(),
                Text(
                  '${table.joined}/${table.players}',
                  style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PastraColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PastraColors.teal.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.login_rounded, color: PastraColors.foam, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A little oval table seen from above with a dot per seat.
class _MiniTable extends StatelessWidget {
  const _MiniTable({required this.seats, required this.taken});

  final int seats;
  final int taken;

  @override
  Widget build(BuildContext context) {
    const w = 120.0;
    const h = 64.0;
    // Seats around the oval: bottom, top (and left, right with four).
    final spots = seats == 4
        ? const <Offset>[Offset(w / 2, h), Offset(0, h / 2), Offset(w / 2, 0), Offset(w, h / 2)]
        : const <Offset>[Offset(w / 2, h), Offset(w / 2, 0)];
    return SizedBox(
      width: w + 20,
      height: h + 20,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 10,
            top: 10,
            width: w,
            height: h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
                gradient: const RadialGradient(
                  colors: <Color>[PastraColors.emeraldLight, PastraColors.emerald, PastraColors.emeraldDark],
                  stops: <double>[0.0, 0.6, 1.0],
                ),
                border: Border.all(color: PastraColors.wood, width: 4),
              ),
            ),
          ),
          for (var i = 0; i < spots.length; i++)
            Positioned(
              left: spots[i].dx + 10 - 9,
              top: spots[i].dy + 10 - 9,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < taken ? PastraColors.gold : PastraColors.raised,
                  border: Border.all(color: i < taken ? PastraColors.goldLight : Colors.white24, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
