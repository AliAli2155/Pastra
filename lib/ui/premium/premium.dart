import 'package:flutter/material.dart';

import '../fx/fx.dart';
import '../palette.dart';

/// Building blocks of the dark premium look: charcoal panels, glass
/// controls and gold for the main action. Nothing here keeps moving by
/// itself: a control animates while it is pressed or under the mouse, a
/// screen, a section or a dialog only as it arrives.

/// Text styles of the look (the font family comes from the theme).
abstract final class PremiumText {
  static const TextStyle eyebrow = TextStyle(
    color: PastraColors.gold,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.4,
  );
  static const TextStyle display = TextStyle(
    color: PastraColors.text,
    fontSize: 60,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -1,
  );
  static const TextStyle title = TextStyle(color: PastraColors.text, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1);
  static const TextStyle section = TextStyle(color: PastraColors.text, fontSize: 18, fontWeight: FontWeight.w700);
  static const TextStyle body = TextStyle(color: PastraColors.text, fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle secondary = TextStyle(color: PastraColors.text2, fontSize: 13, fontWeight: FontWeight.w500);
  static const TextStyle label = TextStyle(color: PastraColors.text2, fontSize: 13, fontWeight: FontWeight.w600);
}

/// The face of the gold buttons.
const LinearGradient goldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[PastraColors.goldTop, PastraColors.goldBottom],
);

/// A charcoal panel with a hairline edge; [highlight] gives it a gold edge
/// and a faint gold light.
BoxDecoration panelDecoration({double radius = 20, bool highlight = false, bool shadow = true}) {
  return BoxDecoration(
    color: PastraColors.nightMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: highlight ? PastraColors.gold.withValues(alpha: 0.75) : PastraColors.edge),
    boxShadow: <BoxShadow>[
      if (shadow) BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
      if (highlight) BoxShadow(color: PastraColors.gold.withValues(alpha: 0.18), blurRadius: 18),
    ],
  );
}

/// A glass control: a light veil and a hairline; tinted gold when selected.
BoxDecoration glassDecoration({double radius = 14, bool selected = false}) {
  return BoxDecoration(
    color: selected ? PastraColors.gold.withValues(alpha: 0.14) : PastraColors.glass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: selected ? PastraColors.gold : Colors.white.withValues(alpha: 0.12),
      width: selected ? 1.5 : 1,
    ),
  );
}

/// The background of the menu screens: a still charcoal gradient with a
/// soft light at the top left.
class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.25, -0.75),
          radius: 1.4,
          colors: <Color>[Color(0xFF23272E), Color(0xFF15171B), Color(0xFF0C0D10)],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// A tappable surface: shrinks a little while pressed and grows a little
/// under the mouse.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.radius,
    this.decoration,
    this.tooltip,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final Decoration? decoration;
  final String? tooltip;
  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget body = Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: widget.decoration,
        child: InkWell(
          borderRadius: widget.radius,
          autofocus: widget.autofocus,
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _down = v),
          onHover: (v) => setState(() => _hover = v),
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          child: widget.child,
        ),
      ),
    );
    body = AnimatedScale(
      scale: _down ? 0.97 : (_hover && enabled ? 1.015 : 1.0),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: body,
    );
    if (!enabled) body = Opacity(opacity: 0.45, child: body);
    if (widget.tooltip != null) body = Tooltip(message: widget.tooltip!, child: body);
    return body;
  }
}

/// Icon and text of a button; the text shrinks instead of being cut (so
/// the button needs a bounded width: in a [Row], wrap it in [Flexible]).
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.icon, required this.style});

  final String label;
  final IconData? icon;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: (style.fontSize ?? 18) + 4, color: style.color),
          const SizedBox(width: 8),
        ],
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: style))),
      ],
    );
  }
}

