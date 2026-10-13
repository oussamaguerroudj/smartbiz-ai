import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/data/settings_providers.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
    required this.onContactUs,
    required this.onFeedback,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onContactUs;
  final VoidCallback onFeedback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      body: GradientHero(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Language Switcher
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<Locale>(
                      initialValue: currentLocale,
                      icon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              currentLocale?.languageCode.toUpperCase() ?? 'AR',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSelected: (locale) => ref.read(localeProvider.notifier).setLocale(locale),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: Locale('ar'),
                          child: Text('العربية (Arabic)'),
                        ),
                        PopupMenuItem(
                          value: Locale('fr'),
                          child: Text('Français (French)'),
                        ),
                        PopupMenuItem(
                          value: Locale('en'),
                          child: Text('English'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Hero Branding Section
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: FadeSlideIn(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.welcomeTitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.screenTitle(Colors.white).copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.welcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: AppTypography.body(Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action Buttons Container
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: onLogin,
                      child: Text(
                        l10n.welcomeLogin,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: onRegister,
                      child: Text(
                        l10n.welcomeRegister,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: onContactUs,
                          icon: const Icon(Icons.support_agent_rounded, size: 18),
                          label: Text(l10n.welcomeContact),
                        ),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        TextButton.icon(
                          onPressed: onFeedback,
                          icon: const Icon(Icons.rate_review_outlined, size: 18),
                          label: Text(l10n.welcomeFeedback),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
