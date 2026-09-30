/// Pharmacy specialized module domain models (business-specialization
/// brief Ch. 15). Same one-file convention as clinic_models.dart /
/// restaurant_models.dart.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class PharmacyLowStockProduct {
  PharmacyLowStockProduct({
    required this.id,
    required this.name,
    this.category,
    required this.quantity,
    required this.minimumStock,
  });

  final String id;
  final String name;
  final String? category;
  final int quantity;
  final int minimumStock;

  factory PharmacyLowStockProduct.fromJson(Map<String, dynamic> json) => PharmacyLowStockProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        quantity: json['quantity'] as int,
        minimumStock: json['minimum_stock'] as int,
      );
}

class PharmacyExpiringProduct {
  PharmacyExpiringProduct({
    required this.id,
    required this.name,
    this.category,
    required this.quantity,
    required this.expirationDate,
  });

  final String id;
  final String name;
  final String? category;
  final int quantity;
  final DateTime expirationDate;

  bool get isExpired => expirationDate.isBefore(DateTime.now());

  factory PharmacyExpiringProduct.fromJson(Map<String, dynamic> json) => PharmacyExpiringProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        quantity: json['quantity'] as int,
        expirationDate: DateTime.parse(json['expiration_date'] as String),
      );
}

class PharmacyBestSeller {
  PharmacyBestSeller({required this.name, required this.unitsSold, required this.revenue});

  final String name;
  final int unitsSold;
  final double revenue;

  factory PharmacyBestSeller.fromJson(Map<String, dynamic> json) => PharmacyBestSeller(
        name: json['name'] as String,
        unitsSold: json['units_sold'] as int,
        revenue: _toDouble(json['revenue']),
      );
}

class PharmacyDashboardStats {
  PharmacyDashboardStats({
    required this.todayRevenue,
    required this.todayGrossProfit,
    required this.todayNetProfit,
    required this.todayExpenses,
    required this.transactionsToday,
    required this.productsSoldToday,
    required this.weekRevenue,
    required this.monthRevenue,
    required this.lowStockCount,
    required this.lowStockProducts,
    required this.expiringCount,
    required this.expiringProducts,
    required this.expiredCount,
    required this.inventoryCostValue,
    required this.inventoryRetailValue,
    required this.unitsInStock,
    required this.bestSellingProducts,
    required this.suppliersCount,
  });

  final double todayRevenue;

  /// Cost-of-goods-aware — from sale_items.line_profit, same as
  /// Reports' `grossProfit`.
  final double todayGrossProfit;

  /// revenue - operating expenses, same formula as the CORE dashboard
  /// and Reports' `netProfit` (does NOT additionally subtract COGS —
  /// see pharmacy.service.js's getDashboard doc comment).
  final double todayNetProfit;
  final double todayExpenses;
  final int transactionsToday;
  final int productsSoldToday;
  final double weekRevenue;
  final double monthRevenue;
  final int lowStockCount;
  final List<PharmacyLowStockProduct> lowStockProducts;
  final int expiringCount;
  final List<PharmacyExpiringProduct> expiringProducts;
  final int expiredCount;
  final double inventoryCostValue;
  final double inventoryRetailValue;
  final int unitsInStock;
  final List<PharmacyBestSeller> bestSellingProducts;
  final int suppliersCount;

  factory PharmacyDashboardStats.fromJson(Map<String, dynamic> json) => PharmacyDashboardStats(
        todayRevenue: _toDouble(json['todayRevenue']),
        todayGrossProfit: _toDouble(json['todayGrossProfit']),
        todayNetProfit: _toDouble(json['todayNetProfit']),
        todayExpenses: _toDouble(json['todayExpenses']),
        transactionsToday: json['transactionsToday'] as int,
        productsSoldToday: json['productsSoldToday'] as int,
        weekRevenue: _toDouble(json['weekRevenue']),
        monthRevenue: _toDouble(json['monthRevenue']),
        lowStockCount: json['lowStockCount'] as int,
        lowStockProducts: (json['lowStockProducts'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(PharmacyLowStockProduct.fromJson)
            .toList(),
        expiringCount: json['expiringCount'] as int,
        expiringProducts: (json['expiringProducts'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(PharmacyExpiringProduct.fromJson)
            .toList(),
        expiredCount: json['expiredCount'] as int,
        inventoryCostValue: _toDouble(json['inventoryCostValue']),
        inventoryRetailValue: _toDouble(json['inventoryRetailValue']),
        unitsInStock: json['unitsInStock'] as int,
        bestSellingProducts: (json['bestSellingProducts'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(PharmacyBestSeller.fromJson)
            .toList(),
        suppliersCount: json['suppliersCount'] as int,
      );
}
