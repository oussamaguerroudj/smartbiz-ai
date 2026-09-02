import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';

/// Create Sale — Spec Ch. 11.2. Implements the full guided flow:
/// Select product(s) → Enter quantity → Add to cart → Calculate total
/// → Confirm sale → (repository handles: Update inventory, Calculate
/// profit, Generate invoice).
class CreateSaleScreen extends ConsumerStatefulWidget {
  const CreateSaleScreen({super.key});

  @override
  ConsumerState<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CartLine {
  _CartLine({required this.product, required this.quantity});
  final Product product;
  int quantity;

  double get lineTotal => product.sellingPrice * quantity;
}

class _CreateSaleScreenState extends ConsumerState<CreateSaleScreen> {
  final List<_CartLine> _cart = [];
  final _discountController = TextEditingController(text: '0');

  double get _subtotal => _cart.fold(0, (sum, line) => sum + line.lineTotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  void _openProductPicker() async {
    final products = ref.read(productsRepositoryProvider);
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductPickerSheet(products: products),
    );
    if (selected == null) return;
    _addOrIncrement(selected);
  }

  void _addOrIncrement(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((l) => l.product.id == product.id);
      if (existingIndex >= 0) {
        final current = _cart[existingIndex];
        final maxQty = product.quantity;
        if (current.quantity < maxQty) {
          current.quantity += 1;
        } else {
          _showSnack('Only $maxQty in stock for ${product.name}');
        }
      } else {
        if (product.quantity <= 0) {
          _showSnack('${product.name} is out of stock');
          return;
        }
        _cart.add(_CartLine(product: product, quantity: 1));
      }
    });
  }

  void _updateQuantity(_CartLine line, int delta) {
    setState(() {
      final newQty = line.quantity + delta;
      if (newQty <= 0) {
        _cart.remove(line);
      } else if (newQty > line.product.quantity) {
        _showSnack('Only ${line.product.quantity} in stock for ${line.product.name}');
      } else {
        line.quantity = newQty;
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirmSale() {
    if (_cart.isEmpty) {
      _showSnack('Add at least one product to the cart');
      return;
    }
    final saleItems = _cart
        .map((line) => SaleItem(
              productId: line.product.id,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.sellingPrice,
              unitCost: line.product.purchasePrice,
            ))
        .toList();

    try {
      final sale = ref.read(salesRepositoryProvider.notifier).createSale(
            cartItems: saleItems,
            discount: _discount,
            paymentStatus: PaymentStatus.paid,
          );
      final invoice = ref.read(invoicesRepositoryProvider.notifier).forSale(sale.id);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnack('Sale recorded — ${invoice?.invoiceNumber ?? sale.id}');
      }
    } on InsufficientStockException catch (e) {
      // Mirrors the required ROLLBACK behavior: nothing was written,
      // cart state is untouched, user can fix quantities and retry.
      _showSnack('Could not complete sale: $e');
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: OutlinedButton.icon(
              onPressed: _openProductPicker,
              icon: const Icon(Icons.search),
              label: const Text('Search product or scan barcode'),
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Cart is empty — add a product above'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final line = _cart[i];
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${line.product.name} × ${line.quantity}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _updateQuantity(line, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => _updateQuantity(line, 1),
                            ),
                            SizedBox(
                              width: 72,
                              child: Text(
                                '${line.lineTotal.toStringAsFixed(0)} DZD',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Discount (DZD)')),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${_total.toStringAsFixed(0)} DZD',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: _confirmSale,
                  child: const Text('Confirm Sale'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.products});
  final List<Product> products;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search product...'),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final p = filtered[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      p.isOutOfStock ? 'Out of stock' : 'Qty: ${p.quantity}',
                    ),
                    trailing: Text('${p.sellingPrice.toStringAsFixed(0)} DZD'),
                    enabled: !p.isOutOfStock,
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
