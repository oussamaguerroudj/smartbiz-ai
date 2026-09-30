import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
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
  // Needed before touching secure storage / SharedPreferences pre-runApp.
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.initBaseUrl();

  final container = ProviderContainer();

  // FIX (reported bug): both awaited here, before the first frame, so
  // the very first thing drawn already reflects the real answer to
  // "is this user logged in?" and "has this device picked a language
  // before?" — rather than the UI briefly showing (and this async work
  // then invisibly racing to correct) the wrong initial screen.
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
      // FIX (reported bug): switching to Arabic previously only flipped
      // TextDirection to RTL via the Locale — no AppLocalizations
      // delegate was ever registered, and no screen ever read translated
      // strings, so the visible text silently stayed English. The .arb
      // files under core/localization/ already had full English/Arabic/
      // French translations sitting unused. Fix: register the generated
      // AppLocalizations.delegate below (produced by `flutter gen-l10n`
      // from those same .arb files — see l10n.yaml) and read strings via
      // AppLocalizations.of(context) instead of hardcoding them.
      //
      // IMPORTANT — one-time setup step: `lib/l10n/app_localizations.dart`
      // is generated code, not checked in. Run `flutter pub get` once
      // after pulling these changes (generate:true in pubspec.yaml runs
      // gen-l10n automatically) before this will compile.
      //
      // Coverage in this pass: Onboarding, Login, Register, Business
      // Type, Business Setup, bottom nav labels, and the More menu are
      // fully wired to real translated strings. Dashboard/Reports/
      // Employees/etc. still have hardcoded English strings — the .arb
      // files don't have keys for them yet, and this pass didn't invent
      // rushed translations for the rest. See REDESIGN_CHANGELOG.md.
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
  // The email a verification/reset code was just sent to — carried across
  // the verifyAccount / forgotPassword phases so those screens know which
  // address to show and confirm against.
  String _pendingEmail = '';

  @override
  void initState() {
    super.initState();
    // Splash's own transition to Onboarding is now driven by
    // VideoSplashScreen calling onFinished (video end / error fallback /
    // safety timeout) — see below — instead of a fixed delay here.
  }

  @override
  Widget build(BuildContext context) {
    // FIX (reported bug — Finish Setup not navigating to Dashboard):
    // this used to read `ref.watch(sessionProvider)` and, if the phase
    // was `main` but the session looked logged-out, mutate `_phase`
    // directly INSIDE build() — a real anti-pattern. Mutating instance
    // state during build (instead of via setState, or better, only in
    // response to an actual event) means a phase transition set moments
    // earlier by a callback (like BusinessSetupScreen's onFinish) could
    // be silently overridden again on the very next rebuild if
    // `sessionProvider` re-emitted for any unrelated reason while its
    // value was momentarily read as logged-out — exactly the "button
    // works, request succeeds, but the screen never actually moves on"
    // symptom that was reported.
    //
    // Fixed by only reacting to a genuine logout EVENT via ref.listen
    // (previous session had a token, new one doesn't) instead of
    // re-deriving `_phase` from session state on every single build.
    ref.listen(sessionProvider, (previous, next) {
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      if (wasLoggedIn && !next.isLoggedIn && _phase == _AppPhase.main) {
        setState(() => _phase = _AppPhase.login);
      }
    });

    return AnimatedSwitcher(
      // Smooth cross-fade between every phase (splash → onboarding →
      // login → ... → main), instead of an abrupt widget swap.
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
          // FIX (reported bug — asked to verify again after closing the
          // app): this used to unconditionally go to onboarding next,
          // regardless of session state — main() now awaits
          // sessionProvider's restore() before this widget is ever
          // built, so by the time the user sees this, `ref.read
          // (sessionProvider).isLoggedIn` already reflects a real,
          // possibly-persisted-from-days-ago session.
          onFinished: () => setState(() {
            if (ref.read(sessionProvider).isLoggedIn) {
              _phase = _AppPhase.main;
            } else {
              _phase = _AppPhase.languageSelect;
            }
          }),
        );

      case _AppPhase.languageSelect:
        return LanguageSelectScreen(
          onSelected: () => setState(() {
            if (ref.read(sessionProvider).isLoggedIn) {
              _phase = _AppPhase.main;
            } else {
              _phase = _AppPhase.onboarding;
            }
          }),
        );

      case _AppPhase.onboarding:
        return OnboardingScreen(
          onFinished: () => setState(() => _phase = _AppPhase.login),
        );

      case _AppPhase.login:
        return LoginScreen(
          onLoginSuccess: () => setState(() => _phase = _AppPhase.main),
          onGoToRegister: () => setState(() => _phase = _AppPhase.register),
          onGoToForgotPassword: () =>
              setState(() => _phase = _AppPhase.forgotPassword),
          // FIX (reported bug): logging in with an unverified account
          // said "verify your account" but left the user with no way to
          // actually do that — going back to Register just said the
          // email was already taken. Now it takes them straight to the
          // code screen for that email.
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
