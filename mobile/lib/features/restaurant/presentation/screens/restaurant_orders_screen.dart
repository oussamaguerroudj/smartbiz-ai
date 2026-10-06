import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import 'restaurant_order_detail_screen.dart';
import 'restaurant_payment_screen.dart';
import '../../../../core/utils/phone_validator.dart';
import '../../../customers/data/customers_repository.dart';
import '../../../../l10n/app_localizations.dart';

final restaurantActiveOrdersProvider = FutureProvider.autoDispose((ref) {
  return ref.read(restaurantRepositoryProvider).activeOrders();
});

final restaurantAllOrdersProvider = FutureProvider.autoDispose((ref) {
  return ref.read(restaurantRepositoryProvider).listOrders();
});

final restaurantTablesProvider = FutureProvider.autoDispose((ref) {
  return ref.read(restaurantRepositoryProvider).listTables();
});

final restaurantMenuItemsProvider = FutureProvider.autoDispose((ref) {
  return ref.read(restaurantRepositoryProvider).listMenuItems();
});

Color restaurantOrderStatusColor(RestaurantOrderStatus status) => switch (status) {
      RestaurantOrderStatus.pending => AppColors.warning,
      RestaurantOrderStatus.preparing => AppColors.info,
      RestaurantOrderStatus.ready => AppColors.primary,
      RestaurantOrderStatus.served => const Color(0xFF0D9488), // Teal
      RestaurantOrderStatus.completed => AppColors.success,
      RestaurantOrderStatus.cancelled => AppColors.danger,
    };

String restaurantOrderStatusLabel(RestaurantOrderStatus status) => switch (status) {
      RestaurantOrderStatus.pending => 'Pending',
      RestaurantOrderStatus.preparing => 'Preparing',
      RestaurantOrderStatus.ready => 'Ready',
      RestaurantOrderStatus.served => 'Served',
      RestaurantOrderStatus.completed => 'Completed',
      RestaurantOrderStatus.cancelled => 'Cancelled',
    };

RestaurantOrderStatus? _nextStatus(RestaurantOrderStatus status) => switch (status) {
      RestaurantOrderStatus.pending => RestaurantOrderStatus.preparing,
      RestaurantOrderStatus.preparing => RestaurantOrderStatus.ready,
      RestaurantOrderStatus.ready => RestaurantOrderStatus.served,
      _ => null,
    };

Widget restaurantPaymentBadge(RestaurantOrder order, AppLocalizations l10n) {
  final color = order.isPaid
      ? AppColors.success
      : order.isPartiallyPaid
          ? AppColors.warning
          : AppColors.danger;

  final label = order.isPaid
      ? l10n.paymentStatusPaidBadge
      : order.isPartiallyPaid
          ? l10n.paymentStatusPartiallyPaidBadge
          : l10n.paymentStatusUnpaidBadge;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
    ),
  );
}

/// Orders board (Part 2, 3, 4, 5, 6, 8, 9, 10).
/// Supports multiple active orders, order tickets, payment guards, and quick switching.
class RestaurantOrdersScreen extends ConsumerStatefulWidget {
  const RestaurantOrdersScreen({super.key});

