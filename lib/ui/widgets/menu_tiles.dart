import 'dart:math';

import 'package:flutter/material.dart';

import '../ege/widgets.dart';
import '../premium/premium.dart';
import '../theme.dart';

/// Colour pairs for the big menu tiles.
class TileColors {
  TileColors._();

  static const List<Color> green = <Color>[Color(0xFF2E9A78), Color(0xFF0F4B45)];
  static const List<Color> blue = <Color>[Color(0xFF3E7BD8), Color(0xFF173B82)];
  static const List<Color> gold = <Color>[Color(0xFFE6B54A), Color(0xFFB8862B)];
  static const List<Color> purple = <Color>[Color(0xFF7B5CD0), Color(0xFF34207A)];
  static const List<Color> teal = <Color>[Color(0xFF2BB1B1), Color(0xFF0E5560)];
  static const List<Color> red = <Color>[Color(0xFFD0613E), Color(0xFF7A2A1A)];
}

/// A big, easy to hit tile with a gradient, an icon, a title and an optional
/// line under it. Tall tiles stack the icon above the text; low ones put it
/// on the left.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.darkText = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Color> colors;
  final VoidCallback? onTap;

  /// Black text (for the gold tile).
  final bool darkText;

  @override
  Widget build(BuildContext context) {
    final fg = darkText ? PastraColors.goldInk : PastraColors.text;
    final sub = darkText ? const Color(0xB31A1305) : PastraColors.text2;
    // The tile's colour tints its icon.
    final accent = darkText ? PastraColors.goldInk : Color.lerp(colors.first, Colors.white, 0.15)!;
    final enabled = onTap != null;
    return HoverLift(
      enabled: enabled,
      child: Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            // A charcoal panel with a hairline (the gold tile stays gold: it
            // is the main action).
            decoration: darkText
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: goldGradient,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: PastraColors.goldBottom.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  )
                : panelDecoration(radius: 20),
            child: LayoutBuilder(
              builder: (context, box) {
                // Icon above the text only in tiles that are high enough for it
                // (more with a line under the title) and not too wide.
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final needed = (subtitle == null ? 140.0 : 215.0) * scale;
                final tall = box.maxHeight.isFinite && box.maxHeight >= needed && box.maxWidth < box.maxHeight * 1.7;
                final iconSize = tall ? min(64.0, box.maxHeight * 0.3) : 30.0;
                final badge = Container(
                  width: iconSize + 18,
                  height: iconSize + 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular((iconSize + 18) * 0.26),
                    color: accent.withValues(alpha: darkText ? 0.12 : 0.16),
                  ),
                  child: Icon(icon, size: iconSize, color: accent),
                );
                // Long words (e.g. "Açık masalar") shrink instead of being cut.
                final titleText = FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: tall ? Alignment.center : Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(color: fg, fontSize: tall ? 24 : 19, fontWeight: FontWeight.w800),
                  ),
                );
                final subText = subtitle == null
                    ? null
                    : Text(
                        subtitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: tall ? TextAlign.center : TextAlign.start,
                        style: TextStyle(color: sub, fontSize: 14, height: 1.25),
                      );
                // Whatever happens, the content is scaled down to fit the tile
                // instead of spilling over its edge.
                Widget fit(Widget child, EdgeInsets pad) {
                  if (!box.maxHeight.isFinite) return Padding(padding: pad, child: child);
                  return Padding(
                    padding: pad,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(width: max(0.0, box.maxWidth - pad.horizontal), child: child),
                    ),
                  );
                }
                if (tall) {
                  return fit(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        badge,
                        const SizedBox(height: 10),
                        titleText,
                        if (subText != null) ...<Widget>[const SizedBox(height: 4), subText],
                      ],
                    ),
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  );
                }
                return fit(
                  Row(
                    children: <Widget>[
                      badge,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[titleText, if (subText != null) subText],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: sub, size: 30),
                    ],
                  ),
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                );
              },
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// On a computer: the widget grows a little under the mouse (and the
/// pointer becomes a hand). Nothing changes on touch screens.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.enabled = true, this.scale = 1.02});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover && widget.enabled ? widget.scale : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A big gold button (at least 56 high) for the main action of a screen.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return BevelButton(
      onPressed: onPressed,
      shimmer: true,
      child: _ButtonLabel(label: label, icon: icon, iconSize: 26),
    );
  }
}

/// Icon and text of a big button; the text shrinks instead of being cut.
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.icon, required this.iconSize});

  final String label;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[Icon(icon, size: iconSize), const SizedBox(width: 8)],
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1))),
      ],
    );
  }
}

/// A big dark-blue button for the second action of a screen.
class BigOutlineButton extends StatelessWidget {
  const BigOutlineButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return BevelButton(
      onPressed: onPressed,
      gold: false,
      height: 52,
      fontSize: 17,
      child: _ButtonLabel(label: label, icon: icon, iconSize: 24),
    );
  }
}

/// One option of a choice (players, difficulty …): a glass pill with a gold
/// edge when selected.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.hint,
  });

  final String label;
  final String? hint;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoicePill(label: label, hint: hint, icon: icon, selected: selected, onTap: onTap, minHeight: 56);
  }
}

/// A dark rounded panel with an optional gold title (and a widget at the
/// right end of the title row).
class MenuPanel extends StatelessWidget {
  const MenuPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null) ...<Widget>[
          SizedBox(
            height: 30,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PastraColors.text, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    );
    return Container(
        padding: padding,
        decoration: tabletDecoration(radius: 22),
        child: LayoutBuilder(
          builder: (context, box) {
            // In a fixed-size cell (the online grid) the content is centred
            // and, on a small screen, scaled down instead of overflowing.
            // Only when the panel is given an exact height (a grid cell).
            if (!box.hasTightHeight || !box.maxWidth.isFinite) return content;
            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: box.maxWidth, child: content),
              ),
            );
          },
        ),
      );
  }
}
