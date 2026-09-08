import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../data/settings_providers.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../l10n/app_localizations.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          _SettingsTile(
            icon: Icons.storefront_outlined,
            title: l10n.businessProfileTitle,
            subtitle: l10n.businessProfileSubtitle,
            onTap: () => _snack(context, l10n.businessProfileSnack),
          ),
          _SettingsTile(
            icon: Icons.payments_outlined,
            title: l10n.currencyTitle,
            subtitle: 'DZD',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: l10n.themeTitle,
            subtitle: _themeLabel(l10n, themeMode),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: l10n.languageTitle,
            subtitle: _localeLabel(locale),
            onTap: () => _showLocalePicker(context, ref, locale),
          ),
          _SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: l10n.aiSettingsTitle,
            subtitle: l10n.aiSettingsSubtitle,
            onTap: () {},
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values
              .map((m) => RadioListTile<ThemeMode>(
                    title: Text(_themeLabel(l10n, m)),
                    value: m,
                    groupValue: current,
                    onChanged: (v) {
                      ref.read(themeModeProvider.notifier).state = v!;
                      Navigator.of(context).pop();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showLocalePicker(BuildContext context, WidgetRef ref, Locale current) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: supportedLocales
              .map((l) => RadioListTile<Locale>(
                    title: Text(_localeLabel(l)),
                    value: l,
                    groupValue: current,
                    onChanged: (v) {
                      ref.read(localeProvider.notifier).state = v!;
                      Navigator.of(context).pop();
                    },
                  ))
              .toList(),
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
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
