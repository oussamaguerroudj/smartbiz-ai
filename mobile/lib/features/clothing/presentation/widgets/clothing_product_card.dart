import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/authenticated_image.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/screens/product_details_screen.dart';

/// Redesigned Clothing Product Card — shows photo/placeholder, name,
/// price, stock status badge, and clothing attributes (size, color, brand).
class ClothingProductCard extends StatelessWidget {
  const ClothingProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  final Product product;
  final VoidCallback? onTap;

  Color get _stockColor {
    if (product.isOutOfStock) return AppColors.stockOut;
    if (product.isLowStock) return AppColors.stockLow;
    return AppColors.stockHealthy;
  }

  String get _stockText {
    if (product.isOutOfStock) return 'Out of Stock';
    if (product.isLowStock) return 'Low Stock (${product.quantity})';
    return '${product.quantity} in stock';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: InkWell(
        onTap: onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailsScreen(productId: product.id),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image or Stylized Placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? AuthenticatedImage(
                          storageKey: product.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Icon(
                            Icons.checkroom_outlined,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Product Info & Attributes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _stockColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            _stockText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _stockColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      '${product.sellingPrice.toStringAsFixed(0)} DZD',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),

                    // Clothing Attributes: Brand, Size, Color
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (product.brand != null && product.brand!.isNotEmpty)
                          _AttributeBadge(
                            icon: Icons.label_outline,
                            text: product.brand!,
                            backgroundColor: Colors.indigo.withValues(alpha: 0.10),
                            textColor: Colors.indigo,
                          ),
                        if (product.size != null && product.size!.isNotEmpty)
                          _AttributeBadge(
                            icon: Icons.straighten_outlined,
                            text: product.size!,
                            backgroundColor: Colors.teal.withValues(alpha: 0.10),
                            textColor: Colors.teal,
                          ),
                        if (product.color != null && product.color!.isNotEmpty)
                          _AttributeBadge(
                            icon: Icons.palette_outlined,
                            text: product.color!,
                            backgroundColor: Colors.purple.withValues(alpha: 0.10),
                            textColor: Colors.purple,
                          ),
                        if ((product.brand == null || product.brand!.isEmpty) &&
                            (product.size == null || product.size!.isEmpty) &&
                            (product.color == null || product.color!.isEmpty))
                          _AttributeBadge(
                            icon: Icons.category_outlined,
                            text: product.category,
                            backgroundColor: Colors.grey.withValues(alpha: 0.12),
                            textColor: Colors.grey.shade700,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttributeBadge extends StatelessWidget {
  const _AttributeBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
