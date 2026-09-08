import 'package:flutter/material.dart';

/// Modiri AI — Design System v2 ("Indigo") — Color Tokens
/// Source of truth: the approved Modiri AI visual redesign (Sept 2026).
/// Never hardcode hex colors in widgets — always reference AppColors.
///
/// All token *names* are unchanged from Design System v1 so every screen
/// that already reads AppColors.primary / AppColors.danger / etc keeps
/// compiling — only the values moved from the old emerald palette to the
/// new indigo/blue brand palette used in the approved mockups.
class AppColors {
  AppColors._();

  // Brand — indigo/blue, matching the approved Modiri AI mockups.
  static const Color primary = Color(0xFF3D55F5); // Indigo 600 (brand)
  static const Color primaryDark = Color(0xFF1A2166); // Deep ink-indigo
  static const Color primaryLight = Color(0xFF7C8CF8); // Indigo 400

  // Semantic
  static const Color warning = Color(0xFFF5A524); // Amber 500
  static const Color danger = Color(0xFFF0654A); // Coral 500
  static const Color success = primary;
  static const Color info = Color(0xFF5B72F7); // Periwinkle — used sparingly

  // Light theme surfaces
  static const Color backgroundLight = Color(0xFFF4F6FC); // Mist
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF141833); // Ink
  static const Color textSecondaryLight = Color(0xFF666C92); // Dim ink
  static const Color borderLight = Color(0xFFE3E6F5); // Hairline

  // Dark theme surfaces
  static const Color backgroundDark = Color(0xFF0A0D24);
  static const Color surfaceDark = Color(0xFF12163D);
  static const Color textPrimaryDark = Color(0xFFF1F3FC);
  static const Color textSecondaryDark = Color(0xFFA7ABC9);
  static const Color borderDark = Color(0xFF232964);

  // Stock status indicators (Inventory)
  static const Color stockHealthy = primary;
  static const Color stockLow = warning;
  static const Color stockOut = danger;

  // New in v2: the gradient hero used on Splash / Onboarding / Dashboard
  // header / AI Assistant background — one consistent brand gradient
  // instead of a flat brand-color fill.
  static const List<Color> heroGradient = [
    Color(0xFF0E1140),
    Color(0xFF1A2166),
    Color(0xFF2A35A8),
  ];

  // New in v2: soft ambient shadow tint for elevated cards (replaces the
  // old hairline-border card look with a floating, shadowed one).
  // Matches the reference's `.row{box-shadow:0 10px 18px -12px
  // rgba(20,23,60,.22)}` exactly — rgb(20,23,60) is AppColors.textPrimaryLight.
  static Color cardShadow = const Color(0xFF141833).withValues(alpha: 0.22);
}
