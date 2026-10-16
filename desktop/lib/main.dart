import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/desktop_database.dart';
import 'core/localization/desktop_localizations.dart';
import 'core/network/api_client.dart';
import 'core/network/session.dart';
import 'core/theme/desktop_theme.dart';
import 'features/auth/presentation/desktop_auth_screen.dart';
import 'features/shell/presentation/desktop_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce Western/Latin ASCII digits (0-9) globally
  Intl.defaultLocale = 'en_US';

  // Initialize native Windows SQLite via FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Pre-load custom API URL if configured
  try {
    await ApiClient.loadPersistedUrl();
  } catch (_) {}

  // Initialize local desktop database
  try {
    await ModiriDesktopDatabase.instance.database;
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: ModiriDesktopApp(),
    ),
  );
}

class ModiriDesktopApp extends ConsumerWidget {
  const ModiriDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(desktopLocaleProvider);

    return MaterialApp(
      title: 'Modiri AI — Enterprise Windows Desktop',
      debugShowCheckedModeBanner: false,
      theme: ModiriTheme.lightTheme,
      darkTheme: ModiriTheme.darkTheme,
      themeMode: ref.watch(desktopThemeModeProvider),
      locale: locale,
      supportedLocales: ModiriLocalizations.supportedLocales,
      localizationsDelegates: const [
        ModiriLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: session.isLoggedIn
          ? const DesktopNavigationShell()
          : const DesktopAuthScreen(),
    );
  }
}
