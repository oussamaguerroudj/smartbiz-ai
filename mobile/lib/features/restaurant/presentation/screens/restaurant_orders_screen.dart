import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import 'restaurant_order_detail_screen.dart';
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
      RestaurantOrderStatus.served => AppColors.success,
      RestaurantOrderStatus.completed => AppColors.success,
      RestaurantOrderStatus.cancelled => AppColors.danger,
    };

// NOTE (Ch. 19 localization pass): these status labels are intentionally
// left as hardcoded English, matching this codebase's own established
// convention — ClinicQueueScreen's _statusLabel (never touched by this
// audit) does the exact same thing, for the same structural reason:
// this is a plain function with no BuildContext to read
// AppLocalizations from. Localizing it would mean changing this
// function's signature and every call site across files, which is a
// wider, deliberate convention change beyond this pass's scope.
String restaurantOrderStatusLabel(RestaurantOrderStatus status) => switch (status) {
      RestaurantOrderStatus.pending => 'Pending',
      RestaurantOrderStatus.preparing => 'Preparing',
      RestaurantOrderStatus.ready => 'Ready',
      RestaurantOrderStatus.served => 'Served',
      RestaurantOrderStatus.completed => 'Completed',
      RestaurantOrderStatus.cancelled => 'Cancelled',
    };

/// The next status a "move it along" tap sends an order to — kitchen
/// board flow: pending -> preparing -> ready -> served -> completed.
RestaurantOrderStatus? _nextStatus(RestaurantOrderStatus status) => switch (status) {
      RestaurantOrderStatus.pending => RestaurantOrderStatus.preparing,
      RestaurantOrderStatus.preparing => RestaurantOrderStatus.ready,
      RestaurantOrderStatus.ready => RestaurantOrderStatus.served,
      RestaurantOrderStatus.served => RestaurantOrderStatus.completed,
      RestaurantOrderStatus.completed => null,
      RestaurantOrderStatus.cancelled => null,
    };

/// Orders board (business-specialization brief Ch. 17 — "Kitchen/order
/// status"): every still-open order today, grouped by status, with a
/// single tap to move an order to its next kitchen stage. This is the
/// restaurant analogue of ClinicQueueScreen — same "who's waiting / in
/// progress / done" shape, applied to orders instead of patients.
class RestaurantOrdersScreen extends ConsumerStatefulWidget {
  const RestaurantOrdersScreen({super.key});

  @override
  ConsumerState<RestaurantOrdersScreen> createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends ConsumerState<RestaurantOrdersScreen> {
  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _advance(RestaurantOrder order) async {
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

  String _nextActionLabel(RestaurantOrderStatus status) => switch (status) {
        RestaurantOrderStatus.pending => 'Prep',
        RestaurantOrderStatus.preparing => 'Ready',
        RestaurantOrderStatus.ready => 'Serve',
        RestaurantOrderStatus.served => 'Done',
        _ => '',
      };

  IconData _nextActionIcon(RestaurantOrderStatus status) => switch (status) {
        RestaurantOrderStatus.pending => Icons.soup_kitchen_outlined,
        RestaurantOrderStatus.preparing => Icons.done_all,
        RestaurantOrderStatus.ready => Icons.room_service_outlined,
        RestaurantOrderStatus.served => Icons.check_circle_outline,
        _ => Icons.arrow_forward,
      };

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
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.flash_on_outlined), text: 'Active Orders'),
              Tab(icon: Icon(Icons.history_outlined), text: 'All Orders'),
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
            // Tab 1: Active Orders
            activeOrdersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(restaurantActiveOrdersProvider);
                      ref.invalidate(restaurantAllOrdersProvider);
                    },
                    child: ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
                                const SizedBox(height: AppSpacing.sm),
                                Text(l10n.noActiveOrdersMessage),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(restaurantActiveOrdersProvider);
                    ref.invalidate(restaurantAllOrdersProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      final color = restaurantOrderStatusColor(order.status);
                      final next = _nextStatus(order.status);

                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          boxShadow: AppSpacing.cardElevation,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RestaurantOrderDetailScreen(orderId: order.id),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                foregroundColor: color,
                                child: Text('#${order.orderNumber.toString().padLeft(2, '0')}'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.tableName ?? l10n.takeawayLabel,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${restaurantOrderStatusLabel(order.status)} · ${order.totalAmount.toStringAsFixed(0)} DZD',
                                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              if (next != null)
                                FilledButton.tonalIcon(
                                  onPressed: () => _advance(order),
                                  icon: Icon(_nextActionIcon(order.status), size: 16),
                                  label: Text(_nextActionLabel(order.status)),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              if (order.status == RestaurantOrderStatus.pending)
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.danger, size: 20),
                                  tooltip: l10n.cancelOrderTooltip,
                                  onPressed: () => _cancel(order),
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

            // Tab 2: All Orders History
            allOrdersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(restaurantAllOrdersProvider),
                    child: ListView(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(child: Text(l10n.noPastOrdersFoundMessage)),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(restaurantAllOrdersProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      final color = restaurantOrderStatusColor(order.status);

                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          boxShadow: AppSpacing.cardElevation,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RestaurantOrderDetailScreen(orderId: order.id),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                foregroundColor: color,
                                child: Text('#${order.orderNumber.toString().padLeft(2, '0')}'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.tableName ?? l10n.takeawayLabel,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${restaurantOrderStatusLabel(order.status)} · ${order.totalAmount.toStringAsFixed(0)} DZD',
                                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey.shade400),
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
  final Map<String, int> _quantities = {};
  bool _isSaving = false;

  Future<void> _save(List<RestaurantMenuItem> menuItems) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = _quantities.entries.where((e) => e.value > 0).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addAtLeastOneItemMessage)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(restaurantRepositoryProvider).createOrder(
            tableId: _tableId,
            items: selected
                .map((e) => {'menuItemId': e.key, 'quantity': e.value})
                .toList(),
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

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, scrollController) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.newOrderTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            tablesAsync.when(
              data: (tables) => DropdownButtonFormField<String>(
                initialValue: _tableId,
                decoration: InputDecoration(labelText: l10n.tableOptionalLabel),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.takeawayNoTableOption)),
                  ...tables.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                ],
                onChanged: (v) => setState(() => _tableId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                            Text('$qty'),
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
