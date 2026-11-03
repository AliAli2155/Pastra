import 'package:flutter/material.dart';

/// Colours of the "Aegean night" look: a night sky over the sea, warm
/// lantern gold, marble and copper.
class PastraColors {
  PastraColors._();

  // Night sky and sea.
  static const Color night = Color(0xFF040817);
  static const Color nightMid = Color(0xFF0A1636);
  static const Color nightLight = Color(0xFF14295A);
  static const Color sea = Color(0xFF1B4F9C);
  static const Color seaLight = Color(0xFF3E86D8);
  static const Color foam = Color(0xFFBFE3FF);

  // Warm lights: gold, lantern, copper, marble.
  static const Color gold = Color(0xFFF2C14E);
  static const Color goldLight = Color(0xFFFFE6A0);
  static const Color goldDeep = Color(0xFFB9821E);
  static const Color lantern = Color(0xFFFFA94D);
  static const Color terracotta = Color(0xFFC95F3C);
  static const Color marble = Color(0xFFF3EEE4);

  // Cards.
  static const Color cream = Color(0xFFFFFBF2);
  static const Color cardEdge = Color(0xFFB9B2A4);
  static const Color cardRed = Color(0xFFC62828);
  static const Color cardBlack = Color(0xFF1B1B1F);

  // Older names, now in the night palette.
  static const Color feltDark = night;
  static const Color felt = nightLight;
  static const Color feltLight = sea;
  static const Color navy = Color(0xFF0D3B8C);
  static const Color aegean = Color(0xFF1E6FD0);

  /// Dark tablet behind dialogs and panels.
  static const Color panel = Color(0xF00B1634);
}
