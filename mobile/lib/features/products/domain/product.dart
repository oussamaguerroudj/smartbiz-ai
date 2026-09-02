/// Product model — mirrors the `products` table (Phase 3 migration 006).
/// Money fields use `double` in the client for simplicity; the backend
/// (Phase 5) is the source of truth and uses NUMERIC(12,2) — client-side
/// values are always round-tripped through the API once it exists.
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

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity > 0 && quantity <= minimumStock;

  double get marginPercent =>
      sellingPrice <= 0 ? 0 : ((sellingPrice - purchasePrice) / sellingPrice) * 100;

  Product copyWith({
    String? name,
    String? category,
    double? purchasePrice,
    double? sellingPrice,
    int? quantity,
    int? minimumStock,
    String? barcode,
    DateTime? expirationDate,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      minimumStock: minimumStock ?? this.minimumStock,
      barcode: barcode ?? this.barcode,
      expirationDate: expirationDate ?? this.expirationDate,
    );
  }
}
