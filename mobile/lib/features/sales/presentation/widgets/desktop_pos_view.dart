import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/desktop_components.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../../customers/data/customers_repository.dart';
import '../../data/cart_manager.dart';
import '../../domain/cart_session.dart';

/// Desktop Point of Sale (POS) View
/// Left: 62% product catalog & barcode search
/// Right: 38% cart tabs, customer selector, line items, and checkout
class DesktopPosView extends ConsumerStatefulWidget {
  const DesktopPosView({
    super.key,
    required this.onCompleteCheckout,
  });

  final VoidCallback onCompleteCheckout;

  @override
  ConsumerState<DesktopPosView> createState() => _DesktopPosViewState();
}

class _DesktopPosViewState extends ConsumerState<DesktopPosView> {
  final _searchController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  String _selectedCategory = 'ALL';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final productsAsync = ref.watch(productsRepositoryProvider);
    final cartState = ref.watch(multiCartProvider);
    final activeCart = cartState.activeCart;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f2) {
          _barcodeFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            DesktopPageHeader(
              title: l10n.newSaleTitle,
              subtitle: 'Multi-cart enterprise terminal with instant keyboard barcode support (F2 to scan).',
              badge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.point_of_sale_rounded, size: 12, color: AppColors.electricBlue),
                    SizedBox(width: 4),
                    Text(
                      'TERMINAL #01',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.electricBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: () => ref.read(multiCartProvider.notifier).createNewCart(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Cart Session'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),

            // Main Split POS View
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: 62% Product Catalog & Search
                  Expanded(
                    flex: 62,
                    child: Column(
                      children: [
                        // Search & Barcode Bar
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _barcodeFocusNode,
                                decoration: InputDecoration(
                                  hintText: l10n.searchProductOrScan,
                                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppColors.electricBlue, width: 1.5),
                                  ),
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                                onSubmitted: (query) {
                                  if (query.isNotEmpty) {
                                    productsAsync.whenData((products) {
                                      final match = products.where((p) => p.barcode == query || p.id == query).firstOrNull;
                                      if (match != null) {
                                        ref.read(multiCartProvider.notifier).addOrIncrementItem(match);
                                      }
                                    });
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _barcodeFocusNode.requestFocus();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Products Catalog Grid
                        Expanded(
                          child: productsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Error loading products: $e')),
                            data: (products) {
                              final categories = ['ALL', ...{for (final p in products) if (p.category.isNotEmpty) p.category}];

                              final filtered = products.where((p) {
                                final matchesCat = _selectedCategory == 'ALL' || p.category == _selectedCategory;
                                final matchesSearch = _searchQuery.isEmpty ||
                                    p.name.toLowerCase().contains(_searchQuery) ||
                                    (p.barcode != null && p.barcode!.contains(_searchQuery));
                                return matchesCat && matchesSearch;
                              }).toList();

                              return Column(
                                children: [
                                  // Category chips bar
                                  if (categories.length > 1)
                                    SizedBox(
                                      height: 34,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: categories.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                                        itemBuilder: (context, i) {
                                          final cat = categories[i];
                                          final isSelected = _selectedCategory == cat;

                                          return ChoiceChip(
                                            label: Text(cat),
                                            selected: isSelected,
                                            onSelected: (_) => setState(() => _selectedCategory = cat),
                                            selectedColor: AppColors.electricBlue.withValues(alpha: 0.2),
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              color: isSelected ? AppColors.electricBlue : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  if (categories.length > 1) const SizedBox(height: 12),

                                  // Products Grid
                                  Expanded(
                                    child: filtered.isEmpty
                                        ? Center(
                                            child: Text(
                                              'No products found matching criteria.',
                                              style: TextStyle(
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          )
                                        : GridView.builder(
                                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 180,
                                              childAspectRatio: 0.85,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                            ),
                                            itemCount: filtered.length,
                                            itemBuilder: (context, i) {
                                              final product = filtered[i];
                                              return _DesktopProductCard(
                                                product: product,
                                                onTap: () {
                                                  ref.read(multiCartProvider.notifier).addOrIncrementItem(product);
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // RIGHT: 38% Active Multi-Cart Session & Checkout
                  Expanded(
                    flex: 38,
                    child: GlassPanel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Cart Session Tabs
                          if (cartState.activeCarts.isNotEmpty)
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: cartState.activeCarts.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 6),
                                itemBuilder: (context, idx) {
                                  final cart = cartState.activeCarts[idx];
                                  final isActive = cart.id == cartState.activeCartId;

                                  return InkWell(
                                    onTap: () => ref.read(multiCartProvider.notifier).switchCart(cart.id),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.electricBlue.withValues(alpha: 0.15)
                                            : (isDark ? AppColors.surfaceSecondaryDark : AppColors.backgroundLight),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isActive
                                              ? AppColors.electricBlue
                                              : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 14,
                                            color: isActive ? AppColors.electricBlue : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            cart.customerName ?? 'Cart #${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                              color: isActive ? (isDark ? Colors.white : AppColors.textPrimaryLight) : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                            ),
                                          ),
                                          if (cartState.activeCarts.length > 1) ...[
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () => ref.read(multiCartProvider.notifier).deleteCart(cart.id),
                                              child: const Icon(Icons.close_rounded, size: 14),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 12),

                          // Customer Selector
                          _CustomerSelectorRow(
                            selectedCustomerId: activeCart?.customerId,
                            selectedCustomerName: activeCart?.customerName,
                            onCustomerSelected: (id, name) {
                              ref.read(multiCartProvider.notifier).updateCustomer(customerId: id, customerName: name);
                            },
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.borderLight,
                          ),
                          const SizedBox(height: 8),

                          // Cart Line Items List
                          Expanded(
                            child: (activeCart == null || activeCart.items.isEmpty)
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_shopping_cart_rounded,
                                          size: 40,
                                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          l10n.cartEmpty,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: activeCart.items.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.borderLight,
                                    ),
                                    itemBuilder: (context, idx) {
                                      final item = activeCart.items[idx];
                                      return _CartItemRow(item: item);
                                    },
                                  ),
                          ),

                          // Cart Math & Checkout Panel
                          Container(
                            padding: const EdgeInsets.only(top: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Subtotal
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    Text(
                                      '${activeCart?.subtotal.toStringAsFixed(2) ?? '0.00'} DZD',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Discount Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.discountDzdLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      height: 30,
                                      child: TextField(
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.end,
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onChanged: (val) {
                                          final discount = double.tryParse(val) ?? 0.0;
                                          ref.read(multiCartProvider.notifier).setDiscount(discount);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Grand Total
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.totalLabel,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${activeCart?.total.toStringAsFixed(2) ?? '0.00'} DZD',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.electricBlue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Checkout Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: (activeCart != null && activeCart.items.isNotEmpty)
                                        ? widget.onCompleteCheckout
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.electricBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      l10n.confirmSaleButton,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopProductCard extends StatelessWidget {
  const _DesktopProductCard({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceSecondaryDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.inventory_2_outlined, size: 28, color: AppColors.electricBlue),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${product.sellingPrice.toStringAsFixed(0)} DZD',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.electricBlue,
                ),
              ),
              Text(
                'x${product.quantity}',
                style: TextStyle(
                  fontSize: 11,
                  color: product.quantity > 5
                      ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                      : AppColors.warningAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends ConsumerWidget {
  const _CartItemRow({required this.item});

  final CartSessionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.unitPrice.toStringAsFixed(2)} DZD',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: () => ref.read(multiCartProvider.notifier).updateQuantity(item.productId, -1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: () => ref.read(multiCartProvider.notifier).updateQuantity(item.productId, 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Text(
            '${item.lineTotal.toStringAsFixed(0)} DZD',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CustomerSelectorRow extends ConsumerWidget {
  const _CustomerSelectorRow({
    required this.selectedCustomerId,
    required this.selectedCustomerName,
    required this.onCustomerSelected,
  });

  final String? selectedCustomerId;
  final String? selectedCustomerName;
  final void Function(String? id, String? name) onCustomerSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersRepositoryProvider);

    return customersAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (customers) {
        return Row(
          children: [
            const Icon(Icons.person_outline, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String?>(
                value: selectedCustomerId,
                isExpanded: true,
                hint: const Text('Walk-in Customer', style: TextStyle(fontSize: 12)),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Walk-in Customer', style: TextStyle(fontSize: 12)),
                  ),
                  ...customers.map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 12)),
                      )),
                ],
                onChanged: (id) {
                  if (id == null) {
                    onCustomerSelected(null, null);
                  } else {
                    final cust = customers.firstWhere((c) => c.id == id);
                    onCustomerSelected(cust.id, cust.name);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
