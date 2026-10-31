import 'package:flutter/material.dart';

import '../theme.dart';

/// A slim game-style header instead of an app bar (the game is played
/// sideways, so every pixel of height counts): a round back button, a gold
/// title and optional widgets on the right.
class GameHeader extends StatelessWidget {
  const GameHeader({super.key, required this.title, this.icon, this.trailing = const <Widget>[]});

  final String title;
  final IconData? icon;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 4),
      child: Row(
        children: <Widget>[
          Material(
            color: Colors.black.withValues(alpha: 0.3),
            shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (icon != null) ...<Widget>[
            Icon(icon, color: PastraColors.gold, size: 26),
            const SizedBox(width: 8),
          ],
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: GoldText(title, size: 26, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[for (final w in trailing) Flexible(child: w)]),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small rounded label (countdown, XP total, …) for the header.
class HeaderPill extends StatelessWidget {
  const HeaderPill({super.key, required this.icon, required this.text, this.color = PastraColors.gold});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
