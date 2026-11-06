import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../premium/premium.dart';
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
        color: PastraColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          // Shrinks a little on a narrow phone instead of being cut.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text, maxLines: 1, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar at the top of every menu screen (instead of the plain app bar):
/// a glass back button, the title with its gold icon and the screen's
/// buttons on the right, on a charcoal band with a hairline under it.
class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GameAppBar({super.key, required this.title, this.icon, this.actions = const <Widget>[], this.bottom});

  final Widget title;
  final IconData? icon;
  final List<Widget> actions;

  /// Tabs under the title.
  final PreferredSizeWidget? bottom;

  /// Slimmer on a phone held sideways, where every pixel of height counts.
  static double get height {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return 56;
    final v = views.first;
    return v.physicalSize.height / v.devicePixelRatio < 460 ? 46 : 56;
  }

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom == null ? 0 : bottom!.preferredSize.height + 8));

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xE6111316),
        border: Border(bottom: BorderSide(color: PastraColors.edge)),
      ),
      child: _content(context, canPop),
    );
  }

  Widget _content(BuildContext context, bool canPop) {
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              // The title in the middle of the bar, the back button on the
              // left and the screen's buttons on the right.
              child: NavigationToolbar(
                middleSpacing: 12,
                // The toolbar stretches its ends to the full height: centred,
                // the buttons keep their own size.
                leading: canPop ? const Center(widthFactor: 1, child: _RoundBack()) : null,
                middle: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        Icon(icon, color: PastraColors.gold, size: 24),
                        const SizedBox(width: 8),
                      ],
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          color: PastraColors.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        child: title,
                      ),
                    ],
                  ),
                ),
                trailing: actions.isEmpty
                    ? null
                    // The buttons keep their size (up to 45% of the bar); the
                    // title gets smaller first.
                    : Center(
                        widthFactor: 1,
                        child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
                        child: IconTheme.merge(
                          data: const IconThemeData(color: PastraColors.text, size: 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[for (final a in actions) Flexible(child: a)],
                          ),
                        ),
                      ),
                      ),
              ),
            ),
          ),
          if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 8), child: bottom!),
        ],
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack();

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}
