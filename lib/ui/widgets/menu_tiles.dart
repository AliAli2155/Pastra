import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Colour pairs for the big menu tiles.
class TileColors {
  TileColors._();

  static const List<Color> green = <Color>[Color(0xFF1F9D63), Color(0xFF0A5A39)];
  static const List<Color> blue = <Color>[Color(0xFF3A82D6), Color(0xFF15427A)];
  static const List<Color> gold = <Color>[Color(0xFFF2C14E), Color(0xFFC08A1E)];
  static const List<Color> purple = <Color>[Color(0xFF8A5CD0), Color(0xFF42207A)];
  static const List<Color> teal = <Color>[Color(0xFF26A69A), Color(0xFF0E5B54)];
  static const List<Color> red = <Color>[Color(0xFFD0505E), Color(0xFF7A1A2A)];
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
    final fg = darkText ? Colors.black87 : Colors.white;
    final sub = darkText ? Colors.black54 : Colors.white70;
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
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
                    shape: BoxShape.circle,
                    color: (darkText ? Colors.black : Colors.white).withValues(alpha: 0.16),
                  ),
                  child: Icon(icon, size: iconSize, color: fg),
                );
                // Long words (e.g. "Açık masalar") shrink instead of being cut.
                final titleText = FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: tall ? Alignment.center : Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(color: fg, fontSize: tall ? 26 : 21, fontWeight: FontWeight.w900),
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
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    return FilledButton(onPressed: onPressed, style: style, child: _ButtonLabel(label: label, icon: icon, iconSize: 26));
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

/// A big outlined button for the second action of a screen.
class BigOutlineButton extends StatelessWidget {
  const BigOutlineButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white54, width: 1.5),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    return OutlinedButton(onPressed: onPressed, style: style, child: _ButtonLabel(label: label, icon: icon, iconSize: 24));
  }
}

/// One option of a choice (players, difficulty …): a big card that is gold
/// when selected.
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
    final fg = selected ? Colors.black : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? PastraColors.gold : Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? PastraColors.gold : Colors.white24, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[Icon(icon, color: fg, size: 24), const SizedBox(width: 8)],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              if (hint != null)
                Text(
                  hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: selected ? Colors.black54 : Colors.white60, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
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
                    style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w800),
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
      decoration: BoxDecoration(
        color: PastraColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // In a fixed-size cell (the online grid) the content is centred and,
          // on a small screen, scaled down instead of overflowing.
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
