import 'package:flutter/material.dart';

/// Color palette harmonized with the official Solfa Logo & Sky/Cosmic Backgrounds.
class AppColors {
  // Core brand colors (Vibrant Royal Azure Blue + Glowing Cyan + Solfa Golden Orange)
  static const Color primary = Color(0xFF0B68E3);
  static const Color primaryDark = Color(0xFF074CB2);
  static const Color primaryLight = Color(0xFFE1F3FE);
  static const Color secondary = Color(0xFF00C2FF);
  static const Color secondaryLight = Color(0xFFE0F7FA);
  static const Color accentCyan = Color(0xFF00B4D8);
  static const Color accentAmber = Color(0xFFFF9800);
  static const Color accentCoral = Color(0xFFFF5E7E);

  // Light mode surfaces & high-contrast navy typography (for bg_light.jpg)
  static const Color backgroundLight = Color(0xFFD8F2FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF082046);
  static const Color textSecondaryLight = Color(0xFF34527E);

  // Dark mode surfaces & crisp starlight typography (for bg_dark.jpg)
  static const Color backgroundDark = Color(0xFF040714);
  static const Color surfaceDark = Color(0xFF0A1026);
  static const Color textPrimaryDark = Color(0xFFF4F8FF);
  static const Color textSecondaryDark = Color(0xFFA8C0E8);

  // Semantic feedback colors
  static const Color correct = Color(0xFF16B374);
  static const Color correctBgLight = Color(0xFFE5F9F0);
  static const Color correctBgDark = Color(0xFF0F382B);

  static const Color wrong = Color(0xFFE85656);
  static const Color wrongBgLight = Color(0xFFFEECEC);
  static const Color wrongBgDark = Color(0xFF3E1926);

  static const Color warning = Color(0xFFFF9800);

  /// Topic-specific harmonious accent color helper
  static Color topicAccent(String code) {
    switch (code) {
      case 'note_recognition':
      case 'notes':
        return const Color(0xFF0B68E3);
      case 'interval_recognition':
      case 'intervals':
        return const Color(0xFF0FA97A);
      case 'key_recognition':
      case 'chords':
        return const Color(0xFFF58216);
      default:
        return primary;
    }
  }
}
