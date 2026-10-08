import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/barcode_scanner_screen.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../../customers/presentation/screens/customers_screen.dart' show Customer, customersRepositoryProvider;
import '../../data/credit_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';

/// Create Credit Sale  -  Ch. 13/14.
///
/// Deliberately mirrors CreateSaleScreen's cart + barcode-scan pattern
/// closely (same _CartLine shape, same _addOrIncrement/_scanBarcode
/// logic, same client-side stock hint backed by the same authoritative
/// server-side check) so the two flows feel identical apart from the
/// two things that actually differ: picking a customer up front, and
/// "Amount to Pay Now" replacing a discount field.
class CreateCreditSaleScreen extends ConsumerStatefulWidget {
  const CreateCreditSaleScreen({super.key});

  @override
  ConsumerState<CreateCreditSaleScreen> createState() => _CreateCreditSaleScreenState();
}

class _CartLine {
  _CartLine({required this.product, required this.quantity});
  final Product product;
  int quantity;

  double get lineTotal => product.sellingPrice * quantity;
}

class _CreateCreditSaleScreenState extends ConsumerState<CreateCreditSaleScreen> {
  final List<_CartLine> _cart = [];
  final _amountPaidController = TextEditingController(text: '0');
  Customer? _selectedCustomer;
  bool _isSubmitting = false;

  double get _total => _cart.fold(0, (sum, line) => sum + line.lineTotal);
  double get _amountPaidNow => double.tryParse(_amountPaidController.text) ?? 0;
  double get _remainingCredit => (_total - _amountPaidNow).clamp(0, double.infinity);

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickCustomer() async {
    final customers = ref.read(customersRepositoryProvider).valueOrNull ?? [];
    final l10n = AppLocalizations.of(context)!;

    if (customers.isEmpty) {
      _showSnack(l10n.noCustomersYet);
      return;
    }

    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: customers.length,
            itemBuilder: (context, i) {
              final c = customers[i];
              return ListTile(
                title: Text(c.name),
                subtitle: c.phone != null ? Text(c.phone!) : null,
                onTap: () => Navigator.of(context).pop(c),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null) setState(() => _selectedCustomer = selected);
  }

  void _openProductPicker() async {
    final products = ref.read(productsRepositoryProvider).valueOrNull ?? [];
    if (products.isEmpty) {
      _showSnack(AppLocalizations.of(context)!.noProductsLoadedYet);
      return;
    }
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreditProductPickerSheet(products: products),
    );
    if (selected == null) return;
    _addOrIncrement(selected);
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final product = await ref.read(productsRepositoryProvider.notifier).findByBarcode(code);
    if (!mounted) return;

    if (product == null) {
      _showSnack(l10n.barcodeNotFoundMessage(code));
      return;
    }

    final added = _addOrIncrement(product);
    if (added) {
      _showSnack(l10n.scannedProductAddedToCart(product.name));
    }
  }

  bool _addOrIncrement(Product product) {
    var added = false;
    setState(() {
      final existingIndex = _cart.indexWhere((l) => l.product.id == product.id);
      if (existingIndex >= 0) {
        final current = _cart[existingIndex];
        if (current.quantity < product.quantity) {
          current.quantity += 1;
          added = true;
        } else {
          _showSnack(AppLocalizations.of(context)!.onlyNInStock(product.quantity, product.name));
        }
      } else {
        if (product.quantity <= 0) {
          _showSnack(AppLocalizations.of(context)!.outOfStockFor(product.name));
        } else {
          _cart.add(_CartLine(product: product, quantity: 1));
          added = true;
        }
      }
    });
    return added;
  }

  void _updateQuantity(_CartLine line, int delta) {
    setState(() {
      final newQty = line.quantity + delta;
      if (newQty <= 0) {
        _cart.remove(line);
      } else if (newQty > line.product.quantity) {
        _showSnack(AppLocalizations.of(context)!.onlyNInStock(line.product.quantity, line.product.name));
      } else {
        line.quantity = newQty;
      }
    });
  }

  Future<void> _confirmCreditSale() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedCustomer == null) {
      _showSnack(l10n.selectCustomerFirst);
      return;
    }
    if (_cart.isEmpty) {
      _showSnack(l10n.addAtLeastOneProduct);
      return;
    }
    if (_amountPaidNow > _total) {
      _showSnack(l10n.amountExceedsTotal);
      return;
    }

    setState(() => _isSubmitting = true);
    final items = _cart
        .map((line) => CreditItemInput(
              productId: line.product.id,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.sellingPrice,
            ))
        .toList();

    try {
      await ref.read(creditRepositoryProvider).createPurchase(
            customerId: _selectedCustomer!.id,
            items: items,
            amountPaidNow: _amountPaidNow,
          );
      // Stock changed (decremented) and the customer's balance changed  - 
      // refresh both so every other screen reading them stays correct.
      await ref.read(productsRepositoryProvider.notifier).load();
      await ref.read(customersRepositoryProvider.notifier).load();
      if (mounted) {
        Navigator.of(context).pop();
        _showSnack(l10n.creditSaleRecorded);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack(l10n.networkError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.creditSaleTitle),
        actions: [
          IconButton(
            tooltip: l10n.scanInvoice,
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AiScannerScreen(mode: InvoiceScanMode.sales),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: OutlinedButton.icon(
              onPressed: _pickCustomer,
              icon: const Icon(Icons.person_outline),
              label: Text(_selectedCustomer?.name ?? l10n.selectCustomerHint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openProductPicker,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.searchProductOrScan),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  child: IconButton(
                    tooltip: l10n.scanBarcodeTooltip,
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                    onPressed: _scanBarcode,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  child: IconButton(
                    tooltip: l10n.scanInvoice,
                    icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AiScannerScreen(mode: InvoiceScanMode.sales),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? Center(child: Text(l10n.cartEmpty))
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
                          boxShadow: AppSpacing.cardElevation,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.totalLabel, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${_total.toStringAsFixed(0)} DZD',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(child: Text(l10n.amountToPayNowLabel)),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _amountPaidController,
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
                    Text(l10n.remainingCreditLabel, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${_remainingCredit.toStringAsFixed(0)} DZD',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmCreditSale,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.confirmCreditSaleButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditProductPickerSheet extends StatefulWidget {
  const _CreditProductPickerSheet({required this.products});
  final List<Product> products;

  @override
  State<_CreditProductPickerSheet> createState() => _CreditProductPickerSheetState();
}

class _CreditProductPickerSheetState extends State<_CreditProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _query.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.searchProductDots),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        p.isOutOfStock ? l10n.outOfStockLabel : l10n.qtyOnly(p.quantity),
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
      ),
    );
  }
}
