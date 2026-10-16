import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _prefKey = 'modiri_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.dark;
      }
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, next == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}

final desktopThemeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ModiriTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: ModiriColors.ink950,
      primaryColor: ModiriColors.brandBlue,
      canvasColor: ModiriColors.ink900,
      cardColor: ModiriColors.ink800,
      dialogBackgroundColor: ModiriColors.ink900,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: ModiriColors.brandBlue,
        secondary: ModiriColors.brandViolet,
        tertiary: ModiriColors.brandTeal,
        surface: ModiriColors.ink900,
        surfaceContainerHighest: ModiriColors.ink800,
        error: ModiriColors.brandRose,
        onPrimary: Colors.white,
        onSurface: ModiriColors.textDarkPrimary,
        outline: ModiriColors.ink600,
      ),
      cardTheme: CardThemeData(
        color: ModiriColors.ink800.withOpacity(0.75),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ModiriColors.lineDark, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ModiriColors.ink900,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ModiriColors.lineDark, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ModiriColors.lineDark,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ModiriColors.ink900.withOpacity(0.85),
        hintStyle: const TextStyle(color: ModiriColors.textDarkMuted, fontSize: 13),
        labelStyle: const TextStyle(color: ModiriColors.textDarkSecondary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.lineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.lineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.brandBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.brandRose),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ModiriColors.brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ModiriColors.textDarkPrimary,
          side: const BorderSide(color: ModiriColors.lineDark),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ModiriColors.brandBlue,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.03)),
        headingTextStyle: GoogleFonts.plusJakartaSans(
          color: ModiriColors.textDarkSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        dataTextStyle: GoogleFonts.plusJakartaSans(
          color: ModiriColors.textDarkPrimary,
          fontSize: 13,
        ),
        dividerThickness: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ModiriColors.brandBlue,
        unselectedLabelColor: ModiriColors.textDarkSecondary,
        indicatorColor: ModiriColors.brandBlue,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: ModiriColors.lightInk950,
      primaryColor: ModiriColors.brandBlue,
      canvasColor: ModiriColors.lightInk900,
      cardColor: ModiriColors.lightInk900,
      dialogBackgroundColor: ModiriColors.lightInk900,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: ModiriColors.brandBlue,
        secondary: ModiriColors.brandViolet,
        tertiary: ModiriColors.brandTeal,
        surface: ModiriColors.lightInk900,
        surfaceContainerHighest: ModiriColors.lightInk850,
        error: ModiriColors.brandRose,
        onPrimary: Colors.white,
        onSurface: ModiriColors.textLightPrimary,
        outline: ModiriColors.lightInk600,
      ),
      cardTheme: CardThemeData(
        color: ModiriColors.lightInk900,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ModiriColors.lineLight, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ModiriColors.lightInk900,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ModiriColors.lineLight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ModiriColors.lineLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ModiriColors.lightInk900,
        hintStyle: const TextStyle(color: ModiriColors.textLightMuted, fontSize: 13),
        labelStyle: const TextStyle(color: ModiriColors.textLightSecondary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.lightInk600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.lightInk600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.brandBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ModiriColors.brandRose),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ModiriColors.brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ModiriColors.textLightPrimary,
          side: const BorderSide(color: ModiriColors.lineLight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ModiriColors.brandBlue,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(ModiriColors.lightInk850),
        headingTextStyle: GoogleFonts.plusJakartaSans(
          color: ModiriColors.textLightSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        dataTextStyle: GoogleFonts.plusJakartaSans(
          color: ModiriColors.textLightPrimary,
          fontSize: 13,
        ),
        dividerThickness: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ModiriColors.brandBlue,
        unselectedLabelColor: ModiriColors.textLightSecondary,
        indicatorColor: ModiriColors.brandBlue,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }
}
