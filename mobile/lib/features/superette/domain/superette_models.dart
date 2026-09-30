/// Supérette / General Store specialized module domain models
/// (business-specialization brief Ch. 16). Same one-file convention as
/// pharmacy_models.dart / clinic_models.dart / restaurant_models.dart.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class SuperetteLowStockProduct {
  SuperetteLowStockProduct({
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

  factory SuperetteLowStockProduct.fromJson(Map<String, dynamic> json) => SuperetteLowStockProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        quantity: json['quantity'] as int,
        minimumStock: json['minimum_stock'] as int,
      );
}

class SuperetteBestSeller {
  SuperetteBestSeller({required this.name, required this.unitsSold, required this.revenue});

  final String name;
  final int unitsSold;
  final double revenue;

  factory SuperetteBestSeller.fromJson(Map<String, dynamic> json) => SuperetteBestSeller(
        name: json['name'] as String,
        unitsSold: json['units_sold'] as int,
        revenue: _toDouble(json['revenue']),
      );
}

/// Ch. 16's "Credit/customer debt when applicable" — a single debtor.
class SuperetteDebtor {
  SuperetteDebtor({required this.id, required this.name, this.phone, required this.balanceDue});

  final String id;
  final String name;
  final String? phone;
  final double balanceDue;

  factory SuperetteDebtor.fromJson(Map<String, dynamic> json) => SuperetteDebtor(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        balanceDue: _toDouble(json['balance_due']),
      );
}

class SuperetteDashboardStats {
  SuperetteDashboardStats({
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
    required this.stockCostValue,
    required this.stockRetailValue,
    required this.unitsInStock,
    required this.bestSellingProducts,
    required this.suppliersCount,
    required this.customersCount,
    required this.outstandingDebt,
    required this.debtorsCount,
    required this.topDebtors,
  });

  final double todayRevenue;

  /// Cost-of-goods-aware — from sale_items.line_profit, same as
  /// Reports'/Pharmacy's `grossProfit`.
  final double todayGrossProfit;

  /// revenue - operating expenses, same formula as the CORE dashboard,
  /// Reports and Pharmacy's dashboard (does NOT additionally subtract
  /// COGS — see superette.service.js's getDashboard doc comment).
  final double todayNetProfit;
  final double todayExpenses;
  final int transactionsToday;
  final int productsSoldToday;
  final double weekRevenue;
  final double monthRevenue;
  final int lowStockCount;
  final List<SuperetteLowStockProduct> lowStockProducts;
  final double stockCostValue;
  final double stockRetailValue;
  final int unitsInStock;
  final List<SuperetteBestSeller> bestSellingProducts;
  final int suppliersCount;
  final int customersCount;
  final double outstandingDebt;
  final int debtorsCount;
  final List<SuperetteDebtor> topDebtors;

  factory SuperetteDashboardStats.fromJson(Map<String, dynamic> json) => SuperetteDashboardStats(
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
            .map(SuperetteLowStockProduct.fromJson)
            .toList(),
        stockCostValue: _toDouble(json['stockCostValue']),
        stockRetailValue: _toDouble(json['stockRetailValue']),
        unitsInStock: json['unitsInStock'] as int,
        bestSellingProducts: (json['bestSellingProducts'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(SuperetteBestSeller.fromJson)
            .toList(),
        suppliersCount: json['suppliersCount'] as int,
        customersCount: json['customersCount'] as int,
        outstandingDebt: _toDouble(json['outstandingDebt']),
        debtorsCount: json['debtorsCount'] as int,
        topDebtors: (json['topDebtors'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(SuperetteDebtor.fromJson)
            .toList(),
      );
}
