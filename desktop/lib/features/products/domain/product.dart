class Product {
  final String id;
  final String companyId;
  final String name;
  final double price;
  final double costPrice;
  final int stockQuantity;
  final int minimumStock;
  final String? barcode;
  final String? category;
  final DateTime? expirationDate;
  final String? size;
  final String? color;
  final String? brand;

  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    this.stockQuantity = 0,
    this.minimumStock = 5,
    this.barcode,
    this.category,
    this.expirationDate,
    this.size,
    this.color,
    this.brand,
  });

  bool get isOutOfStock => stockQuantity <= 0;
  bool get isLowStock => stockQuantity > 0 && stockQuantity <= minimumStock;
  double get marginPercent =>
      price <= 0 ? 0.0 : ((price - costPrice) / price) * 100;

  factory Product.fromJson(Map<String, dynamic> json) {
    DateTime? expDate;
    final rawExp = json['expiration_date'] ?? json['expirationDate'];
    if (rawExp != null) {
      expDate = DateTime.tryParse(rawExp.toString());
    }

    return Product(
      id: json['id']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? json['company_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] ?? json['selling_price'] ?? json['sellingPrice'] ?? 0.0 as num).toDouble(),
      costPrice: (json['costPrice'] ?? json['cost_price'] ?? json['purchase_price'] ?? json['purchasePrice'] ?? 0.0 as num).toDouble(),
      stockQuantity: (json['stockQuantity'] ?? json['stock_quantity'] ?? json['quantity'] ?? 0 as num).toInt(),
      minimumStock: (json['minimumStock'] ?? json['minimum_stock'] ?? 5 as num).toInt(),
      barcode: json['barcode']?.toString(),
      category: json['category']?.toString(),
      expirationDate: expDate,
      size: json['size']?.toString(),
      color: json['color']?.toString(),
      brand: json['brand']?.toString(),
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) => Product.fromJson(map);

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'name': name,
    'price': price,
    'cost_price': costPrice,
    'stock_quantity': stockQuantity,
    'minimum_stock': minimumStock,
    'barcode': barcode,
    'category': category,
    'expiration_date': expirationDate?.toIso8601String().substring(0, 10),
    'size': size,
    'color': color,
    'brand': brand,
  };
}
