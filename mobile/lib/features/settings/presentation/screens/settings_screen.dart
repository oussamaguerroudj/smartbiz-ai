import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../data/settings_providers.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/clear_application_data_dialog.dart';
import 'profile_screen.dart';
import '../../../subscriptions/data/subscriptions_repository.dart';
import '../../../subscriptions/presentation/screens/purchase_screen.dart';
import '../../../subscriptions/presentation/screens/subscription_screen.dart';
import '../../../support/presentation/screens/contact_us_screen.dart';
import '../../../support/presentation/screens/feedback_screen.dart';

/// Settings — Spec Ch. 23. Business profile / currency editing from
/// Settings still needs its own dedicated edit screen — PUT /companies/me
/// exists and IS used already (Business Setup screen, onboarding), but
/// there's no "edit later" UI wired to it yet from here. Theme and
/// language are fully functional (Phase 5 wiring). Logout is real.
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
    final entitlementAsync = ref.watch(entitlementProvider);
    final entitlement = entitlementAsync.valueOrNull;

    String licenseSubtitle = l10n.lifetimeLicenseSubtitle;
    if (entitlement != null) {
      if (entitlement.entitlementType == 'lifetime') {
        licenseSubtitle = 'Licence à vie active / Active';
      } else if (entitlement.entitlementType == 'trial') {
        final days = entitlement.daysRemaining ?? 0;
        licenseSubtitle = l10n.trialExpiringNotice(days);
      } else if (entitlement.status == 'expired') {
        licenseSubtitle = l10n.trialExpiredNotice;
      }
    }

      return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        children: [
          _SettingsSectionHeader(title: l10n.moreSectionSystem),
          _SettingsTile(
            icon: Icons.workspace_premium_rounded,
            title: l10n.lifetimeLicenseTitle,
            subtitle: licenseSubtitle,
            iconColor: entitlement?.entitlementType == 'lifetime' ? AppColors.success : AppColors.primary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSectionHeader(title: l10n.businessProfileTitle),
          _SettingsTile(
            icon: Icons.storefront_outlined,
            title: l10n.businessProfileTitle,
            subtitle: l10n.businessProfileSubtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.payments_outlined,
            title: l10n.currencyTitle,
            subtitle: 'DZD',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSectionHeader(title: l10n.themeTitle),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: l10n.themeTitle,
            subtitle: _themeLabel(l10n, themeMode),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: l10n.languageTitle,
            subtitle: _localeLabel(locale ?? Localizations.localeOf(context)),
            onTap: () => _showLocalePicker(
              context,
              ref,
              locale ?? Localizations.localeOf(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSectionHeader(title: l10n.contactUsTitle),
          _SettingsTile(
            icon: Icons.support_agent_rounded,
            title: l10n.contactUsTitle,
            subtitle: l10n.contactOnWhatsApp,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactUsScreen()),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.rate_review_outlined,
            title: l10n.feedbackTitle,
            subtitle: l10n.submitFeedbackAction,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsSectionHeader(title: l10n.clearDataTitle),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: l10n.clearDataTitle,
            subtitle: l10n.clearDataSubtitle,
            iconColor: AppColors.danger,
            onTap: () => _showClearDataDialog(context, ref),
          ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: l10n.logoutTitle,
            iconColor: AppColors.danger,
            onTap: () => _confirmLogout(context, ref),
          ),
        ].staggered(),
      ),
    );
  }


  Future<void> _showClearDataDialog(BuildContext context, WidgetRef ref) async {
    final result = await ClearApplicationDataDialog.show(context);
    if (result != null && context.mounted) {
      final isSuccess = result == true || (result is Map && result['cleared'] == true);
      if (isSuccess) {
        final l10n = AppLocalizations.of(context)!;
        final isOffline = (result is Map && result['isOffline'] == true);
        _snack(context, isOffline ? l10n.clearDataOfflineSuccess : l10n.clearDataSuccess);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutTitle),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(authRepositoryProvider).logout();
              // Pop every pushed screen back to the app's base route —
              // main.dart's _AppFlow will then rebuild and, seeing the
              // now-empty session, fall back to the Login screen.
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(l10n.logoutTitle),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                ref.read(themeModeProvider.notifier).state = v;
                Navigator.of(context).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeMode.values
                  .map((m) => RadioListTile<ThemeMode>(
                        title: Text(_themeLabel(l10n, m)),
                        value: m,
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showLocalePicker(BuildContext context, WidgetRef ref, Locale current) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: RadioGroup<Locale>(
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                ref.read(localeProvider.notifier).setLocale(v);
                Navigator.of(context).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: supportedLocales
                  .map((l) => RadioListTile<Locale>(
                        title: Text(_localeLabel(l)),
                        value: l,
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: AppSpacing.xs,
        top: AppSpacing.xs,
        bottom: 4,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 19),
        ),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left
              : Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }
}
