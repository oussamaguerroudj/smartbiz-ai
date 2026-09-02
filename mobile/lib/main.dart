import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/business_type_screen.dart';
import 'features/auth/presentation/screens/business_setup_screen.dart';
import 'features/shell/presentation/main_shell.dart';

void main() {
  runApp(const SmartBizApp());
}

/// Root widget.
///
/// NOTE on scope (Phase 2, first batch):
/// - Navigation here is a simple Navigator.push chain to demonstrate
///   the full onboarding → auth → shell flow end to end.
/// - It will be replaced by a proper router (go_router) with route
///   guards (auth state, business-type persisted, etc.) once the
///   data layer exists (Phase 4/5) — noted in core/routing/ as a stub.
/// - flutter_localizations / intl codegen (for the .arb files already
///   created under core/localization/) will be wired in the next
///   Phase-2 batch together with RTL verification screens.
/// - Theme follows system brightness by default; a manual toggle will
///   be added with the Settings screen (later Phase-2 batch).
class SmartBizApp extends StatelessWidget {
  const SmartBizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartBiz AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _AppFlow(),
    );
  }
}

class _AppFlow extends StatefulWidget {
  const _AppFlow();

  @override
  State<_AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<_AppFlow> {
  @override
  void initState() {
    super.initState();
    // Simulate splash init delay, then move to onboarding.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _buildOnboarding(context)),
        );
      }
    });
  }

  Widget _buildOnboarding(BuildContext context) {
    return OnboardingScreen(
      onFinished: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _buildLogin(context)),
        );
      },
    );
  }

  Widget _buildLogin(BuildContext context) {
    return LoginScreen(
      onLoginSuccess: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      },
      onGoToRegister: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _buildRegister(context)),
        );
      },
    );
  }

  Widget _buildRegister(BuildContext context) {
    return RegisterScreen(
      onRegisterSuccess: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _buildBusinessType(context)),
        );
      },
      onGoToLogin: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildBusinessType(BuildContext context) {
    return BusinessTypeScreen(
      onContinue: (type) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _buildBusinessSetup(context, type)),
        );
      },
    );
  }

  Widget _buildBusinessSetup(BuildContext context, BusinessType type) {
    return BusinessSetupScreen(
      businessType: type,
      onFinish: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
