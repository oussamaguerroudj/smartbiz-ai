import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide UI preference state  -  theme + locale  -  consumed by
/// ModiriApp (main.dart) and mutated from the Settings screen.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

const supportedLocales = [
  Locale('en'),
  Locale('ar'),
  Locale('fr'),
];

/// Persists the chosen app language (SharedPreferences  -  plain text
/// preference, not a secret, so this doesn't need the secure storage
/// used for session tokens). `state == null` specifically means "the
/// user has never chosen a language yet"  -  main.dart uses exactly that
/// to decide whether to show the first-launch language picker. Once a
/// language is chosen, it is never null again for that install.
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _readyFuture = _load();
  }

  static const _prefsKey = 'app_locale_code';

  late final Future<void> _readyFuture;

  /// Awaited once in main() before the first frame, so the app never
  /// flashes the language picker for a returning user just because the
  /// SharedPreferences read hadn't completed yet.
  Future<void> get ready => _readyFuture;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
    }
  }

  bool get hasChosenLanguage => state != null;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(),
);
