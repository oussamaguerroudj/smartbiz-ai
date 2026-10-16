import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/receipt_printer.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../ai/presentation/desktop_ai_invoice_scanner_screen.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';

class DesktopInventoryScreen extends ConsumerStatefulWidget {
  const DesktopInventoryScreen({super.key});

  @override
  ConsumerState<DesktopInventoryScreen> createState() => _DesktopInventoryScreenState();
}

class _DesktopInventoryScreenState extends ConsumerState<DesktopInventoryScreen> {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  final _searchController = TextEditingController();
  final _barcodeLookupController = TextEditingController();

  // ignore: prefer_final_fields
  String _selectedCategory = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeLookupController.dispose();
    super.dispose();
  }

  void _showProductDetailsModal(Product p) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final margin = p.price > 0 ? (((p.price - p.costPrice) / p.price) * 100).toStringAsFixed(1) : '0.0';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: ModiriColors.brandBlue, size: 22),
                  const SizedBox(width: 10),
                  Text(p.name, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: ModiriColors.textMuted(isDark)),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ModiriColors.border(isDark)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.get('barcode_sku_label'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                          const SizedBox(height: 4),
                          Text((p.barcode != null && p.barcode!.isNotEmpty) ? p.barcode! : loc.get('no_barcode_assigned'),
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(loc.get('category'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                          const SizedBox(height: 4),
                          Text((p.category != null && p.category!.isNotEmpty) ? p.category! : 'General',
                              style: const TextStyle(color: ModiriColors.brandBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ModiriPanel(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('purchase_cost_column'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(_formatCurrency(p.costPrice),
                                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ModiriPanel(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('retail_selling_price'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(_formatCurrency(p.price),
                                style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ModiriPanel(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('gross_profit_margin'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('$margin%',
                                style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ModiriPanel(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('in_stock_quantity'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${p.stockQuantity} units (Min: ${p.minimumStock})',
                                style: TextStyle(
                                    color: p.stockQuantity <= 0
                                        ? ModiriColors.brandRose
                                        : p.stockQuantity <= p.minimumStock
                                            ? ModiriColors.brandAmber
                                            : ModiriColors.brandTeal,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('close'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(loc.get('print_label')),
              onPressed: () {
                final companyName = ref.read(sessionProvider).companyName ?? 'Modiri Store';
                ReceiptPrinter.printProductLabel(
                  companyName: companyName,
                  name: p.name,
                  price: p.price,
                  barcode: p.barcode ?? '',
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: Text(loc.get('restock')),
              onPressed: () {
                if (ctx.mounted) Navigator.of(ctx).pop();
                _showRestockModal(p);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: Text(loc.get('edit_product')),
              onPressed: () {
                if (ctx.mounted) Navigator.of(ctx).pop();
                _showProductModal(editingProduct: p);
              },
            ),
          ],
        );
      },
    );
  }

  void _showRestockModal(Product p) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl = TextEditingController(text: p.costPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Text('${loc.get('restock_product')}: ${p.name}',
              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loc.get('current_stock_label')}: ${p.stockQuantity} units',
                    style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('quantity_to_add')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('updated_unit_cost')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: Text(loc.get('confirm_restock')),
              onPressed: () async {
                final addQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (addQty <= 0) return;
                final newCost = double.tryParse(costCtrl.text.trim()) ?? p.costPrice;
                Navigator.of(ctx).pop();
                final updated = Product(
                  id: p.id,
                  companyId: p.companyId,
                  name: p.name,
                  category: p.category,
                  costPrice: newCost,
                  price: p.price,
                  stockQuantity: p.stockQuantity + addQty,
                  minimumStock: p.minimumStock,
                  barcode: p.barcode,
                  expirationDate: p.expirationDate,
                  size: p.size,
                  color: p.color,
                  brand: p.brand,
                );
                await ref.read(productsRepositoryProvider.notifier).updateProduct(updated);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${loc.get('added_units_to')} "${p.name}" (Stock: ${updated.stockQuantity})'),
                      backgroundColor: ModiriColors.brandTeal,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showProductModal({Product? editingProduct}) {
    final session = ref.read(sessionProvider);
    final bType = session.businessType ?? 'company';
    final isPharmacy = bType == 'pharmacy';
    final isClothing = bType == 'clothing';

    final nameCtrl = TextEditingController(text: editingProduct?.name ?? '');
    final catCtrl = TextEditingController(text: editingProduct?.category ?? 'General');
    final barcodeCtrl = TextEditingController(text: editingProduct?.barcode ?? '');
    final costCtrl = TextEditingController(
        text: editingProduct != null ? editingProduct.costPrice.toString() : '');
    final priceCtrl = TextEditingController(
        text: editingProduct != null ? editingProduct.price.toString() : '');
    final stockCtrl = TextEditingController(
        text: editingProduct != null ? editingProduct.stockQuantity.toString() : '0');
    final minStockCtrl = TextEditingController(
        text: editingProduct != null ? editingProduct.minimumStock.toString() : '5');
    final expDateCtrl = TextEditingController(
        text: editingProduct?.expirationDate != null
            ? editingProduct!.expirationDate!.toIso8601String().substring(0, 10)
            : '');
    final sizeCtrl = TextEditingController(text: editingProduct?.size ?? '');
    final colorCtrl = TextEditingController(text: editingProduct?.color ?? '');
    final brandCtrl = TextEditingController(text: editingProduct?.brand ?? '');

    String? modalError;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
          return AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Row(
              children: [
                Icon(
                  editingProduct != null ? Icons.edit_outlined : Icons.add_box_outlined,
                  color: ModiriColors.brandBlue,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  editingProduct != null ? loc.get('edit_product') : loc.get('add_new_product'),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (modalError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandRose.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
                        ),
                        child: Text(modalError!,
                            style: const TextStyle(color: ModiriColors.brandRose, fontSize: 12)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('product_name')),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: catCtrl,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('category')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: barcodeCtrl,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('barcode_sku')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('purchase_cost_input')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('selling_price_input')),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('stock_qty')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minStockCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(labelText: loc.get('minimum_alert_stock')),
                          ),
                        ),
                      ],
                    ),
                    if (isPharmacy) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: expDateCtrl,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: loc.get('expiration_date_input'),
                          hintText: 'e.g. 2026-12-31',
                          prefixIcon: const Icon(Icons.event, color: ModiriColors.brandAmber, size: 18),
                        ),
                      ),
                    ],
                    if (isClothing) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sizeCtrl,
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                              decoration: InputDecoration(labelText: loc.get('size_variant_input')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: colorCtrl,
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                              decoration: InputDecoration(labelText: loc.get('color_variant_input')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: brandCtrl,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('brand_input')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                          setModalState(() => modalError = 'Product name and selling price are required.');
                          return;
                        }

                        setModalState(() {
                          isSaving = true;
                          modalError = null;
                        });

                        final pPrice = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                        final cPrice = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                        final sQty = int.tryParse(stockCtrl.text.trim()) ?? 0;
                        final mStock = int.tryParse(minStockCtrl.text.trim()) ?? 5;

                        final repo = ref.read(productsRepositoryProvider.notifier);
                        DateTime? expDate;
                        if (expDateCtrl.text.trim().isNotEmpty) {
                          expDate = DateTime.tryParse(expDateCtrl.text.trim());
                        }

                        try {
                          if (editingProduct != null) {
                            final updated = Product(
                              id: editingProduct.id,
                              companyId: editingProduct.companyId,
                              name: nameCtrl.text.trim(),
                              category: catCtrl.text.trim().isNotEmpty ? catCtrl.text.trim() : 'General',
                              costPrice: cPrice,
                              price: pPrice,
                              stockQuantity: sQty,
                              minimumStock: mStock,
                              barcode: barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                              expirationDate: expDate ?? editingProduct.expirationDate,
                              size: sizeCtrl.text.trim().isNotEmpty ? sizeCtrl.text.trim() : null,
                              color: colorCtrl.text.trim().isNotEmpty ? colorCtrl.text.trim() : null,
                              brand: brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
                            );
                            await repo.updateProduct(updated);
                          } else {
                            await repo.addProduct(
                              name: nameCtrl.text.trim(),
                              category: catCtrl.text.trim().isNotEmpty ? catCtrl.text.trim() : 'General',
                              costPrice: cPrice,
                              price: pPrice,
                              stockQuantity: sQty,
                              minimumStock: mStock,
                              barcode: barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                              expirationDate: expDate,
                              size: sizeCtrl.text.trim().isNotEmpty ? sizeCtrl.text.trim() : null,
                              color: colorCtrl.text.trim().isNotEmpty ? colorCtrl.text.trim() : null,
                              brand: brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
                            );
                          }

                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          setModalState(() {
                            modalError = 'Failed to save product: $e';
                            isSaving = false;
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(editingProduct != null ? loc.get('update_product') : loc.get('create_product')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct(Product p) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Text(loc.get('delete_product'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${loc.get('confirm_delete_product')} "${p.name}"?',
              style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.get('delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await ref.read(productsRepositoryProvider.notifier).deleteProduct(p.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('removed_prefix')} "${p.name}".'), backgroundColor: ModiriColors.brandTeal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_failed_prefix')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final productsAsync = ref.watch(productsRepositoryProvider);
    final allProducts = productsAsync.valueOrNull ?? [];
    final session = ref.watch(sessionProvider);
    final bType = session.businessType ?? 'company';
    final isPharmacy = bType == 'pharmacy';
    final isClothing = bType == 'clothing';

    final categories = ['ALL', ...allProducts.map((p) => p.category ?? '').where((c) => c.isNotEmpty).toSet()];
    final lowStockCount = allProducts.where((p) => p.stockQuantity <= p.minimumStock).length;

    final filteredProducts = allProducts.where((p) {
      if (_selectedCategory != 'ALL' && p.category != _selectedCategory) return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header matching website
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2, color: ModiriColors.brandBlue, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        loc.get('inventory_title'),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('inventory_subtitle'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.document_scanner_outlined, size: 16, color: ModiriColors.brandBlue),
                    label: Text(loc.get('ai_scanner')),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (sCtx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Scaffold(
                              appBar: AppBar(
                                title: Text(loc.get('ai_scanner_title')),
                                leading: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(sCtx).pop(),
                                ),
                              ),
                              body: const DesktopAiInvoiceScannerScreen(initialMode: InvoiceScanMode.purchase),
                            ),
                          ),
                        ),
                      ).then((_) => ref.read(productsRepositoryProvider.notifier).load());
                    },
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: () => ref.read(productsRepositoryProvider.notifier).load(),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(loc.get('add_product')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModiriColors.brandBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    onPressed: () => _showProductModal(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3 KPI Stats Banner Cards matching website ProductsPage
          Row(
            children: [
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.get('total_products'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('${allProducts.length}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.get('low_stock_alert'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('$lowStockCount ${loc.get('items_count_suffix')}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: lowStockCount > 0 ? ModiriColors.brandAmber : ModiriColors.brandTeal,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.get('active_categories'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('${categories.where((c) => c != 'ALL').length}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.brandBlue, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Search and Quick Barcode Lookup Row
          Row(
            children: [
              Expanded(
                flex: 6,
                child: TextField(
                  controller: _searchController,
                  onChanged: (q) => ref.read(productsRepositoryProvider.notifier).load(search: q),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: loc.get('search_products_hint'),
                    prefixIcon: const Icon(Icons.search, color: ModiriColors.brandBlue, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _barcodeLookupController,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: loc.get('scan_barcode_hint'),
                    prefixIcon: const Icon(Icons.qr_code_scanner, color: ModiriColors.brandTeal, size: 20),
                    suffixIcon: TextButton(
                      child: Text(loc.get('lookup'), style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandTeal)),
                      onPressed: () {
                        final code = _barcodeLookupController.text.trim();
                        if (code.isNotEmpty) {
                          final match = allProducts.where((p) => p.barcode == code);
                          if (match.isNotEmpty) {
                            _showProductDetailsModal(match.first);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${loc.get('no_product_barcode')} "$code"'),
                                backgroundColor: ModiriColors.brandAmber,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  onSubmitted: (code) {
                    final match = allProducts.where((p) => p.barcode == code.trim());
                    if (match.isNotEmpty) {
                      _showProductDetailsModal(match.first);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Category Pills Filter
          if (categories.length > 2) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: ModiriColors.brandBlue,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : ModiriColors.textSecondary(isDark),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Product Inventory Table
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: ModiriColors.brandBlue)),
              error: (err, _) => Center(
                child: Text('${loc.get('error_loading_inventory')} $err', style: const TextStyle(color: ModiriColors.brandRose)),
              ),
              data: (_) {
                if (filteredProducts.isEmpty) {
                  return Center(
                    child: ModiriPanel(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: ModiriColors.brandBlue, size: 48),
                          const SizedBox(height: 12),
                          Text(loc.get('no_products_found'),
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(loc.get('no_products_found_desc'),
                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(loc.get('add_first_product')),
                            onPressed: () => _showProductModal(),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ModiriPanel(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(ModiriColors.tableHeader(isDark)),
                        columns: [
                          DataColumn(label: Text(loc.get('product_sku_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(loc.get('category'), style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(loc.get('purchase_cost_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(loc.get('selling_price'), style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(loc.get('stock_level_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (isPharmacy)
                            DataColumn(label: Text(loc.get('expiry_date_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (isClothing)
                            DataColumn(label: Text(loc.get('size_color_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(loc.get('action'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredProducts.map((p) {
                          final isOut = p.stockQuantity <= 0;
                          final isLow = p.stockQuantity <= p.minimumStock;
                          Color stockBadgeColor = ModiriColors.brandTeal;
                          if (isOut) {
                            stockBadgeColor = ModiriColors.brandRose;
                          } else if (isLow) {
                            stockBadgeColor = ModiriColors.brandAmber;
                          }

                          final expStr = p.expirationDate != null
                              ? p.expirationDate!.toIso8601String().substring(0, 10)
                              : 'N/A';
                          final variantParts = <String>[
                            if (p.size != null && p.size!.isNotEmpty) p.size!,
                            if (p.color != null && p.color!.isNotEmpty) p.color!,
                            if (p.brand != null && p.brand!.isNotEmpty) '(${p.brand!})',
                          ];
                          final variantStr = variantParts.isNotEmpty ? variantParts.join(' / ') : '—';

                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _showProductDetailsModal(p),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: ModiriColors.card(isDark),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: ModiriColors.border(isDark)),
                                        ),
                                        child: Icon(Icons.inventory_2, size: 18, color: ModiriColors.textMuted(isDark)),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(p.name,
                                              style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                                          if (p.barcode != null && p.barcode!.isNotEmpty)
                                            Text(p.barcode!,
                                                style: TextStyle(
                                                    fontFamily: 'monospace', fontSize: 11, color: ModiriColors.textMuted(isDark))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ModiriColors.border(isDark)),
                                  ),
                                  child: Text((p.category != null && p.category!.isNotEmpty) ? p.category! : 'General',
                                      style: TextStyle(fontSize: 11, color: ModiriColors.textSecondary(isDark))),
                                ),
                              ),
                              DataCell(
                                Text(_formatCurrency(p.costPrice),
                                    style: TextStyle(fontFamily: 'monospace', color: ModiriColors.textSecondary(isDark))),
                              ),
                              DataCell(
                                Text(_formatCurrency(p.price),
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontWeight: FontWeight.bold, color: ModiriColors.brandTeal)),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: stockBadgeColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: stockBadgeColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    '${p.stockQuantity} units',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stockBadgeColor),
                                  ),
                                ),
                              ),
                              if (isPharmacy)
                                DataCell(Text(expStr, style: TextStyle(fontFamily: 'monospace', color: ModiriColors.textSecondary(isDark)))),
                              if (isClothing)
                                DataCell(Text(variantStr, style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                                      color: ModiriColors.brandTeal,
                                      tooltip: loc.get('restock_product'),
                                      onPressed: () => _showRestockModal(p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 18),
                                      color: ModiriColors.textSecondary(isDark),
                                      tooltip: loc.get('view_details'),
                                      onPressed: () => _showProductDetailsModal(p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      color: ModiriColors.brandBlue,
                                      tooltip: loc.get('edit_product'),
                                      onPressed: () => _showProductModal(editingProduct: p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      color: ModiriColors.brandRose,
                                      tooltip: loc.get('delete_product'),
                                      onPressed: () => _deleteProduct(p),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
