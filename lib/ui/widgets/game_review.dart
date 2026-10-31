import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/move_review.dart';
import '../../game/app_settings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import 'playing_card.dart';

/// After the game: the chances the player let slip ("a jack would have
/// taken the pile here"), at most a few, the biggest first.
Future<void> showGameReview(BuildContext context, List<MissedChance> misses) {
  final settings = SettingsScope.read(context);
  final t = SocialStrings(settings.language);
  final s = Strings.of(context);
  final list = List<MissedChance>.of(misses)
    ..sort((a, b) {
      final kind = a.kind.index.compareTo(b.kind.index);
      if (kind != 0) return kind;
      return (b.points * 2 + b.cards).compareTo(a.points * 2 + a.cards);
    });
  final shown = list.take(6).toList();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(misses.isEmpty ? Icons.verified_rounded : Icons.manage_search_rounded, color: PastraColors.gold, size: 40),
      title: Text(t.analysis, textAlign: TextAlign.center),
      content: SizedBox(
        width: 460,
        child: misses.isEmpty
            ? Text(t.noMisses, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      t.missedCount(misses.length),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    for (final m in shown) _MissRow(miss: m, t: t, s: s),
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
      ],
    ),
  );
}

class _MissRow extends StatelessWidget {
  const _MissRow({required this.miss, required this.t, required this.s});

  final MissedChance miss;
  final SocialStrings t;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final better = Cards.label(miss.better);
    final played = Cards.label(miss.played);
    final pastra = miss.kind == MissKind.pastra;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pastra ? PastraColors.gold.withValues(alpha: 0.7) : Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: 30, height: 42, child: PlayingCardView(card: miss.played, faceUp: true)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 18),
          ),
          SizedBox(width: 30, height: 42, child: PlayingCardView(card: miss.better, faceUp: true, highlighted: true)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  pastra ? t.missedPastra(better, miss.points) : t.missedCapture(better, miss.cards),
                  style: TextStyle(color: pastra ? PastraColors.gold : Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  '${s.round(miss.round)} · ${t.playedInstead(played)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
