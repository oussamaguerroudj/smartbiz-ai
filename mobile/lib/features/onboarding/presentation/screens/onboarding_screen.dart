import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../../l10n/app_localizations.dart';

/// Onboarding  -  Spec Ch. 8.2 (3 slides)
/// Each slide: illustration placeholder, title, one-line description.
/// Skip / Next controls; final slide replaces Next with Get Started.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinished,
  });

  /// Called when the user taps "Get Started" on the last slide,
  /// or "Skip" at any point. Routing itself is handled by the caller.
  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  // FIX (reported bug  -  Arabic only mirrored layout, text stayed
  // English): these used to be a `static const` list of hardcoded
  // English strings. Now built per-build from AppLocalizations, which
  // is wired to the existing per-locale .arb files (already had full
  // Arabic/French translations sitting unused  -  see main.dart).
  List<_OnboardingSlideData> _slides(AppLocalizations l10n) => [
        _OnboardingSlideData(
          icon: Icons.storefront_rounded,
          title: l10n.onboardingTitle1,
          description: l10n.onboardingDesc1,
        ),
        _OnboardingSlideData(
          icon: Icons.inventory_2_rounded,
          title: l10n.onboardingTitle2,
          description: l10n.onboardingDesc2,
        ),
        _OnboardingSlideData(
          icon: Icons.auto_awesome_rounded,
          title: l10n.onboardingTitle3,
          description: l10n.onboardingDesc3,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = _slides(l10n);
    final isLast = _index == slides.length - 1;
    return Scaffold(
      body: GradientHero(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: TextButton(
                    onPressed: widget.onFinished,
                    style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.65)),
                    child: Text(l10n.skip),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(slide: slides[i]),
                ),
              ),
              _DotsIndicator(count: slides.length, activeIndex: _index),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(
                  height: AppSpacing.touchTargetMin + 6,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                    ),
                    onPressed: () {
                      if (isLast) {
                        widget.onFinished();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Text(isLast ? l10n.getStarted : l10n.next),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _OnboardingSlideData slide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BreathingIcon(
              size: 132,
              child: Icon(slide.icon, size: 56, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: AppTypography.screenTitle(Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: AppTypography.body(Colors.white.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 16),
          width: active ? 16 : 6,
          height: 5,
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
