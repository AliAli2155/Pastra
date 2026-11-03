import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../game/app_settings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/menu_tiles.dart';
import '../widgets/playing_card.dart';

/// "Play": big tiles. Offline (with "Continue" under it when a game is
/// saved) and online.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.onOffline,
    required this.onContinue,
    required this.onOnline,
  });

  final Future<void> Function(BuildContext context) onOffline;
  final Future<void> Function(BuildContext context) onContinue;
  final Future<void> Function(BuildContext context) onOnline;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  /// Runs [action], then rebuilds: a game started from here may have created
  /// (or finished) the saved game.
  Future<void> _run(Future<void> Function(BuildContext context) action) async {
    await action(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final saved = SettingsScope.of(context).hasSavedGame;
    final offline = _ModeTile(
      title: s.playOffline,
      hint: s.playOfflineHint,
      icon: Icons.smart_toy_rounded,
      colors: const <Color>[Color(0xFF1F9D63), Color(0xFF0A5A39)],
      cards: <int>[
        Cards.make(Cards.spades, Cards.ace),
        Cards.make(Cards.hearts, Cards.king),
        Cards.tenOfDiamonds,
      ],
      onTap: () => _run(widget.onOffline),
    );
    final online = _ModeTile(
      title: s.playOnline,
      hint: s.playOnlineHint,
      icon: Icons.public,
      colors: const <Color>[Color(0xFF3A82D6), Color(0xFF15427A)],
      cards: <int>[
        Cards.twoOfClubs,
        Cards.make(Cards.hearts, Cards.jack),
        Cards.make(Cards.diamonds, Cards.queen),
      ],
      onTap: () => _run(widget.onOnline),
    );
    return Scaffold(
      appBar: GameAppBar(
        icon: Icons.play_arrow_rounded,title: Text(s.play)),
      body: Felt(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight;
              final gap = wide ? 20.0 : 16.0;
              // Offline on top, "Continue" half-and-half underneath it.
              final offlineColumn = Column(
                children: <Widget>[
                  Expanded(child: offline),
                  if (saved) ...<Widget>[
                    SizedBox(height: gap / 2),
                    Expanded(child: _ContinueTile(label: s.continueGame, onTap: () => _run(widget.onContinue))),
                  ],
                ],
              );
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 960 : 520, maxHeight: wide ? 460 : 760),
                    child: wide
                        ? Row(
                            children: <Widget>[
                              Expanded(child: offlineColumn),
                              SizedBox(width: gap),
                              Expanded(child: online),
                            ],
                          )
                        : Column(
                            children: <Widget>[
                              Expanded(child: offlineColumn),
                              SizedBox(height: gap),
                              Expanded(child: online),
                            ],
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

/// A night-blue tablet tinted at the top with the tile's own colour, with a
/// gold edge.
BoxDecoration _tileDecoration(List<Color> colors) => BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.lerp(colors.first, const Color(0xFF0B1634), 0.5)!,
          const Color(0xFF14295A),
          const Color(0xFF0B1634),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ),
      border: Border.all(color: PastraColors.gold.withValues(alpha: 0.55), width: 1.5),
      boxShadow: <BoxShadow>[
        BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 10)),
        BoxShadow(color: colors.first.withValues(alpha: 0.18), blurRadius: 28),
      ],
    );

/// The gold of the main action, lighter at the top.
const BoxDecoration _goldDecoration = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(28)),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[PastraColors.goldLight, PastraColors.gold, Color(0xFFD9A234)],
    stops: <double>[0.0, 0.5, 1.0],
  ),
  border: Border.fromBorderSide(BorderSide(color: PastraColors.goldLight, width: 1.5)),
  boxShadow: <BoxShadow>[
    BoxShadow(color: PastraColors.goldDeep, offset: Offset(0, 5)),
    BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 10)),
  ],
);

/// Three cards fanned out.
class _Fan extends StatelessWidget {
  const _Fan({required this.cards, required this.cardWidth});

  final List<int> cards;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final cw = cardWidth;
    return SizedBox(
      width: cw * 2.4,
      height: cw * 1.42 + cw * 0.2,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: cw * 0.7 + (i - 1) * cw * 0.62,
              top: i == 1 ? 0 : cw * 0.1,
              width: cw,
              height: cw * 1.42,
              child: Transform.rotate(
                angle: (i - 1) * 0.26,
                child: PlayingCardView(card: cards[i], faceUp: true),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.hint,
    required this.icon,
    required this.colors,
    required this.cards,
    required this.onTap,
  });

  final String title;
  final String hint;
  final IconData icon;
  final List<Color> colors;
  final List<int> cards;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleText = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        title,
        style: const TextStyle(
          color: PastraColors.gold,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: <Shadow>[Shadow(color: Color(0xCC7A5210), offset: Offset(0, 2))],
        ),
      ),
    );
    final hintText = Text(
      hint,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.3),
    );
    return HoverLift(
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: _tileDecoration(colors),
          child: LayoutBuilder(
            builder: (context, box) {
              // Short tile (offline with "Continue" below it): art left, text right.
              if (box.maxHeight < 190) {
                final cw = ((box.maxHeight - 32) / 1.62).clamp(28.0, 80.0).toDouble();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: min(cw * 2.4, box.maxWidth * 0.42),
                        child: FittedBox(fit: BoxFit.scaleDown, child: _Fan(cards: cards, cardWidth: cw)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(icon, color: PastraColors.gold, size: 26),
                                const SizedBox(width: 8),
                                Flexible(child: titleText),
                              ],
                            ),
                            const SizedBox(height: 2),
                            hintText,
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              final cw = min(box.maxWidth * 0.26, 110.0);
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: FittedBox(fit: BoxFit.scaleDown, child: _Fan(cards: cards, cardWidth: cw)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(icon, color: PastraColors.gold, size: 30),
                        const SizedBox(width: 10),
                        Flexible(child: titleText),
                      ],
                    ),
                    const SizedBox(height: 4),
                    hintText,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
    );
  }
}

/// "Continue" bar under the offline tile.
class _ContinueTile extends StatelessWidget {
  const _ContinueTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: _goldDecoration,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.play_arrow_rounded, color: Color(0xFF2A1A00), size: 36),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF2A1A00), fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
