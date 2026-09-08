import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Modiri AI — Design System v2 — Spacing, Radius & Elevation Tokens
/// 8px base unit (unchanged). Radii are rounder and cards float on a soft
/// shadow instead of sitting inside a hairline border, per the approved
/// redesign.
class AppSpacing {
  AppSpacing._();

  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;

  static const double radiusButton = 14;
  static const double radiusCard = 16;
  static const double radiusInput = 11;
  static const double radiusPill = 999;

  static const double touchTargetMin = 44;

  /// Standard floating-card shadow used across dashboards, list rows and
  /// bottom sheets. Matches the reference's `.row`/`.card` box-shadow
  /// exactly: `0 10px 18px -12px rgba(20,23,60,.22)`.
  static List<BoxShadow> get cardElevation => [
        BoxShadow(
          color: AppColors.cardShadow,
          blurRadius: 18,
          offset: const Offset(0, 10),
          spreadRadius: -12,
        ),
      ];

  /// A slightly stronger shadow for primary buttons / FABs, tinted with
  /// the brand color so CTAs feel like they're glowing rather than just
  /// sitting on a grey drop-shadow. Matches the reference's exact
  /// `.fab{box-shadow:0 10px 20px -6px rgba(61,85,245,.65)}`.
  static List<BoxShadow> get brandGlow => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.65),
          blurRadius: 20,
          offset: const Offset(0, 10),
          spreadRadius: -6,
        ),
      ];
}
