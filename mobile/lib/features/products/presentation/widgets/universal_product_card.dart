import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/authenticated_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/companies_repository.dart';
import '../../domain/product.dart';
import '../screens/product_details_screen.dart';

/// Universal Product Card  -  the single source of truth for rich product
/// presentation across all business types (Clothing, Pharmacy, Grocery /
/// Supermarket, Retail, Restaurant, Company, etc.).
///
/// Fully data-driven: displays product image, name, price, stock status,
/// category, and all available existing metadata (size, color, brand,
/// expiration date, barcode). If an attribute is null or empty, it is
/// hidden with no empty badges or placeholders.
class UniversalProductCard extends ConsumerWidget {
  const UniversalProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.isCompact = false,
    this.showAttributes = true,
  });

  final Product product;
  final VoidCallback? onTap;

  /// If true, renders a compact horizontal row card (ideal for dashboard
  /// widget lists or tight spaces). If false (default), renders a rich
  /// modern card with a prominent top image.
  final bool isCompact;

  /// Whether to display metadata attribute chips (size, color, brand, etc.).
  final bool showAttributes;

  Color _stockColor(Product p) {
    if (p.isOutOfStock) return AppColors.stockOut;
    if (p.isLowStock) return AppColors.stockLow;
    return AppColors.stockHealthy;
  }

  String _stockLabel(BuildContext context, Product p) {
    final l10n = AppLocalizations.of(context);
    if (p.isOutOfStock) return l10n.qtyOutOfStock;
    if (p.isLowStock) return l10n.qtyLowStock(p.quantity);
    return l10n.qtyOnly(p.quantity);
  }

  IconData _businessContextIcon(String? businessType, String category) {
    final catLower = category.toLowerCase();
    if (catLower.contains('cloth') ||
        catLower.contains('shirt') ||
        catLower.contains('pant') ||
        catLower.contains('dress') ||
        catLower.contains('shoe') ||
        catLower.contains('vetement') ||
        businessType == 'clothing') {
      return Icons.checkroom_outlined;
    }
    if (catLower.contains('med') ||
        catLower.contains('drug') ||
        catLower.contains('pharma') ||
        catLower.contains('health') ||
        catLower.contains('soin') ||
        businessType == 'pharmacy') {
      return Icons.medication_outlined;
    }
    if (catLower.contains('food') ||
        catLower.contains('drink') ||
        catLower.contains('snack') ||
        catLower.contains('grocery') ||
        catLower.contains('fruit') ||
        catLower.contains('lait') ||
        businessType == 'grocery' ||
        businessType == 'supermarket' ||
        businessType == 'retail_store') {
      return Icons.shopping_basket_outlined;
    }
    if (catLower.contains('dish') ||
        catLower.contains('menu') ||
        catLower.contains('meal') ||
        catLower.contains('plat') ||
        catLower.contains('repas') ||
        businessType == 'restaurant' ||
        businessType == 'cafe') {
      return Icons.restaurant_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  String _formatPrice(double price) {
    final intPrice = price.round();
    final chars = intPrice.toString().split('');
    final buffer = StringBuffer();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && (chars.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }
    return '${buffer.toString()} DZD';
  }

  String _formatDate(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _hasAttributes(Product p) {
    return (p.brand != null && p.brand!.trim().isNotEmpty) ||
        (p.size != null && p.size!.trim().isNotEmpty) ||
        (p.color != null && p.color!.trim().isNotEmpty) ||
        p.expirationDate != null ||
        (p.barcode != null && p.barcode!.trim().isNotEmpty) ||
        (p.category.trim().isNotEmpty && p.category.toLowerCase() != 'uncategorized');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyInfoProvider).valueOrNull;
    final businessType = company?.businessType;
    final hasRealImage = product.imageUrl != null && product.imageUrl!.trim().isNotEmpty;
    final fallbackIcon = _businessContextIcon(businessType, product.category);
    final stockColor = _stockColor(product);
    final stockText = _stockLabel(context, product);
    final l10n = AppLocalizations.of(context);

    void defaultOnTap() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(productId: product.id),
        ),
      );
    }

    if (isCompact) {
      return _buildCompactCard(
        context: context,
        hasRealImage: hasRealImage,
        fallbackIcon: fallbackIcon,
        stockColor: stockColor,
        stockText: stockText,
        l10n: l10n,
        onTapAction: onTap ?? defaultOnTap,
      );
    }

    return _buildRichCard(
      context: context,
      hasRealImage: hasRealImage,
      fallbackIcon: fallbackIcon,
      stockColor: stockColor,
      stockText: stockText,
      l10n: l10n,
      onTapAction: onTap ?? defaultOnTap,
    );
  }

  /// Rich, modern vertical card layout with prominent top image.
  Widget _buildRichCard({
    required BuildContext context,
    required bool hasRealImage,
    required IconData fallbackIcon,
    required Color stockColor,
    required String stockText,
    required AppLocalizations? l10n,
    required VoidCallback onTapAction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = isDark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
        : const Color(0xFFE2E6F2);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapAction,
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            boxShadow: AppSpacing.cardElevation,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Prominent Top Product Image Container
              Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                        : const Color(0xFFF1F3FA),
                    child: hasRealImage
                        ? AuthenticatedImage(
                            storageKey: product.imageUrl!,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorWidget: _buildImageFallback(context, fallbackIcon),
                          )
                        : _buildImageFallback(context, fallbackIcon),
                  ),

                  // Floating Stock Badge (top corner)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: stockColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stockText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: stockColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Category Badge (top opposite corner) when available
                  if (product.category.trim().isNotEmpty &&
                      product.category.toLowerCase() != 'uncategorized')
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.75)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                product.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // 2. Product Information Details
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name & Selling Price Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _formatPrice(product.sellingPrice),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),

                    // Existing Metadata Attributes Wrap (Size, Color, Brand, Expiration, Barcode)
                    if (showAttributes && _hasAttributes(product)) ...[
                      const SizedBox(height: 10),
                      _buildAttributesWrap(context: context, l10n: l10n),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact horizontal card layout (for dashboard recent lists or tight views).
  Widget _buildCompactCard({
    required BuildContext context,
    required bool hasRealImage,
    required IconData fallbackIcon,
    required Color stockColor,
    required String stockText,
    required AppLocalizations? l10n,
    required VoidCallback onTapAction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.2)
        : const Color(0xFFE2E6F2);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapAction,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: AppSpacing.cardElevation,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image / Stylized Placeholder (84 x 84)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                child: Container(
                  width: 84,
                  height: 84,
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                      : const Color(0xFFF1F3FA),
                  child: hasRealImage
                      ? AuthenticatedImage(
                          storageKey: product.imageUrl!,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorWidget: _buildImageFallback(context, fallbackIcon, size: 32),
                        )
                      : _buildImageFallback(context, fallbackIcon, size: 32),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Product Info & Attributes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Stock Status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: stockColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            stockText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: stockColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      _formatPrice(product.sellingPrice),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                    if (showAttributes && _hasAttributes(product)) ...[
                      const SizedBox(height: 6),
                      _buildAttributesWrap(context: context, l10n: l10n),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the fallback container when no real image exists.
  Widget _buildImageFallback(BuildContext context, IconData icon, {double size = 44}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: size,
            color: theme.colorScheme.primary.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }

  /// Builds clean, informative badges for all non-null, non-empty existing attributes.
  Widget _buildAttributesWrap({
    required BuildContext context,
    required AppLocalizations? l10n,
  }) {
    final chips = <Widget>[];

    // 1. Brand (e.g. Nike, Zara, Pfizer, Danone)
    if (product.brand != null && product.brand!.trim().isNotEmpty) {
      chips.add(
        _AttributeChip(
          icon: Icons.label_outline_rounded,
          text: product.brand!.trim(),
          backgroundColor: Colors.indigo.withValues(alpha: 0.10),
          textColor: Colors.indigo.shade700,
        ),
      );
    }

    // 2. Size (e.g. S, M, L, XL, 42, 500ml)
    if (product.size != null && product.size!.trim().isNotEmpty) {
      final label = l10n != null ? '${l10n.sizeLabel}: ${product.size!.trim()}' : 'Size: ${product.size!.trim()}';
      chips.add(
        _AttributeChip(
          icon: Icons.straighten_outlined,
          text: label,
          backgroundColor: Colors.teal.withValues(alpha: 0.10),
          textColor: Colors.teal.shade800,
        ),
      );
    }

    // 3. Color (e.g. Black, Blue, Red)
    if (product.color != null && product.color!.trim().isNotEmpty) {
      final label = l10n != null ? '${l10n.colorLabel}: ${product.color!.trim()}' : 'Color: ${product.color!.trim()}';
      chips.add(
        _AttributeChip(
          icon: Icons.palette_outlined,
          text: label,
          backgroundColor: Colors.purple.withValues(alpha: 0.10),
          textColor: Colors.purple.shade700,
        ),
      );
    }

    // 4. Expiration Date (e.g. Pharmacy / Grocery)
    if (product.expirationDate != null) {
      final isExpired = product.expirationDate!.isBefore(DateTime.now());
      final formatted = _formatDate(product.expirationDate!);
      chips.add(
        _AttributeChip(
          icon: isExpired ? Icons.event_busy_outlined : Icons.event_outlined,
          text: isExpired ? 'Expired: $formatted' : 'Exp: $formatted',
          backgroundColor: isExpired
              ? AppColors.danger.withValues(alpha: 0.14)
              : Colors.amber.withValues(alpha: 0.14),
          textColor: isExpired ? AppColors.danger : const Color(0xFFB45309),
        ),
      );
    }

    // 5. Barcode (when available and non-empty)
    if (product.barcode != null && product.barcode!.trim().isNotEmpty) {
      chips.add(
        _AttributeChip(
          icon: Icons.qr_code_2_rounded,
          text: product.barcode!.trim(),
          backgroundColor: Colors.blueGrey.withValues(alpha: 0.10),
          textColor: Colors.blueGrey.shade800,
        ),
      );
    }

    // 6. Category badge if not already presented or when no other attributes
    if (chips.isEmpty &&
        product.category.trim().isNotEmpty &&
        product.category.toLowerCase() != 'uncategorized') {
      chips.add(
        _AttributeChip(
          icon: Icons.category_outlined,
          text: product.category.trim(),
          backgroundColor: Colors.grey.withValues(alpha: 0.12),
          textColor: Colors.grey.shade800,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }
}

class _AttributeChip extends StatelessWidget {
  const _AttributeChip({
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
