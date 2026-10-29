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
                // Icon above the text only in tiles that are high and not too wide.
                final tall = box.maxHeight.isFinite && box.maxHeight >= 130 && box.maxWidth < box.maxHeight * 1.7;
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
                final titleText = Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: tall ? TextAlign.center : TextAlign.start,
                  style: TextStyle(color: fg, fontSize: tall ? 26 : 21, fontWeight: FontWeight.w900),
                );
                final subText = subtitle == null
                    ? null
                    : Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: tall ? TextAlign.center : TextAlign.start,
                        style: TextStyle(color: sub, fontSize: 14, height: 1.25),
                      );
                if (tall) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        badge,
                        const SizedBox(height: 10),
                        titleText,
                        if (subText != null) ...<Widget>[const SizedBox(height: 4), subText],
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
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
      textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: text)
        : FilledButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 26), label: text);
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
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white54, width: 1.5),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: text)
        : OutlinedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 24), label: text);
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
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800),
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: PastraColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }
}
