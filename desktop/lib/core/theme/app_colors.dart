import 'package:flutter/material.dart';

class ModiriColors {
  // Website Ink Design Tokens (:root CSS & tailwind.config.js)
  // Dark mode surfaces
  static const Color ink950 = Color(0xFF05060F); // #05060f Deep canvas
  static const Color ink900 = Color(0xFF070A1A); // #070a1a Card & modal surface
  static const Color ink850 = Color(0xFF0A0E22); // #0a0e22 Table headers & sub-panels
  static const Color ink800 = Color(0xFF0D1230); // #0d1230 Panel / surface background
  static const Color ink700 = Color(0xFF121938); // #121938 Interactive / hover surface
  static const Color ink600 = Color(0xFF1A2247); // #1a2247 Refined borders

  // Light mode surfaces (modiri-web-phase1 html.light tokens)
  static const Color lightInk950 = Color(0xFFF8FAFC); // #f8fafc canvas background
  static const Color lightInk900 = Color(0xFFFFFFFF); // #ffffff card / modal background
  static const Color lightInk850 = Color(0xFFF1F5F9); // #f1f5f9 sub-layer / table headers
  static const Color lightInk800 = Color(0xFFFFFFFF); // #ffffff panel background
  static const Color lightInk700 = Color(0xFFE2E8F0); // #e2e8f0 hover background
  static const Color lightInk600 = Color(0xFFCBD5E1); // #cbd5e1 border / secondary accent

  // Borders & Lines
  static const Color lineDark = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color lineLight = Color(0x170F172A); // rgba(15, 23, 42, 0.09)

  // Brand Accents
  static const Color brandBlue = Color(0xFF3B6DF0); // #3b6df0 primary button & action accent
  static const Color brandIndigo = Color(0xFF5B5BF6); // #5b5bf6
  static const Color brandViolet = Color(0xFF8B5CF6); // #8b5cf6 AI Assistant & features
  static const Color brandTeal = Color(0xFF14B8A6); // #14b8a6 success & completed status
  static const Color brandGreen = Color(0xFF10B981); // #10b981 payments & positive ledger balance
  static const Color brandAmber = Color(0xFFF0A83B); // #f0a83b warning & pending status
  static const Color brandRose = Color(0xFFF43F5E); // #f43f5e error & alert status

  // Text Colors
  static const Color textDarkPrimary = Color(0xFFF8FAFC); // Slate-100
  static const Color textDarkSecondary = Color(0xFF94A3B8); // Slate-400
  static const Color textDarkMuted = Color(0xFF64748B); // Slate-500

  static const Color textLightPrimary = Color(0xFF0F172A); // Slate-900
  static const Color textLightSecondary = Color(0xFF475569); // Slate-600
  static const Color textLightMuted = Color(0xFF94A3B8); // Slate-400

  // Brand Gradient (135deg, #3b6df0 -> #5b5bf6 -> #8b5cf6)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      brandBlue,
      brandIndigo,
      brandViolet,
    ],
  );

  // Dynamic Theme Helpers
  static Color canvas(bool isDark) => isDark ? ink950 : lightInk950;
  static Color surface(bool isDark) => isDark ? ink900 : lightInk900;
  static Color card(bool isDark) => isDark ? ink800 : lightInk900;
  static Color tableHeader(bool isDark) => isDark ? ink850 : lightInk850;
  static Color hover(bool isDark) => isDark ? ink700 : lightInk700;
  static Color border(bool isDark) => isDark ? lineDark : lineLight;
  static Color textPrimary(bool isDark) => isDark ? textDarkPrimary : textLightPrimary;
  static Color textSecondary(bool isDark) => isDark ? textDarkSecondary : textLightSecondary;
  static Color textMuted(bool isDark) => isDark ? textDarkMuted : textLightMuted;
}
