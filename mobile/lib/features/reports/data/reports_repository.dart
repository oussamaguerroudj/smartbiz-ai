import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/local_financial_calculator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session.dart';
import '../domain/report.dart';

class ReportFilter {
  final String period; // 'daily' | 'monthly' | 'yearly'
  final String? date; // 'YYYY-MM-DD'
  final String? month; // 'YYYY-MM'
  final int? year; // 2026

  const ReportFilter({
    required this.period,
    this.date,
    this.month,
    this.year,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportFilter &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          date == other.date &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode =>
      period.hashCode ^
      (date?.hashCode ?? 0) ^
      (month?.hashCode ?? 0) ^
      (year?.hashCode ?? 0);
}

class ReportsRepository {
  ReportsRepository(this._ref);
  final Ref _ref;

  String get _companyId {
    final session = _ref.read(sessionProvider);
    return session.companyId ?? session.userId ?? 'default';
  }

  String _cacheKey(String companyId, String period, String? date, String? month, int? year) {
    final resolved = LocalFinancialCalculator.resolveRange(
      period: period,
      date: date,
      month: month,
      year: year,
    );
    final rangeStart = resolved['rangeStart']!;
    final rangeEnd = resolved['rangeEnd']!;
    return 'report_cache_${companyId}_${period}_${rangeStart}_$rangeEnd';
  }

  Future<void> _cacheServerReport(String cacheKey, Map<String, dynamic> data, {Database? db}) async {
    try {
      final activeDb = db ?? await AppDatabase.instance.database;
      await activeDb.insert(
        'sync_metadata',
        {
          'key': cacheKey,
          'value': jsonEncode(data),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<ReportData?> _getCachedServerReport(String cacheKey, {Database? db}) async {
    try {
      final activeDb = db ?? await AppDatabase.instance.database;
      final rows = await activeDb.query(
        'sync_metadata',
        where: 'key = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['value'] != null) {
        final decoded = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
        return ReportData.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<ReportData> getReport({
    required String period,
    String? date,
    String? month,
    int? year,
    Database? db,
  }) async {
    final companyId = _companyId;
    final cacheKey = _cacheKey(companyId, period, date, month, year);

    // 1. Calculate locally from SQLite first (guarantees offline support!)
    ReportData? localReport;
    final businessType = _ref.read(sessionProvider).businessType;
    try {
      localReport = await LocalFinancialCalculator.calculateReport(
        period: period,
        companyId: companyId,
        businessType: businessType,
        date: date,
        month: month,
        year: year,
        db: db,
      );
    } catch (e) {
      // Diagnostic logging (error category and company, no secrets)
      // ignore: avoid_print
      print('[REPORTS] Local calculation error for tenant=$companyId period=$period cacheKey=$cacheKey: $e');
    }

    // Check connectivity status
    final connStatus = _ref.read(connectionStatusProvider);
    final isOnline = connStatus == ConnectionStatus.online;

    // 2. If online, fetch authoritative server report and reconcile with unsynced local mutations
    if (isOnline) {
      try {
        final client = _ref.read(apiClientProvider);
        final query = <String, String>{'period': period};
        if (date != null && date.isNotEmpty) query['date'] = date;
        if (month != null && month.isNotEmpty) query['month'] = month;
        if (year != null) query['year'] = year.toString();

        final response = await client.get('/reports', query: query);
        final data = response['data'] as Map<String, dynamic>;
        final serverReport = ReportData.fromJson(data);

        // Cache the authoritative server payload locally for offline resilience
        await _cacheServerReport(cacheKey, data, db: db);

        // Reconcile with pending offline transactions (synced = 0) so pending sales are reflected immediately without waiting or double-counting
        final activeDb = db ?? await AppDatabase.instance.database;
        final resolved = LocalFinancialCalculator.resolveRange(
          period: period,
          date: date,
          month: month,
          year: year,
        );
        final rangeStart = resolved['rangeStart']!;
        final rangeEnd = resolved['rangeEnd']!;

        final unsyncedSalesRes = await activeDb.rawQuery(
          '''
          SELECT
            COALESCE(SUM(CASE WHEN s.payment_status = 'paid' THEN s.total ELSE 0 END), 0) AS revenue,
            COALESCE(SUM(
              (SELECT COALESCE(SUM(COALESCE(NULLIF(si.unit_cost, 0), p.purchase_price, 0) * si.quantity), 0)
               FROM sale_items si
               LEFT JOIN products p ON p.id = si.product_id AND (p.company_id = s.company_id OR p.company_id IS NULL)
               WHERE si.sale_id = s.id)
            ), 0) AS cogs,
            COUNT(*) AS count
          FROM sales s
          WHERE s.company_id = ? AND s.synced = 0 AND s.payment_status != 'cancelled'
            AND (CASE WHEN s.sold_at LIKE '%Z' OR s.sold_at LIKE '%+%' THEN date(s.sold_at, 'localtime') ELSE date(s.sold_at) END) BETWEEN date(?) AND date(?)
          ''',
          [companyId, rangeStart, rangeEnd],
        );
        final unsyncedExpRes = await activeDb.rawQuery(
          '''
          SELECT
            COALESCE(SUM(CASE WHEN NOT (category LIKE '%salary%' OR category LIKE '%salair%' OR category LIKE '%payroll%' OR category LIKE '%paie%' OR category LIKE '%wage%' OR employee_id IS NOT NULL) THEN amount ELSE 0 END), 0) AS op_expenses,
            COALESCE(SUM(CASE WHEN (category LIKE '%salary%' OR category LIKE '%salair%' OR category LIKE '%payroll%' OR category LIKE '%paie%' OR category LIKE '%wage%' OR employee_id IS NOT NULL) THEN amount ELSE 0 END), 0) AS salary_expenses,
            COUNT(*) AS count
          FROM expenses
          WHERE company_id = ? AND synced = 0
            AND (CASE WHEN expense_date LIKE '%Z' OR expense_date LIKE '%+%' THEN date(expense_date, 'localtime') ELSE date(expense_date) END) BETWEEN date(?) AND date(?)
          ''',
          [companyId, rangeStart, rangeEnd],
        );

        double unsyncedCredit = 0.0;
        try {
          final unsyncedCreditRes = await activeDb.rawQuery(
            '''
            SELECT COALESCE(SUM(amount), 0) AS total
            FROM credit_payments
            WHERE company_id = ? AND synced = 0
              AND ${LocalFinancialCalculator.safeCreatedAtDate} BETWEEN date(?) AND date(?)
            ''',
            [companyId, rangeStart, rangeEnd],
          );
          unsyncedCredit = (unsyncedCreditRes.first['total'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}

        final isRestaurant = (businessType == 'restaurant' || businessType == 'cafe');
        final unsyncedSalesRev = (unsyncedSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
        final unsyncedRev = unsyncedSalesRev + unsyncedCredit;
        final unsyncedCogs = isRestaurant ? 0.0 : ((unsyncedSalesRes.first['cogs'] as num?)?.toDouble() ?? 0.0);
        final unsyncedGrossProfit = unsyncedRev - unsyncedCogs;
        final unsyncedCount = (unsyncedSalesRes.first['count'] as num?)?.toInt() ?? 0;

        final unsyncedOp = (unsyncedExpRes.first['op_expenses'] as num?)?.toDouble() ?? 0.0;
        final unsyncedSal = (unsyncedExpRes.first['salary_expenses'] as num?)?.toDouble() ?? 0.0;
        final unsyncedTotalExp = unsyncedOp + unsyncedSal;
        final unsyncedNetProfit = unsyncedGrossProfit - unsyncedTotalExp;

        if (unsyncedRev > 0 || unsyncedCount > 0 || unsyncedTotalExp > 0) {
          return _reconcileReport(
            base: serverReport,
            unsyncedRev: unsyncedRev,
            unsyncedCogs: unsyncedCogs,
            unsyncedGrossProfit: unsyncedGrossProfit,
            unsyncedCount: unsyncedCount,
            unsyncedOp: unsyncedOp,
            unsyncedSal: unsyncedSal,
            unsyncedTotalExp: unsyncedTotalExp,
            unsyncedNetProfit: unsyncedNetProfit,
          );
        }

        return serverReport;
      } catch (e) {
        // Fallback to local calculation or cached report if server call fails
      }
    }

    // 3. Offline Mode: If cached server report exists, reconcile with local unsynced mutations
    var cached = await _getCachedServerReport(cacheKey, db: db);
    if (cached == null) {
      final legacyKey = 'report_cache_${companyId}_${period}_${date ?? ''}_${month ?? ''}_${year ?? ''}';
      cached = await _getCachedServerReport(legacyKey, db: db);
    }
    if (cached != null) {
      final activeDb = db ?? await AppDatabase.instance.database;
      final resolved = LocalFinancialCalculator.resolveRange(
        period: period,
        date: date,
        month: month,
        year: year,
      );
      final rangeStart = resolved['rangeStart']!;
      final rangeEnd = resolved['rangeEnd']!;

      final unsyncedSalesRes = await activeDb.rawQuery(
        '''
        SELECT
          COALESCE(SUM(total), 0) AS revenue,
          COALESCE(SUM(
            (SELECT COALESCE(SUM(COALESCE(NULLIF(si.unit_cost, 0), p.purchase_price, 0) * si.quantity), 0)
             FROM sale_items si
             LEFT JOIN products p ON p.id = si.product_id AND (p.company_id = s.company_id OR p.company_id IS NULL)
             WHERE si.sale_id = s.id)
          ), 0) AS cogs,
          COUNT(*) AS count
        FROM sales s
        WHERE s.company_id = ? AND s.synced = 0 AND s.payment_status != 'cancelled'
          AND (CASE WHEN s.sold_at LIKE '%Z' OR s.sold_at LIKE '%+%' THEN date(s.sold_at, 'localtime') ELSE date(s.sold_at) END) BETWEEN date(?) AND date(?)
        ''',
        [companyId, rangeStart, rangeEnd],
      );
      final unsyncedExpRes = await activeDb.rawQuery(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN NOT (category LIKE '%salary%' OR category LIKE '%salair%' OR category LIKE '%payroll%' OR category LIKE '%paie%' OR category LIKE '%wage%' OR employee_id IS NOT NULL) THEN amount ELSE 0 END), 0) AS op_expenses,
          COALESCE(SUM(CASE WHEN (category LIKE '%salary%' OR category LIKE '%salair%' OR category LIKE '%payroll%' OR category LIKE '%paie%' OR category LIKE '%wage%' OR employee_id IS NOT NULL) THEN amount ELSE 0 END), 0) AS salary_expenses,
          COUNT(*) AS count
        FROM expenses
        WHERE company_id = ? AND synced = 0
          AND (CASE WHEN expense_date LIKE '%Z' OR expense_date LIKE '%+%' THEN date(expense_date, 'localtime') ELSE date(expense_date) END) BETWEEN date(?) AND date(?)
        ''',
        [companyId, rangeStart, rangeEnd],
      );

      double unsyncedCredit = 0.0;
      try {
        final unsyncedCreditRes = await activeDb.rawQuery(
          '''
          SELECT COALESCE(SUM(amount), 0) AS total
          FROM credit_payments
          WHERE company_id = ? AND synced = 0
            AND ${LocalFinancialCalculator.safeCreatedAtDate} BETWEEN date(?) AND date(?)
          ''',
          [companyId, rangeStart, rangeEnd],
        );
        unsyncedCredit = (unsyncedCreditRes.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}

      final isRestaurant = (businessType == 'restaurant' || businessType == 'cafe');
      final unsyncedSalesRev = (unsyncedSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
      final unsyncedRev = unsyncedSalesRev + unsyncedCredit;
      final unsyncedCogs = isRestaurant ? 0.0 : ((unsyncedSalesRes.first['cogs'] as num?)?.toDouble() ?? 0.0);
      final unsyncedGrossProfit = unsyncedRev - unsyncedCogs;
      final unsyncedCount = (unsyncedSalesRes.first['count'] as num?)?.toInt() ?? 0;

      final unsyncedOp = (unsyncedExpRes.first['op_expenses'] as num?)?.toDouble() ?? 0.0;
      final unsyncedSal = (unsyncedExpRes.first['salary_expenses'] as num?)?.toDouble() ?? 0.0;
      final unsyncedTotalExp = unsyncedOp + unsyncedSal;
      final unsyncedNetProfit = unsyncedGrossProfit - unsyncedTotalExp;

      if (unsyncedRev > 0 || unsyncedCount > 0 || unsyncedTotalExp > 0) {
        return _reconcileReport(
          base: cached,
          unsyncedRev: unsyncedRev,
          unsyncedCogs: unsyncedCogs,
          unsyncedGrossProfit: unsyncedGrossProfit,
          unsyncedCount: unsyncedCount,
          unsyncedOp: unsyncedOp,
          unsyncedSal: unsyncedSal,
          unsyncedTotalExp: unsyncedTotalExp,
          unsyncedNetProfit: unsyncedNetProfit,
        );
      }

      // If no unsynced mutations, check if local calculation has more recent data or differences
      if (localReport != null) {
        if (localReport.salesCount >= cached.salesCount ||
            localReport.revenue >= cached.revenue ||
            cached.revenue == 0) {
          return localReport;
        }
      }

      return cached;
    }

    if (localReport != null) {
      return localReport;
    }

    return ReportData(
      period: period,
      rangeStart: date ?? '',
      rangeEnd: date ?? '',
      revenue: 0,
      expenses: 0,
      operatingExpenses: 0,
      employeeSalaries: 0,
      netProfit: 0,
      grossProfit: 0,
      profitMargin: 0,
      salesCount: 0,
      topProducts: [],
      expensesByCategory: [],
      employeeSalariesBreakdown: [],
      revenueBreakdown: RevenueBreakdown(
        sales: 0,
        creditPayments: 0,
        clinicRevenue: 0,
        restaurantRevenue: 0,
        totalRevenue: 0,
      ),
      expensesBreakdown: ExpensesBreakdown(
        operatingExpenses: 0,
        employeeSalaries: 0,
        costOfGoodsSold: 0,
        totalExpenses: 0,
        byCategory: [],
        byEmployee: [],
      ),
      activitySummary: ActivitySummary(
        salesCount: 0,
        expensesCount: 0,
        employeesCount: 0,
        invoicesCount: 0,
      ),
      recentTransactions: [],
      monthlyBreakdown: [],
      global: GlobalFinancials(
        allRevenue: 0,
        allExpenses: 0,
        globalNetProfit: 0,
        inventoryValue: 0,
      ),
      allRevenue: 0,
      allExpenses: 0,
      globalNetProfit: 0,
      inventoryValue: 0,
    );
  }

  ReportData _reconcileReport({
    required ReportData base,
    required double unsyncedRev,
    required double unsyncedCogs,
    required double unsyncedGrossProfit,
    required int unsyncedCount,
    required double unsyncedOp,
    required double unsyncedSal,
    required double unsyncedTotalExp,
    required double unsyncedNetProfit,
  }) {
    final newRevenue = base.revenue + unsyncedRev;
    final newExpenses = base.expenses + unsyncedTotalExp;
    final newOpExpenses = base.operatingExpenses + unsyncedOp;
    final newSalaries = base.employeeSalaries + unsyncedSal;
    final newGrossProfit = base.grossProfit + unsyncedGrossProfit;
    final newNetProfit = base.netProfit + unsyncedNetProfit;
    final newCogs = base.expensesBreakdown.costOfGoodsSold + unsyncedCogs;
    final newSalesCount = base.salesCount + unsyncedCount;
    final newMargin = newRevenue > 0 ? ((newNetProfit / newRevenue) * 100) : 0.0;

    return ReportData(
      period: base.period,
      rangeStart: base.rangeStart,
      rangeEnd: base.rangeEnd,
      revenue: newRevenue,
      expenses: newExpenses,
      operatingExpenses: newOpExpenses,
      employeeSalaries: newSalaries,
      netProfit: newNetProfit,
      grossProfit: newGrossProfit,
      profitMargin: newMargin,
      salesCount: newSalesCount,
      topProducts: base.topProducts,
      expensesByCategory: base.expensesByCategory,
      employeeSalariesBreakdown: base.employeeSalariesBreakdown,
      revenueBreakdown: RevenueBreakdown(
        sales: base.revenueBreakdown.sales + unsyncedRev,
        creditPayments: base.revenueBreakdown.creditPayments,
        clinicRevenue: base.revenueBreakdown.clinicRevenue,
        restaurantRevenue: base.revenueBreakdown.restaurantRevenue,
        totalRevenue: base.revenueBreakdown.totalRevenue + unsyncedRev,
      ),
      expensesBreakdown: ExpensesBreakdown(
        operatingExpenses: newOpExpenses,
        employeeSalaries: newSalaries,
        costOfGoodsSold: newCogs,
        totalExpenses: newExpenses,
        byCategory: base.expensesBreakdown.byCategory,
        byEmployee: base.expensesBreakdown.byEmployee,
      ),
      activitySummary: ActivitySummary(
        salesCount: base.activitySummary.salesCount + unsyncedCount,
        expensesCount: base.activitySummary.expensesCount + (unsyncedTotalExp > 0 ? 1 : 0),
        employeesCount: base.activitySummary.employeesCount,
        invoicesCount: base.activitySummary.invoicesCount + unsyncedCount,
      ),
      recentTransactions: base.recentTransactions,
      monthlyBreakdown: base.monthlyBreakdown,
      global: GlobalFinancials(
        allRevenue: base.global.allRevenue + unsyncedRev,
        allExpenses: base.global.allExpenses + unsyncedTotalExp,
        globalNetProfit: base.global.globalNetProfit + unsyncedNetProfit,
        inventoryValue: base.global.inventoryValue,
      ),
      allRevenue: base.allRevenue + unsyncedRev,
      allExpenses: base.allExpenses + unsyncedTotalExp,
      globalNetProfit: base.globalNetProfit + unsyncedNetProfit,
      inventoryValue: base.inventoryValue,
    );
  }

  Future<List<SlowMovingProductItem>> getSlowMovingProducts({
    int days = 30,
    int threshold = 2,
    bool includeInsufficient = false,
  }) async {
    final companyId = _companyId;
    final conn = _ref.read(connectionStatusProvider);

    // 1. Try server endpoint first if online
    if (conn == ConnectionStatus.online) {
      try {
        final client = _ref.read(apiClientProvider);
        final res = await client.get('/reports/slow-moving', query: {
          'days': '$days',
          'threshold': '$threshold',
          'includeInsufficient': '$includeInsufficient',
        });
        if (res is Map && res['data'] is Map && res['data']['items'] is List) {
          final items = (res['data']['items'] as List)
              .map((e) => SlowMovingProductItem.fromJson(e as Map<String, dynamic>))
              .toList();
          return items;
        }
      } catch (_) {}
    }

    // 2. Fallback to local SQLite evaluation
    final db = await AppDatabase.instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    const sql = '''
      SELECT
        p.id,
        p.name,
        p.category,
        p.barcode,
        p.quantity AS current_stock,
        p.purchase_price,
        p.selling_price,
        p.created_at,
        COALESCE(sales_agg.units_sold, 0) AS units_sold
      FROM products p
      LEFT JOIN (
        SELECT si.product_id, SUM(si.quantity) AS units_sold
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        WHERE s.company_id = ? AND s.sold_at >= ?
        GROUP BY si.product_id
      ) sales_agg ON sales_agg.product_id = p.id
      WHERE p.company_id = ?
        AND (? = 1 OR (p.created_at IS NOT NULL AND p.created_at <= ?))
        AND COALESCE(sales_agg.units_sold, 0) <= ?
      ORDER BY units_sold ASC, current_stock DESC, p.name ASC
    ''';

    final rows = await db.rawQuery(sql, [
      companyId,
      cutoff,
      companyId,
      includeInsufficient ? 1 : 0,
      cutoff,
      threshold,
    ]);

    final now = DateTime.now();
    return rows.map((r) {
      final createdAtStr = r['created_at'] as String?;
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      final daysInInv = createdAt != null ? now.difference(createdAt).inDays : 0;
      final isInsufficient = createdAt != null && createdAt.isAfter(DateTime.now().subtract(Duration(days: days)));
      final currentStock = (r['current_stock'] as num?)?.toInt() ?? 0;
      final purchasePrice = (r['purchase_price'] as num?)?.toDouble() ?? 0.0;

      return SlowMovingProductItem(
        id: (r['id'] ?? '').toString(),
        name: (r['name'] ?? 'Product').toString(),
        category: r['category'] as String?,
        barcode: r['barcode'] as String?,
        currentStock: currentStock,
        purchasePrice: purchasePrice,
        sellingPrice: (r['selling_price'] as num?)?.toDouble() ?? 0.0,
        unitsSold: (r['units_sold'] as num?)?.toInt() ?? 0,
        insufficientHistory: isInsufficient,
        daysInInventory: daysInInv,
        stockValuation: currentStock * purchasePrice,
      );
    }).toList();
  }
}

class SlowMovingFilter {
  final int days;
  final int threshold;
  final bool includeInsufficient;

  const SlowMovingFilter({
    this.days = 30,
    this.threshold = 2,
    this.includeInsufficient = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlowMovingFilter &&
          runtimeType == other.runtimeType &&
          days == other.days &&
          threshold == other.threshold &&
          includeInsufficient == other.includeInsufficient;

  @override
  int get hashCode => days.hashCode ^ threshold.hashCode ^ includeInsufficient.hashCode;
}

final slowMovingReportProvider =
    FutureProvider.autoDispose.family<List<SlowMovingProductItem>, SlowMovingFilter>((ref, filter) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getSlowMovingProducts(
    days: filter.days,
    threshold: filter.threshold,
    includeInsufficient: filter.includeInsufficient,
  );
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  ref.watch(sessionProvider.select((s) => s.companyId ?? s.userId));
  ref.watch(connectionStatusProvider);
  return ReportsRepository(ref);
});

final reportProvider =
    FutureProvider.autoDispose.family<ReportData, String>((ref, period) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getReport(period: period);
});

final filteredReportProvider =
    FutureProvider.autoDispose.family<ReportData, ReportFilter>((ref, filter) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getReport(
    period: filter.period,
    date: filter.date,
    month: filter.month,
    year: filter.year,
  );
});

void invalidateAllReports(Ref ref) {
  ref.invalidate(reportsRepositoryProvider);
  ref.invalidate(reportProvider);
  ref.invalidate(filteredReportProvider);
  ref.invalidate(slowMovingReportProvider);
}

