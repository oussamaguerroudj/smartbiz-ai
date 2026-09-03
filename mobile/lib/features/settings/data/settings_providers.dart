import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide UI preference state — theme + locale — consumed by
/// SmartBizApp (main.dart) and mutated from the Settings screen.
/// These stay in-memory only for now; persisting them (SharedPreferences)
/// is a follow-up once the local storage layer is generalized beyond
/// this Riverpod-only setup.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

const supportedLocales = [
  Locale('en'),
  Locale('ar'),
  Locale('fr'),
];
