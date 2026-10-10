import 'desktop_database.dart';

class FinancialSummary {
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final double profitMargin;
  final int salesCount;

  const FinancialSummary({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.profitMargin,
    required this.salesCount,
  });

  factory FinancialSummary.empty() => const FinancialSummary(
        revenue: 0.0,
        cogs: 0.0,
        grossProfit: 0.0,
        totalExpenses: 0.0,
        netProfit: 0.0,
        profitMargin: 0.0,
        salesCount: 0,
      );
}

class LocalFinancialCalculator {
  static Future<FinancialSummary> calculateSummary({
    required String companyId,
    String? startDate,
    String? endDate,
  }) async {
    if (companyId.isEmpty) return FinancialSummary.empty();

    final db = await DesktopDatabase.instance.database;

    final start = startDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final end = endDate ?? start;

    // 1. Core sales revenue & COGS
    final salesRes = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total), 0) AS rev,
        COUNT(id) AS count
      FROM sales
      WHERE company_id = ? AND payment_status != 'cancelled'
        AND substr(sold_at, 1, 10) BETWEEN ? AND ?
    ''', [companyId, start, end]);

    final cogsRes = await db.rawQuery('''
      SELECT
        COALESCE(SUM(si.unit_cost * si.quantity), 0) AS cogs
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.company_id = ? AND s.payment_status != 'cancelled'
        AND substr(s.sold_at, 1, 10) BETWEEN ? AND ?
    ''', [companyId, start, end]);

    // 2. Credit payments
    double creditRev = 0.0;
    try {
      final creditRes = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM credit_payments
        WHERE company_id = ? AND substr(created_at, 1, 10) BETWEEN ? AND ?
      ''', [companyId, start, end]);
      creditRev = (creditRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 3. Restaurant orders
    double restRev = 0.0;
    try {
      final restRes = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount), 0) AS total
        FROM restaurant_orders
        WHERE company_id = ? AND status != 'cancelled'
          AND substr(created_at, 1, 10) BETWEEN ? AND ?
      ''', [companyId, start, end]);
      restRev = (restRes.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    // 4. Expenses
    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS exp
      FROM expenses
      WHERE company_id = ? AND substr(expense_date, 1, 10) BETWEEN ? AND ?
    ''', [companyId, start, end]);

    final salesRev = (salesRes.first['rev'] as num?)?.toDouble() ?? 0.0;
    final totalRevenue = salesRev + creditRev + restRev;
    final totalCogs = (cogsRes.first['cogs'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = totalRevenue - totalCogs;
    final totalExpenses = (expRes.first['exp'] as num?)?.toDouble() ?? 0.0;
    final netProfit = grossProfit - totalExpenses;
    final margin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0.0;
    final salesCount = (salesRes.first['count'] as num?)?.toInt() ?? 0;

    return FinancialSummary(
      revenue: totalRevenue,
      cogs: totalCogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      profitMargin: margin,
      salesCount: salesCount,
    );
  }
}
