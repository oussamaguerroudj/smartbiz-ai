import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/session.dart';
import '../../../../core/widgets/barcode_scanner_screen.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../data/sales_repository.dart';
import '../../data/cart_manager.dart';
import '../../domain/cart_session.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';
import '../../../customers/data/customers_repository.dart';

/// Create Sale  -  Multi-Cart POS System (Part 1 & Part 11).
///
/// Supports multiple simultaneous customers / shopping carts:
/// - Cashier can switch between Client 1, Client 2, Client 3...
/// - Each cart maintains its own independent items, quantities, and discount.
/// - Offline-first persistence via SQLite (`cart_sessions`, `cart_session_items`).
/// - Full tenant isolation by company_id.
/// - Hold / Resume / Clear / Create / Checkout operations.
class CreateSaleScreen extends ConsumerStatefulWidget {
  const CreateSaleScreen({super.key});

  @override
  ConsumerState<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends ConsumerState<CreateSaleScreen> {
  final _discountController = TextEditingController(text: '0');
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final session = ref.read(sessionProvider);
      if (!session.isLoggedIn || session.companyId == null) return;
      final multiCart = ref.read(multiCartProvider);
      if (multiCart.carts.isEmpty && !multiCart.isLoading) {
        try {
          await ref.read(multiCartProvider.notifier).createNewCart();
        } catch (_) {}
      }
      if (!mounted) return;
      final activeCart = ref.read(multiCartProvider).activeCart;
      if (activeCart != null && activeCart.discount > 0) {
        _discountController.text = activeCart.discount.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openCustomerPicker() async {
    final customers = ref.read(customersRepositoryProvider).valueOrNull ?? [];
    final l10n = AppLocalizations.of(context)!;

    final selected = await showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: Text(l10n.walkInCustomer),
                onTap: () => Navigator.of(context).pop(null),
              ),
              const Divider(height: 1),
              Expanded(
                child: customers.isEmpty
                    ? Center(child: Text(l10n.noCustomersYet))
                    : ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, i) {
                          final c = customers[i];
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: c.phone != null ? Text(c.phone!) : null,
                            onTap: () => Navigator.of(context).pop(c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (selected != null) {
      await ref.read(multiCartProvider.notifier).updateCustomer(
            customerId: selected.id,
            customerName: selected.name,
          );
    }
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
      builder: (context) => _ProductPickerSheet(products: products),
    );
    if (selected == null) return;
    _addProduct(selected);
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

    final added = await _addProduct(product);
    if (added && mounted) {
      _showSnack(l10n.scannedProductAddedToCart(product.name));
    }
  }

  Future<bool> _addProduct(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    if (product.quantity <= 0) {
      _showSnack(l10n.outOfStockFor(product.name));
      return false;
    }

    final manager = ref.read(multiCartProvider.notifier);
    final success = await manager.addOrIncrementItem(product);
    if (!success && mounted) {
      _showSnack(l10n.onlyNInStock(product.quantity, product.name));
    }
    return success;
  }

  Future<void> _confirmSale() async {
    final l10n = AppLocalizations.of(context)!;
    final cartState = ref.read(multiCartProvider);
    final activeCart = cartState.activeCart;

    if (activeCart == null || activeCart.isEmpty) {
      _showSnack(l10n.addAtLeastOneProduct);
      return;
    }

    setState(() => _isSubmitting = true);
    final manager = ref.read(multiCartProvider.notifier);
    final salesRepo = ref.read(salesRepositoryProvider.notifier);

    try {
      final result = await manager.checkoutActiveCart(salesRepo);
      if (mounted) {
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        nav.pop();

        final invoice = result['invoice'] as Map<String, dynamic>?;
        final invoiceId = invoice?['id']?.toString();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.saleRecordedSuccessfully),
            action: invoiceId != null
                ? SnackBarAction(
                    label: l10n.invoicesTitle,
                    onPressed: () {
                      nav.push(
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailsScreen(invoiceId: invoiceId),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(l10n.couldNotCompleteSale(e.message));
    } catch (_) {
      if (mounted) _showSnack(l10n.networkError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final multiCart = ref.watch(multiCartProvider);
    final activeCart = multiCart.activeCart;
    final cartManager = ref.read(multiCartProvider.notifier);

    // Sync discount controller if cart changed
    if (activeCart != null &&
        double.tryParse(_discountController.text) != activeCart.discount &&
        !FocusScope.of(context).hasFocus) {
      _discountController.text = activeCart.discount.toStringAsFixed(0);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newSaleTitle),
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
      body: multiCart.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Multi-Cart Selector
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.activeClients(multiCart.activeCarts.length),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (activeCart != null && multiCart.carts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                                tooltip: l10n.cancel,
                                onPressed: () => cartManager.deleteCart(activeCart.id),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Row(
                          children: [
                            for (final cart in multiCart.carts) ...[
                              _CartTabChip(
                                cart: cart,
                                isSelected: cart.id == multiCart.activeCartId,
                                onTap: () {
                                  cartManager.switchCart(cart.id);
                                  _discountController.text = cart.discount.toStringAsFixed(0);
                                },
                              ),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: Text(l10n.newClientAction),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                              onPressed: () async {
                                final newCart = await cartManager.createNewCart();
                                _discountController.text = '0';
                                cartManager.switchCart(newCart.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Cart control toolbar (Customer selector, Item count, Hold/Resume, Clear)
                if (activeCart != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: InkWell(
                                  onTap: _openCustomerPicker,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_outline, size: 15, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            activeCart.customerName ?? l10n.walkInCustomer,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '· ${l10n.cartItemCount(activeCart.totalItemCount)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (activeCart.status == CartSessionStatus.onHold)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.resumeCartAction,
                            icon: const Icon(Icons.play_circle_outline, color: AppColors.success),
                            onPressed: () => cartManager.resumeCart(activeCart.id),
                          )
                        else
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.holdCartAction,
                            icon: const Icon(Icons.pause_circle_outline, color: AppColors.warning),
                            onPressed: () => cartManager.holdActiveCart(),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: l10n.clearCartAction,
                          icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
                          onPressed: activeCart.isEmpty ? null : () => cartManager.clearActiveCart(),
                        ),
                      ],
                    ),
                  ),

                // Search & Scan Bar
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

                // Cart items list for currently active cart
                Expanded(
                  child: (activeCart == null || activeCart.isEmpty)
                      ? Center(child: Text(l10n.cartEmpty))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          itemCount: activeCart.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, i) {
                            final line = activeCart.items[i];
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.productName,
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${line.unitPrice.toStringAsFixed(0)} DZD × ${line.quantity}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () => cartManager.updateQuantity(line.productId, -1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      '${line.quantity}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () => cartManager.updateQuantity(line.productId, 1),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${line.lineTotal.toStringAsFixed(0)} DZD',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Bottom total and checkout bar
                if (activeCart != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, -2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(l10n.discountDzdLabel)),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _discountController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.end,
                                onChanged: (v) {
                                  final discount = double.tryParse(v) ?? 0;
                                  cartManager.setDiscount(discount);
                                },
                                decoration: const InputDecoration(isDense: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.totalLabel, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              '${activeCart.total.toStringAsFixed(0)} DZD',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ElevatedButton(
                          onPressed: _isSubmitting || activeCart.isEmpty ? null : _confirmSale,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(l10n.confirmSaleButton),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CartTabChip extends StatelessWidget {
  const _CartTabChip({
    required this.cart,
    required this.isSelected,
    required this.onTap,
  });

  final CartSession cart;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOnHold = cart.status == CartSessionStatus.onHold;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : isOnHold
                    ? AppColors.warning
                    : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOnHold) ...[
              const Icon(Icons.pause_circle_outline, size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
            ],
            Text(
              cart.customerName ?? 'Client',
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (cart.items.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${cart.totalItemCount}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${cart.total.toStringAsFixed(0)} DZD',
                style: TextStyle(
                  color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final filtered = _query.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    final sheetHeight = (availableHeight * 0.65).clamp(240.0, 520.0);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: mediaQuery.viewInsets.bottom + AppSpacing.sm,
        ),
        child: SizedBox(
          height: sheetHeight,
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
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
