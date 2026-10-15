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
  static const Color success = Color(0xFF10B981); // Emerald 500 (Clean, modern SaaS green)
  static const Color info = Color(0xFF5B72F7); // Periwinkle — used sparingly

  // Section 5.1: 2026 Premium Design System Tokens
  static const Color brandPrimary = Color(0xFF304FFE);
  static const Color brandPrimaryBlue = Color(0xFF3563FF);
  static const Color brandBrightBlue = Color(0xFF287BFF);
  static const Color brandViolet = Color(0xFF713BFF);
  static const Color brandDeepNavy = Color(0xFF071B49);
  static const Color brandSecondaryNavy = Color(0xFF102B68);
  static const Color brandCyan = Color(0xFF18C8F4);
  static const Color brandBackground = Color(0xFFF4F6FD);
  static const Color brandCard = Color(0xFFFFFFFF);
  static const Color brandTextPrimary = Color(0xFF111936);
  static const Color brandTextSecondary = Color(0xFF7884A5);
  static const Color brandBorder = Color(0xFFE1E7F5);
  static const Color brandDivider = Color(0xFFE8EDF8);

  static const List<Color> premiumNavyGradient = [
    Color(0xFF071B49),
    Color(0xFF102B68),
    Color(0xFF1A3378),
  ];

  static const List<Color> primaryButtonGradient = [
    Color(0xFF287BFF),
    Color(0xFF713BFF),
  ];

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

  // Cyber-Navy Enterprise Glassmorphism (Windows Desktop & Web Edition)
  static const Color cyberNavy = Color(0xFF05060F);
  static const Color surfaceElevatedDark = Color(0xFF070A1A);
  static const Color surfaceSecondaryDark = Color(0xFF0A0E22);
  static const Color surfacePanelDark = Color(0xFF0D1230);
  static const Color surfaceHoverDark = Color(0xFF121938);

  static const Color electricBlue = Color(0xFF3B6DF0);
  static const Color indigo = Color(0xFF5B5BF6);
  static const Color aiViolet = Color(0xFF8B5CF6);
  static const Color successTeal = Color(0xFF14B8A6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF0A83B);
  static const Color errorRose = Color(0xFFEF4444);

  static const List<Color> aiGradient = [
    Color(0xFF3B6DF0),
    Color(0xFF5B5BF6),
    Color(0xFF8B5CF6),
  ];
}
