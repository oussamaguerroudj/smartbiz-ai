import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/reports/domain/report.dart';

void main() {
  group('ReportData Model Tests', () {
    test('Correctly parses complete financial report from JSON', () {
      final json = {
        'period': 'monthly',
        'rangeStart': '2026-09-01',
        'rangeEnd': '2026-09-30',
        'revenue': 300000.0,
        'expenses': 70000.0,
        'operatingExpenses': 30000.0,
        'employeeSalaries': 40000.0,
        'costOfGoodsSold': 0.0,
        'grossProfit': 300000.0,
        'netProfit': 230000.0,
        'profitMargin': 76.67,
        'salesCount': 15,
        'topProducts': [
          {'name': 'Laptop Stand', 'units_sold': 10, 'total': 25000.0},
        ],
        'expensesByCategory': [
          {'category': 'Rent', 'amount': 20000.0, 'total': 20000.0},
          {'category': 'Utilities', 'amount': 10000.0, 'total': 10000.0},
        ],
        'employeeSalariesBreakdown': [
          {
            'id': 'emp-1',
            'name': 'Ahmed',
            'position': 'Manager',
            'baseSalary': 40000.0,
            'periodSalary': 40000.0,
          },
        ],
        'revenueBreakdown': {
          'sales': 250000.0,
          'creditPayments': 50000.0,
          'clinicRevenue': 0.0,
          'restaurantRevenue': 0.0,
          'totalRevenue': 300000.0,
        },
        'expensesBreakdown': {
          'operatingExpenses': 30000.0,
          'employeeSalaries': 40000.0,
          'costOfGoodsSold': 0.0,
          'totalExpenses': 70000.0,
          'byCategory': [
            {'category': 'Rent', 'amount': 20000.0},
            {'category': 'Utilities', 'amount': 10000.0},
          ],
          'byEmployee': [
            {
              'id': 'emp-1',
              'name': 'Ahmed',
              'position': 'Manager',
              'baseSalary': 40000.0,
              'periodSalary': 40000.0,
            },
          ],
        },
        'activitySummary': {
          'salesCount': 15,
          'expensesCount': 2,
          'employeesCount': 1,
          'invoicesCount': 3,
        },
        'recentTransactions': [
          {
            'id': 'tx-1',
            'type': 'sale',
            'amount': 5000.0,
            'status': 'paid',
            'date': '2026-09-28T10:00:00Z',
            'title': 'Vente #tx-1',
          },
          {
            'id': 'tx-2',
            'type': 'expense',
            'amount': 2000.0,
            'status': 'Rent',
            'date': '2026-09-27T10:00:00Z',
            'title': 'Rent - Sept',
          },
        ],
      };

      final report = ReportData.fromJson(json);

      expect(report.period, 'monthly');
      expect(report.rangeStart, '2026-09-01');
      expect(report.rangeEnd, '2026-09-30');
      expect(report.revenue, 300000.0);
      expect(report.expenses, 70000.0);
      expect(report.netProfit, 230000.0);
      expect(report.profitMargin, 76.67);
      expect(report.salesCount, 15);

      // Verify breakdowns
      expect(report.revenueBreakdown.sales, 250000.0);
      expect(report.revenueBreakdown.creditPayments, 50000.0);
      expect(report.expensesBreakdown.operatingExpenses, 30000.0);
      expect(report.expensesBreakdown.employeeSalaries, 40000.0);
      expect(report.expensesByCategory.length, 2);
      expect(report.employeeSalariesBreakdown.length, 1);
      expect(report.employeeSalariesBreakdown[0].name, 'Ahmed');
      expect(report.activitySummary.invoicesCount, 3);
      expect(report.recentTransactions.length, 2);
      expect(report.recentTransactions[0].type, 'sale');
    });

    test('Handles zero revenue and negative net profit (loss) cleanly', () {
      final json = {
        'period': 'daily',
        'rangeStart': '2026-09-30',
        'rangeEnd': '2026-09-30',
        'revenue': 0.0,
        'expenses': 5000.0,
        'operatingExpenses': 5000.0,
        'employeeSalaries': 0.0,
        'netProfit': -5000.0,
        'profitMargin': 0.0,
        'salesCount': 0,
      };

      final report = ReportData.fromJson(json);

      expect(report.revenue, 0.0);
      expect(report.expenses, 5000.0);
      expect(report.netProfit, -5000.0);
      expect(report.profitMargin, 0.0);
      expect(report.salesCount, 0);
      expect(report.topProducts, isEmpty);
      expect(report.recentTransactions, isEmpty);
    });

    test('Handles fallback for minimal json response gracefully', () {
      final json = <String, dynamic>{};

      final report = ReportData.fromJson(json);

      expect(report.period, 'monthly');
      expect(report.revenue, 0.0);
      expect(report.expenses, 0.0);
      expect(report.netProfit, 0.0);
      expect(report.topProducts, isEmpty);
      expect(report.expensesByCategory, isEmpty);
      expect(report.employeeSalariesBreakdown, isEmpty);
    });

    test('Parses Global Net Profit and Yearly Monthly Breakdown correctly', () {
      final json = {
        'period': 'yearly',
        'rangeStart': '2026-01-01',
        'rangeEnd': '2026-12-31',
        'revenue': 1200000.0,
        'expenses': 400000.0,
        'operatingExpenses': 200000.0,
        'employeeSalaries': 200000.0,
        'netProfit': 800000.0,
        'global': {
          'allRevenue': 5000000.0,
          'allExpenses': 2000000.0,
          'globalNetProfit': 3000000.0,
        },
        'allRevenue': 5000000.0,
        'allExpenses': 2000000.0,
        'globalNetProfit': 3000000.0,
        'monthlyBreakdown': [
          {
            'month': 1,
            'monthName': 'January',
            'revenue': 100000.0,
            'expenses': 30000.0,
            'salaryExpenses': 20000.0,
            'operatingExpenses': 10000.0,
            'netProfit': 70000.0,
          },
          {
            'month': 2,
            'monthName': 'February',
            'revenue': 110000.0,
            'expenses': 35000.0,
            'salaryExpenses': 20000.0,
            'operatingExpenses': 15000.0,
            'netProfit': 75000.0,
          },
        ],
        'recentTransactions': [
          {
            'id': 'tx-salary-1',
            'type': 'salary',
            'amount': 30000.0,
            'status': 'Salary',
            'date': '2026-09-30T00:00:00.000Z',
            'title': 'Salary - Ahmed',
            'description': 'Ahmed - September 2026 salary',
            'employeeName': 'Ahmed',
            'salaryPeriod': 'September 2026',
            'duration': '1 month',
          },
        ],
      };

      final report = ReportData.fromJson(json);

      expect(report.allRevenue, 5000000.0);
      expect(report.allExpenses, 2000000.0);
      expect(report.globalNetProfit, 3000000.0);
      expect(report.global.globalNetProfit, 3000000.0);
      expect(report.monthlyBreakdown, hasLength(2));
      expect(report.monthlyBreakdown[0].monthName, 'January');
      expect(report.monthlyBreakdown[0].salaryExpenses, 20000.0);

      expect(report.recentTransactions, hasLength(1));
      final tx = report.recentTransactions.first;
      expect(tx.type, 'salary');
      expect(tx.employeeName, 'Ahmed');
      expect(tx.salaryPeriod, 'September 2026');
      expect(tx.duration, '1 month');
    });

    test('Correctly computes and parses profit margin Revenue, Inventory Value, and Net Profit', () {
      const purchasePrice = 100.0;
      const salePrice = 150.0;
      const quantitySold = 10;
      const currentStock = 20;
      const expenses = 200.0;

      const marginPerUnit = salePrice - purchasePrice;
      const revenue = marginPerUnit * quantitySold; // 500
      const inventoryValue = marginPerUnit * currentStock; // 1000
      const netProfit = revenue - expenses; // 300

      final json = {
        'period': 'daily',
        'rangeStart': '2026-09-30',
        'rangeEnd': '2026-09-30',
        'revenue': revenue,
        'inventoryValue': inventoryValue,
        'expenses': expenses,
        'netProfit': netProfit,
        'grossProfit': revenue,
        'salesCount': 1,
      };

      final report = ReportData.fromJson(json);
      expect(report.revenue, 500.0);
      expect(report.inventoryValue, 1000.0);
      expect(report.expenses, 200.0);
      expect(report.netProfit, 300.0);
    });
  });
}

