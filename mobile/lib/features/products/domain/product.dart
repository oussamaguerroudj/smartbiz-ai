/// Product model  -  mirrors the `products` table (Phase 3 migration 006)
/// and the exact JSON shape verified against the real backend in Phase 5
/// testing (purchase_price/selling_price arrive as strings from
/// PostgreSQL NUMERIC via node-postgres, so fromJson parses them safely).
class Product {
  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    this.minimumStock = 5,
    this.barcode,
    this.expirationDate,
    this.imageUrl,
    // Ch. 18 (Clothing) attributes  -  backend migration 020, nullable for
    // every business type that doesn't use them.
    this.size,
    this.color,
    this.brand,
  });

  final String id;
  final String name;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int minimumStock;
  final String? barcode;
  final DateTime? expirationDate;
  final String? imageUrl;
  final String? size;
  final String? color;
  final String? brand;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        category: (json['category'] as String?) ?? 'Uncategorized',
        purchasePrice: double.parse(json['purchase_price'].toString()),
        sellingPrice: double.parse(json['selling_price'].toString()),
        quantity: (json['quantity'] as num).toInt(),
        minimumStock: (json['minimum_stock'] as num?)?.toInt() ?? 5,
        barcode: json['barcode'] as String?,
        expirationDate: json['expiration_date'] != null
            ? DateTime.tryParse(json['expiration_date'] as String)
            : null,
        imageUrl: json['image_url'] as String?,
        size: json['size'] as String?,
        color: json['color'] as String?,
        brand: json['brand'] as String?,
      );

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity > 0 && quantity <= minimumStock;

  double get marginPercent =>
      sellingPrice <= 0 ? 0 : ((sellingPrice - purchasePrice) / sellingPrice) * 100;
}

