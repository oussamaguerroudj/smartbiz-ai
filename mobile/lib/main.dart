import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/database/app_database.dart';
import 'core/network/session.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'features/settings/data/settings_providers.dart';
import 'features/onboarding/presentation/screens/video_splash_screen.dart';
import 'features/onboarding/presentation/screens/language_select_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/onboarding/presentation/screens/welcome_screen.dart';
import 'features/subscriptions/presentation/screens/plan_selection_screen.dart';
import 'features/subscriptions/presentation/screens/purchase_screen.dart';
import 'features/subscriptions/presentation/screens/account_suspended_screen.dart';
import 'features/subscriptions/presentation/screens/trial_expired_screen.dart';
import 'features/subscriptions/data/subscriptions_repository.dart';
import 'features/support/presentation/screens/contact_us_screen.dart';
import 'features/support/presentation/screens/feedback_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/verify_account_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/business_type_screen.dart';
import 'features/auth/presentation/screens/business_setup_screen.dart';
import 'features/shell/presentation/main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

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

  // Initialize native Firebase before notification service registration
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Firebase] Native Firebase initialized successfully');
    } catch (e) {
      debugPrint('[Firebase] Native Firebase initialization skipped or failed: $e');
    }
  }

  await container.read(notificationServiceProvider).initialize();

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
      navigatorKey: rootNavigatorKey,
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
  welcome,
  login,
  register,
  verifyAccount,
  planSelection,
  purchase,
  suspended,
  trialExpired,
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

