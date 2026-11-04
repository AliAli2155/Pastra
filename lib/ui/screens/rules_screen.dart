import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../engine/rules.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
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
    final sections = s.rulesSections(v);
    final points = Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
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
              style: TextStyle(color: PastraColors.gold, fontSize: 44, fontWeight: FontWeight.w800, fontFamily: 'Manrope'),
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: GameAppBar(
        icon: Icons.menu_book_rounded,
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
          bottom: false,
          // A section of the rules per tab; the points are on the first one.
          child: SideTabs(
            tabs: <PageTab>[
              for (var i = 0; i < sections.length; i++)
                PageTab(
                  icon: _icons[i % _icons.length],
                  label: sections[i][0],
                  builder: (_) => TabBody(
                    children: <Widget>[
                      if (i == 0) SectionPanel(child: Center(child: points)),
                      SectionPanel(
                        title: sections[i][0],
                        icon: _icons[i % _icons.length],
                        child: Text(
                          sections[i][1],
                          style: const TextStyle(color: PastraColors.text, fontSize: 15, height: 1.55),
                        ),
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

  static const List<IconData> _icons = <IconData>[
    Icons.style_rounded,
    Icons.back_hand_rounded,
    Icons.layers_rounded,
    Icons.auto_awesome_rounded,
    Icons.calculate_rounded,
    Icons.emoji_events_rounded,
    Icons.tune_rounded,
    Icons.lightbulb_outline_rounded,
  ];
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
      decoration: glassDecoration(radius: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(width: 58, height: 82, child: art),
          const SizedBox(height: 6),
          Text(
            '+$points',
            style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: PastraColors.text2, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
