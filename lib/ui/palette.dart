import 'package:flutter/material.dart';

/// Colours of the dark premium look: charcoal surfaces, an emerald card
/// table with a wooden rim, gold for the main action and teal accents.
///
/// The older names (night, sea, …) are kept and now point at the new
/// colours, so every screen follows the same look.
class PastraColors {
  PastraColors._();

  // Charcoal surfaces, darkest first.
  static const Color night = Color(0xFF111316);
  static const Color nightMid = Color(0xFF181B20);
  static const Color nightLight = Color(0xFF23272E);
  static const Color raised = Color(0xFF2A2E36);

  // The card table: emerald cloth and a wooden rim.
  static const Color emeraldLight = Color(0xFF16A07A);
  static const Color emerald = Color(0xFF0D7356);
  static const Color emeraldDark = Color(0xFF064734);
  static const Color wood = Color(0xFF5A3D1E);
  static const Color woodDark = Color(0xFF2E1E0E);

  // Older names for the table colours.
  static const Color sea = emerald;
  static const Color seaLight = emeraldLight;
  static const Color foam = Color(0xFFA6EDE2);

  // Gold (main action, selection) and the other accents.
  static const Color gold = Color(0xFFE6B54A);
  static const Color goldLight = Color(0xFFF7E2B0);
  static const Color goldDeep = Color(0xFFB8862B);
  static const Color goldTop = Color(0xFFF2C866);
  static const Color goldBottom = Color(0xFFD9A033);

  /// Dark text on gold.
  static const Color goldInk = Color(0xFF1A1305);
  static const Color teal = Color(0xFF5FD3C2);
  static const Color coral = Color(0xFFF0785A);
  static const Color alert = Color(0xFFE04848);
  static const Color lantern = coral;
  static const Color terracotta = Color(0xFFC95F3C);

  // Text on charcoal.
  static const Color text = Color(0xFFF3EEE2);
  static const Color text2 = Color(0xFFA7B0BA);
  static const Color muted = Color(0xFF8C96A1);
  static const Color marble = text;

  /// Hairline edge of panels and glass controls.
  static const Color edge = Color(0x1AFFFFFF);

  /// Glass controls: a light veil over the charcoal.
  static const Color glass = Color(0x0FFFFFFF);

  // Cards.
  static const Color cream = Color(0xFFFBF8F1);
  static const Color cardEdge = Color(0xFFB9B2A4);
  static const Color cardRed = Color(0xFFB3261E);
  static const Color cardBlack = Color(0xFF14161A);
  static const Color cardBack = Color(0xFF1C1F25);

  // Older names, now in the charcoal palette.
  static const Color feltDark = night;
  static const Color felt = nightLight;
  static const Color feltLight = emerald;
  static const Color navy = cardBack;
  static const Color aegean = teal;

  /// Panels and dialogs.
  static const Color panel = Color(0xF2181B20);
}
