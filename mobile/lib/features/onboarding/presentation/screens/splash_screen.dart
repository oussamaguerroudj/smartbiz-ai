import '../../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_hero.dart';

/// Splash Screen  -  Spec Ch. 8.1
/// Shows brand while the app checks auth state / loads cached data,
/// then routes to Onboarding, Login, or Dashboard.
/// Routing decision itself belongs to core/routing (not implemented here  - 
/// this widget is presentation-only per Phase 2 scope).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: GradientHero(
        child: Center(
          child: FadeSlideIn(
            duration: const Duration(milliseconds: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BreathingIcon(
                  size: 84,
                  child: Icon(Icons.trending_up_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 24),
                Text('Modiri AI', style: AppTypography.screenTitle(Colors.white).copyWith(fontSize: 24)),
                const SizedBox(height: 6),
                Text(
                  l10n.appTagline,
                  style: AppTypography.body(Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.85)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
