import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import '../../features/reports/domain/report.dart';
import '../../features/dashboard/domain/dashboard_data.dart';
import '../../features/superette/domain/superette_models.dart';
import '../../features/clothing/domain/clothing_models.dart';
import '../../features/pharmacy/domain/pharmacy_models.dart';
import 'app_database.dart';

class LocalFinancialCalculator {
  static Future<ReportData> calculateReport({
    required String period, // 'daily' | 'weekly' | 'monthly' | 'yearly' | 'custom'
    required String companyId, // TENANT ISOLATION: all queries filter by this
    String? date,
    String? month,
    int? year,
    Database? db,
  }) async {
    final activeDb = db ?? await AppDatabase.instance.database;

    final resolved = _resolveRange(
      period: period,
      date: date,
      month: month,
      year: year,
    );

    final rangeStart = resolved['rangeStart']!;
    final rangeEnd = resolved['rangeEnd']!;

    // 1. Global all-time numbers — scoped to this company
    final globalSalesRes = await activeDb.rawQuery(
      '''
      SELECT
        COALESCE((SELECT SUM(total) FROM sales WHERE company_id = ?), 0) AS revenue,
        COALESCE((SELECT SUM(si.unit_cost * si.quantity) FROM sale_items si JOIN sales s ON s.id = si.sale_id WHERE s.company_id = ?), 0) AS cogs
      ''',
      [companyId, companyId],
    );
    final globalExpensesRes = await activeDb.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE company_id = ?',
      [companyId],
    );
    final globalInventoryRes = await activeDb.rawQuery(
      '''SELECT COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * (selling_price - purchase_price) ELSE 0 END), 0) AS inventory_value FROM products WHERE company_id = ?''',
      [companyId],
    );

