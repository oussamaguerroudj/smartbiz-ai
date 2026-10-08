import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/database/app_database.dart';
import 'core/network/session.dart';
import 'core/network/api_client.dart';
import 'features/settings/data/settings_providers.dart';
import 'features/onboarding/presentation/screens/video_splash_screen.dart';
import 'features/onboarding/presentation/screens/language_select_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/verify_account_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/business_type_screen.dart';
import 'features/auth/presentation/screens/business_setup_screen.dart';
import 'features/shell/presentation/main_shell.dart';

Future<void> main() async {
  // Needed before touching secure storage / SharedPreferences / SQLite pre-runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  await ApiClient.initBaseUrl();

  final container = ProviderContainer();

  // Both awaited here, before the first frame, so the very first thing
  // drawn already reflects the real session and language settings.
  await container.read(sessionProvider.notifier).restore();
  await container.read(localeProvider.notifier).ready;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ModiriApp(),
    ),
  );
}

class ModiriApp extends ConsumerWidget {
  const ModiriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Modiri AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AppFlow(),
    );
  }
}

enum _AppPhase {
  splash,
  languageSelect,
  onboarding,
  login,
  register,
  verifyAccount,
  forgotPassword,
  businessType,
  businessSetup,
  main,
}

class _AppFlow extends ConsumerStatefulWidget {
  const _AppFlow();

  @override
  ConsumerState<_AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends ConsumerState<_AppFlow> {
  _AppPhase _phase = _AppPhase.splash;
  BusinessType? _selectedBusinessType;
  String _pendingEmail = '';

  void _navigateAuthenticated() {
    final session = ref.read(sessionProvider);
    if (!session.isLoggedIn) {
      setState(() => _phase = _AppPhase.login);
      return;
    }
    if (session.role == 'super_admin' || session.role == 'support') {
      setState(() => _phase = _AppPhase.main);
      return;
    }
    if (session.onboardingCompleted == false || session.businessType == null) {
      setState(() => _phase = _AppPhase.businessType);
      return;
    }
    setState(() => _phase = _AppPhase.main);
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode && ApiClient.baseUrl.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Configuration Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'API_URL is not configured for this release build.\nPlease rebuild the application with:\n--dart-define=API_URL=https://<your-backend-url>/api',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    ref.listen(sessionProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      if (wasLoggedIn && !next.isLoggedIn && _phase == _AppPhase.main) {
        setState(() => _phase = _AppPhase.login);
      }
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey(_phase),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _AppPhase.splash:
        return VideoSplashScreen(
          onFinished: () {
            if (ref.read(sessionProvider).isLoggedIn) {
              _navigateAuthenticated();
            } else {
              setState(() => _phase = _AppPhase.languageSelect);
            }
          },
        );

      case _AppPhase.languageSelect:
        return LanguageSelectScreen(
          onSelected: () {
            if (ref.read(sessionProvider).isLoggedIn) {
              _navigateAuthenticated();
            } else {
              setState(() => _phase = _AppPhase.onboarding);
            }
          },
        );

      case _AppPhase.onboarding:
        return OnboardingScreen(
          onFinished: () => setState(() => _phase = _AppPhase.login),
        );

      case _AppPhase.login:
        return LoginScreen(
          onLoginSuccess: _navigateAuthenticated,
          onGoToRegister: () => setState(() => _phase = _AppPhase.register),
          onGoToForgotPassword: () =>
              setState(() => _phase = _AppPhase.forgotPassword),
          onGoToVerify: (email) => setState(() {
            _pendingEmail = email;
            _phase = _AppPhase.verifyAccount;
          }),
        );

      case _AppPhase.register:
        return RegisterScreen(
          onRegisterSuccess: (email) => setState(() {
            _pendingEmail = email;
            _phase = _AppPhase.verifyAccount;
          }),
          onGoToLogin: () => setState(() => _phase = _AppPhase.login),
        );

      case _AppPhase.verifyAccount:
        return VerifyAccountScreen(
          email: _pendingEmail,
          onVerified: () => setState(() => _phase = _AppPhase.businessType),
          onGoToLogin: () => setState(() => _phase = _AppPhase.login),
        );

      case _AppPhase.forgotPassword:
        return ForgotPasswordScreen(
          onResetSuccess: () => setState(() => _phase = _AppPhase.login),
          onGoToLogin: () => setState(() => _phase = _AppPhase.login),
        );

      case _AppPhase.businessType:
        return BusinessTypeScreen(
          onContinue: (type) => setState(() {
            _selectedBusinessType = type;
            _phase = _AppPhase.businessSetup;
          }),
        );

      case _AppPhase.businessSetup:
        return BusinessSetupScreen(
          businessType: _selectedBusinessType ?? BusinessType.company,
          onFinish: () => setState(() => _phase = _AppPhase.main),
        );

      case _AppPhase.main:
        return const MainShell();
    }
  }
}
