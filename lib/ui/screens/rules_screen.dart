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
    final pointCards = v == GameVariant.pile
        ? <List<Object>>[
            <Object>[Cards.make(Cards.spades, Cards.ace), '1'],
            <Object>[Cards.make(Cards.hearts, Cards.king), '1'],
            <Object>[Cards.tenOfDiamonds, '2'],
            <Object>[Cards.twoOfClubs, '1'],
          ]
        : <List<Object>>[
            <Object>[Cards.make(Cards.spades, Cards.ace), '1'],
            <Object>[Cards.make(Cards.clubs, Cards.jack), '1'],
            <Object>[Cards.twoOfClubs, '2'],
            <Object>[Cards.tenOfDiamonds, '3'],
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
      body: Container(
        decoration: feltDecoration,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: _listPadding(context),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (final pc in pointCards)
                      Column(
                        children: <Widget>[
                          SizedBox(
                            width: 58,
                            height: 82,
                            child: PlayingCardView(card: pc[0] as int, faceUp: true),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '+${pc[1]}',
                            style: const TextStyle(
                              color: PastraColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
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

/// Side padding that keeps the list readable on a wide (landscape) screen.
EdgeInsets _listPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final side = w > 792 ? (w - 760) / 2 : 16.0;
  return EdgeInsets.fromLTRB(side, 8, side, 32);
}
