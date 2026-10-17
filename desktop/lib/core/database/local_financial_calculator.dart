import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'desktop_database.dart';

class LocalFinancialSummary {
  final double allRevenue;
  final double allExpenses;
  final double globalCogs;
  final double globalNetProfit;
  final double periodRevenue;
  final double periodTotalSales;
  final double periodCollected;
  final double outstandingDebt;
  final double periodCogs;
  final double periodGrossProfit;
  final double inventoryValue;
  final double periodExpenses;
  final double periodNetProfit;
  final double profitMargin;
  final int salesCount;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> expensesByCategory;

  const LocalFinancialSummary({
    required this.allRevenue,
    required this.allExpenses,
    this.globalCogs = 0.0,
    required this.globalNetProfit,
    required this.periodRevenue,
    this.periodTotalSales = 0.0,
    this.periodCollected = 0.0,
    this.outstandingDebt = 0.0,
    this.inventoryValue = 0.0,
    required this.periodCogs,
    required this.periodGrossProfit,
    required this.periodExpenses,
    required this.periodNetProfit,
    required this.profitMargin,
    required this.salesCount,
    this.topProducts = const [],
    this.expensesByCategory = const [],
  });
}

class DesktopLocalFinancialCalculator {
  /// Calculate full financial report scoped strictly to [companyId] for tenant isolation.
  static Future<LocalFinancialSummary> calculateReport({
    required String period, // 'daily' | 'monthly' | 'yearly'
    required String companyId,
    String? businessType,
    String? date,
    String? month,
    int? year,
    Database? customDb,
  }) async {
    final db = customDb ?? await ModiriDesktopDatabase.instance.database;

    // 1. Global all-time revenue, cogs & expenses (tenant-isolated)
    final globalSalesRes = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total), 0.0) AS revenue
      FROM sales
      WHERE company_id = ? AND payment_status = 'paid' AND id NOT LIKE 'REST-%'
      ''',
      [companyId],
    );

    final globalExpensesRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0.0) AS total
      FROM expenses
      WHERE company_id = ?
      ''',
      [companyId],
    );

    final isRestaurant = (businessType == 'restaurant' || businessType == 'cafe');

    double globalCogs = 0.0;
    if (!isRestaurant) {
      try {
        final cogsRes = await db.rawQuery(
          '''
          SELECT
            COALESCE(SUM(
              (SELECT COALESCE(SUM(COALESCE(NULLIF(si.unit_cost, 0), p.cost_price, 0) * si.quantity), 0.0)
               FROM sale_items si
               LEFT JOIN products p ON p.id = si.product_id AND (p.company_id = s.company_id OR p.company_id IS NULL)
               WHERE si.sale_id = s.id)
            ), 0.0) AS cogs
          FROM sales s
          WHERE s.company_id = ? AND s.payment_status = 'paid'
          ''',
          [companyId],
        );
        globalCogs = (cogsRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {
        try {
          final fallbackCogs = await db.rawQuery(
            '''
            SELECT
              COALESCE(SUM(si.unit_cost * si.quantity), 0.0) AS cogs
            FROM sale_items si
            JOIN sales s ON s.id = si.sale_id
            WHERE s.company_id = ? AND s.payment_status = 'paid'
            ''',
            [companyId],
          );
          globalCogs = (fallbackCogs.first['cogs'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }
    }

    // Inventory Value for company
    double inventoryValue = 0.0;
    try {
      final invRes = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(CASE WHEN stock_quantity > 0 THEN stock_quantity * cost_price ELSE 0.0 END), 0.0) AS inventory_value
        FROM products
        WHERE company_id = ?
        ''',
        [companyId],
      );
      inventoryValue = (invRes.first['inventory_value'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      try {
        final fallbackInv = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * purchase_price ELSE 0.0 END), 0.0) AS inventory_value
          FROM products
          WHERE company_id = ?
          ''',
          [companyId],
        );
        inventoryValue = (fallbackInv.first['inventory_value'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
    }



    // Global credit payments
    double globalCreditPayments = 0.0;
    try {
      final cpRes = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0.0) AS total FROM credit_payments WHERE company_id = ?',
        [companyId],
      );
      globalCreditPayments = (cpRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // Global restaurant revenue
    double globalRestRevenue = 0.0;
    try {
      final rpRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0.0) AS total FROM restaurant_payments WHERE company_id = ?",
        [companyId],
      );
      globalRestRevenue = (rpRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      try {
        final roRes = await db.rawQuery(
          "SELECT COALESCE(SUM(amount_paid), 0.0) AS total FROM restaurant_orders WHERE company_id = ? AND status != 'cancelled'",
          [companyId],
        );
        globalRestRevenue = (roRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
    }

    double globalProductPurchases = 0.0;
    try {
      final suppPayRes = await db.rawQuery(
        '''
        SELECT (
          COALESCE((
            SELECT SUM(amount)
            FROM supplier_payments
            WHERE company_id = ?
          ), 0.0)
          +
          COALESCE((
            SELECT SUM(sp.amount_paid)
            FROM supplier_purchases sp
            WHERE sp.company_id = ?
              AND sp.amount_paid > 0
              AND sp.id NOT IN (
                SELECT DISTINCT purchase_id
                FROM supplier_payments
                WHERE purchase_id IS NOT NULL AND company_id = ?
              )
          ), 0.0)
        ) AS total
        ''',
        [companyId, companyId, companyId],
      );
      globalProductPurchases = (suppPayRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      try {
        final suppPurchRes = await db.rawQuery(
          'SELECT COALESCE(SUM(amount_paid), 0.0) AS total FROM supplier_purchases WHERE company_id = ?',
          [companyId],
        );
        globalProductPurchases = (suppPurchRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {
        try {
          final suppPurchRes = await db.rawQuery(
            'SELECT COALESCE(SUM(paid_amount), 0.0) AS total FROM supplier_purchases WHERE company_id = ?',
            [companyId],
          );
          globalProductPurchases = (suppPurchRes.first['total'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }
    }

    final allSalesRevenue = (globalSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
    final allRevenue = allSalesRevenue + globalCreditPayments + globalRestRevenue;
    final allRecordedExpenses = (globalExpensesRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final allExpenses = globalProductPurchases + allRecordedExpenses;
    final globalNetProfit = allRevenue - allExpenses;

    // 2. Period filtering range
    String salesDateClause;
    String joinSalesDateClause;
    String expensesDateClause;
    String periodKey;
    final now = DateTime.now();

    if (period == 'daily') {
      periodKey = date ?? now.toIso8601String().substring(0, 10);
      salesDateClause = "SUBSTR(sold_at, 1, 10) = ?";
      joinSalesDateClause = "SUBSTR(s.sold_at, 1, 10) = ?";
      expensesDateClause = "SUBSTR(date, 1, 10) = ?";
    } else if (period == 'monthly') {
      periodKey = month ?? '${now.year}-${now.month.toString().padLeft(2, '0')}';
      salesDateClause = "SUBSTR(sold_at, 1, 7) = ?";
      joinSalesDateClause = "SUBSTR(s.sold_at, 1, 7) = ?";
      expensesDateClause = "SUBSTR(date, 1, 7) = ?";
    } else {
      final y = year ?? now.year;
      periodKey = y.toString();
      salesDateClause = "SUBSTR(sold_at, 1, 4) = ?";
      joinSalesDateClause = "SUBSTR(s.sold_at, 1, 4) = ?";
      expensesDateClause = "SUBSTR(date, 1, 4) = ?";
    }

    final periodSalesRes = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN total ELSE 0.0 END), 0.0) AS revenue,
        COUNT(CASE WHEN payment_status != 'cancelled' THEN 1 ELSE NULL END) AS sales_count
      FROM sales
      WHERE company_id = ?
        AND id NOT LIKE 'REST-%'
        AND $salesDateClause
      ''',
      [companyId, periodKey],
    );

    // Period credit transactions date clause
    final txDateClause = period == 'daily'
        ? "SUBSTR(created_at, 1, 10) = ?"
        : period == 'monthly'
            ? "SUBSTR(created_at, 1, 7) = ?"
            : "SUBSTR(created_at, 1, 4) = ?";

    // Period restaurant revenue
    final restPayDateClause = period == 'daily'
        ? "SUBSTR(paid_at, 1, 10) = ?"
        : period == 'monthly'
            ? "SUBSTR(paid_at, 1, 7) = ?"
            : "SUBSTR(paid_at, 1, 4) = ?";
    double periodRestRevenue = 0.0;
    try {
      final rpPeriodRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0.0) AS total FROM restaurant_payments WHERE company_id = ? AND $restPayDateClause",
        [companyId, periodKey],
      );
      periodRestRevenue = (rpPeriodRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      try {
        final roPeriodRes = await db.rawQuery(
          "SELECT COALESCE(SUM(amount_paid), 0.0) AS total FROM restaurant_orders WHERE company_id = ? AND status != 'cancelled' AND $txDateClause",
          [companyId, periodKey],
        );
        periodRestRevenue = (roPeriodRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
    }

    // Period credit payments
    double periodCreditPayments = 0.0;
    try {
      final cpPeriodRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0.0) AS total FROM credit_payments WHERE company_id = ? AND $txDateClause",
        [companyId, periodKey],
      );
      periodCreditPayments = (cpPeriodRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    final periodSalesRevenue = (periodSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
    final periodRevenue = periodSalesRevenue + periodCreditPayments + periodRestRevenue;
    final salesCount = (periodSalesRes.first['sales_count'] as num?)?.toInt() ?? 0;

    // Period COGS from sale_items with fallback to product cost_price (0 for restaurants)
    double periodCogs = 0.0;
    if (!isRestaurant) {
      try {
        final periodCogsRes = await db.rawQuery(
          '''
          SELECT
            COALESCE(SUM(COALESCE(NULLIF(si.unit_cost, 0), p.cost_price, 0) * si.quantity), 0.0) AS cogs
          FROM sale_items si
          JOIN sales s ON s.id = si.sale_id
          LEFT JOIN products p ON p.id = si.product_id AND p.company_id = s.company_id
          WHERE s.company_id = ?
            AND s.payment_status != 'cancelled'
            AND s.id NOT LIKE 'REST-%'
            AND $joinSalesDateClause
          ''',
          [companyId, periodKey],
        );
        periodCogs = (periodCogsRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {
        try {
          final fallbackCogs = await db.rawQuery(
            '''
            SELECT
              COALESCE(SUM(si.unit_cost * si.quantity), 0.0) AS cogs
            FROM sale_items si
            JOIN sales s ON s.id = si.sale_id
            WHERE s.company_id = ?
              AND s.payment_status != 'cancelled'
              AND s.id NOT LIKE 'REST-%'
              AND $joinSalesDateClause
            ''',
            [companyId, periodKey],
          );
          periodCogs = (fallbackCogs.first['cogs'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }
    }

    // Exact financial formulas (matching mobile accounting rules):
    // Gross profit = revenue - COGS (COGS is 0 for restaurants where food ingredients are tracked as expenses)
    final periodGrossProfit = isRestaurant ? periodRevenue : (periodRevenue - periodCogs);

    // Period Product Purchases (Cash-based)
    final purchaseDateClause = period == 'daily'
        ? "SUBSTR(purchase_date, 1, 10) = ?"
        : period == 'monthly'
            ? "SUBSTR(purchase_date, 1, 7) = ?"
            : "SUBSTR(purchase_date, 1, 4) = ?";
    final paymentDateClause = period == 'daily'
        ? "SUBSTR(payment_date, 1, 10) = ?"
        : period == 'monthly'
            ? "SUBSTR(payment_date, 1, 7) = ?"
            : "SUBSTR(payment_date, 1, 4) = ?";
    double periodProductPurchases = 0.0;
    try {
      final suppPayRes = await db.rawQuery(
        '''
        SELECT (
          COALESCE((
            SELECT SUM(amount)
            FROM supplier_payments
            WHERE company_id = ?
              AND $paymentDateClause
          ), 0.0)
          +
          COALESCE((
            SELECT SUM(sp.amount_paid)
            FROM supplier_purchases sp
            WHERE sp.company_id = ?
              AND sp.amount_paid > 0
              AND $purchaseDateClause
              AND sp.id NOT IN (
                SELECT DISTINCT purchase_id
                FROM supplier_payments
                WHERE purchase_id IS NOT NULL AND company_id = ?
              )
          ), 0.0)
        ) AS total
        ''',
        [companyId, periodKey, companyId, periodKey, companyId],
      );
      periodProductPurchases = (suppPayRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      try {
        final suppPurchRes = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(amount_paid), 0.0) AS total
          FROM supplier_purchases
          WHERE company_id = ? AND $purchaseDateClause
          ''',
          [companyId, periodKey],
        );
        periodProductPurchases = (suppPurchRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {
        try {
          final suppPurchRes = await db.rawQuery(
            '''
            SELECT COALESCE(SUM(paid_amount), 0.0) AS total
            FROM supplier_purchases
            WHERE company_id = ? AND $purchaseDateClause
            ''',
            [companyId, periodKey],
          );
          periodProductPurchases = (suppPurchRes.first['total'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}
      }
    }


    // Period Expenses
    final periodExpensesRes = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0.0) AS total
      FROM expenses
      WHERE company_id = ?
        AND $expensesDateClause
      ''',
      [companyId, periodKey],
    );

    final periodRecordedExpenses = (periodExpensesRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final periodExpenses = periodProductPurchases + periodRecordedExpenses;
    final periodNetProfit = periodRevenue - periodExpenses;
    final profitMargin = periodRevenue > 0 ? (periodNetProfit / periodRevenue) * 100 : 0.0;

    // Top Selling Products in period
    List<Map<String, dynamic>> topProducts = [];
    try {
      final topRows = await db.rawQuery(
        '''
        SELECT
          si.product_name AS name,
          SUM(si.quantity) AS quantity,
          SUM(si.line_total) AS revenue
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        WHERE s.company_id = ? AND s.payment_status != 'cancelled' AND $joinSalesDateClause
        GROUP BY si.product_id, si.product_name
        ORDER BY quantity DESC
        LIMIT 5
        ''',
        [companyId, periodKey],
      );
      topProducts = List<Map<String, dynamic>>.from(topRows);
    } catch (_) {}

    // Expenses by Category in period
    List<Map<String, dynamic>> expensesByCategory = [];
    try {
      final expCatRows = await db.rawQuery(
        '''
        SELECT
          category,
          SUM(amount) AS amount,
          SUM(amount) AS total
        FROM expenses
        WHERE company_id = ? AND $expensesDateClause
        GROUP BY category
        ORDER BY total DESC
        ''',
        [companyId, periodKey],
      );
      expensesByCategory = List<Map<String, dynamic>>.from(expCatRows);
      if (periodProductPurchases > 0) {
        expensesByCategory.insert(0, {
          'category': 'Product Purchases',
          'amount': periodProductPurchases,
          'total': periodProductPurchases,
        });
      }
    } catch (_) {}

    // Total sales (accrual basis: all non-cancelled sales regardless of payment timing)
    final periodTotalSalesRes = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total), 0.0) AS total_sales
      FROM sales
      WHERE company_id = ?
        AND payment_status != 'cancelled'
        AND $salesDateClause
      ''',
      [companyId, periodKey],
    );
    final periodTotalSales = (periodTotalSalesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;

    // Collections (cash basis: direct cash/card sales + actual debt repayments recorded in customer ledger)
    double periodCollected = 0.0;
    try {
      final directCashSalesRes = await db.rawQuery(
        '''
        SELECT
          COALESCE(SUM(total), 0.0) AS direct_paid
        FROM sales
        WHERE company_id = ?
          AND payment_status = 'paid'
          AND payment_method != 'credit'
          AND $salesDateClause
        ''',
        [companyId, periodKey],
      );
      final periodCollectionsRes = await db.rawQuery(
        '''
        SELECT
          COALESCE(SUM(amount), 0.0) AS collected
        FROM customer_transactions
        WHERE company_id = ?
          AND type = 'payment'
          AND $txDateClause
        ''',
        [companyId, periodKey],
      );
      periodCollected = ((directCashSalesRes.first['direct_paid'] as num?)?.toDouble() ?? 0.0) +
          ((periodCollectionsRes.first['collected'] as num?)?.toDouble() ?? 0.0);
    } catch (_) {
      periodCollected = periodRevenue;
    }

    // Outstanding customer debt
    double outstandingDebt = 0.0;
    try {
      final debtRes = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(credit_balance), 0.0) AS total_debt
        FROM customers
        WHERE company_id = ?
        ''',
        [companyId],
      );
      outstandingDebt = (debtRes.first['total_debt'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    return LocalFinancialSummary(
      allRevenue: allRevenue,
      allExpenses: allExpenses,
      globalCogs: globalCogs,
      globalNetProfit: globalNetProfit,
      periodRevenue: periodRevenue,
      periodTotalSales: periodTotalSales,
      periodCollected: periodCollected,
      outstandingDebt: outstandingDebt,
      inventoryValue: inventoryValue,
      periodCogs: periodCogs,
      periodGrossProfit: periodGrossProfit,
      periodExpenses: periodExpenses,
      periodNetProfit: periodNetProfit,
      profitMargin: profitMargin,
      salesCount: salesCount,
      topProducts: topProducts,
      expensesByCategory: expensesByCategory,
    );
  }
}
