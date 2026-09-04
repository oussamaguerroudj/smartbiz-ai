import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/settings_providers.dart';
import '../../../auth/data/auth_repository.dart';

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

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          _SettingsTile(
            code: 'BZ',
            title: 'Business Profile',
            subtitle: 'Edit-from-Settings UI not wired yet',
            onTap: () => _snack(context, 'Business profile is set during onboarding — an edit screen is a follow-up'),
          ),
          _SettingsTile(
            code: 'CUR',
            title: 'Currency',
            subtitle: 'DZD',
            onTap: () {},
          ),
          _SettingsTile(
            code: 'DK',
            title: 'Theme',
            subtitle: _themeLabel(themeMode),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),
          _SettingsTile(
            code: 'LG',
            title: 'Language',
            subtitle: _localeLabel(locale),
            onTap: () => _showLocalePicker(context, ref, locale),
          ),
          _SettingsTile(
            code: 'AI',
            title: 'AI Settings',
            subtitle: 'Rate limits, usage — Phase 6',
            onTap: () {},
          ),
          _SettingsTile(
            code: 'OUT',
            title: 'Logout',
            iconColor: AppColors.danger,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values
              .map((m) => RadioListTile<ThemeMode>(
                    title: Text(_themeLabel(m)),
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
    required this.code,
    required this.title,
    this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  final String code;
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
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Text(code, style: const TextStyle(fontSize: 11)),
        ),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
