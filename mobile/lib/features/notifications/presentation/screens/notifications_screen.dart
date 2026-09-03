import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../products/data/products_repository.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/sale.dart';

enum NotifKind { lowStock, unpaidInvoice, appointment, salary, expiration }

class _NotifItem {
  _NotifItem(this.kind, this.title, this.subtitle);
  final NotifKind kind;
  final String title;
  final String subtitle;
}

/// Notifications — Spec Ch. 19. Deliberately DERIVED from real repository
/// state (low stock, unpaid invoices) rather than a separately-seeded
/// mock list — this keeps every notification tied to something actually
/// true in the app right now, consistent with the "never invent numbers"
/// principle applied elsewhere. Appointment/salary reminder triggers
/// need a scheduler (Phase 5/6 backend job), so those categories are
/// wired but won't populate until that exists.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(NotifKind k) => switch (k) {
        NotifKind.lowStock => Icons.inventory_2_outlined,
        NotifKind.unpaidInvoice => Icons.receipt_long_outlined,
        NotifKind.appointment => Icons.event_outlined,
        NotifKind.salary => Icons.payments_outlined,
        NotifKind.expiration => Icons.event_busy_outlined,
      };

  Color _colorFor(NotifKind k) => switch (k) {
        NotifKind.lowStock => AppColors.warning,
        NotifKind.unpaidInvoice => AppColors.danger,
        NotifKind.appointment => AppColors.info,
        NotifKind.salary => AppColors.primary,
        NotifKind.expiration => AppColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsRepositoryProvider);
    final invoices = ref.watch(invoicesRepositoryProvider);

    final items = <_NotifItem>[
      ...products.where((p) => p.isLowStock || p.isOutOfStock).map(
            (p) => _NotifItem(
              NotifKind.lowStock,
              p.isOutOfStock
                  ? 'Out of stock: ${p.name}'
                  : 'Low stock: ${p.name}',
              '${p.quantity} units remaining',
            ),
          ),
      ...invoices.where((i) => i.status == PaymentStatus.unpaid).map(
            (i) => _NotifItem(
              NotifKind.unpaidInvoice,
              'Invoice ${i.invoiceNumber} still unpaid',
              'Tap to view details',
            ),
          ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? const Center(
              child: Text('No notifications — everything looks good'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            _colorFor(item.kind).withValues(alpha: 0.15),
                        foregroundColor: _colorFor(item.kind),
                        child: Icon(_iconFor(item.kind), size: 18),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(item.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
