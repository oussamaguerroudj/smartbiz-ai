import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'directional_chevron.dart';

/// A single interactive or informative row inside a [SettingsGroup].
class SettingsTileData {
  const SettingsTileData({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.badge,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
}

/// A professional, cohesive grouped settings section container
/// matching modern mobile SaaS standards (Apple Settings / Stripe / Linear).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.title,
    required this.items,
  });

  final String? title;
  final List<SettingsTileData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1,
            ),
            boxShadow: AppSpacing.cardElevation,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _SettingsTileRow(
                  data: items[i],
                  isLast: i == items.length - 1,
                ),
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 58,
                    endIndent: AppSpacing.sm,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight.withValues(alpha: 0.7),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTileRow extends StatelessWidget {
  const _SettingsTileRow({
    required this.data,
    required this.isLast,
  });

  final SettingsTileData data;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = data.isDestructive
        ? AppColors.danger
        : (data.iconColor ?? AppColors.primary);

    return InkWell(
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 12,
        ),
        child: Row(
          children: [
            // Leading Icon Container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(data.icon, color: color, size: 19),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: data.isDestructive ? AppColors.danger : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.subtitle != null && data.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Optional Badge
            if (data.badge != null) ...[
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: data.badge!,
              ),
            ],

            // Trailing Widget
            const SizedBox(width: AppSpacing.xs),
            data.trailing ??
                (data.onTap != null && !data.isDestructive
                    ? const NextChevron(size: 18)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
