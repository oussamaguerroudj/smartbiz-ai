import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/cart_manager.dart';
import '../../domain/cart_session.dart';
import 'create_sale_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';

/// Sales Screen — POS / Active Open Carts Overview.
///
/// Dedicated to current in-progress sales and open cart sessions.
/// Displays each open cart with:
/// - Cart number / customer name
/// - Product count & running DZD total
/// - Hold/Active status
///
/// Completed invoices and past sales history are strictly separated
/// and located inside [InvoicesScreen].
class SalesListScreen extends ConsumerWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final multiCart = ref.watch(multiCartProvider);
    final cartManager = ref.read(multiCartProvider.notifier);
    final activeCarts = multiCart.activeCarts;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSales),
        actions: [
          IconButton(
            tooltip: l10n.invoicesTitle,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InvoicesScreen()),
            ),
          ),
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
          : activeCarts.isEmpty
              ? _EmptyCartsView(
                  l10n: l10n,
                  onNewCart: () async {
                    final newCart = await cartManager.createNewCart();
                    cartManager.switchCart(newCart.id);
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
                    );
                  },
                )
              : _OpenCartsContent(
                  carts: activeCarts,
                  activeCartId: multiCart.activeCartId,
                  cartManager: cartManager,
                  l10n: l10n,
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final newCart = await cartManager.createNewCart();
          cartManager.switchCart(newCart.id);
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
          );
        },
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(l10n.newCartAction),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyCartsView extends StatelessWidget {
  const _EmptyCartsView({required this.l10n, required this.onNewCart});
  final AppLocalizations l10n;
  final VoidCallback onNewCart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.noOpenCarts,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onNewCart,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text(l10n.newCartAction),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content List / Grid
// ---------------------------------------------------------------------------

class _OpenCartsContent extends StatelessWidget {
  const _OpenCartsContent({
    required this.carts,
    required this.activeCartId,
    required this.cartManager,
    required this.l10n,
  });

  final List<CartSession> carts;
  final String activeCartId;
  final CartManager cartManager;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtitle header banner
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.openCartsTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  l10n.activeClients(carts.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ),

        // Carts list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: carts.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => FadeSlideIn(
              delay: Duration(milliseconds: 35 * i),
              child: _CartCard(
                cart: carts[i],
                cartIndex: i + 1,
                isActive: carts[i].id == activeCartId,
                cartManager: cartManager,
                l10n: l10n,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cart Card
// ---------------------------------------------------------------------------

class _CartCard extends StatelessWidget {
  const _CartCard({
    required this.cart,
    required this.cartIndex,
    required this.isActive,
    required this.cartManager,
    required this.l10n,
  });

  final CartSession cart;
  final int cartIndex;
  final bool isActive;
  final CartManager cartManager;
  final AppLocalizations l10n;

  bool get _isOnHold => cart.status == CartSessionStatus.onHold;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isActive
        ? AppColors.primary
        : _isOnHold
            ? AppColors.warning
            : AppColors.borderLight;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      onTap: () {
        cartManager.switchCart(cart.id);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: borderColor, width: isActive ? 2 : 1),
          boxShadow: AppSpacing.cardElevation,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Cart Label + On Hold Badge + Delete
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : _isOnHold
                            ? AppColors.warning.withValues(alpha: 0.12)
                            : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🛒', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.cartLabel(cartIndex),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? AppColors.primary : null,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isOnHold) const SizedBox(width: 6),
                          if (_isOnHold) ...[
                            const Icon(
                              Icons.pause_circle_outline,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.cartOnHoldStatus,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        cart.customerName ?? l10n.walkInCustomer,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                  tooltip: l10n.deleteCartTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),

            // Bottom Row: Items count + Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    l10n.cartProductCount(cart.totalItemCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  '${cart.total.toStringAsFixed(0)} DZD',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            // Resume button if on hold
            if (_isOnHold) ...[
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    cartManager.resumeCart(cart.id);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.success),
                  label: Text(l10n.resumeCartAction),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: const BorderSide(color: AppColors.success, width: 1.2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCartTitle),
        content: Text(l10n.deleteCartConfirm(cart.customerName ?? l10n.walkInCustomer)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      cartManager.deleteCart(cart.id);
    }
  }
}