    final allRevenue = (globalSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
    final globalCogs = (globalSalesRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
    final allExpenses = (globalExpensesRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final globalNetProfit = allRevenue - globalCogs - allExpenses;
    final inventoryValue = (globalInventoryRes.first['inventory_value'] as num?)?.toDouble() ?? 0.0;

    // 2. Period Revenue (Sales revenue in period) — scoped to this company
    final periodSalesRes = await activeDb.rawQuery(
      '''
      SELECT
        COALESCE((SELECT SUM(total) FROM sales WHERE company_id = ? AND date(sold_at) BETWEEN date(?) AND date(?)), 0) AS revenue,
        COALESCE((SELECT SUM(si.unit_cost * si.quantity) FROM sale_items si JOIN sales s ON s.id = si.sale_id WHERE s.company_id = ? AND date(s.sold_at) BETWEEN date(?) AND date(?)), 0) AS cogs,
        (SELECT COUNT(*) FROM sales WHERE company_id = ? AND date(sold_at) BETWEEN date(?) AND date(?)) AS sales_count
      ''',
      [companyId, rangeStart, rangeEnd, companyId, rangeStart, rangeEnd, companyId, rangeStart, rangeEnd],
    );

    final coreRevenue = (periodSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
    final periodCogs = (periodSalesRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
    final salesCount = (periodSalesRes.first['sales_count'] as num?)?.toInt() ?? 0;

    // 3. Operating expenses in period (excluding salary categories) — scoped to this company
    final opExpensesRes = await activeDb.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE company_id = ?
        AND date(expense_date) BETWEEN date(?) AND date(?)
        AND NOT (category LIKE '%salary%' OR category LIKE '%salair%' OR category LIKE '%payroll%' OR category LIKE '%paie%' OR category LIKE '%wage%' OR employee_id IS NOT NULL)
      ''',
      [companyId, rangeStart, rangeEnd],
    );
    final operatingExpenses = (opExpensesRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 4. Employee salaries in period — scoped to this company
    final salaryExpensesRes = await activeDb.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE company_id = ?
        AND date(expense_date) BETWEEN date(?) AND date(?)
        AND (category LIKE '%salary%' OR category LIKE '%salair%' OR category LIKE '%payroll%' OR category LIKE '%paie%' OR category LIKE '%wage%' OR employee_id IS NOT NULL)
      ''',
      [companyId, rangeStart, rangeEnd],
    );
    final employeeSalaries = (salaryExpensesRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final totalExpenses = operatingExpenses + employeeSalaries;
    final revenue = coreRevenue;
    final costOfGoodsSold = periodCogs;
    final grossProfit = revenue - costOfGoodsSold;
    final netProfit = grossProfit - totalExpenses;
    final profitMargin = revenue > 0 ? ((netProfit / revenue) * 100) : 0.0;

    // 5. Top Products — scoped to this company
    final topProductsRes = await activeDb.rawQuery(
      '''
      SELECT
        COALESCE(si.product_name, 'Product') AS name,
        SUM(si.quantity) AS units_sold,
        SUM(si.line_total) AS total
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.company_id = ? AND date(s.sold_at) BETWEEN date(?) AND date(?)
      GROUP BY si.product_id, si.product_name
      ORDER BY units_sold DESC
      LIMIT 5
      ''',
      [companyId, rangeStart, rangeEnd],
    );

    final topProducts = topProductsRes.map((r) {
      return TopProduct(
        name: (r['name'] ?? 'Product').toString(),
        unitsSold: (r['units_sold'] as num?)?.toInt() ?? 0,
        total: (r['total'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    // 6. Expenses by Category — scoped to this company
    final expCategoryRes = await activeDb.rawQuery(
      '''
      SELECT category, COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE company_id = ?
        AND date(expense_date) BETWEEN date(?) AND date(?)
        AND NOT (category LIKE '%salary%' OR category LIKE '%salair%' OR category LIKE '%payroll%' OR category LIKE '%paie%' OR category LIKE '%wage%' OR employee_id IS NOT NULL)
      GROUP BY category
      ORDER BY total DESC
      ''',
      [companyId, rangeStart, rangeEnd],
    );

    final expensesByCategory = expCategoryRes.map((r) {
      final amt = (r['total'] as num?)?.toDouble() ?? 0.0;
      return ExpenseCategoryItem(
        category: (r['category'] ?? 'General').toString(),
        amount: amt,
        total: amt,
      );
    }).toList();

    // 7. Activity Counts — scoped to this company
    final expCountRes = await activeDb.rawQuery(
      'SELECT COUNT(*) AS count FROM expenses WHERE company_id = ? AND date(expense_date) BETWEEN date(?) AND date(?)',
      [companyId, rangeStart, rangeEnd],
    );
    final invCountRes = await activeDb.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM sales s
      JOIN invoices inv ON inv.sale_id = s.id
      WHERE s.company_id = ? AND date(s.sold_at) BETWEEN date(?) AND date(?)
      ''',
      [companyId, rangeStart, rangeEnd],
    );

    final activitySummary = ActivitySummary(
      salesCount: salesCount,
      expensesCount: (expCountRes.first['count'] as num?)?.toInt() ?? 0,
      employeesCount: 0,
      invoicesCount: (invCountRes.first['count'] as num?)?.toInt() ?? 0,
    );

    // 8. Recent Transactions — scoped to this company
    final recentSales = await activeDb.rawQuery(
      '''
      SELECT id, total AS amount, sold_at AS date, customer_name, 'sale' AS type
      FROM sales
      WHERE company_id = ? AND date(sold_at) BETWEEN date(?) AND date(?)
      ORDER BY sold_at DESC
      LIMIT 5
      ''',
      [companyId, rangeStart, rangeEnd],
    );

    final recentExpenses = await activeDb.rawQuery(
      '''
      SELECT id, amount, expense_date AS date, category, description, employee_id, 'expense' AS type
      FROM expenses
      WHERE company_id = ? AND date(expense_date) BETWEEN date(?) AND date(?)
      ORDER BY expense_date DESC
      LIMIT 5
      ''',
      [companyId, rangeStart, rangeEnd],
    );

    final List<ReportTransaction> recentTransactions = [];
    for (final s in recentSales) {
      final sId = s['id'].toString();
      recentTransactions.add(
        ReportTransaction(
          id: sId,
          type: 'sale',
          amount: (s['amount'] as num?)?.toDouble() ?? 0.0,
          date: DateTime.tryParse(s['date'].toString()),
          title: 'Sale #${sId.length > 8 ? sId.substring(0, 8) : sId}',
          description: s['customer_name']?.toString() ?? 'Walk-in customer',
        ),
      );
    }
    for (final e in recentExpenses) {
      final isSal = e['employee_id'] != null || e['category'].toString().toLowerCase().contains('salary');
      recentTransactions.add(
        ReportTransaction(
          id: e['id'].toString(),
          type: isSal ? 'salary' : 'expense',
          amount: (e['amount'] as num?)?.toDouble() ?? 0.0,
          date: DateTime.tryParse(e['date'].toString()),
          title: e['category'].toString(),
          description: e['description']?.toString(),
        ),
      );
    }
    recentTransactions.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

    // 9. Monthly breakdown (for yearly view) — scoped to this company
    List<MonthlyBreakdownItem> monthlyBreakdown = [];
    if (period == 'yearly') {
      final yr = int.tryParse(rangeStart.substring(0, 4)) ?? DateTime.now().year;
      final monthsNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (int m = 1; m <= 12; m++) {
        final mStr = m.toString().padLeft(2, '0');
        final mStart = '$yr-$mStr-01';
        final lastDay = DateTime(yr, m + 1, 0).day;
        final mEnd = '$yr-$mStr-${lastDay.toString().padLeft(2, '0')}';

        final mSales = await activeDb.rawQuery(
          '''
          SELECT
            COALESCE((SELECT SUM(total) FROM sales WHERE company_id = ? AND date(sold_at) BETWEEN date(?) AND date(?)), 0) AS rev,
            COALESCE((SELECT SUM(si.unit_cost * si.quantity) FROM sale_items si JOIN sales s ON s.id = si.sale_id WHERE s.company_id = ? AND date(s.sold_at) BETWEEN date(?) AND date(?)), 0) AS cogs
          ''',
          [companyId, mStart, mEnd, companyId, mStart, mEnd],
        );
        final mOpExp = await activeDb.rawQuery(
          '''SELECT COALESCE(SUM(amount), 0) AS exp FROM expenses WHERE company_id = ? AND date(expense_date) BETWEEN date(?) AND date(?) AND NOT (category LIKE '%salary%' OR employee_id IS NOT NULL)''',
          [companyId, mStart, mEnd],
        );
        final mSalExp = await activeDb.rawQuery(
          '''SELECT COALESCE(SUM(amount), 0) AS sal FROM expenses WHERE company_id = ? AND date(expense_date) BETWEEN date(?) AND date(?) AND (category LIKE '%salary%' OR employee_id IS NOT NULL)''',
          [companyId, mStart, mEnd],
        );

        final mRev = (mSales.first['rev'] as num?)?.toDouble() ?? 0.0;
        final mCogs = (mSales.first['cogs'] as num?)?.toDouble() ?? 0.0;
        final mGross = mRev - mCogs;
        final mOp = (mOpExp.first['exp'] as num?)?.toDouble() ?? 0.0;
        final mSal = (mSalExp.first['sal'] as num?)?.toDouble() ?? 0.0;
        final mTotExp = mOp + mSal;

        monthlyBreakdown.add(
          MonthlyBreakdownItem(
            month: m,
            monthName: monthsNames[m - 1],
            revenue: mRev,
            expenses: mTotExp,
            salaryExpenses: mSal,
            operatingExpenses: mOp,
            netProfit: mGross - mTotExp,
          ),
        );
      }
    }

    final globalFin = GlobalFinancials(
      allRevenue: allRevenue,
      allExpenses: allExpenses,
      globalNetProfit: globalNetProfit,
      inventoryValue: inventoryValue,
    );

    return ReportData(
      period: period,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      revenue: revenue,
      expenses: totalExpenses,
      operatingExpenses: operatingExpenses,
      employeeSalaries: employeeSalaries,
      netProfit: netProfit,
      grossProfit: grossProfit,
      profitMargin: profitMargin,
      salesCount: salesCount,
      topProducts: topProducts,
      expensesByCategory: expensesByCategory,
      employeeSalariesBreakdown: const [],
      revenueBreakdown: RevenueBreakdown(
        sales: revenue,
        creditPayments: 0.0,
        clinicRevenue: 0.0,
        restaurantRevenue: 0.0,
        totalRevenue: revenue,
      ),
      expensesBreakdown: ExpensesBreakdown(
        operatingExpenses: operatingExpenses,
        employeeSalaries: employeeSalaries,
        costOfGoodsSold: costOfGoodsSold,
        totalExpenses: totalExpenses,
        byCategory: expensesByCategory,
        byEmployee: const [],
      ),
      activitySummary: activitySummary,
      recentTransactions: recentTransactions,
      monthlyBreakdown: monthlyBreakdown,
      global: globalFin,
      allRevenue: allRevenue,
      allExpenses: allExpenses,
      globalNetProfit: globalNetProfit,
      inventoryValue: inventoryValue,
    );
  }

  static Map<String, String> _resolveRange({
    required String period,
    String? date,
    String? month,
    int? year,
  }) {
    final now = DateTime.now();
    final todayStr = _toIsoDate(now);

    switch (period) {
      case 'daily':
        final d = (date != null && date.isNotEmpty) ? date : todayStr;
        return {'rangeStart': d, 'rangeEnd': d};
      case 'yearly':
        final y = year ?? now.year;
        return {'rangeStart': '$y-01-01', 'rangeEnd': '$y-12-31'};
      case 'monthly':
      default:
        if (month != null && month.isNotEmpty && month.contains('-')) {
          final parts = month.split('-');
          final y = int.tryParse(parts[0]) ?? now.year;
          final m = int.tryParse(parts[1]) ?? now.month;
          final lastDay = DateTime(y, m + 1, 0).day;
          final mStr = m.toString().padLeft(2, '0');
          return {
            'rangeStart': '$y-$mStr-01',
            'rangeEnd': '$y-$mStr-${lastDay.toString().padLeft(2, '0')}',
          };
        } else {
          final y = now.year;
          final m = now.month;
          final lastDay = DateTime(y, m + 1, 0).day;
          final mStr = m.toString().padLeft(2, '0');
          return {
            'rangeStart': '$y-$mStr-01',
            'rangeEnd': '$y-$mStr-${lastDay.toString().padLeft(2, '0')}',
          };
        }
    }
  }

  static String _toIsoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Calculates authoritative Dashboard metrics directly from SQLite.
  static Future<DashboardData> calculateDashboard({
    required String companyId,
    Database? db,
  }) async {
    final activeDb = db ?? await AppDatabase.instance.database;
    final now = DateTime.now();
    final todayStr = _toIsoDate(now);

    final report = await calculateReport(
      period: 'daily',
      companyId: companyId,
      date: todayStr,
      db: activeDb,
    );

    final lowStockRes = await activeDb.rawQuery(
      'SELECT COUNT(*) AS count FROM products WHERE company_id = ? AND quantity <= minimum_stock',
      [companyId],
    );

    final unpaidInvRes = await activeDb.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM sales s
      JOIN invoices inv ON inv.sale_id = s.id
      WHERE s.company_id = ? AND inv.status = 'unpaid'
      ''',
      [companyId],
    );

    final creditRes = await activeDb.rawQuery(
      'SELECT COALESCE(SUM(balance_due), 0) AS total FROM customers WHERE company_id = ?',
      [companyId],
    );

    final apptRes = await activeDb.rawQuery(
      "SELECT COUNT(*) AS count FROM appointments WHERE company_id = ? AND status = 'scheduled' AND date(scheduled_at) >= date(?)",
      [companyId, todayStr],
    );

    return DashboardData(
      todayRevenue: report.revenue,
      todayExpenses: report.expenses,
      todayProfit: report.netProfit,
      salesCount: report.salesCount,
      lowStockCount: (lowStockRes.first['count'] as num?)?.toInt() ?? 0,
      unpaidInvoicesCount: (unpaidInvRes.first['count'] as num?)?.toInt() ?? 0,
      upcomingAppointmentsCount: (apptRes.first['count'] as num?)?.toInt() ?? 0,
      totalOutstandingCredit: (creditRes.first['total'] as num?)?.toDouble() ?? 0.0,
      inventoryValue: report.inventoryValue,
      todayGrossProfit: report.grossProfit,
    );
  }

  /// Calculates authoritative specialized dashboard stats (Supérette, General Store, Retail, etc.) directly from SQLite.
  static Future<SuperetteDashboardStats> calculateSuperetteDashboard({
    required String companyId,
    Database? db,
  }) async {
    final activeDb = db ?? await AppDatabase.instance.database;
    final now = DateTime.now();
    final todayStr = _toIsoDate(now);

    final dailyReport = await calculateReport(
      period: 'daily',
      companyId: companyId,
      date: todayStr,
      db: activeDb,
    );

    final weeklyReport = await calculateReport(
      period: 'weekly',
      companyId: companyId,
      db: activeDb,
    );

    final monthlyReport = await calculateReport(
      period: 'monthly',
      companyId: companyId,
      db: activeDb,
    );

    final productsSoldRes = await activeDb.rawQuery(
      '''SELECT COALESCE(SUM(si.quantity), 0) AS qty
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id
         WHERE s.company_id = ? AND date(s.sold_at) = date(?)''',
      [companyId, todayStr],
    );
    final productsSoldToday = (productsSoldRes.first['qty'] as num?)?.toInt() ?? 0;

    final lowStockRows = await activeDb.query(
      'products',
      where: 'company_id = ? AND quantity <= minimum_stock',
      whereArgs: [companyId],
      orderBy: 'quantity ASC',
      limit: 10,
    );
    final lowStockProducts = lowStockRows
        .map((r) => SuperetteLowStockProduct(
              id: r['id'] as String,
              name: (r['name'] ?? 'Product') as String,
              category: r['category'] as String?,
              quantity: (r['quantity'] as num?)?.toInt() ?? 0,
              minimumStock: (r['minimum_stock'] as num?)?.toInt() ?? 5,
            ))
        .toList();

    final stockSummary = await activeDb.rawQuery(
      '''SELECT
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * purchase_price ELSE 0 END), 0) AS cost,
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * selling_price ELSE 0 END), 0) AS retail,
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity ELSE 0 END), 0) AS units
         FROM products WHERE company_id = ?''',
      [companyId],
    );
    final stockCostValue = (stockSummary.first['cost'] as num?)?.toDouble() ?? 0.0;
    final stockRetailValue = (stockSummary.first['retail'] as num?)?.toDouble() ?? 0.0;
    final unitsInStock = (stockSummary.first['units'] as num?)?.toInt() ?? 0;

    int suppliersCount = 0;
    try {
      final suppliersRes = await activeDb.rawQuery(
        'SELECT COUNT(*) AS count FROM suppliers WHERE company_id = ? AND deleted_at IS NULL',
        [companyId],
      );
      suppliersCount = (suppliersRes.first['count'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    final customersRes = await activeDb.rawQuery(
      'SELECT COUNT(*) AS count FROM customers WHERE company_id = ?',
      [companyId],
    );
    final customersCount = (customersRes.first['count'] as num?)?.toInt() ?? 0;

    final debtorsRes = await activeDb.rawQuery(
      'SELECT id, name, phone, balance_due FROM customers WHERE company_id = ? AND balance_due > 0 ORDER BY balance_due DESC',
      [companyId],
    );
    final debtorsCount = debtorsRes.length;
    final outstandingDebt = debtorsRes.fold<double>(
      0.0,
      (sum, r) => sum + ((r['balance_due'] as num?)?.toDouble() ?? 0.0),
    );
    final topDebtors = debtorsRes.take(5).map((r) {
      return SuperetteDebtor(
        id: r['id'] as String,
        name: (r['name'] ?? 'Customer') as String,
        phone: r['phone'] as String?,
        balanceDue: (r['balance_due'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    final bestSellingProducts = dailyReport.topProducts
        .map((tp) => SuperetteBestSeller(
              name: tp.name,
              unitsSold: tp.unitsSold,
              revenue: tp.total,
            ))
        .toList();

    return SuperetteDashboardStats(
      todayRevenue: dailyReport.revenue,
      todayGrossProfit: dailyReport.grossProfit,
      todayNetProfit: dailyReport.netProfit,
      todayExpenses: dailyReport.expenses,
      transactionsToday: dailyReport.salesCount,
      productsSoldToday: productsSoldToday,
      weekRevenue: weeklyReport.revenue,
      monthRevenue: monthlyReport.revenue,
      lowStockCount: lowStockProducts.length,
      lowStockProducts: lowStockProducts,
      stockCostValue: stockCostValue,
      stockRetailValue: stockRetailValue,
      unitsInStock: unitsInStock,
      bestSellingProducts: bestSellingProducts,
      suppliersCount: suppliersCount,
      customersCount: customersCount,
      outstandingDebt: outstandingDebt,
      debtorsCount: debtorsCount,
      topDebtors: topDebtors,
    );
  }

  /// Calculates authoritative Clothing Store dashboard stats directly from SQLite.
  static Future<ClothingDashboardStats> calculateClothingDashboard({
    required String companyId,
    Database? db,
  }) async {
    final activeDb = db ?? await AppDatabase.instance.database;
    final now = DateTime.now();
    final todayStr = _toIsoDate(now);

    final dailyReport = await calculateReport(
      period: 'daily',
      companyId: companyId,
      date: todayStr,
      db: activeDb,
    );

    final weeklyReport = await calculateReport(
      period: 'weekly',
      companyId: companyId,
      db: activeDb,
    );

    final monthlyReport = await calculateReport(
      period: 'monthly',
      companyId: companyId,
      db: activeDb,
    );

    final productsSoldRes = await activeDb.rawQuery(
      '''SELECT COALESCE(SUM(si.quantity), 0) AS qty
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id
         WHERE s.company_id = ? AND date(s.sold_at) = date(?)''',
      [companyId, todayStr],
    );
    final itemsSoldToday = (productsSoldRes.first['qty'] as num?)?.toInt() ?? 0;

    final lowStockRows = await activeDb.query(
      'products',
      where: 'company_id = ? AND quantity <= minimum_stock',
      whereArgs: [companyId],
      orderBy: 'quantity ASC',
      limit: 10,
    );
    final lowStockProducts = lowStockRows
        .map((r) => ClothingLowStockProduct(
              id: r['id'] as String,
              name: (r['name'] ?? 'Product') as String,
              category: r['category'] as String?,
              size: r['size'] as String?,
              color: r['color'] as String?,
              brand: r['brand'] as String?,
              quantity: (r['quantity'] as num?)?.toInt() ?? 0,
              minimumStock: (r['minimum_stock'] as num?)?.toInt() ?? 5,
            ))
        .toList();

    final stockSummary = await activeDb.rawQuery(
      '''SELECT
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * purchase_price ELSE 0 END), 0) AS cost,
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * selling_price ELSE 0 END), 0) AS retail,
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity ELSE 0 END), 0) AS units
         FROM products WHERE company_id = ?''',
      [companyId],
    );
    final stockCostValue = (stockSummary.first['cost'] as num?)?.toDouble() ?? 0.0;
    final stockRetailValue = (stockSummary.first['retail'] as num?)?.toDouble() ?? 0.0;
    final unitsInStock = (stockSummary.first['units'] as num?)?.toInt() ?? 0;

    int suppliersCount = 0;
    try {
      final suppliersRes = await activeDb.rawQuery(
        'SELECT COUNT(*) AS count FROM suppliers WHERE company_id = ? AND deleted_at IS NULL',
        [companyId],
      );
      suppliersCount = (suppliersRes.first['count'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    final customersRes = await activeDb.rawQuery(
      'SELECT COUNT(*) AS count FROM customers WHERE company_id = ?',
      [companyId],
    );
    final customersCount = (customersRes.first['count'] as num?)?.toInt() ?? 0;

    final debtorsRes = await activeDb.rawQuery(
      'SELECT id, name, phone, balance_due FROM customers WHERE company_id = ? AND balance_due > 0 ORDER BY balance_due DESC',
      [companyId],
    );
    final debtorsCount = debtorsRes.length;
    final outstandingDebt = debtorsRes.fold<double>(
      0.0,
      (sum, r) => sum + ((r['balance_due'] as num?)?.toDouble() ?? 0.0),
    );
    final topDebtors = debtorsRes.take(5).map((r) {
      return ClothingDebtor(
        id: r['id'] as String,
        name: (r['name'] ?? 'Customer') as String,
        phone: r['phone'] as String?,
        balanceDue: (r['balance_due'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    final bestSellingProducts = dailyReport.topProducts
        .map((tp) => ClothingBestSeller(
              name: tp.name,
              unitsSold: tp.unitsSold,
              revenue: tp.total,
            ))
        .toList();

    final categoryRows = await activeDb.rawQuery(
      '''SELECT COALESCE(category, 'General') AS category,
                COUNT(*) AS product_count,
                COALESCE(SUM(quantity), 0) AS units_in_stock
         FROM products
         WHERE company_id = ?
         GROUP BY category
         ORDER BY units_in_stock DESC
         LIMIT 6''',
      [companyId],
    );
    final stockByCategory = categoryRows
        .map((r) => ClothingCategoryStock(
              category: (r['category'] ?? 'General') as String,
              productCount: (r['product_count'] as num?)?.toInt() ?? 0,
              unitsInStock: (r['units_in_stock'] as num?)?.toInt() ?? 0,
            ))
        .toList();

    return ClothingDashboardStats(
      todayRevenue: dailyReport.revenue,
      todayGrossProfit: dailyReport.grossProfit,
      todayNetProfit: dailyReport.netProfit,
      todayExpenses: dailyReport.expenses,
      transactionsToday: dailyReport.salesCount,
      itemsSoldToday: itemsSoldToday,
      weekRevenue: weeklyReport.revenue,
      monthRevenue: monthlyReport.revenue,
      lowStockCount: lowStockProducts.length,
      lowStockProducts: lowStockProducts,
      stockCostValue: stockCostValue,
      stockRetailValue: stockRetailValue,
      unitsInStock: unitsInStock,
      bestSellingProducts: bestSellingProducts,
      stockByCategory: stockByCategory,
      suppliersCount: suppliersCount,
      customersCount: customersCount,
      outstandingDebt: outstandingDebt,
      debtorsCount: debtorsCount,
      topDebtors: topDebtors,
    );
  }

  /// Calculates authoritative Pharmacy dashboard stats directly from SQLite.
  static Future<PharmacyDashboardStats> calculatePharmacyDashboard({
    required String companyId,
    Database? db,
  }) async {
    final activeDb = db ?? await AppDatabase.instance.database;
    final now = DateTime.now();
    final todayStr = _toIsoDate(now);

    final dailyReport = await calculateReport(
      period: 'daily',
      companyId: companyId,
      date: todayStr,
      db: activeDb,
    );

    final weeklyReport = await calculateReport(
      period: 'weekly',
      companyId: companyId,
      db: activeDb,
    );

    final monthlyReport = await calculateReport(
      period: 'monthly',
      companyId: companyId,
      db: activeDb,
    );

    final productsSoldRes = await activeDb.rawQuery(
      '''SELECT COALESCE(SUM(si.quantity), 0) AS qty
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id
         WHERE s.company_id = ? AND date(s.sold_at) = date(?)''',
      [companyId, todayStr],
    );
    final productsSoldToday = (productsSoldRes.first['qty'] as num?)?.toInt() ?? 0;

    final lowStockRows = await activeDb.query(
      'products',
      where: 'company_id = ? AND quantity <= minimum_stock',
      whereArgs: [companyId],
      orderBy: 'quantity ASC',
      limit: 10,
    );
    final lowStockProducts = lowStockRows
        .map((r) => PharmacyLowStockProduct(
              id: r['id'] as String,
              name: (r['name'] ?? 'Product') as String,
              category: r['category'] as String?,
              quantity: (r['quantity'] as num?)?.toInt() ?? 0,
              minimumStock: (r['minimum_stock'] as num?)?.toInt() ?? 5,
            ))
        .toList();

    // Expiring within 30 days — scoped to this company
    final in30Days = now.add(const Duration(days: 30));
    final in30DaysStr = _toIsoDate(in30Days);

    final expiringRows = await activeDb.rawQuery(
      '''SELECT id, name, expiration_date, quantity
         FROM products
         WHERE company_id = ?
           AND expiration_date IS NOT NULL
           AND date(expiration_date) BETWEEN date(?) AND date(?)
         ORDER BY expiration_date ASC''',
      [companyId, todayStr, in30DaysStr],
    );
    final expiringProducts = expiringRows.map((r) {
      final exp = DateTime.tryParse(r['expiration_date']?.toString() ?? '') ?? now;
      final days = exp.difference(now).inDays;
      return PharmacyExpiringProduct(
        id: r['id'] as String,
        name: (r['name'] ?? 'Product') as String,
        expirationDate: exp,
        daysUntilExpiration: days,
        quantity: (r['quantity'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final expiredRes = await activeDb.rawQuery(
      '''SELECT COUNT(*) AS count
         FROM products
         WHERE company_id = ?
           AND expiration_date IS NOT NULL
           AND date(expiration_date) < date(?)''',
      [companyId, todayStr],
    );
    final expiredCount = (expiredRes.first['count'] as num?)?.toInt() ?? 0;

    final stockSummary = await activeDb.rawQuery(
      '''SELECT
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * purchase_price ELSE 0 END), 0) AS cost,
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * selling_price ELSE 0 END), 0) AS retail,
           COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity ELSE 0 END), 0) AS units
         FROM products WHERE company_id = ?''',
      [companyId],
    );
    final stockCostValue = (stockSummary.first['cost'] as num?)?.toDouble() ?? 0.0;
    final stockRetailValue = (stockSummary.first['retail'] as num?)?.toDouble() ?? 0.0;
    final unitsInStock = (stockSummary.first['units'] as num?)?.toInt() ?? 0;

    int suppliersCount = 0;
    try {
      final suppliersRes = await activeDb.rawQuery(
        'SELECT COUNT(*) AS count FROM suppliers WHERE company_id = ? AND deleted_at IS NULL',
        [companyId],
      );
      suppliersCount = (suppliersRes.first['count'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    final bestSellingProducts = dailyReport.topProducts
        .map((tp) => PharmacyBestSeller(
              name: tp.name,
              unitsSold: tp.unitsSold,
              revenue: tp.total,
            ))
        .toList();

    return PharmacyDashboardStats(
      todayRevenue: dailyReport.revenue,
      todayGrossProfit: dailyReport.grossProfit,
      todayNetProfit: dailyReport.netProfit,
      todayExpenses: dailyReport.expenses,
      transactionsToday: dailyReport.salesCount,
      productsSoldToday: productsSoldToday,
      weekRevenue: weeklyReport.revenue,
      monthRevenue: monthlyReport.revenue,
      lowStockCount: lowStockProducts.length,
      lowStockProducts: lowStockProducts,
      expiringCount: expiringProducts.length,
      expiringProducts: expiringProducts,
      expiredCount: expiredCount,
      inventoryCostValue: stockCostValue,
      inventoryRetailValue: stockRetailValue,
      unitsInStock: unitsInStock,
      bestSellingProducts: bestSellingProducts,
      suppliersCount: suppliersCount,
    );
  }
}
