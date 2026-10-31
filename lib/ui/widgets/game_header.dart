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
  Widget build(BuildContext context) => GameAppBar(title: Text(title), icon: icon, actions: trailing);
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

/// The bar at the top of every menu screen (instead of the plain app bar):
/// the round back button, a gold title with its icon and the screen's
/// buttons on the right, on a dark band that suits every table colour.
class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GameAppBar({super.key, required this.title, this.icon, this.actions = const <Widget>[], this.bottom});

  final Widget title;
  final IconData? icon;
  final List<Widget> actions;

  /// Tabs under the title.
  final PreferredSizeWidget? bottom;

  static const double height = 56;

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom == null ? 0 : bottom!.preferredSize.height + 8));

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.28)],
        ),
        border: Border(bottom: BorderSide(color: PastraColors.gold.withValues(alpha: 0.18))),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: <Widget>[
                    if (canPop) ...<Widget>[
                      const _RoundBack(),
                      const SizedBox(width: 12),
                    ],
                    if (icon != null) ...<Widget>[
                      Icon(icon, color: PastraColors.gold, size: 24),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: DefaultTextStyle.merge(
                            style: const TextStyle(
                              color: PastraColors.gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            child: title,
                          ),
                        ),
                      ),
                    ),
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 8),
                      // The buttons keep their size (up to 60% of the bar);
                      // the title gets smaller first.
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.6),
                        child: IconTheme.merge(
                          data: const IconThemeData(color: Colors.white, size: 24),
                          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[for (final a in actions) Flexible(child: a)]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 8), child: bottom!),
          ],
        ),
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Material(
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
    );
  }
}
