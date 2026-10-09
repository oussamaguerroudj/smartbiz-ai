import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import '../../../../l10n/app_localizations.dart';
import 'restaurant_orders_screen.dart'
    show
        restaurantActiveOrdersProvider,
        restaurantOrderStatusColor,
        restaurantOrderStatusLabel,
        restaurantPaymentBadge;
import 'restaurant_payment_screen.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/phone_validator.dart';

/// Restaurant Order Details Screen (Parts 4, 5, 6, 8, 9, 10).
/// Shows complete order information (number, time, customer, order type, table,
/// items, preparation status, payment status, extras, and full invoice printing).
/// Enforces Part 5 & 6 payment guard: unpaid orders cannot be marked completed.
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateStatus(RestaurantOrder order, RestaurantOrderStatus status) async {
    final l10n = AppLocalizations.of(context)!;

    if (status == RestaurantOrderStatus.completed) {
      if (!order.isPreparationReady) {
        _showSnack(l10n.orderNotReadyMessage);
        return;
      }
      if (!order.isPaid) {
        _showSnack(l10n.paymentRequiredMessage);
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => RestaurantPaymentScreen(orderId: order.id),
          ),
        );
        ref.invalidate(_restaurantOrderDetailProvider(widget.orderId));
        ref.invalidate(restaurantActiveOrdersProvider);
        if (paid == true) {
          if (mounted) _showSnack(l10n.tableStatusCompleted);
        }
        return;
      }
    }

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

  Future<void> _openPaymentScreen(RestaurantOrder order) async {
    final l10n = AppLocalizations.of(context)!;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RestaurantPaymentScreen(orderId: order.id),
      ),
    );
    ref.invalidate(_restaurantOrderDetailProvider(widget.orderId));
    ref.invalidate(restaurantActiveOrdersProvider);
    if (completed == true && mounted) {
      _showSnack(l10n.tableStatusCompleted);
    }
  }

  Future<Uint8List> _generateOrderInvoicePdf(RestaurantOrder order) async {
    final pdf = pw.Document();

    pw.ThemeData? theme;
    try {
      final fontDataRegular = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final fontDataBold = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      final cairoRegular = pw.Font.ttf(fontDataRegular);
      final cairoBold = pw.Font.ttf(fontDataBold);
      theme = pw.ThemeData.withFont(
        base: cairoRegular,
        bold: cairoBold,
      );
    } catch (_) {
      // Fall back to default PDF fonts if assets are unavailable
    }

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MODIRI RESTAURANT',
                          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('FACTURE COMMANDE / RESTAURANT RECEIPT',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.blue300),
                    ),
                    child: pw.Text(
                      'COMMANDE #${order.orderNumber}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Date: ${_formatDate(order.createdAt)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(
                        'Type: ${order.orderType == "delivery" ? "Livraison / Delivery" : "Table ${order.tableName ?? 'Sur Place'}"}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      if (order.customerName != null && order.customerName!.trim().isNotEmpty)
                        pw.Text('Client: ${order.customerName}', style: const pw.TextStyle(fontSize: 10)),
                      if (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty)
                        pw.Text('Tél: ${order.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                      if (order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty)
                        pw.Text('Adresse: ${order.deliveryAddress}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Statut paiement: ${order.isPaid ? "PAYÉ" : order.isPartiallyPaid ? "PARTIELLEMENT PAYÉ" : "NON PAYÉ"}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: order.isPaid ? PdfColors.green700 : PdfColors.red700,
                          )),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Items table
              pw.TableHelper.fromTextArray(
                headers: ['Article / Item', 'Prix Unitaire', 'Qté', 'Total (DZD)'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellHeight: 28,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
                data: order.items.map((i) => [
                  i.itemName,
                  '${i.unitPrice.toStringAsFixed(0)} DZD',
                  'x${i.quantity}',
                  '${i.subtotal.toStringAsFixed(0)} DZD',
                ]).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),

              // Financial totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text('${order.totalAmount.toStringAsFixed(0)} DZD',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Montant Payé:', style: const pw.TextStyle(fontSize: 11)),
                          pw.Text('${order.amountPaid.toStringAsFixed(0)} DZD', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                      if (order.remaining > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Reste à payer:',
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                            pw.Text('${order.remaining.toStringAsFixed(0)} DZD',
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Remarques / Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(order.notes!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
              ],

              pw.Spacer(),
              pw.Center(
                child: pw.Text('Merci pour votre visite! · Modiri AI Restaurant POS',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _printInvoice(RestaurantOrder order) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Printing.layoutPdf(
        onLayout: (_) async {
          try {
            return await ref.read(restaurantRepositoryProvider).fetchOrderInvoicePdf(widget.orderId);
          } catch (_) {
            return await _generateOrderInvoicePdf(order);
          }
        },
        name: 'order-${order.orderNumber}.pdf',
      );
    } catch (_) {
      if (mounted) _showSnack(l10n.networkError);
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
          if (orderAsync.hasValue) ...[
            IconButton(
              tooltip: l10n.editOrderTitle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _EditOrderSheet(order: orderAsync.value!),
                );
                if (updated == true) {
                  ref.invalidate(_restaurantOrderDetailProvider(widget.orderId));
                  ref.invalidate(restaurantActiveOrdersProvider);
                }
              },
            ),
            IconButton(
              tooltip: l10n.exportAsPdf,
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _printInvoice(orderAsync.value!),
            ),
          ],
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          final prepColor = restaurantOrderStatusColor(order.status);
          final prepLabel = restaurantOrderStatusLabel(order.status);
          final isDineIn = order.orderType == 'dine_in';

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Header Card
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  boxShadow: AppSpacing.cardElevation,
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.orderNumberLabel(order.orderNumber),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        restaurantPaymentBadge(order, l10n),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(order.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Badges row: Prep status, Type, Table/Customer
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: prepColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: prepColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            prepLabel,
                            style: TextStyle(color: prepColor, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDineIn
                                    ? Icons.table_restaurant
                                    : Icons.delivery_dining,
                                size: 14,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDineIn
                                    ? (order.tableName != null ? order.tableName! : l10n.dineInOption)
                                    : l10n.deliveryOption,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (order.customerName != null && order.customerName!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person, size: 14, color: AppColors.info),
                                const SizedBox(width: 4),
                                Text(
                                  order.customerName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: AppColors.info,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (order.customerPhone != null && order.customerPhone!.trim().isNotEmpty)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: order.customerPhone!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.phoneCopiedMessage)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.customerPhone!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (order.deliveryAddress != null && order.deliveryAddress!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${l10n.deliveryAddressLabel}: ${order.deliveryAddress!}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Items Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.itemsLabel} (${order.items.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Detailed Item Cards (Never overflow horizontally)
              for (final item in order.items)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.quantity}×',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.unitPrice.toStringAsFixed(0)} DZD / وحدة',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.subtotal.toStringAsFixed(0)} DZD',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.sm),

              // Financial Breakdown Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  boxShadow: AppSpacing.cardElevation,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.totalLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${order.totalAmount.toStringAsFixed(0)} DZD',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.paidAmountShortLabel),
                        Text(
                          '${order.amountPaid.toStringAsFixed(0)} DZD',
                          style: TextStyle(
                            color: order.isPaid ? AppColors.success : Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (order.remaining > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.remainingLabel, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                          Text(
                            '${order.remaining.toStringAsFixed(0)} DZD',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        ],
                      ),
                    ],
                    if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                      const Divider(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ملاحظات / Notes: ${order.notes!}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Print Invoice / Imprimer Facture Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _printInvoice(order),
                  icon: const Icon(Icons.print_outlined),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  label: Text(
                    l10n.exportAsPdf,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              // Payment Action
              if (order.remaining > 0 && order.status != RestaurantOrderStatus.cancelled) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openPaymentScreen(order),
                    icon: const Icon(Icons.payments_outlined),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: Text(
                      '${l10n.payNowAction} (${order.remaining.toStringAsFixed(0)} DZD)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Status Management
              if (order.status != RestaurantOrderStatus.completed &&
                  order.status != RestaurantOrderStatus.cancelled) ...[
                Text(l10n.updateStatusLabel, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
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
                        avatar: status == RestaurantOrderStatus.completed && !order.isPaid
                            ? const Icon(Icons.lock, size: 14, color: AppColors.danger)
                            : null,
                        onSelected: (_) => _updateStatus(order, status),
                      ),
                    ActionChip(
                      label: Text(l10n.cancel),
                      backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                      onPressed: () => _updateStatus(order, RestaurantOrderStatus.cancelled),
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

class _EditOrderSheet extends ConsumerStatefulWidget {
  const _EditOrderSheet({required this.order});
  final RestaurantOrder order;

  @override
  ConsumerState<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends ConsumerState<_EditOrderSheet> {
  late final TextEditingController _customerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(text: widget.order.customerName ?? '');
    _phoneController = TextEditingController(text: widget.order.customerPhone ?? '');
    _addressController = TextEditingController(text: widget.order.deliveryAddress ?? '');
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final name = _customerNameController.text.trim();
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();

      await ref.read(restaurantRepositoryProvider).updateOrder(
            orderId: widget.order.id,
            customerName: name.isNotEmpty ? name : null,
            customerPhone: phone.isNotEmpty ? phone : null,
            clearPhone: phone.isEmpty,
            deliveryAddress: address.isNotEmpty ? address : null,
            clearAddress: address.isEmpty,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.orderUpdatedMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDelivery = widget.order.orderType == 'delivery';

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editOrderTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                prefixIcon: const Icon(Icons.person_outline),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
            if (isDelivery) ...[
              const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.updateOrderAction),
            ),
          ],
        ),
      ),
    );
  }
}
