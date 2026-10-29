import 'package:flutter/material.dart';

import '../theme.dart';

/// One match box of a knockout bracket.
class BracketCell {
  const BracketCell({this.a, this.b, this.winner, this.meA = false, this.meB = false, this.current = false});

  /// Names (null = not known yet).
  final String? a;
  final String? b;

  /// 0 = a won, 1 = b won, null = not decided.
  final int? winner;
  final bool meA;
  final bool meB;

  /// The local player's match being played now (gold frame).
  final bool current;
}

/// A knockout bracket: one column per round, `cells[round][match]`. Drawn at
/// a fixed design size and scaled down to fit.
class BracketView extends StatelessWidget {
  const BracketView({super.key, required this.titles, required this.cells});

  final List<String> titles;
  final List<List<BracketCell>> cells;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 190.0 * titles.length + 12 * (titles.length - 1),
        height: 330,
        child: Row(
          children: <Widget>[
            for (var r = 0; r < titles.length; r++) ...<Widget>[
              if (r > 0) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      titles[r],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[for (final c in cells[r]) _Cell(cell: c)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final BracketCell cell;

  @override
  Widget build(BuildContext context) {
    Widget line(String? name, bool me, int side) {
      final won = cell.winner == side;
      final lost = cell.winner != null && !won;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                name ?? '?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: me || won ? FontWeight.w800 : FontWeight.w500,
                  color: name == null || lost ? Colors.white38 : (me ? PastraColors.gold : Colors.white),
                  decoration: lost ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (won) const Icon(Icons.check_circle, size: 14, color: PastraColors.gold),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cell.current ? PastraColors.gold : Colors.white12, width: cell.current ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          line(cell.a, cell.meA, 0),
          const Divider(height: 1, color: Colors.white12),
          line(cell.b, cell.meB, 1),
        ],
      ),
    );
  }
}
