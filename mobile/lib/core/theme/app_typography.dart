import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modiri AI  -  Design System v2  -  Typography Scale
///
/// Two families, each with a clear job (per the approved redesign):
///   • Space Grotesk  -  screen titles / section titles / big numbers.
///     Carries the brand's personality  -  confident, technical, a little
///     distinctive  -  anywhere text is acting as a headline.
///   • Plus Jakarta Sans  -  everything people actually read: body copy,
///     labels, buttons, captions. Warm, legible, and quiet.
///
/// Method names/signatures are unchanged from v1 so every screen that
/// already calls AppTypography.screenTitle(...) / .body(...) / etc still
/// compiles  -  only the fonts and a few weights moved.
class AppTypography {
  AppTypography._();

  // Kept for any legacy reference; ThemeData.fontFamily is no longer set
  // directly (GoogleFonts textStyles below fully specify their own font).
  static const String fontFamily = 'PlusJakartaSans';

  static TextStyle screenTitle(Color color) => GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.25,
        letterSpacing: -0.2,
      );

  static TextStyle sectionTitle(Color color) => GoogleFonts.spaceGrotesk(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.1,
      );

  /// A big, tabular-figure number  -  KPI values, totals, prices.
  static TextStyle statValue(Color color) => GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle body(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.45,
      );

  static TextStyle bodyStrong(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle label(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle caption(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}
