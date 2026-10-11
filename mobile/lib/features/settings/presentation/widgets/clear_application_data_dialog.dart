import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/session.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';

class ClearApplicationDataDialog extends ConsumerStatefulWidget {
  const ClearApplicationDataDialog({super.key});

  static Future<dynamic> show(BuildContext context) {
    return showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ClearApplicationDataDialog(),
    );
  }

  @override
  ConsumerState<ClearApplicationDataDialog> createState() =>
      _ClearApplicationDataDialogState();
}

class _ClearApplicationDataDialogState
    extends ConsumerState<ClearApplicationDataDialog> {
  final _passwordController = TextEditingController();
  bool _confirmed = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isRetrying = false;
  bool _hasFailedReset = false;
  String? _errorMessage;
  int _pendingSyncCount = 0;
  bool _checkingPending = true;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final db = await AppDatabase.instance.database;
      final session = ref.read(sessionProvider);
      final companyId = session.companyId ?? session.userId;

      final res = await db.rawQuery(
        "SELECT COUNT(*) AS count FROM sync_queue WHERE status = 'pending'",
      );
      final count = (res.first['count'] as num?)?.toInt() ?? 0;

      bool hasFailed = false;
      if (companyId != null) {
        final failedClearRes = await db.query(
          'sync_queue',
          where: "company_id = ? AND entity_type = 'business_data' AND operation_type = 'CLEAR_DATA' AND status = 'failed'",
          whereArgs: [companyId],
        );
        hasFailed = failedClearRes.isNotEmpty;
      }

      if (mounted) {
        setState(() {
          _pendingSyncCount = count;
          _hasFailedReset = hasFailed;
          _checkingPending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkingPending = false);
      }
    }
  }

  Future<void> _handleRetryReset() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });

    try {
      final success = await ref.read(syncServiceProvider.notifier).retryFailedReset();
      if (mounted) {
        setState(() => _isRetrying = false);
        if (success && Navigator.canPop(context)) {
          Navigator.of(context).pop({'cleared': true, 'isOffline': false, 'isRetry': true});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleClear() async {
    final l10n = AppLocalizations.of(context)!;
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorMessage = l10n.clearDataPasswordPrompt;
      });
      return;
    }

    final connStatus = ref.read(connectionStatusProvider);
    final isOffline = connStatus == ConnectionStatus.offline ||
        connStatus == ConnectionStatus.serverUnavailable;
    if (isOffline) {
      setState(() {
        _errorMessage = l10n.clearDataOfflineNotice;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .clearBusinessData(password: password);

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(result);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.code == 'INVALID_PASSWORD' ||
              e.message.toLowerCase().contains('password')) {
            _errorMessage = l10n.clearDataIncorrectPassword;
          } else {
            _errorMessage = e.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final msg = e.toString().toLowerCase();
          if (msg.contains('password')) {
            _errorMessage = l10n.clearDataIncorrectPassword;
          } else {
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connStatus = ref.watch(connectionStatusProvider);
    final isOffline = connStatus == ConnectionStatus.offline ||
        connStatus == ConnectionStatus.serverUnavailable;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.clearDataTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.clearDataWarning,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 12),
            if (!_checkingPending && _pendingSyncCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sync_problem_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.clearDataUnsyncedWarning(_pendingSyncCount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_hasFailedReset)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.clearDataFailedBanner,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: _isRetrying ? null : _handleRetryReset,
                        icon: _isRetrying
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(l10n.clearDataRetryAction),
                      ),
                    ),
                  ],
                ),
              ),
            if (isOffline)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.clearDataOfflineNotice,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            InkWell(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _confirmed = !_confirmed;
                      });
                    },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _confirmed,
                        activeColor: AppColors.danger,
                        onChanged: _isLoading
                            ? null
                            : (val) {
                                setState(() {
                                  _confirmed = val ?? false;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.clearDataConfirmCheckbox,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: l10n.clearDataPasswordPrompt,
                hintText: '••••••••',
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              onChanged: (_) {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: (_isLoading ||
                  isOffline ||
                  !_confirmed ||
                  _passwordController.text.trim().isEmpty)
              ? null
              : _handleClear,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(l10n.clearDataButton),
        ),
      ],
    );
  }
}
