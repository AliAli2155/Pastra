import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/progression.dart';

/// Colours of an avatar frame (a ring around the player's initial).
List<Color> frameColors(AvatarFrame f) => switch (f) {
      AvatarFrame.none => const <Color>[Color(0x33FFFFFF), Color(0x33FFFFFF)],
      AvatarFrame.bronze => const <Color>[Color(0xFFE3A869), Color(0xFF8C5523), Color(0xFFCD7F32)],
      AvatarFrame.silver => const <Color>[Color(0xFFFFFFFF), Color(0xFF9EA4AA), Color(0xFFE0E3E6)],
      AvatarFrame.gold => const <Color>[Color(0xFFFFE9A6), Color(0xFFC9A227), Color(0xFFF2C14E)],
      AvatarFrame.jade => const <Color>[Color(0xFFA8F0CC), Color(0xFF1B8A5A), Color(0xFF5BD69A)],
      AvatarFrame.ruby => const <Color>[Color(0xFFFF8FA0), Color(0xFFA30D2A), Color(0xFFE5304F)],
      AvatarFrame.sapphire => const <Color>[Color(0xFF9CC4FF), Color(0xFF1A44A6), Color(0xFF4C7FE6)],
      AvatarFrame.diamond => const <Color>[Color(0xFFFFFFFF), Color(0xFF7FD8F0), Color(0xFFE0FBFF), Color(0xFF9BE3F5)],
      AvatarFrame.legend => const <Color>[
          Color(0xFFF2C14E),
          Color(0xFFE5304F),
          Color(0xFF9B4DE0),
          Color(0xFF4C7FE6),
          Color(0xFF5BD69A),
          Color(0xFFF2C14E),
        ],
    };

/// The player's initial in a circle, with the frame they chose.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.name, this.frame = AvatarFrame.none, this.size = 48});

  final String name;
  final AvatarFrame frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final ring = frame == AvatarFrame.none ? 0.0 : math.max(2.5, size * 0.075);
    final colors = frameColors(frame);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: frame == AvatarFrame.none
            ? null
            : SweepGradient(colors: colors, transform: const GradientRotation(-math.pi / 2)),
        boxShadow: frame.index >= AvatarFrame.gold.index
            ? <BoxShadow>[BoxShadow(color: colors[1].withValues(alpha: 0.55), blurRadius: size * 0.22)]
            : null,
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF2E7D5B), Color(0xFF0A4A30)],
          ),
        ),
        child: Text(
          initial,
          style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900, height: 1),
        ),
      ),
    );
  }
}