  @override
  ConsumerState<RestaurantOrdersScreen> createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends ConsumerState<RestaurantOrdersScreen> {
  String? _selectedActiveOrderId;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _advancePrep(RestaurantOrder order) async {
    final next = _nextStatus(order.status);
    if (next == null) return;
    try {
      await ref.read(restaurantRepositoryProvider).updateOrderStatus(order.id, next);
      ref.invalidate(restaurantActiveOrdersProvider);
      ref.invalidate(restaurantTablesProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack(AppLocalizations.of(context)!.networkError);
    }
  }

  Future<void> _onCompleteClicked(RestaurantOrder order) async {
    final l10n = AppLocalizations.of(context)!;

    // Rule 1: Preparation must be finished (ready or served)
    if (!order.isPreparationReady) {
      _showSnack(l10n.orderNotReadyMessage);
      return;
    }

    // Rule 2: Payment must be fully paid!
    if (!order.isPaid || order.remaining > 0) {
      // Must NOT complete! Open payment page immediately.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantPaymentScreen(orderId: order.id),
        ),
      );
      ref.invalidate(restaurantActiveOrdersProvider);
      ref.invalidate(restaurantTablesProvider);
      return;
    }

    // Both ready/served AND fully paid: complete order!
    try {
      await ref.read(restaurantRepositoryProvider).completeOrder(order.id);
      ref.invalidate(restaurantActiveOrdersProvider);
      ref.invalidate(restaurantTablesProvider);
      if (mounted) {
        _showSnack(l10n.tableStatusCompleted);
      }
    } on ApiException catch (e) {
      if (e.code == 'ORDER_PAYMENT_REQUIRED') {
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RestaurantPaymentScreen(orderId: order.id),
            ),
          );
          ref.invalidate(restaurantActiveOrdersProvider);
        }
      } else {
        _showSnack(e.message);
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.networkError);
    }
  }

  Future<void> _cancel(RestaurantOrder order) async {
    try {
      await ref.read(restaurantRepositoryProvider).updateOrderStatus(order.id, RestaurantOrderStatus.cancelled);
      ref.invalidate(restaurantActiveOrdersProvider);
      ref.invalidate(restaurantTablesProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack(AppLocalizations.of(context)!.networkError);
    }
  }

  String _elapsedLabel(BuildContext context, DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    final l10n = AppLocalizations.of(context)!;
    if (diff.inMinutes <= 0) return l10n.elapsedJustNow;
    return l10n.elapsedMinutes(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeOrdersAsync = ref.watch(restaurantActiveOrdersProvider);
    final allOrdersAsync = ref.watch(restaurantAllOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.ordersTitle),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.flash_on_outlined), text: l10n.activeOrdersLabel),
              Tab(icon: const Icon(Icons.history_outlined), text: l10n.todaysOrdersLabel),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _NewOrderSheet(),
            );
            ref.invalidate(restaurantActiveOrdersProvider);
            ref.invalidate(restaurantAllOrdersProvider);
            ref.invalidate(restaurantTablesProvider);
          },
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Active Orders
            activeOrdersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text(l10n.networkError)),
              data: (orders) {
                if (orders.isEmpty) {
                  return Center(child: Text(l10n.noActiveOrdersMessage));
                }

                // Filter to single order if selected via quick switcher
                final displayedOrders = _selectedActiveOrderId != null &&
                        orders.any((o) => o.id == _selectedActiveOrderId)
                    ? orders.where((o) => o.id == _selectedActiveOrderId).toList()
                    : orders;

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(restaurantActiveOrdersProvider);
                    ref.invalidate(restaurantTablesProvider);
                  },
                  child: Column(
                    children: [
                      // Active orders switcher bar
                      if (orders.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: AppSpacing.sm),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  label: Text('${l10n.activeOrdersLabel} (${orders.length})'),
                                  selected: _selectedActiveOrderId == null,
                                  onSelected: (_) => setState(() => _selectedActiveOrderId = null),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                for (final o in orders) ...[
                                  FilterChip(
                                    avatar: Icon(
                                      o.isPaid ? Icons.check_circle : Icons.receipt,
                                      size: 14,
                                      color: o.isPaid ? AppColors.success : AppColors.danger,
                                    ),
                                    label: Text('#${o.orderNumber} ${o.tableName ?? o.orderType}'),
                                    selected: _selectedActiveOrderId == o.id,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedActiveOrderId = selected ? o.id : null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                ],
                              ],
                            ),
                          ),
                        ),

                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          itemCount: displayedOrders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            final order = displayedOrders[i];
                            return _buildOrderTicket(context, order, l10n);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // TAB 2: All Orders History
            allOrdersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text(l10n.networkError)),
              data: (orders) {
                if (orders.isEmpty) {
                  return Center(child: Text(l10n.noPastOrdersFoundMessage));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(restaurantAllOrdersProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
                        tileColor: Theme.of(context).colorScheme.surface,
                        title: Text('#${order.orderNumber} · ${order.tableName ?? order.orderType}'),
                        subtitle: Text(
                          '${order.totalAmount.toStringAsFixed(0)} DZD · ${restaurantOrderStatusLabel(order.status)}',
                        ),
                        trailing: _buildPaymentBadge(order, l10n),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => RestaurantOrderDetailScreen(orderId: order.id)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(RestaurantOrder order, AppLocalizations l10n) =>
      restaurantPaymentBadge(order, l10n);

  /// Part 4: Complete Order Ticket / Card Widget
  Widget _buildOrderTicket(BuildContext context, RestaurantOrder order, AppLocalizations l10n) {
    final prepColor = restaurantOrderStatusColor(order.status);
    final prepLabel = restaurantOrderStatusLabel(order.status);
    final isDineIn = order.orderType == 'dine_in';

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RestaurantOrderDetailScreen(orderId: order.id),
          ),
        );
        ref.invalidate(restaurantActiveOrdersProvider);
        ref.invalidate(restaurantTablesProvider);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          boxShadow: AppSpacing.cardElevation,
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Order number & Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.orderNumberLabel(order.orderNumber),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _elapsedLabel(context, order.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                // Payment Status Badge (Highly visible)
                _buildPaymentBadge(order, l10n),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Type & Customer
            Row(
              children: [
                Icon(
                  isDineIn
                      ? Icons.table_restaurant_outlined
                      : Icons.delivery_dining_outlined,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    isDineIn
                        ? (order.tableName != null ? '${l10n.dineInOption} · ${order.tableName}' : l10n.dineInOption)
                        : l10n.deliveryOption,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order.customerName != null && order.customerName!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      order.customerName!,
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                const Spacer(),
                // Preparation status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: prepColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    prepLabel,
                    style: TextStyle(color: prepColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            if (!isDineIn && (order.customerPhone != null || order.deliveryAddress != null)) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty) ...[
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      order.customerPhone!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty) ...[
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.deliveryAddress!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const Divider(height: 16),

            // Items summary
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('${item.quantity}× ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${item.subtotal.toStringAsFixed(0)} DZD', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            const Divider(height: 16),

            // Amounts breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.totalLabel}: ${order.totalAmount.toStringAsFixed(0)} DZD',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (order.remaining > 0)
                  Text(
                    '${l10n.remainingAmountLabel}: ${order.remaining.toStringAsFixed(0)} DZD',
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
                  )
                else if (order.amountPaid > 0)
                  Text(
                    '${l10n.paidAmountShortLabel}: ${order.amountPaid.toStringAsFixed(0)} DZD',
                    style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Action buttons in Wrap (never overflow)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Details button
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RestaurantOrderDetailScreen(orderId: order.id),
                      ),
                    );
                    ref.invalidate(restaurantActiveOrdersProvider);
                    ref.invalidate(restaurantTablesProvider);
                  },
                  icon: const Icon(Icons.receipt_long, size: 14),
                  label: Text(l10n.orderDetailsTitle, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                ),

                // Advance Preparation Stage (Prep -> Ready -> Serve)
                if (_nextStatus(order.status) != null)
                  OutlinedButton.icon(
                    onPressed: () => _advancePrep(order),
                    icon: const Icon(Icons.fast_forward, size: 14),
                    label: Text(
                      order.status == RestaurantOrderStatus.pending
                          ? 'Prep'
                          : order.status == RestaurantOrderStatus.preparing
                              ? 'Ready'
                              : 'Serve',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                  ),

                // Pay Button (if unpaid or partially paid)
                if (!order.isPaid)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    icon: const Icon(Icons.payment, size: 14),
                    label: Text(l10n.payNowAction, style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RestaurantPaymentScreen(orderId: order.id),
                        ),
                      );
                      ref.invalidate(restaurantActiveOrdersProvider);
                      ref.invalidate(restaurantTablesProvider);
                    },
                  ),

                // Complete Order Button (Part 5 & 6)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: order.isPaid ? AppColors.success : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _onCompleteClicked(order),
                  child: Text(l10n.completeOrderAction, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),

                // Cancel button
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
                  tooltip: l10n.cancel,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _cancel(order),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewOrderSheet extends ConsumerStatefulWidget {
  const _NewOrderSheet();

  @override
  ConsumerState<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends ConsumerState<_NewOrderSheet> {
  String? _tableId;
  String? _tableName;
  String _orderType = 'dine_in';
  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _customerId;
  final Map<String, int> _quantities = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save(List<RestaurantMenuItem> menuItems) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = _quantities.entries.where((e) => e.value > 0).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addAtLeastOneItemMessage)),
      );
      return;
    }

    final isDelivery = _orderType == 'delivery';
    final phoneText = _phoneController.text.trim();
    final addressText = _addressController.text.trim();

    final items = selected.map((e) {
      final menuItem = menuItems.firstWhere((m) => m.id == e.key);
      return {
        'menuItemId': menuItem.id,
        'name': menuItem.name,
        'unitPrice': menuItem.price,
        'quantity': e.value,
      };
    }).toList();

    setState(() => _isSaving = true);
    try {
      await ref.read(restaurantRepositoryProvider).createOrder(
            tableId: _orderType == 'dine_in' ? _tableId : null,
            tableName: _orderType == 'dine_in' ? _tableName : null,
            orderType: _orderType,
            customerName: _customerNameController.text.trim().isNotEmpty
                ? _customerNameController.text.trim()
                : null,
            customerId: _customerId,
            customerPhone: isDelivery && phoneText.isNotEmpty ? phoneText : null,
            deliveryAddress: isDelivery && addressText.isNotEmpty ? addressText : null,
            items: items,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.orderCreatedMessage)));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final menuAsync = ref.watch(restaurantMenuItemsProvider);
    final tablesAsync = ref.watch(restaurantTablesProvider);
    final customersAsync = ref.watch(customersRepositoryProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (context, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.newOrderTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),

            // Order Type Selector: Strictly 2 options (Table or Delivery) - "sfri" / takeaway removed
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.table_restaurant_outlined, size: 16),
                    label: Center(
                      child: Text(
                        l10n.dineInOption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: _orderType == 'dine_in',
                    onSelected: (s) => setState(() => _orderType = 'dine_in'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.delivery_dining_outlined, size: 16),
                    label: Center(
                      child: Text(
                        l10n.deliveryOption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: _orderType == 'delivery',
                    onSelected: (s) => setState(() => _orderType = 'delivery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Table selector (for dine-in)
            if (_orderType == 'dine_in')
              tablesAsync.when(
                data: (tables) => DropdownButtonFormField<String>(
                  initialValue: _tableId,
                  decoration: InputDecoration(labelText: l10n.tableNameFieldLabel),
                  items: [
                    ...tables.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _tableId = v;
                      _tableName = tables.firstWhere((t) => t.id == v).name;
                    });
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            // Customer Selector (for delivery)
            if (_orderType == 'delivery')
              customersAsync.when(
                data: (customers) {
                  if (customers.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: DropdownButtonFormField<String>(
                      initialValue: _customerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.selectExistingCustomerHint,
                        prefixIcon: const Icon(Icons.people_outline, size: 20),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(l10n.anonymousWalkInCustomer),
                        ),
                        ...customers.map((c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(
                                '${c.name}${c.phone != null && c.phone!.isNotEmpty ? ' (${c.phone})' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (id) {
                        setState(() {
                          _customerId = id;
                          if (id != null) {
                            final c = customers.firstWhere((cust) => cust.id == id);
                            _customerNameController.text = c.name;
                            if (c.phone != null && c.phone!.isNotEmpty) {
                              _phoneController.text = c.phone!;
                            }
                            if (c.address != null && c.address!.isNotEmpty) {
                              _addressController.text = c.address!;
                            }
                          }
                        });
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            const SizedBox(height: AppSpacing.xs),
            // Customer Name Field
            TextField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                hintText: l10n.anonymousWalkInCustomer,
                prefixIcon: const Icon(Icons.person_outline),
                isDense: true,
              ),
            ),

            // Phone and Address Fields (Delivery)
            if (_orderType == 'delivery') ...[
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.clientPhoneNumberLabel,
                  hintText: '0551234567, +213...',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: l10n.deliveryAddressLabel,
                  hintText: l10n.deliveryAddressHint,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Menu Items List
            Expanded(
              child: menuAsync.when(
                data: (items) {
                  final available = items.where((i) => i.isAvailable).toList();
                  if (available.isEmpty) {
                    return Center(child: Text(l10n.noMenuItemsYetMessage));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: available.length,
                    itemBuilder: (context, i) {
                      final item = available[i];
                      final qty = _quantities[item.id] ?? 0;
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text('${item.price.toStringAsFixed(0)} DZD'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: qty > 0
                                  ? () => setState(() => _quantities[item.id] = qty - 1)
                                  : null,
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => _quantities[item.id] = qty + 1),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.networkError)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: _isSaving || !menuAsync.hasValue ? null : () => _save(menuAsync.value!),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.createOrderAction),
            ),
          ],
        ),
      ),
    );
  }
}
