import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/data/settings_providers.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/business_type_screen.dart';
import 'features/auth/presentation/screens/business_setup_screen.dart';
import 'features/shell/presentation/main_shell.dart';

void main() {
  // ProviderScope is Riverpod's root — required for every provider used
  // throughout the app (ProductsRepository, SalesRepository, etc. —
  // introduced in Phase 4 as the Local/Data Layer).
  runApp(const ProviderScope(child: SmartBizApp()));
}

class SmartBizApp extends ConsumerWidget {
  const SmartBizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'SmartBiz AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      // NOTE: this enables real RTL layout mirroring (Directionality
      // flows from the active Locale via GlobalWidgetsLocalizations) —
      // switching to Arabic in Settings will visibly mirror the whole
      // app. Actual string TRANSLATION (AppLocalizations.of(context))
      // is a separate, larger follow-up: the .arb files under
      // core/localization/ are ready, but wiring flutter gen-l10n and
      // replacing every hardcoded string across ~20 screens needs its
      // own reviewable batch — flagged in README, not done here.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AppFlow(),
    );
  }
}

/// FIX (reported bug): the previous version pushed each screen via
/// Navigator.push using a BuildContext captured once in initState and
/// re-used across every nested callback. That pattern is fragile — the
/// "Get Started" transition (and, latently, several after it) could fail
/// to navigate because the captured context stopped resolving to the
/// active Navigator reliably.
///
/// Replaced with a single explicit state enum + switch in build(). Each
/// screen's callback just calls setState to move to the next phase — no
/// BuildContext reuse, no ambiguity about which Navigator is being used.
/// This will be replaced by go_router with real route guards once the
/// data/auth layer exists (Phase 4/5), as already noted in core/routing/.
enum _AppPhase {
  splash,
  onboarding,
  login,
  register,
  businessType,
  businessSetup,
  main,
}

class _AppFlow extends StatefulWidget {
  const _AppFlow();

  @override
  State<_AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<_AppFlow> {
  _AppPhase _phase = _AppPhase.splash;
  BusinessType? _selectedBusinessType;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _phase = _AppPhase.onboarding);
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _AppPhase.splash:
        return const SplashScreen();

      case _AppPhase.onboarding:
        return OnboardingScreen(
          onFinished: () => setState(() => _phase = _AppPhase.login),
        );

      case _AppPhase.login:
        return LoginScreen(
          onLoginSuccess: () => setState(() => _phase = _AppPhase.main),
          onGoToRegister: () => setState(() => _phase = _AppPhase.register),
        );

      case _AppPhase.register:
        return RegisterScreen(
          onRegisterSuccess: () =>
              setState(() => _phase = _AppPhase.businessType),
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
