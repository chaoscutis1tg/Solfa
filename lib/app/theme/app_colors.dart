import 'package:flutter/material.dart';

/// Unified Modern Minimalist Color System for Solfa Studio.
/// Uses 1 Primary brand color and strictly controlled semantic accents.
class AppColors {
  // 1 Primary Brand Color & Controlled Accents
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color secondaryLight = Color(0xFFDBEAFE);
  static const Color accentCyan = Color(0xFF0284C7);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentCoral = Color(0xFFEF4444);

  // Calm Light Mode Surfaces & Typography
  static const Color backgroundLight = Color(0xFFF4F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);

  // Calm Dark Mode Surfaces & Typography
  static const Color backgroundDark = Color(0xFF090D16);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Strictly Semantic Feedback Colors
  static const Color correct = Color(0xFF10B981);
  static const Color correctBgLight = Color(0xFFECFDF5);
  static const Color correctBgDark = Color(0xFF064E3B);

  static const Color wrong = Color(0xFFEF4444);
  static const Color wrongBgLight = Color(0xFFFEF2F2);
  static const Color wrongBgDark = Color(0xFF450A0A);

  static const Color warning = Color(0xFFF59E0B);

  /// Controlled topic accent helper — keeps a cohesive blue/indigo/teal family
  /// instead of competing rainbow colors across screens.
  static Color topicAccent(String code) {
    return primary;
  }
}
