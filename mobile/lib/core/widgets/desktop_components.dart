import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'glass_panel.dart';

/// Desktop Page Header with localized title, subtitle, badges, and action buttons.
class DesktopPageHeader extends StatelessWidget {
  const DesktopPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.actions,
    this.breadcrumbs,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget>? actions;
  final List<String>? breadcrumbs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breadcrumbs != null && breadcrumbs!.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                for (int i = 0; i < breadcrumbs!.length; i++) ...[
                  if (i > 0)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  Text(
                    breadcrumbs![i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == breadcrumbs!.length - 1 ? FontWeight.w600 : FontWeight.normal,
                      color: i == breadcrumbs!.length - 1
                          ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: AppTypography.screenTitle(
                        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 12),
                      badge!,
                    ],
                  ],
                ),
              ),
              if (actions != null) ...[
                Wrap(
                  spacing: 10,
                  children: actions!,
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.caption(
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Desktop KPI Card
class DesktopKpiCard extends StatefulWidget {
  const DesktopKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.trend,
    this.isPositiveTrend = true,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final String? trend;
  final bool isPositiveTrend;
  final VoidCallback? onTap;

  @override
  State<DesktopKpiCard> createState() => _DesktopKpiCardState();
}

class _DesktopKpiCardState extends State<DesktopKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? AppColors.electricBlue;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: _isHovered ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
        child: GlassPanel(
          onTap: widget.onTap,
          borderColor: _isHovered ? accent.withValues(alpha: 0.35) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (widget.icon != null)
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, size: 18, color: accent),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.subtitle != null)
                    Expanded(
                      child: Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (widget.trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (widget.isPositiveTrend ? AppColors.successGreen : AppColors.errorRose)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.trend!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.isPositiveTrend ? AppColors.successGreen : AppColors.errorRose,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Column configuration for DesktopDataTable
class DesktopDataColumn {
  const DesktopDataColumn({
    required this.label,
    this.flex = 1,
    this.width,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final int flex;
  final double? width;
  final TextAlign textAlign;
}

/// Desktop Data Table with striped rows, responsive columns, and scroll support
class DesktopDataTable<T> extends StatelessWidget {
  const DesktopDataTable({
    super.key,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.onRowTap,
    this.emptyMessage = 'No records found',
    this.isLoading = false,
  });

  final List<DesktopDataColumn> columns;
  final List<T> items;
  final List<Widget> Function(BuildContext context, T item) rowBuilder;
  final void Function(T item)? onRowTap;
  final String emptyMessage;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage,
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceSecondaryDark : AppColors.backgroundLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: columns.map((col) {
                final child = Text(
                  col.label.toUpperCase(),
                  textAlign: col.textAlign,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                );

                if (col.width != null) {
                  return SizedBox(width: col.width, child: child);
                }
                return Expanded(flex: col.flex, child: child);
              }).toList(),
            ),
          ),

          // Data Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.borderLight,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final cells = rowBuilder(context, item);

              return InkWell(
                onTap: onRowTap != null ? () => onRowTap!(item) : null,
                hoverColor: isDark
                    ? AppColors.surfaceHoverDark
                    : AppColors.backgroundLight.withValues(alpha: 0.7),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      for (int i = 0; i < columns.length; i++) ...[
                        if (i < cells.length) ...[
                          if (columns[i].width != null)
                            SizedBox(width: columns[i].width, child: cells[i])
                          else
                            Expanded(flex: columns[i].flex, child: cells[i]),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
