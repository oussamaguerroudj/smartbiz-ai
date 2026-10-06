import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../connectivity/connectivity_service.dart';
import '../sync/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SyncStatusDialog extends ConsumerWidget {
  const SyncStatusDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connStatus = ref.watch(connectionStatusProvider);
    final syncState = ref.watch(syncServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    String connLabel;
    Color connColor;
    IconData connIcon;

    switch (connStatus) {
      case ConnectionStatus.online:
        connLabel = l10n.connectionOnline;
        connColor = AppColors.success;
        connIcon = Icons.cloud_done_rounded;
        break;
      case ConnectionStatus.offline:
        connLabel = l10n.connectionOffline;
        connColor = AppColors.warning;
        connIcon = Icons.cloud_off_rounded;
        break;
      case ConnectionStatus.serverUnavailable:
        connLabel = l10n.connectionServerUnavailable;
        connColor = AppColors.warning;
        connIcon = Icons.cloud_off_rounded;
        break;
      case ConnectionStatus.syncing:
        connLabel = l10n.syncingPending(syncState.pendingCount);
        connColor = AppColors.info;
        connIcon = Icons.sync_rounded;
        break;
    }

    final timeFormatter = DateFormat.jm();
    final lastSyncedStr = syncState.lastSyncedAt != null
        ? l10n.lastSynced(timeFormatter.format(syncState.lastSyncedAt!))
        : null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      title: Row(
        children: [
          Icon(Icons.sync_alt_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(l10n.syncDetails, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: connColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(connIcon, size: 18, color: connColor),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    connLabel,
                    style: TextStyle(
                      color: connColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Counts summary
          _StatTile(
            label: l10n.pendingOperations,
            value: '${syncState.pendingCount}',
            color: syncState.pendingCount > 0 ? AppColors.warning : AppColors.textSecondaryLight,
            icon: Icons.hourglass_top_rounded,
          ),
          const SizedBox(height: AppSpacing.xs),
          _StatTile(
            label: l10n.syncedOperations,
            value: '${syncState.syncedCount}',
            color: AppColors.success,
            icon: Icons.check_circle_outline_rounded,
          ),
          if (syncState.failedCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _StatTile(
              label: l10n.failedOperations,
              value: '${syncState.failedCount}',
              color: AppColors.danger,
              icon: Icons.error_outline_rounded,
            ),
          ],

          if (lastSyncedStr != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              lastSyncedStr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: syncState.isSyncing
              ? null
              : () {
                  ref.read(syncServiceProvider.notifier).syncPending();
                },
          icon: syncState.isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.sync_rounded, size: 18),
          label: Text(l10n.syncNow),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
