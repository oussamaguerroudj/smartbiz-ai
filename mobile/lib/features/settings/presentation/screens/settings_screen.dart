import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../data/settings_providers.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/clear_application_data_dialog.dart';
import 'profile_screen.dart';
import '../../../subscriptions/data/subscriptions_repository.dart';
import '../../../subscriptions/presentation/screens/subscription_screen.dart';
import '../../../support/presentation/screens/contact_us_screen.dart';
import '../../../support/presentation/screens/feedback_screen.dart';

/// Production-Grade 2026 Premium Application Settings Screen for Modiri AI.
/// Pixel-perfect implementation following the approved design reference.
/// Features the Modiri AI Brand Header Card, structured system, business profile,
/// appearance, localization, support, and data management sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _localeLabel(Locale l) => switch (l.languageCode) {
        'ar' => 'العربية',
        'fr' => 'Français',
        _ => 'English',
      };

  String _themeLabel(AppLocalizations l10n, ThemeMode m) => switch (m) {
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
        ThemeMode.system => l10n.themeSystem,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final entitlementAsync = ref.watch(entitlementProvider);
    final entitlement = entitlementAsync.valueOrNull;

    String licenseSubtitle = l10n.lifetimeLicenseSubtitle;
    PillTone licenseTone = PillTone.brand;
    String licenseBadgeText = l10n.subscriptionStatusTrial;

    if (entitlement != null) {
      if (entitlement.entitlementType == 'lifetime') {
        licenseSubtitle = l10n.subscriptionLifetimeDesc;
        licenseTone = PillTone.success;
        licenseBadgeText = l10n.subscriptionStatusLifetime;
      } else if (entitlement.entitlementType == 'trial') {
        final days = entitlement.daysRemaining ?? 0;
        licenseSubtitle = l10n.trialExpiringNotice(days);
        licenseTone = days <= 3 ? PillTone.warning : PillTone.brand;
        licenseBadgeText = l10n.subscriptionDaysRemaining(days);
      } else if (entitlement.status == 'expired') {
        licenseSubtitle = l10n.trialExpiredNotice;
        licenseTone = PillTone.warning;
        licenseBadgeText = l10n.subscriptionStatusExpired;
      } else if (entitlement.isSuspended) {
        licenseSubtitle = l10n.subscriptionSuspendedDesc;
        licenseTone = PillTone.danger;
        licenseBadgeText = l10n.subscriptionStatusSuspended;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.brandBackground,
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          children: [
            // 1. Modiri AI Brand Card
            _buildBrandHeaderCard(context, l10n, isDark),
            const SizedBox(height: 12),

            // 2. Section 1: Account & Licensing
            SettingsGroup(
              title: l10n.accountSystemSection,
              items: [
                SettingsTileData(
                  icon: Icons.storefront_rounded,
                  title: l10n.businessProfileTitle,
                  subtitle: l10n.businessProfileSubtitle,
                  iconColor: AppColors.brandPrimaryBlue,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                SettingsTileData(
                  icon: Icons.payments_rounded,
                  title: l10n.currencyTitle,
                  subtitle: 'DZD',
                  iconColor: const Color(0xFF0EA5E9),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                SettingsTileData(
                  icon: Icons.workspace_premium_rounded,
                  title: l10n.lifetimeLicenseTitle,
                  subtitle: licenseSubtitle,
                  iconColor: entitlement?.entitlementType == 'lifetime'
                      ? AppColors.success
                      : AppColors.brandPrimaryBlue,
                  badge: StatusPill(
                    label: licenseBadgeText,
                    tone: licenseTone,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 4. Section 3: Preferences & Appearance
            SettingsGroup(
              title: l10n.preferencesSection,
              items: [
                SettingsTileData(
                  icon: Icons.dark_mode_rounded,
                  title: l10n.themeTitle,
                  subtitle: _themeLabel(l10n, themeMode),
                  iconColor: const Color(0xFF8B5CF6),
                  onTap: () => _showThemePicker(context, ref, themeMode),
                ),
                SettingsTileData(
                  icon: Icons.language_rounded,
                  title: l10n.languageTitle,
                  subtitle: _localeLabel(locale ?? Localizations.localeOf(context)),
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () => _showLocalePicker(
                    context,
                    ref,
                    locale ?? Localizations.localeOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 5. Section 4: Help & Support
            SettingsGroup(
              title: l10n.supportSection,
              items: [
                SettingsTileData(
                  icon: Icons.headset_mic_rounded,
                  title: l10n.contactUsTitle,
                  subtitle: l10n.contactOnWhatsApp,
                  iconColor: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                    );
                  },
                ),
                SettingsTileData(
                  icon: Icons.edit_note_rounded,
                  title: l10n.feedbackTitle,
                  subtitle: l10n.submitFeedbackAction,
                  iconColor: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 6. Section 5: Data Management & System Maintenance
            SettingsGroup(
              title: l10n.dataManagementSection,
              items: [
                SettingsTileData(
                  icon: Icons.delete_sweep_rounded,
                  title: l10n.clearDataTitle,
                  subtitle: l10n.clearDataSubtitle,
                  iconColor: AppColors.danger,
                  onTap: () => _showClearDataDialog(context, ref),
                ),
                SettingsTileData(
                  icon: Icons.logout_rounded,
                  title: l10n.logoutTitle,
                  iconColor: AppColors.danger,
                  isDestructive: true,
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 7. App Version & Platform Branding Footer
            Center(
              child: Column(
                children: [
                  Text(
                    'Modiri AI • ${l10n.appVersion} 0.1.5 (Build 13)',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart Business Management Platform',
                    style: TextStyle(
                      fontSize: 11,
                      color: (isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary)
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Modiri AI Brand Header Card
  Widget _buildBrandHeaderCard(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.brandBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF287BFF),
                  Color(0xFF713BFF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Tagline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modiri AI',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.brandTagline,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.brandTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDataDialog(BuildContext context, WidgetRef ref) async {
    final result = await ClearApplicationDataDialog.show(context);
    if (result != null && context.mounted) {
      final isSuccess = result == true || (result is Map && result['cleared'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSuccess
                ? 'Local cache cleared successfully'
                : 'Failed to clear local cache completely',
          ),
          backgroundColor: isSuccess ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logoutTitle),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.logoutTitle),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authRepositoryProvider).logout();
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto_outlined),
                title: Text(l10n.themeSystem),
                trailing: current == ThemeMode.system
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).state = ThemeMode.system;
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_outlined),
                title: Text(l10n.themeLight),
                trailing: current == ThemeMode.light
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).state = ThemeMode.light;
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.themeDark),
                trailing: current == ThemeMode.dark
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocalePicker(BuildContext context, WidgetRef ref, Locale current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('العربية'),
                trailing: current.languageCode == 'ar'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('ar'));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                title: const Text('Français'),
                trailing: current.languageCode == 'fr'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('fr'));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                title: const Text('English'),
                trailing: current.languageCode == 'en'
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
