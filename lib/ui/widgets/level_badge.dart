import 'package:flutter/material.dart';

import '../../game/progression.dart';
import '../../l10n/strings.dart';
import '../theme.dart';

/// The player's level with a progress bar towards the next one.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.xp, this.width = 220});

  /// The player's XP, passed in by the parent so the badge is rebuilt
  /// whenever the value changes.
  final int xp;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final level = Progression.levelOf(xp);
    final p = Progression.progress(xp);
    final maxed = level >= Progression.maxLevel;
    final fraction = maxed ? 1.0 : (p.needed == 0 ? 0.0 : (p.into / p.needed).clamp(0.0, 1.0));
    return SizedBox(
      width: width,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PastraColors.gold,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '$level',
              style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        s.levelN(level),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      maxed ? 'MAX' : '${p.into} / ${p.needed} XP',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 7,
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    valueColor: const AlwaysStoppedAnimation<Color>(PastraColors.gold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
