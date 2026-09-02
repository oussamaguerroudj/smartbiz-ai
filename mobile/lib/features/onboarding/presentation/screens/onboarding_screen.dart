import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Onboarding — Spec Ch. 8.2 (3 slides)
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

  // NOTE: strings below will be swapped for AppLocalizations lookups
  // once flutter_localizations/intl codegen is wired up (Phase 2 follow-up).
  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      icon: Icons.storefront_rounded,
      title: 'Manage Your Business',
      description:
          'Track sales, stock and profit in one place, from your phone.',
    ),
    _OnboardingSlideData(
      icon: Icons.inventory_2_rounded,
      title: 'Track Your Inventory',
      description:
          'Never run out of stock — get alerts before products sell out.',
    ),
    _OnboardingSlideData(
      icon: Icons.auto_awesome_rounded,
      title: 'Work Smarter with AI',
      description:
          'Scan supplier invoices and ask your AI assistant about your business.',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: widget.onFinished,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            _DotsIndicator(count: _slides.length, activeIndex: _index),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ElevatedButton(
                onPressed: () {
                  if (_isLast) {
                    widget.onFinished();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(_isLast ? 'Get Started' : 'Next'),
              ),
            ),
          ],
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
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.screenTitle(textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
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
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
