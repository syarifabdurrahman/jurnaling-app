import 'package:flutter/material.dart';

/// App colors following the "Coral & Ivory" light theme design system
class AppColors {
  AppColors._();

  // Background - Light Ivory Theme
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);

  // Accents - Coral & Slate
  static const Color accentPrimary = Color(0xFFFF7E54); // Coral/Orange
  static const Color accentSecondary = Color(0xFF2CB67D); // Emerald (kept for success states)

  // Secondary Soft - for borders and dividers
  static const Color secondarySoft = Color(0xFFE2E8F0);

  // Text - Dark Slate for light theme
  static const Color textHighContrast = Color(0xFF1E293B); // Deep slate blue-gray
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);

  // Mood colors - Soft pastels for light theme
  static const Color moodHappy = Color(0xFFFBBF24); // Warm amber
  static const Color moodCalm = Color(0xFF34D399); // Soft mint
  static const Color moodSad = Color(0xFF60A5FA); // Gentle blue
  static const Color moodAnxious = Color(0xFFF87171); // Soft coral
  static const Color moodNeutral = Color(0xFF94A3B8); // Neutral gray

  // Floating Bottom Bar - Dark Slate
  static const Color bottomBarBackground = Color(0xFF1E293B);
  static const Color bottomBarShadow = Color(0x1A000000);

  // Glassmorphism - Updated for light theme
  static const Color glassBackground = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0x1A1E293B);
  static const Color glassShadow = Color(0x0D1E293B);
}