/// The main action of a screen: a gold button with dark text.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
    this.fontSize = 19,
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double fontSize;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(height >= 52 ? 14 : 12);
    return SizedBox(
      height: height,
      child: Pressable(
        onTap: onPressed,
        radius: r,
        autofocus: autofocus,
        decoration: BoxDecoration(
          gradient: goldGradient,
          borderRadius: r,
          boxShadow: <BoxShadow>[
            BoxShadow(color: PastraColors.goldBottom.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: padding,
          // As wide as the label unless the parent sets the width.
          child: Center(
            widthFactor: 1,
            child: _ButtonLabel(
              label: label,
              icon: icon,
              style: TextStyle(color: PastraColors.goldInk, fontSize: fontSize, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

/// A second action: a glass button with light text.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(height >= 52 ? 14 : 12);
    return SizedBox(
      height: height,
      child: Pressable(
        onTap: onPressed,
        radius: r,
        decoration: glassDecoration(radius: r.topLeft.x),
        child: Padding(
          padding: padding,
          // As wide as the label unless the parent sets the width.
          child: Center(
            widthFactor: 1,
            child: _ButtonLabel(
              label: label,
              icon: icon,
              style: TextStyle(color: PastraColors.text, fontSize: fontSize, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// A square glass button with an icon (back, settings, chat …).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.color = PastraColors.text,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * 0.27);
    return SizedBox.square(
      dimension: size,
      child: Pressable(
        onTap: onPressed,
        radius: r,
        tooltip: tooltip,
        decoration: glassDecoration(radius: r.topLeft.x),
        child: Center(child: Icon(icon, color: color, size: size * 0.5)),
      ),
    );
  }
}

/// One option of a choice (players, difficulty, target …): glass, gold
/// edge and tint when selected.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.icon,
    this.minHeight,
  });

  final String label;
  final String? hint;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? PastraColors.goldLight : PastraColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        radius: BorderRadius.circular(12),
        decoration: glassDecoration(radius: 12, selected: selected),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight ?? (hint == null ? 48 : 60)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[Icon(icon, color: fg, size: 20), const SizedBox(width: 6)],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1, style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                if (hint != null)
                  Text(
                    hint!,
                    // Long languages (or a narrow phone) get more lines.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded square with a tinted icon (the start of a list row).
class IconSquare extends StatelessWidget {
  const IconSquare({super.key, required this.icon, required this.color, this.size = 46});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// A small round number (things to collect, unread …).
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.color = PastraColors.coral});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
      child: Text(
        '$count',
        style: const TextStyle(color: Color(0xFF1A0E0A), fontSize: 12, fontWeight: FontWeight.w800, height: 1),
      ),
    );
  }
}

/// A row of a menu list: tinted icon, title, a line under it and a chevron
/// (or a count of things waiting).
class ModeRow extends StatelessWidget {
  const ModeRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge = 0,
    this.height = 76,
    this.subtitleLines = 1,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;

  /// Lines the subtitle may take before it is cut with "…".
  final int subtitleLines;
  final VoidCallback? onTap;
  final int badge;
  final double height;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(16);
    return Pressable(
      onTap: onTap,
      radius: r,
      decoration: glassDecoration(radius: 16),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              IconSquare(icon: icon, color: accent, size: (height * 0.6).clamp(36.0, 46.0).toDouble()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PastraColors.text, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: subtitleLines,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumText.secondary,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (badge > 0)
                CountBadge(count: badge)
              else
                const Icon(Icons.chevron_right_rounded, color: PastraColors.text2, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small square tile: an icon over a short label.
class LobbyTile extends StatelessWidget {
  const LobbyTile({super.key, required this.icon, required this.label, required this.onTap, this.height = 64, this.badge = 0});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double height;

  /// Things waiting behind the tile (a coral count in its corner).
  final int badge;

  @override
  Widget build(BuildContext context) {
    final tile = _tile();
    if (badge <= 0) return tile;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        tile,
        Positioned(top: -6, right: -6, child: IgnorePointer(child: CountBadge(count: badge))),
      ],
    );
  }

  Widget _tile() {
    return Pressable(
      onTap: onTap,
      radius: BorderRadius.circular(14),
      decoration: glassDecoration(radius: 14),
      child: SizedBox(
        height: height,
        // A tall tile (filling a column) gets a bigger icon and label.
        child: LayoutBuilder(
          builder: (context, box) {
            final big = box.maxHeight.isFinite && box.maxHeight > 110;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (big)
                  IconSquare(icon: icon, color: PastraColors.gold, size: 52)
                else
                  Icon(icon, color: PastraColors.text, size: 21),
                SizedBox(height: big ? 10 : 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: big ? PastraColors.text : const Color(0xFFC9D0D8),
                        fontSize: big ? 15 : 12,
                        fontWeight: big ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A dialog in the premium look: a charcoal panel with a hairline edge.
/// It grows a little while it fades in (and shrinks while it goes).
class PremiumDialog extends StatelessWidget {
  const PremiumDialog({super.key, required this.child, this.maxWidth = 580});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => DialogPop(child: _dialog(context));

  Widget _dialog(BuildContext context) {
    return Dialog(
      backgroundColor: PastraColors.nightMid,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: PastraColors.edge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // A low screen (a phone held sideways): the whole dialog is scaled
        // down to fit instead of scrolling.
        child: MediaQuery.sizeOf(context).height < 480
            ? LayoutBuilder(
                builder: (context, box) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: box.maxWidth, child: child),
                ),
              )
            : child,
      ),
    );
  }
}

/// Lets a dialog grow a little while it fades in (and shrink while it
/// goes), with the animation of its route.
class DialogPop extends StatelessWidget {
  const DialogPop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.animation;
    if (route == null) return child;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(
        CurvedAnimation(parent: route, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
      ),
      child: child,
    );
  }
}

/// One section of a [SideTabs] page.
class PageTab {
  const PageTab({required this.icon, required this.label, required this.builder, this.badge = 0});

  final IconData icon;
  final String label;

  /// Builds the section (it scrolls by itself, see [TabBody]).
  final WidgetBuilder builder;

  /// Things waiting in this section (a coral count on the tab).
  final int badge;
}

/// A page split into sections: on a wide screen the sections are a column
/// of glass rows on the left and the chosen one fills the right; on a
/// narrow one they are a row of pills at the top.
class SideTabs extends StatefulWidget {
  const SideTabs({super.key, required this.tabs, this.initial = 0, this.onChanged});

  final List<PageTab> tabs;
  final int initial;
  final ValueChanged<int>? onChanged;

  /// Screens at least this wide get the column of tabs on the left.
  static const double wideFrom = 720;

  @override
  State<SideTabs> createState() => _SideTabsState();
}

class _SideTabsState extends State<SideTabs> {
  late int _index = widget.initial.clamp(0, widget.tabs.length - 1);

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    widget.onChanged?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= SideTabs.wideFrom;
        // A new section fades in and rises a little into place.
        final content = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: _sectionTransition,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: <Widget>[...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: TabScope(wide: wide, child: Builder(builder: widget.tabs[_index].builder)),
          ),
        );
        if (wide) {
          // On a low screen (a phone held sideways) the rows get closer and
          // a little lower, so that every section fits without scrolling.
          final n = widget.tabs.length;
          final roomy = 32 + n * 48.0 + (n - 1) * 8 <= box.maxHeight;
          final pad = roomy ? 16.0 : 8.0;
          final gap = roomy ? 8.0 : 4.0;
          final rowHeight = roomy ? 48.0 : ((box.maxHeight - 2 * pad + gap) / n - gap).clamp(34.0, 48.0).toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: box.maxWidth >= 1000 ? 248 : 206,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, pad, 8, pad),
                  children: <Widget>[
                    for (var i = 0; i < n; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i < n - 1 ? gap : 0),
                        child: _RailItem(
                          tab: widget.tabs[i],
                          selected: i == _index,
                          onTap: () => _select(i),
                          height: rowHeight,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: <Widget>[
                  for (var i = 0; i < widget.tabs.length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: _PillItem(tab: widget.tabs[i], selected: i == _index, onTap: () => _select(i)),
                    ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

Widget _sectionTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.translate(offset: Offset(0, 10 * (1 - animation.value)), child: child),
    ),
  );
}

/// Tells a section whether it is shown next to the column of tabs.
class TabScope extends InheritedWidget {
  const TabScope({super.key, required this.wide, required super.child});

  final bool wide;

  static bool wideOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabScope>()?.wide ?? MediaQuery.sizeOf(context).width >= SideTabs.wideFrom;

  @override
  bool updateShouldNotify(TabScope oldWidget) => oldWidget.wide != wide;
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.tab, required this.selected, required this.onTap, this.height = 48});

  final PageTab tab;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? PastraColors.goldLight : PastraColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        radius: BorderRadius.circular(12),
        decoration: selected
            ? glassDecoration(radius: 12, selected: true)
            : BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.transparent)),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Icon(tab.icon, size: 20, color: selected ? PastraColors.gold : PastraColors.text2),
                const SizedBox(width: 12),
                Expanded(
                  // A long section name shrinks a little instead of being cut.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      style: TextStyle(color: fg, fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
                    ),
                  ),
                ),
                if (tab.badge > 0) CountBadge(count: tab.badge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({required this.tab, required this.selected, required this.onTap});

  final PageTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        radius: BorderRadius.circular(20),
        decoration: glassDecoration(radius: 20, selected: selected),
        child: SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(tab.icon, size: 17, color: selected ? PastraColors.gold : PastraColors.text2),
                const SizedBox(width: 7),
                Text(
                  tab.label,
                  style: TextStyle(
                    color: selected ? PastraColors.goldLight : PastraColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (tab.badge > 0) ...<Widget>[const SizedBox(width: 6), CountBadge(count: tab.badge)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The scrolling body of a section: its panels one under the other, at a
/// readable width.
class TabBody extends StatelessWidget {
  const TabBody({super.key, required this.children, this.maxWidth = 820});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = TabScope.wideOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, wide ? 16 : 8, 16, 28),
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 14),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A charcoal panel with an optional title row (tinted icon, title, a
/// widget at the end).
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.accent = PastraColors.gold,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.highlight = false,
    this.expand = false,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color accent;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool highlight;

  /// Fill the height it is given (the child gets what is left under the
  /// title).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: panelDecoration(radius: 18, highlight: highlight, shadow: false),
      // Own (see-through) Material: ripples of switches and buttons show on it.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    IconSquare(icon: icon!, color: accent, size: 34),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumText.section,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (expand) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

/// A row with a label (and a line under it) and a control at the end
/// (a switch, a value …).
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.label, required this.trailing, this.hint, this.icon});

  final String label;
  final String? hint;
  final IconData? icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: PastraColors.text2),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: PremiumText.body),
                if (hint != null) Text(hint!, style: PremiumText.secondary),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

/// Children in as many equal columns as fit (each at least [minItemWidth]
/// wide), row after row.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 200,
    this.spacing = 12,
    this.maxColumns = 6,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final columns = ((w + spacing) ~/ (minItemWidth + spacing)).clamp(1, maxColumns);
        final itemWidth = (w - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          // A last, shorter row sits in the middle.
          alignment: WrapAlignment.center,
          children: <Widget>[for (final c in children) SizedBox(width: itemWidth, child: c)],
        );
      },
    );
  }
}

/// Plays the arrival of a screen once: its parts ([EntranceItem]) fade in
/// and rise into place one after the other. Nothing moves afterwards, and
/// in low graphics quality nothing moves at all.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child});

  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
    value: Fx.low.value ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (_c.value < 1) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EntranceScope(animation: _c, child: widget.child);
}

class _EntranceScope extends InheritedWidget {
  const _EntranceScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_EntranceScope oldWidget) => oldWidget.animation != animation;
}

/// One part of an [Entrance]: the [order]-th to arrive (0 first). The
/// [builder] gets how far it has arrived (0 → 1; 1 outside an [Entrance]).
class EntranceBuilder extends StatelessWidget {
  const EntranceBuilder({super.key, required this.order, required this.builder, this.child});

  final int order;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final parent = context.dependOnInheritedWidgetOfExactType<_EntranceScope>()?.animation;
    if (parent == null) return builder(context, 1, child);
    final start = (order * 0.08).clamp(0.0, 0.5).toDouble();
    final t = CurvedAnimation(parent: parent, curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic));
    return AnimatedBuilder(animation: t, child: child, builder: (context, child) => builder(context, t.value, child));
  }
}

/// One part of an [Entrance] that fades in and rises [rise] pixels into
/// place, the [order]-th to arrive (0 first).
class EntranceItem extends StatelessWidget {
  const EntranceItem({super.key, required this.order, required this.child, this.rise = 16});

  final int order;
  final double rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return EntranceBuilder(
      order: order,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset(0, rise * (1 - t)), child: child),
      ),
    );
  }
}
