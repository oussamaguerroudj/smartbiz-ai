import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // Initialize native Windows SQLite via FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Pre-load custom API URL if configured
  await ApiClient.loadPersistedUrl();

  // Ensure local database schema is ready
  await DesktopDatabase.instance.database;

  runApp(
    const ProviderScope(
      child: ModiriDesktopApp(),
    ),
  );
}

class ModiriDesktopApp extends ConsumerStatefulWidget {
  const ModiriDesktopApp({super.key});

  @override
  ConsumerState<ModiriDesktopApp> createState() => _ModiriDesktopAppState();
}

class _ModiriDesktopAppState extends ConsumerState<ModiriDesktopApp> {
  Locale _locale = const Locale('en');

  void setLocale(Locale loc) {
    setState(() => _locale = loc);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return MaterialApp(
      title: 'Modiri AI — Enterprise Windows Desktop',
      debugShowCheckedModeBanner: false,
      theme: DesktopTheme.darkTheme,
      locale: _locale,
      supportedLocales: DesktopLocalizations.supportedLocales,
      localizationsDelegates: const [
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
