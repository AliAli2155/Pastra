import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/cards.dart';
import '../../game/avatar_pic.dart';
import '../../game/progression.dart';
import 'suit_icon.dart';

/// What each avatar picture shows: a suit, or an icon in its own colour.
({IconData? icon, int? suit, Color color}) avatarArt(AvatarPic p) => switch (p) {
      AvatarPic.letter => (icon: null, suit: null, color: const Color(0xFFF3EEE2)),
      AvatarPic.spade => (icon: null, suit: Cards.spades, color: const Color(0xFFF3EEE2)),
      AvatarPic.heart => (icon: null, suit: Cards.hearts, color: const Color(0xFFE05A47)),
      AvatarPic.diamond => (icon: null, suit: Cards.diamonds, color: const Color(0xFFE05A47)),
      AvatarPic.club => (icon: null, suit: Cards.clubs, color: const Color(0xFFF3EEE2)),
      AvatarPic.anchor => (icon: Icons.anchor_rounded, suit: null, color: const Color(0xFF7FB8F0)),
      AvatarPic.sun => (icon: Icons.wb_sunny_rounded, suit: null, color: const Color(0xFFF2C866)),
      AvatarPic.boat => (icon: Icons.sailing_rounded, suit: null, color: const Color(0xFF5FD3C2)),
      AvatarPic.olive => (icon: Icons.eco_rounded, suit: null, color: const Color(0xFF8FCB6A)),
      AvatarPic.cat => (icon: Icons.pets_rounded, suit: null, color: const Color(0xFFF0A65A)),
      AvatarPic.star => (icon: Icons.star_rounded, suit: null, color: const Color(0xFFF2C866)),
      AvatarPic.bolt => (icon: Icons.bolt_rounded, suit: null, color: const Color(0xFFFFD54F)),
      AvatarPic.castle => (icon: Icons.castle_rounded, suit: null, color: const Color(0xFFC9D0D8)),
      AvatarPic.fire => (icon: Icons.local_fire_department_rounded, suit: null, color: const Color(0xFFF0785A)),
      AvatarPic.music => (icon: Icons.music_note_rounded, suit: null, color: const Color(0xFFC08CF0)),
      AvatarPic.gem => (icon: Icons.diamond_rounded, suit: null, color: const Color(0xFF7FD8F5)),
      AvatarPic.crown => (icon: Icons.workspace_premium_rounded, suit: null, color: const Color(0xFFE6B54A)),
      AvatarPic.rocket => (icon: Icons.rocket_launch_rounded, suit: null, color: const Color(0xFFF07AA8)),
    };

/// Colours of an avatar frame (a ring around the player's initial).
List<Color> frameColors(AvatarFrame f) => switch (f) {
      AvatarFrame.none => const <Color>[Color(0x33FFFFFF), Color(0x33FFFFFF)],
      AvatarFrame.bronze => const <Color>[Color(0xFFE3A869), Color(0xFF8C5523), Color(0xFFCD7F32)],
      AvatarFrame.silver => const <Color>[Color(0xFFFFFFFF), Color(0xFF9EA4AA), Color(0xFFE0E3E6)],
      AvatarFrame.gold => const <Color>[Color(0xFFFFE9A6), Color(0xFFC9A227), Color(0xFFE6B54A)],
      AvatarFrame.jade => const <Color>[Color(0xFFA8F0CC), Color(0xFF1B8A5A), Color(0xFF5BD69A)],
      AvatarFrame.ruby => const <Color>[Color(0xFFFF8FA0), Color(0xFFA30D2A), Color(0xFFE5304F)],
      AvatarFrame.sapphire => const <Color>[Color(0xFF9CC4FF), Color(0xFF1A44A6), Color(0xFF4C7FE6)],
      AvatarFrame.diamond => const <Color>[Color(0xFFFFFFFF), Color(0xFF7FD8F0), Color(0xFFE0FBFF), Color(0xFF9BE3F5)],
      AvatarFrame.legend => const <Color>[
          Color(0xFFE6B54A),
          Color(0xFFE5304F),
          Color(0xFF9B4DE0),
          Color(0xFF4C7FE6),
          Color(0xFF5BD69A),
          Color(0xFFE6B54A),
        ],
    };

/// The player's initial (or the picture they chose) in a circle, with the
/// frame they chose.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.frame = AvatarFrame.none,
    this.size = 48,
    this.pic = AvatarPic.letter,
  });

  final String name;
  final AvatarFrame frame;
  final double size;
  final AvatarPic pic;

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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2A2E36),
          border: frame == AvatarFrame.none ? Border.all(color: const Color(0x33FFFFFF), width: 1.5) : null,
        ),
        child: _picture(initial),
      ),
    );
  }

  Widget _picture(String initial) {
    final art = avatarArt(pic);
    if (art.suit != null) return SuitIcon(suit: art.suit!, size: size * 0.46, color: art.color);
    if (art.icon != null) return Icon(art.icon, size: size * 0.52, color: art.color);
    return Text(
      initial,
      style: TextStyle(color: art.color, fontSize: size * 0.42, fontWeight: FontWeight.w700, height: 1),
    );
  }
}
