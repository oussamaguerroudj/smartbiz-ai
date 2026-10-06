import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../connectivity/connectivity_service.dart';
import '../sync/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'sync_status_dialog.dart';

class OfflineStatusBar extends ConsumerWidget {
  const OfflineStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connStatus = ref.watch(connectionStatusProvider);
    final syncState = ref.watch(syncServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    final isOnline = connStatus == ConnectionStatus.online;
    final isSyncing = connStatus == ConnectionStatus.syncing || syncState.isSyncing;
    final isServerDown = connStatus == ConnectionStatus.serverUnavailable;
    final isOffline = connStatus == ConnectionStatus.offline;
    final hasFailed = syncState.failedCount > 0;

    // When fully online and not syncing with zero pending and no failures, keep screen clean
    if (isOnline && !isSyncing && syncState.pendingCount == 0 && !hasFailed) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color fgColor;
    IconData icon;
    String text;

    if (isSyncing) {
      bgColor = AppColors.info.withValues(alpha: 0.12);
      fgColor = AppColors.info;
      icon = Icons.sync_rounded;
      text = syncState.pendingCount > 0
          ? l10n.syncingPending(syncState.pendingCount)
          : l10n.syncNow;
    } else if (hasFailed) {
      bgColor = AppColors.danger.withValues(alpha: 0.12);
      fgColor = AppColors.danger;
      icon = Icons.sync_problem_rounded;
      text = l10n.syncFailed;
    } else if (isServerDown) {
      bgColor = AppColors.warning.withValues(alpha: 0.12);
      fgColor = AppColors.warning;
      icon = Icons.cloud_off_rounded;
      text = l10n.connectionServerUnavailable;
    } else if (isOffline) {
      bgColor = AppColors.warning.withValues(alpha: 0.12);
      fgColor = AppColors.warning;
      icon = Icons.wifi_off_rounded;
      text = l10n.connectionOffline;
    } else if (syncState.pendingCount > 0) {
      bgColor = AppColors.primary.withValues(alpha: 0.12);
      fgColor = AppColors.primary;
      icon = Icons.cloud_upload_outlined;
      text = l10n.syncingPending(syncState.pendingCount);
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Material(
        color: bgColor,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const SyncStatusDialog(),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            child: Row(
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                else
                  Icon(icon, size: 16, color: fgColor),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (syncState.pendingCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: fgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${syncState.pendingCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right, size: 16, color: fgColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
