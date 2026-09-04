import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../data/sales_repository.dart';
import '../../domain/sale.dart';

/// Create Sale — Spec Ch. 11.2.
///
/// SIMPLIFICATION vs. Phase 4: cart quantity limits are still checked
/// client-side against the last-loaded product list for immediate UI
/// feedback (no point letting someone tap +50 in the cart when they can
/// see only 5 are in stock) — but the AUTHORITATIVE check is now the
/// real server-side transaction (Phase 5, verified: rejects with
/// INSUFFICIENT_STOCK and rolls back cleanly). If stock changed between
/// opening this screen and confirming (e.g. someone else sold the last
/// unit), the server call will still catch it and this screen surfaces
/// that ApiException — the client-side check is a UX nicety, not the
/// source of truth.
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
  bool _isSubmitting = false;

  double get _subtotal => _cart.fold(0, (sum, line) => sum + line.lineTotal);
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  void _openProductPicker() async {
    final products = ref.read(productsRepositoryProvider).valueOrNull ?? [];
    if (products.isEmpty) {
      _showSnack('No products loaded yet — check your connection and try again');
      return;
    }
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
        if (current.quantity < product.quantity) {
          current.quantity += 1;
        } else {
          _showSnack('Only ${product.quantity} in stock for ${product.name}');
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

  Future<void> _confirmSale() async {
    if (_cart.isEmpty) {
      _showSnack('Add at least one product to the cart');
      return;
    }
    setState(() => _isSubmitting = true);
    final items = _cart
        .map((line) => SaleItemInput(
              productId: line.product.id,
              productName: line.product.name,
              quantity: line.quantity,
            ))
        .toList();

    try {
      await ref.read(salesRepositoryProvider.notifier).createSale(
            items: items,
            discount: _discount,
            paymentStatus: PaymentStatus.paid,
          );
      if (mounted) {
        Navigator.of(context).pop();
        _showSnack('Sale recorded successfully');
      }
    } on ApiException catch (e) {
      // Real server rejection (e.g. INSUFFICIENT_STOCK) — nothing was
      // written server-side, cart stays exactly as the user left it so
      // they can adjust quantities and retry.
      if (mounted) _showSnack('Could not complete sale: ${e.message}');
    } catch (e) {
      if (mounted) _showSnack('Could not reach the server — check your connection');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                  onPressed: _isSubmitting ? null : _confirmSale,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Sale'),
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
