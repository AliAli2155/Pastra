import 'package:flutter/material.dart';

import '../palette.dart';

/// Building blocks of the dark premium look: charcoal panels, glass
/// controls and gold for the main action. Nothing here moves by itself:
/// a control only animates while it is pressed or under the mouse.

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
                    maxLines: 1,
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
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
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
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: PremiumText.secondary),
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
  const LobbyTile({super.key, required this.icon, required this.label, required this.onTap, this.height = 64});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      radius: BorderRadius.circular(14),
      decoration: glassDecoration(radius: 14),
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: PastraColors.text, size: 21),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(color: Color(0xFFC9D0D8), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dialog in the premium look: a charcoal panel with a hairline edge.
class PremiumDialog extends StatelessWidget {
  const PremiumDialog({super.key, required this.child, this.maxWidth = 580});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PastraColors.nightMid,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: PastraColors.edge),
      ),
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