class _AppFlowState extends ConsumerState<_AppFlow> with WidgetsBindingObserver {
  _AppPhase _phase = _AppPhase.splash;
  _AppPhase _purchaseReturnPhase = _AppPhase.planSelection;
  BusinessType? _selectedBusinessType;
  String _pendingEmail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final session = ref.read(sessionProvider);
      if (session.isSuspendedLocked && _phase != _AppPhase.suspended) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _phase = _AppPhase.suspended);
        return;
      }
      if (session.isTrialOrLicenseExpired &&
          _phase != _AppPhase.trialExpired &&
          _phase != _AppPhase.purchase) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _phase = _AppPhase.trialExpired);
        return;
      }
      if (session.isLoggedIn &&
          session.role != 'super_admin' &&
          session.role != 'support') {
        ref.read(subscriptionsRepositoryProvider).getEntitlementStatus().ignore();
      }
    }
  }

  Future<void> _navigateAuthenticated() async {
    final session = ref.read(sessionProvider);
    if (session.isSuspendedLocked) {
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => _phase = _AppPhase.suspended);
      return;
    }
    if (!session.isLoggedIn) {
      setState(() => _phase = _AppPhase.welcome);
      return;
    }
    if (session.role == 'super_admin' || session.role == 'support') {
      setState(() => _phase = _AppPhase.main);
      return;
    }

    // Onboarding check: If user has not selected a business type or completed onboarding,
    // route directly to BusinessTypeScreen.
    if (session.onboardingCompleted == false || session.businessType == null) {
      setState(() => _phase = _AppPhase.businessType);
      return;
    }

    try {
      final entitlement = await ref.read(subscriptionsRepositoryProvider).getEntitlementStatus();
      if (!mounted) return;
      if (entitlement.isSuspended || entitlement.status == 'suspended') {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _phase = _AppPhase.suspended);
        return;
      }
      if (entitlement.status == 'expired_trial' || entitlement.status == 'expired_temporary') {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _phase = _AppPhase.trialExpired);
        return;
      }
      if (!entitlement.hasAccess && entitlement.status == 'none') {
        setState(() => _phase = _AppPhase.planSelection);
        return;
      }
    } catch (_) {
      // Offline or API error: enforce durable local restriction state
    }

    if (!mounted) return;
    final currentSession = ref.read(sessionProvider);
    if (currentSession.isSuspendedLocked) {
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => _phase = _AppPhase.suspended);
      return;
    }
    if (!currentSession.isLoggedIn) {
      setState(() => _phase = _AppPhase.welcome);
      return;
    }
    if (currentSession.isTrialOrLicenseExpired) {
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => _phase = _AppPhase.trialExpired);
      return;
    }
    if (currentSession.onboardingCompleted == false || currentSession.businessType == null) {
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

    ref.listen<Session>(sessionProvider, (previous, next) {
      if (next.isSuspendedLocked && _phase != _AppPhase.suspended) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _phase = _AppPhase.suspended);
        return;
      }
      if (next.isTrialOrLicenseExpired &&
          _phase != _AppPhase.trialExpired &&
          _phase != _AppPhase.purchase &&
          _phase != _AppPhase.splash) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _phase = _AppPhase.trialExpired);
        return;
      }
      final wasLoggedIn = previous?.isLoggedIn ?? false;
      if (wasLoggedIn && !next.isLoggedIn && !next.isSuspendedLocked && _phase == _AppPhase.main) {
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        setState(() => _phase = _AppPhase.welcome);
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
            final s = ref.read(sessionProvider);
            if (s.isLoggedIn || s.isSuspendedLocked) {
              _navigateAuthenticated();
            } else {
              setState(() => _phase = _AppPhase.languageSelect);
            }
          },
        );

      case _AppPhase.languageSelect:
        return LanguageSelectScreen(
          onSelected: () {
            final s = ref.read(sessionProvider);
            if (s.isLoggedIn || s.isSuspendedLocked) {
              _navigateAuthenticated();
            } else {
              setState(() => _phase = _AppPhase.onboarding);
            }
          },
        );

      case _AppPhase.onboarding:
        return OnboardingScreen(
          onFinished: () => setState(() => _phase = _AppPhase.welcome),
        );

      case _AppPhase.welcome:
        return WelcomeScreen(
          onLogin: () => setState(() => _phase = _AppPhase.login),
          onRegister: () => setState(() => _phase = _AppPhase.register),
          onContactUs: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ContactUsScreen()),
          ),
          onFeedback: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FeedbackScreen()),
          ),
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
          onGoogleSuccess: _navigateAuthenticated,
        );

      case _AppPhase.verifyAccount:
        return VerifyAccountScreen(
          email: _pendingEmail,
          onVerified: () => setState(() => _phase = _AppPhase.planSelection),
          onGoToLogin: () => setState(() => _phase = _AppPhase.login),
        );

      case _AppPhase.planSelection:
        return PlanSelectionScreen(
          onTrialSelected: () {
            final session = ref.read(sessionProvider);
            if (session.onboardingCompleted == false || session.businessType == null) {
              setState(() => _phase = _AppPhase.businessType);
            } else {
              setState(() => _phase = _AppPhase.main);
            }
          },
          onUpgradeSelected: () => setState(() {
            _purchaseReturnPhase = _AppPhase.planSelection;
            _phase = _AppPhase.purchase;
          }),
        );

      case _AppPhase.purchase:
        return PurchaseScreen(
          onBack: () => setState(() => _phase = _purchaseReturnPhase),
        );

      case _AppPhase.suspended:
        return AccountSuspendedScreen(
          onSwitchAccount: () => setState(() => _phase = _AppPhase.login),
          onCreateNewAccount: () => setState(() => _phase = _AppPhase.register),
          onAccountReactivated: _navigateAuthenticated,
        );

      case _AppPhase.trialExpired:
        return TrialExpiredScreen(
          onUpgradeSelected: () => setState(() {
            _purchaseReturnPhase = _AppPhase.trialExpired;
            _phase = _AppPhase.purchase;
          }),
          onLicenseActivated: _navigateAuthenticated,
          onSwitchAccount: () => setState(() => _phase = _AppPhase.login),
          onCreateNewAccount: () => setState(() => _phase = _AppPhase.register),
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
          onFinish: _navigateAuthenticated,
        );

      case _AppPhase.main:
        return const MainShell();
    }
  }
}
