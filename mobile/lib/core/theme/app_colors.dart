import 'package:flutter/material.dart';

/// SmartBiz AI — Design System — Color Tokens
/// Source of truth: Product Specification, Chapter 30 (Design System).
/// Never hardcode hex colors in widgets — always reference AppColors.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF059669); // Emerald 600
  static const Color primaryDark = Color(0xFF065F46); // Emerald 800
  static const Color primaryLight = Color(0xFF34D399); // Emerald 400

  // Semantic
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color danger = Color(0xFFEF4444); // Red 500
  static const Color success = primary;
  static const Color info = Color(0xFF3B82F6); // Blue 500 (used sparingly)

  // Light theme surfaces
  static const Color backgroundLight = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // Dark theme surfaces
  static const Color backgroundDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF1F2937);

  // Stock status indicators (Inventory)
  static const Color stockHealthy = primary;
  static const Color stockLow = warning;
  static const Color stockOut = danger;
}
