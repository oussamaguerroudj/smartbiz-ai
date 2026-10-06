import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import 'restaurant_orders_screen.dart';

/// Restaurant Payment Screen (Part 5 & Part 7).
///
/// Displays:
/// - Order number, Table / Order type, Customer
/// - Items breakdown
/// - Subtotal, Total, Already paid, Remaining
/// - Highly visible Payment status badge (PAID, PARTIALLY PAID, UNPAID)
/// - Cash / Card payment methods
/// - [ Pay Full Amount ] & [ Partial Payment ] actions
/// - Allows completing the order once fully paid.
class RestaurantPaymentScreen extends ConsumerStatefulWidget {
  const RestaurantPaymentScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<RestaurantPaymentScreen> createState() => _RestaurantPaymentScreenState();
}

class _RestaurantPaymentScreenState extends ConsumerState<RestaurantPaymentScreen> {
  final _amountController = TextEditingController();
  String _selectedMethod = 'cash';
  bool _isProcessing = false;
  RestaurantOrder? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await ref.read(restaurantRepositoryProvider).orderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
          _amountController.text = order.remaining.toStringAsFixed(0);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recordPayment({double? overrideAmount}) async {
    final order = _order;
    if (order == null) return;

    final amountToPay = overrideAmount ?? double.tryParse(_amountController.text.trim()) ?? 0.0;
    final l10n = AppLocalizations.of(context)!;

    if (amountToPay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterValidAmount)),
      );
      return;
    }

    if (amountToPay > order.remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.remainingAmountLabel}: ${order.remaining.toStringAsFixed(0)} DZD')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await ref.read(restaurantRepositoryProvider).recordPayment(
            widget.orderId,
            amount: amountToPay,
            method: _selectedMethod,
          );
      ref.invalidate(restaurantActiveOrdersProvider);
      ref.invalidate(restaurantDashboardProvider);
      await _loadOrder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.paymentRecordedMessage)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _completeOrder() async {
    final order = _order;
    if (order == null) return;
    final l10n = AppLocalizations.of(context)!;

    if (!order.isPaid || order.remaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paymentRequiredMessage)),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await ref.read(restaurantRepositoryProvider).completeOrder(order.id);
      ref.invalidate(restaurantActiveOrdersProvider);
      ref.invalidate(restaurantDashboardProvider);
      ref.invalidate(restaurantTablesProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentCompletedTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _loadOrder, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : _order == null
                  ? Center(child: Text(l10n.networkError))
                  : _buildPaymentContent(context, _order!, l10n),
    );
  }

  Widget _buildPaymentContent(BuildContext context, RestaurantOrder order, AppLocalizations l10n) {
    final paymentColor = order.isPaid
        ? AppColors.success
        : order.isPartiallyPaid
            ? AppColors.warning
            : AppColors.danger;

    final paymentText = order.isPaid
        ? l10n.paymentStatusPaidBadge
        : order.isPartiallyPaid
            ? l10n.paymentStatusPartiallyPaidBadge
            : l10n.paymentStatusUnpaidBadge;

    final orderTypeStr = order.orderType == 'dine_in'
        ? (order.tableName != null ? '${l10n.dineInOption} · ${order.tableName}' : l10n.dineInOption)
        : order.orderType == 'delivery'
            ? l10n.deliveryOption
            : l10n.takeawayOption;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppSpacing.cardElevation,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.orderNumberLabel(order.orderNumber),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: paymentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: paymentColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order.isPaid
                                ? Icons.check_circle_rounded
                                : order.isPartiallyPaid
                                    ? Icons.timelapse_rounded
                                    : Icons.error_outline_rounded,
                            size: 14,
                            color: paymentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentText,
                            style: TextStyle(
                              color: paymentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      order.orderType == 'dine_in'
                          ? Icons.table_restaurant_outlined
                          : order.orderType == 'delivery'
                              ? Icons.delivery_dining_outlined
                              : Icons.takeout_dining_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        orderTypeStr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (order.customerName != null && order.customerName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          order.customerName!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Items Breakdown Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppSpacing.cardElevation,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.itemsLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Divider(height: 16),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('${item.quantity}× ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(item.itemName)),
                        Text('${item.subtotal.toStringAsFixed(0)} DZD'),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                _summaryRow(l10n.totalLabel, '${order.totalAmount.toStringAsFixed(0)} DZD', isBold: true),
                const SizedBox(height: 4),
                _summaryRow(l10n.paidAmountShortLabel, '${order.amountPaid.toStringAsFixed(0)} DZD', color: AppColors.success),
                const SizedBox(height: 4),
                _summaryRow(
                  l10n.remainingAmountLabel,
                  '${order.remaining.toStringAsFixed(0)} DZD',
                  color: order.remaining > 0 ? AppColors.danger : AppColors.success,
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Payment Actions
          if (order.remaining > 0) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                boxShadow: AppSpacing.cardElevation,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.restaurantRecordPaymentAction,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Method Selection
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(l10n.cashPaymentMethod)),
                          selected: _selectedMethod == 'cash',
                          onSelected: (s) => setState(() => _selectedMethod = 'cash'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text(l10n.cardPaymentMethod)),
                          selected: _selectedMethod == 'card',
                          onSelected: (s) => setState(() => _selectedMethod = 'card'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Quick Pay Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _amountController.text = order.remaining.toStringAsFixed(0);
                            setState(() {});
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.payFullAmountAction),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final half = (order.remaining / 2).ceilToDouble();
                            _amountController.text = half.toStringAsFixed(0);
                            setState(() {});
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.partialPaymentAction),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Amount TextField
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.amountDzdLabel,
                      suffixText: 'DZD',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  ElevatedButton(
                    onPressed: _isProcessing ? null : () => _recordPayment(),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.payNowAction),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Order is fully paid! Ready for completion
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    l10n.paymentStatusPaidBadge,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.totalAmount.toStringAsFixed(0)} DZD',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isProcessing ? null : _completeOrder,
                    icon: const Icon(Icons.check),
                    label: Text(l10n.completeOrderAction),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
