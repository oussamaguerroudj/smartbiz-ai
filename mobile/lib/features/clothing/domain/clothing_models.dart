// Clothing Store specialized module domain models (business-
// specialization brief Ch. 18). Same one-file convention as
// superette_models.dart / pharmacy_models.dart.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class ClothingLowStockProduct {
  ClothingLowStockProduct({
    required this.id,
    required this.name,
    this.category,
    this.size,
    this.color,
    this.brand,
    required this.quantity,
    required this.minimumStock,
  });

  final String id;
  final String name;
  final String? category;
  final String? size;
  final String? color;
  final String? brand;
  final int quantity;
  final int minimumStock;

  /// Short "Size M · Blue · Nike"-style tag built from whichever
  /// attributes are actually set  -  none of them are required (Ch. 18
  /// attributes are optional per product, see migration 020).
  String? get attributeSummary {
    final parts = <String>[
      if (size != null && size!.isNotEmpty) 'Size $size',
      if (color != null && color!.isNotEmpty) color!,
      if (brand != null && brand!.isNotEmpty) brand!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory ClothingLowStockProduct.fromJson(Map<String, dynamic> json) => ClothingLowStockProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        size: json['size'] as String?,
        color: json['color'] as String?,
        brand: json['brand'] as String?,
        quantity: json['quantity'] as int,
        minimumStock: json['minimum_stock'] as int,
      );
}

class ClothingBestSeller {
  ClothingBestSeller({
    required this.name,
    this.size,
    this.color,
    this.brand,
    required this.unitsSold,
    required this.revenue,
  });

  final String name;
  final String? size;
  final String? color;
  final String? brand;
  final int unitsSold;
  final double revenue;

  factory ClothingBestSeller.fromJson(Map<String, dynamic> json) => ClothingBestSeller(
        name: json['name'] as String,
        size: json['size'] as String?,
        color: json['color'] as String?,
        brand: json['brand'] as String?,
        unitsSold: json['units_sold'] as int,
        revenue: _toDouble(json['revenue']),
      );
}

class ClothingCategoryStock {
  ClothingCategoryStock({required this.category, required this.productCount, required this.unitsInStock});

  final String category;
  final int productCount;
  final int unitsInStock;

  factory ClothingCategoryStock.fromJson(Map<String, dynamic> json) => ClothingCategoryStock(
        category: json['category'] as String,
        productCount: json['product_count'] as int,
        unitsInStock: json['units_in_stock'] as int,
      );
}

class ClothingDebtor {
  ClothingDebtor({required this.id, required this.name, this.phone, required this.balanceDue});

  final String id;
  final String name;
  final String? phone;
  final double balanceDue;

  factory ClothingDebtor.fromJson(Map<String, dynamic> json) => ClothingDebtor(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        balanceDue: _toDouble(json['balance_due']),
      );
}

class ClothingDashboardStats {
  ClothingDashboardStats({
    required this.todayRevenue,
    required this.todayGrossProfit,
    required this.todayNetProfit,
    required this.todayExpenses,
    required this.transactionsToday,
    required this.itemsSoldToday,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.lowStockCount,
    required this.lowStockProducts,
    required this.stockCostValue,
    required this.stockRetailValue,
    required this.unitsInStock,
    required this.bestSellingProducts,
    required this.stockByCategory,
    required this.suppliersCount,
    required this.customersCount,
    required this.outstandingDebt,
    required this.debtorsCount,
    required this.topDebtors,
  });

  final double todayRevenue;
  final double todayGrossProfit;
  final double todayNetProfit;
  final double todayExpenses;
  final int transactionsToday;
  final int itemsSoldToday;
  final double weekRevenue;
  final double monthRevenue;
  final int lowStockCount;
  final List<ClothingLowStockProduct> lowStockProducts;
  final double stockCostValue;
  final double stockRetailValue;
  final int unitsInStock;
  final List<ClothingBestSeller> bestSellingProducts;
  final List<ClothingCategoryStock> stockByCategory;
  final int suppliersCount;
  final int customersCount;
  final double outstandingDebt;
  final int debtorsCount;
  final List<ClothingDebtor> topDebtors;

  factory ClothingDashboardStats.fromJson(Map<String, dynamic> json) => ClothingDashboardStats(
        todayRevenue: _toDouble(json['todayRevenue']),
        todayGrossProfit: _toDouble(json['todayGrossProfit']),
        todayNetProfit: _toDouble(json['todayNetProfit']),
        todayExpenses: _toDouble(json['todayExpenses']),
        transactionsToday: json['transactionsToday'] as int,
        itemsSoldToday: json['itemsSoldToday'] as int,
        weekRevenue: _toDouble(json['weekRevenue']),
        monthRevenue: _toDouble(json['monthRevenue']),
        lowStockCount: json['lowStockCount'] as int,
        lowStockProducts: (json['lowStockProducts'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClothingLowStockProduct.fromJson)
            .toList(),
        stockCostValue: _toDouble(json['stockCostValue']),
        stockRetailValue: _toDouble(json['stockRetailValue']),
        unitsInStock: json['unitsInStock'] as int,
        bestSellingProducts: (json['bestSellingProducts'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClothingBestSeller.fromJson)
            .toList(),
        stockByCategory: (json['stockByCategory'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClothingCategoryStock.fromJson)
            .toList(),
        suppliersCount: json['suppliersCount'] as int,
        customersCount: json['customersCount'] as int,
        outstandingDebt: _toDouble(json['outstandingDebt']),
        debtorsCount: json['debtorsCount'] as int,
        topDebtors: (json['topDebtors'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(ClothingDebtor.fromJson)
            .toList(),
      );
}
