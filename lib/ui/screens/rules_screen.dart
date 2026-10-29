import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/rules.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/playing_card.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key, this.variant});

  /// Rules of this game; null = the variant chosen in the settings.
  final GameVariant? variant;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final v = variant ?? SettingsScope.of(context).rules.variant;
    final rules = PastraRules.defaultsFor(v);
    // The values come from the game itself, so this strip can never say
    // something else than the scoring does.
    final pointCards = <(int, String)>[
      (Cards.make(Cards.spades, Cards.ace), s.aces),
      (Cards.make(Cards.clubs, Cards.jack), s.jacks),
      (Cards.twoOfClubs, s.twoOfClubs),
      (Cards.tenOfDiamonds, s.tenOfDiamonds),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${s.rules} · ${s.variantName(v)}'),
        actions: <Widget>[
          IconButton(
            tooltip: s.tutorial,
            icon: const Icon(Icons.school_outlined),
            onPressed: () {
              SettingsScope.read(context).tutorialDone = false;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.tutorialQueued)));
            },
          ),
        ],
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: _listPadding(context),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final (card, label) in pointCards)
                      _PointTile(
                        label: label,
                        points: rules.pointsOf(card),
                        art: PlayingCardView(card: card, faceUp: true),
                      ),
                    _PointTile(
                      label: s.mostCards,
                      points: PastraRules.mostCardsBonus,
                      art: Stack(
                        children: <Widget>[
                          for (var i = 0; i < 3; i++)
                            Positioned(
                              left: i * 6.0,
                              top: i * 4.0,
                              width: 46,
                              height: 66,
                              child: const PlayingCardView(card: 0, faceUp: false),
                            ),
                        ],
                      ),
                    ),
                    _PointTile(
                      label: s.pastraRow,
                      points: rules.pastraPoints,
                      art: const Center(
                        child: Text(
                          'Π',
                          style: TextStyle(color: PastraColors.gold, fontSize: 44, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final section in s.rulesSections(v))
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        section[0],
                        style: const TextStyle(
                          color: PastraColors.gold,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section[1],
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One scoring item: a picture, "+points" and what it is.
class _PointTile extends StatelessWidget {
  const _PointTile({required this.label, required this.points, required this.art});

  final String label;
  final int points;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(width: 58, height: 82, child: art),
          const SizedBox(height: 6),
          Text(
            '+$points',
            style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w900, fontSize: 20),
          ),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Side padding that keeps the list readable on a wide (landscape) screen.
EdgeInsets _listPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final side = w > 792 ? (w - 760) / 2 : 16.0;
  return EdgeInsets.fromLTRB(side, 8, side, 32);
}
