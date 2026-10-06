import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import 'restaurant_orders_screen.dart' show restaurantTablesProvider, restaurantActiveOrdersProvider;
import 'restaurant_order_detail_screen.dart';
import 'restaurant_payment_screen.dart';
import '../../../../l10n/app_localizations.dart';

Color _tableStatusColor(RestaurantTableStatus status) => switch (status) {
      RestaurantTableStatus.available => AppColors.success,
      RestaurantTableStatus.occupied => AppColors.warning,
      RestaurantTableStatus.reserved => AppColors.info,
      RestaurantTableStatus.cleaning => const Color(0xFF64748B),
    };

String _tableStatusLabel(RestaurantTableStatus status, AppLocalizations l10n) => switch (status) {
      RestaurantTableStatus.available => l10n.tableStatusAvailable,
      RestaurantTableStatus.occupied => l10n.tableStatusOccupied,
      RestaurantTableStatus.reserved => 'RESERVED',
      RestaurantTableStatus.cleaning => l10n.tableStatusCompleted,
    };

/// Table status board (Part 8: "Table Status for Dine-In Orders").
/// Reflects real-time table statuses based on active dine-in orders:
/// AVAILABLE (green), OCCUPIED (orange), ORDER READY (blue/purple),
/// PAYMENT PENDING (red), COMPLETED (grey).
class RestaurantTablesScreen extends ConsumerWidget {
  const RestaurantTablesScreen({super.key});

  Future<void> _cycleStatus(WidgetRef ref, BuildContext context, RestaurantTable table) async {
    final next = switch (table.status) {
      RestaurantTableStatus.available => RestaurantTableStatus.occupied,
      RestaurantTableStatus.occupied => RestaurantTableStatus.cleaning,
      RestaurantTableStatus.cleaning => RestaurantTableStatus.available,
      RestaurantTableStatus.reserved => RestaurantTableStatus.occupied,
    };
    try {
      await ref.read(restaurantRepositoryProvider).updateTableStatus(table.id, next);
      ref.invalidate(restaurantTablesProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    }
  }

  void _showTableActionSheet(
    BuildContext context,
    WidgetRef ref,
    RestaurantTable table,
    RestaurantOrder? order,
    AppLocalizations l10n,
  ) {
    if (order == null) {
      _cycleStatus(ref, context, table);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${table.name} · ${l10n.orderNumberLabel(order.orderNumber)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${order.totalAmount.toStringAsFixed(0)} DZD',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (order.customerName != null && order.customerName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.customerNameLabel}: ${order.customerName}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${order.items.length} ${l10n.itemsLabel.toLowerCase()} · ${order.remaining > 0 ? '${l10n.remainingLabel}: ${order.remaining.toStringAsFixed(0)} DZD' : l10n.paymentStatusPaidBadge}',
                style: TextStyle(
                  color: order.remaining > 0 ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: Text(l10n.orderDetailsTitle),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RestaurantOrderDetailScreen(orderId: order.id),
                    ),
                  );
                },
              ),
              if (order.remaining > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.payNowAction),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RestaurantPaymentScreen(orderId: order.id),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _cycleStatus(ref, context, table);
                },
                child: Text(l10n.updateStatusLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tablesAsync = ref.watch(restaurantTablesProvider);
    final activeOrders = ref.watch(restaurantActiveOrdersProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tablesTitle)),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddTableSheet(),
          );
          ref.invalidate(restaurantTablesProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: tablesAsync.when(
        data: (tables) {
          if (tables.isEmpty) {
            return Center(child: Text(l10n.noTablesYetMessage));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(restaurantTablesProvider);
              ref.invalidate(restaurantActiveOrdersProvider);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 0.88,
              ),
              itemCount: tables.length,
              itemBuilder: (context, i) {
                final table = tables[i];
                final order = activeOrders.where((o) =>
                  (o.tableId != null && o.tableId == table.id) ||
                  (o.tableName != null && o.tableName!.toLowerCase().trim() == table.name.toLowerCase().trim())
                ).firstOrNull;

                Color color;
                String statusLabel;
                IconData statusIcon;

                if (order != null) {
                  if (order.status == RestaurantOrderStatus.ready) {
                    color = AppColors.primary;
                    statusLabel = l10n.tableStatusOrderReady;
                    statusIcon = Icons.check_circle_outline;
                  } else if (order.isPreparationReady && !order.isPaid) {
                    color = AppColors.danger;
                    statusLabel = l10n.tableStatusPaymentPending;
                    statusIcon = Icons.receipt_long;
                  } else if (order.status == RestaurantOrderStatus.preparing || order.status == RestaurantOrderStatus.pending) {
                    color = AppColors.warning;
                    statusLabel = l10n.tableStatusOccupied;
                    statusIcon = Icons.soup_kitchen_outlined;
                  } else if (order.status == RestaurantOrderStatus.completed) {
                    color = const Color(0xFF64748B);
                    statusLabel = l10n.tableStatusCompleted;
                    statusIcon = Icons.cleaning_services_outlined;
                  } else {
                    color = AppColors.warning;
                    statusLabel = l10n.tableStatusOccupied;
                    statusIcon = Icons.table_restaurant_outlined;
                  }
                } else {
                  color = _tableStatusColor(table.status);
                  statusLabel = _tableStatusLabel(table.status, l10n);
                  statusIcon = table.status == RestaurantTableStatus.cleaning
                      ? Icons.cleaning_services_outlined
                      : Icons.table_restaurant_outlined;
                }

                return InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  onTap: () => _showTableActionSheet(context, ref, table, order, l10n),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(statusIcon, color: color, size: 26),
                        const SizedBox(height: 2),
                        Text(
                          table.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order != null)
                          Text(
                            '#${order.orderNumber}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          )
                        else
                          Text(
                            '${table.seats} ${l10n.seatsLabel.toLowerCase()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.networkError)),
      ),
    );
  }
}

class _AddTableSheet extends ConsumerStatefulWidget {
  const _AddTableSheet();

  @override
  ConsumerState<_AddTableSheet> createState() => _AddTableSheetState();
}

class _AddTableSheetState extends ConsumerState<_AddTableSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _seatsController = TextEditingController(text: '2');
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(restaurantRepositoryProvider).createTable(
            name: _nameController.text.trim(),
            seats: int.tryParse(_seatsController.text) ?? 2,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.addTableTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.tableNameFieldLabel,
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.seatsLabel,
                controller: _seatsController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.saveAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
