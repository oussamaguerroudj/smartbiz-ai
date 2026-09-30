import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import '../../../../l10n/app_localizations.dart';
import 'restaurant_orders_screen.dart' show restaurantActiveOrdersProvider, restaurantOrderStatusColor, restaurantOrderStatusLabel;

/// Ch. 10 "Restaurant Dashboard — Order Details": this screen did not
/// exist before this audit pass — tapping an order in
/// RestaurantOrdersScreen did nothing at all. Shows order
/// number/date/table/items/quantities/unit prices/subtotals/total/
/// payment status/order status, lets the user update status and record
/// a payment (server-side duplicate-payment guard — Ch. 11 — applies
/// automatically), and links to the computed invoice (Ch. 9-equivalent).
class RestaurantOrderDetailScreen extends ConsumerStatefulWidget {
  const RestaurantOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<RestaurantOrderDetailScreen> createState() => _RestaurantOrderDetailScreenState();
}

final _restaurantOrderDetailProvider =
    FutureProvider.autoDispose.family<RestaurantOrder, String>((ref, orderId) {
  return ref.read(restaurantRepositoryProvider).orderDetail(orderId);
});

class _RestaurantOrderDetailScreenState extends ConsumerState<RestaurantOrderDetailScreen> {
  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateStatus(RestaurantOrderStatus status) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(restaurantRepositoryProvider).updateOrderStatus(widget.orderId, status);
      ref.invalidate(_restaurantOrderDetailProvider(widget.orderId));
      ref.invalidate(restaurantActiveOrdersProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(l10n.networkError);
    }
  }

  Future<void> _recordPayment(RestaurantOrder order) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: order.remaining.toStringAsFixed(0));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.restaurantRecordPaymentAction),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.amountDzdLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(controller.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack(l10n.enterValidAmountMessage);
      return;
    }

    try {
      await ref.read(restaurantRepositoryProvider).recordPayment(order.id, amount: amount);
      ref.invalidate(_restaurantOrderDetailProvider(widget.orderId));
      ref.invalidate(restaurantActiveOrdersProvider);
      if (mounted) _showSnack(l10n.paymentRecordedMessage);
    } on ApiException catch (e) {
      // Ch. 11 — this is exactly where a double-tap on an
      // already-fully-paid order now surfaces the backend's
      // ORDER_ALREADY_PAID 409 as a plain message instead of silently
      // recording a second payment.
      _showSnack(e.message);
    } catch (_) {
      _showSnack(l10n.networkError);
    }
  }

  Future<void> _printInvoice() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Printing.layoutPdf(
        onLayout: (_) => ref.read(restaurantRepositoryProvider).fetchOrderInvoicePdf(widget.orderId),
        name: 'order-${widget.orderId}',
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(l10n.networkError);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orderAsync = ref.watch(_restaurantOrderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderDetailsTitle),
        actions: [
          IconButton(icon: const Icon(Icons.print_outlined), onPressed: _printInvoice),
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          final color = restaurantOrderStatusColor(order.status);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.orderNumber.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                    ),
                    child: Text(
                      restaurantOrderStatusLabel(order.status),
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Text(_formatDate(order.createdAt)),
              if (order.tableName != null) Text(order.tableName!),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.itemsLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(item.itemName)),
                      Expanded(child: Text('x${item.quantity}', textAlign: TextAlign.center)),
                      Expanded(
                        child: Text(
                          '${item.unitPrice.toStringAsFixed(0)} DZD',
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${item.subtotal.toStringAsFixed(0)} DZD',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.totalLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${order.totalAmount.toStringAsFixed(0)} DZD',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.paidAmountShortLabel),
                  Text('${order.amountPaid.toStringAsFixed(0)} DZD'),
                ],
              ),
              if (order.remaining > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.remainingLabel),
                    Text('${order.remaining.toStringAsFixed(0)} DZD'),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              if (order.remaining > 0 && order.status != RestaurantOrderStatus.cancelled)
                ElevatedButton.icon(
                  onPressed: () => _recordPayment(order),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.restaurantRecordPaymentAction),
                ),
              const SizedBox(height: AppSpacing.sm),
              if (order.status != RestaurantOrderStatus.completed &&
                  order.status != RestaurantOrderStatus.cancelled) ...[
                Text(l10n.updateStatusLabel, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final status in const [
                      RestaurantOrderStatus.pending,
                      RestaurantOrderStatus.preparing,
                      RestaurantOrderStatus.ready,
                      RestaurantOrderStatus.served,
                      RestaurantOrderStatus.completed,
                    ])
                      ChoiceChip(
                        label: Text(restaurantOrderStatusLabel(status)),
                        selected: order.status == status,
                        onSelected: (_) => _updateStatus(status),
                      ),
                    ActionChip(
                      label: Text(l10n.cancel),
                      backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                      onPressed: () => _updateStatus(RestaurantOrderStatus.cancelled),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.networkError)),
      ),
    );
  }
}
