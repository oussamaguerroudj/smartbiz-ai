import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../credit/presentation/screens/credit_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../products/presentation/screens/products_list_screen.dart';
import '../../../subscriptions/presentation/screens/purchase_screen.dart';

class NotificationItem {
  NotificationItem({
    required this.type,
    required this.title,
    this.body,
    this.referenceId,
  });

  final String type;
  final String title;
  final String? body;
  final String? referenceId;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        type: (json['type'] as String?) ?? 'general',
        title: (json['title'] as String?) ?? '',
        body: json['body'] as String?,
        referenceId: json['referenceId']?.toString(),
      );
}

/// GET /notifications — real API-backed with offline SQLite fallback.
/// Computes low stock, unpaid invoices, debt reminders, and expiration alerts.
final notificationsProvider = FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final companyId = ref.read(sessionProvider).companyId;
  try {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/notifications');
    return (response['data'] as List)
        .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Offline SQLite fallback
    if (companyId == null) return [];
    final db = await AppDatabase.instance.database;
    final List<NotificationItem> items = [];

    // 1. Low stock
    try {
      final rows = await db.rawQuery(
        'SELECT id, name, quantity FROM products WHERE (company_id = ? OR company_id IS NULL) AND quantity <= minimum_stock ORDER BY quantity ASC LIMIT 20',
        [companyId],
      );
      for (final r in rows) {
        final qty = (r['quantity'] as num?)?.toInt() ?? 0;
        final name = (r['name'] as String?) ?? 'Product';
        items.add(NotificationItem(
          type: 'low_stock',
          title: qty == 0 ? 'Out of stock: $name' : 'Low stock: $name',
          body: '$qty units remaining',
          referenceId: r['id'] as String?,
        ));
      }
    } catch (_) {}

    // 2. Unpaid invoices
    try {
      final rows = await db.rawQuery(
        "SELECT id, invoice_number, total FROM invoices WHERE company_id = ? AND status = 'unpaid' ORDER BY sold_at DESC LIMIT 20",
        [companyId],
      );
      for (final r in rows) {
        items.add(NotificationItem(
          type: 'unpaid_invoice',
          title: 'Invoice ${r['invoice_number']} still unpaid',
          body: '${(r['total'] as num?)?.toStringAsFixed(0)} DZD',
          referenceId: r['id'] as String?,
        ));
      }
    } catch (_) {}

    // 3. Customer debts
    try {
      final rows = await db.rawQuery(
        'SELECT id, name, balance_due FROM customers WHERE (company_id = ? OR company_id IS NULL) AND balance_due > 0 ORDER BY balance_due DESC LIMIT 20',
        [companyId],
      );
      for (final r in rows) {
        items.add(NotificationItem(
          type: 'debt_reminder',
          title: 'Debt reminder: ${r['name']}',
          body: '${(r['balance_due'] as num?)?.toStringAsFixed(0)} DZD outstanding',
          referenceId: r['id'] as String?,
        ));
      }
    } catch (_) {}

    // 4. Expiry alerts
    try {
      final now = DateTime.now();
      final rows = await db.rawQuery(
        "SELECT id, name, quantity, expiration_date FROM products WHERE (company_id = ? OR company_id IS NULL) AND expiration_date IS NOT NULL AND expiration_date != '' LIMIT 30",
        [companyId],
      );
      for (final r in rows) {
        final expStr = r['expiration_date'] as String?;
        if (expStr != null) {
          final expDate = DateTime.tryParse(expStr);
          if (expDate != null) {
            final diff = expDate.difference(now).inDays;
            final name = (r['name'] as String?) ?? 'Product';
            final qty = (r['quantity'] as num?)?.toInt() ?? 0;
            if (diff < 0 && qty > 0) {
              items.add(NotificationItem(
                type: 'expired_stock',
                title: 'Expired: $name',
                body: 'Expired on ${expStr.length >= 10 ? expStr.substring(0, 10) : expStr} ($qty in stock)',
                referenceId: r['id'] as String?,
              ));
            } else if (diff <= 30 && qty > 0) {
              items.add(NotificationItem(
                type: 'expiring_soon',
                title: 'Expiring soon: $name',
                body: 'Expires in $diff days ($qty in stock)',
                referenceId: r['id'] as String?,
              ));
            }
          }
        }
      }
    } catch (_) {}

    return items;
  }
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) => switch (type) {
        'low_stock' => Icons.inventory_2_outlined,
        'unpaid_invoice' => Icons.receipt_long_outlined,
        'expiring_soon' => Icons.timer_outlined,
        'expired_stock' => Icons.warning_amber_rounded,
        'debt_reminder' => Icons.account_balance_wallet_outlined,
        'trial_expiring' => Icons.workspace_premium_outlined,
        'appointment_reminder' => Icons.event_outlined,
        'salary_reminder' => Icons.payments_outlined,
        _ => Icons.notifications_none_rounded,
      };

  Color _colorFor(String type) => switch (type) {
        'low_stock' => AppColors.warning,
        'unpaid_invoice' => AppColors.danger,
        'expiring_soon' => AppColors.warning,
        'expired_stock' => AppColors.danger,
        'debt_reminder' => AppColors.danger,
        'trial_expiring' => AppColors.primary,
        'appointment_reminder' => AppColors.info,
        'salary_reminder' => AppColors.primary,
        _ => AppColors.info,
      };

  void _onNotificationTap(BuildContext context, NotificationItem item) {
    switch (item.type) {
      case 'low_stock':
      case 'expiring_soon':
      case 'expired_stock':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductsListScreen()),
        );
        break;
      case 'unpaid_invoice':
        if (item.referenceId != null && item.referenceId!.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => InvoiceDetailsScreen(invoiceId: item.referenceId!)),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InvoicesScreen()),
          );
        }
        break;
      case 'debt_reminder':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreditScreen()),
        );
        break;
      case 'trial_expiring':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PurchaseScreen()),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreNotifications)),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.noNotifications))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return InkWell(
                      onTap: () => _onNotificationTap(context, item),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          boxShadow: AppSpacing.cardElevation,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _colorFor(item.type).withValues(alpha: 0.15),
                              foregroundColor: _colorFor(item.type),
                              child: Icon(_iconFor(item.type), size: 18),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                                  if (item.body != null)
                                    Text(item.body!, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
