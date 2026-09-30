import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/data/settings_providers.dart';

/// First-launch language picker — shown exactly once, before
/// Onboarding, the very first time the app is ever opened on a device
/// (see main.dart's boot logic: `LocaleNotifier.hasChosenLanguage`).
/// Not localized itself for the obvious reason that no language has
/// been chosen yet — each option is labeled in its own language/script,
/// matching how virtually every app's first-run language picker works.
class LanguageSelectScreen extends ConsumerWidget {
  const LanguageSelectScreen({super.key, required this.onSelected});

  final VoidCallback onSelected;

  static const _options = [
    (locale: Locale('ar'), flag: '🇩🇿', label: 'العربية'),
    (locale: Locale('fr'), flag: '🇫🇷', label: 'Français'),
    (locale: Locale('en'), flag: '🇬🇧', label: 'English'),
  ];

  Future<void> _choose(WidgetRef ref, Locale locale) async {
    await ref.read(localeProvider.notifier).setLocale(locale);
    onSelected();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Modiri AI',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Trilingual prompt, one line per language — nobody has
                // to already read one specific script to know what to do.
                const Text('اختر لغة التطبيق', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Choisissez la langue', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const Text('Choose your language', style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: AppSpacing.lg),
                for (final option in _options) ...[
                  _LanguageOptionCard(
                    flag: option.flag,
                    label: option.label,
                    onTap: () => _choose(ref, option.locale),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOptionCard extends StatelessWidget {
  const _LanguageOptionCard({
    required this.flag,
    required this.label,
    required this.onTap,
  });

  final String flag;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
