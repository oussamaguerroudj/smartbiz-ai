import 'package:flutter/material.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/widgets/universal_product_card.dart';

export '../../../products/presentation/widgets/universal_product_card.dart';

/// Legacy ClothingProductCard wrapper  -  delegates directly to [UniversalProductCard]
/// to guarantee ONE single source of truth for product-card UI across the entire
/// application without duplicating code.
class ClothingProductCard extends StatelessWidget {
  const ClothingProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.isCompact = true,
  });

  final Product product;
  final VoidCallback? onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return UniversalProductCard(
      product: product,
      onTap: onTap,
      isCompact: isCompact,
    );
  }
}
