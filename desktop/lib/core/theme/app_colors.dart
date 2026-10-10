import 'package:flutter/material.dart';

class AppColors {
  // Cyber-Navy Brand Palette
  static const Color cyberNavy = Color(0xFF0A0F1D);
  static const Color cyberNavyDeep = Color(0xFF060913);
  static const Color surfaceDark = Color(0xFF10172A);
  static const Color surfaceElevatedDark = Color(0xFF162038);
  static const Color surfaceHighlight = Color(0xFF1E2B4A);
  static const Color borderDark = Color(0xFF243256);
  static const Color borderLight = Color(0x33475569);

  // Accents
  static const Color electricBlue = Color(0xFF38BDF8);
  static const Color electricBlueHover = Color(0xFF0EA5E9);
  static const Color cyanAccent = Color(0xFF06B6D4);
  static const Color neonEmerald = Color(0xFF10B981);
  static const Color neonAmber = Color(0xFFF59E0B);
  static const Color neonRose = Color(0xFFF43F5E);
  static const Color neonPurple = Color(0xFF8B5CF6);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradients
  static const LinearGradient ambientGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A0F1D),
      Color(0xFF0B1426),
      Color(0xFF070B14),
    ],
  );

  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0x1F38BDF8), Color(0x050F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
