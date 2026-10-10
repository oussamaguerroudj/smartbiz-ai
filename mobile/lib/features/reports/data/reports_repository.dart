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
    return 'report_cache_${companyId}_${period}_${date ?? ''}_${month ?? ''}_${year ?? ''}';
  }

  Future<void> _cacheServerReport(String cacheKey, Map<String, dynamic> data) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
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

  Future<ReportData?> _getCachedServerReport(String cacheKey) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
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
    try {
      localReport = await LocalFinancialCalculator.calculateReport(
        period: period,
        companyId: companyId,
        date: date,
        month: month,
        year: year,
        db: db,
      );
    } catch (_) {}

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
        await _cacheServerReport(cacheKey, data);

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
            COALESCE(SUM(total), 0) AS revenue,
            COUNT(*) AS count
          FROM sales
          WHERE company_id = ? AND synced = 0 AND payment_status != 'cancelled'
            AND (CASE WHEN sold_at LIKE '%Z' OR sold_at LIKE '%+%' THEN date(sold_at, 'localtime') ELSE date(sold_at) END) BETWEEN date(?) AND date(?)
          ''',
          [companyId, rangeStart, rangeEnd],
        );

        final unsyncedRev = (unsyncedSalesRes.first['revenue'] as num?)?.toDouble() ?? 0.0;
        final unsyncedCount = (unsyncedSalesRes.first['count'] as num?)?.toInt() ?? 0;

        if (unsyncedRev > 0 || unsyncedCount > 0) {
          return ReportData(
            period: serverReport.period,
            rangeStart: serverReport.rangeStart,
            rangeEnd: serverReport.rangeEnd,
            revenue: serverReport.revenue + unsyncedRev,
            expenses: serverReport.expenses,
            operatingExpenses: serverReport.operatingExpenses,
            employeeSalaries: serverReport.employeeSalaries,
            netProfit: serverReport.netProfit + unsyncedRev,
            grossProfit: serverReport.grossProfit + unsyncedRev,
            profitMargin: (serverReport.revenue + unsyncedRev) > 0
                ? (((serverReport.netProfit + unsyncedRev) / (serverReport.revenue + unsyncedRev)) * 100)
                : 0.0,
            salesCount: serverReport.salesCount + unsyncedCount,
            topProducts: serverReport.topProducts,
            expensesByCategory: serverReport.expensesByCategory,
            employeeSalariesBreakdown: serverReport.employeeSalariesBreakdown,
            revenueBreakdown: RevenueBreakdown(
              sales: serverReport.revenueBreakdown.sales + unsyncedRev,
              creditPayments: serverReport.revenueBreakdown.creditPayments,
              clinicRevenue: serverReport.revenueBreakdown.clinicRevenue,
              restaurantRevenue: serverReport.revenueBreakdown.restaurantRevenue,
              totalRevenue: serverReport.revenueBreakdown.totalRevenue + unsyncedRev,
            ),
            expensesBreakdown: serverReport.expensesBreakdown,
            activitySummary: ActivitySummary(
              salesCount: serverReport.activitySummary.salesCount + unsyncedCount,
              expensesCount: serverReport.activitySummary.expensesCount,
              employeesCount: serverReport.activitySummary.employeesCount,
              invoicesCount: serverReport.activitySummary.invoicesCount,
            ),
            recentTransactions: serverReport.recentTransactions,
            monthlyBreakdown: serverReport.monthlyBreakdown,
            global: GlobalFinancials(
              allRevenue: serverReport.global.allRevenue + unsyncedRev,
              allExpenses: serverReport.global.allExpenses,
              globalNetProfit: serverReport.global.globalNetProfit + unsyncedRev,
              inventoryValue: serverReport.global.inventoryValue,
            ),
            allRevenue: serverReport.allRevenue + unsyncedRev,
            allExpenses: serverReport.allExpenses,
            globalNetProfit: serverReport.globalNetProfit + unsyncedRev,
            inventoryValue: serverReport.inventoryValue,
          );
        }

        return serverReport;
      } catch (e) {
        // Fallback to local calculation or cached report if server call fails
      }
    }

    // 3. Offline Mode: Return authoritative local report from SQLite
    if (localReport != null && (localReport.salesCount > 0 || localReport.revenue > 0 || localReport.expenses > 0)) {
      return localReport;
    }

    // If SQLite is completely empty for this period, check for cached server report
    final cached = await _getCachedServerReport(cacheKey);
    if (cached != null) {
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
}

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
}
