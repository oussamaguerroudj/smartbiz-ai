import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_desktop/core/database/local_financial_calculator.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Desktop LocalFinancialCalculator Refactor Tests', () {
    late Database db;
    const testCompanyId = 'desktop_clothing_company_001';

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          cost_price REAL NOT NULL DEFAULT 0.0,
          purchase_price REAL NOT NULL DEFAULT 0.0,
          sale_price REAL NOT NULL DEFAULT 0.0,
          stock_quantity INTEGER NOT NULL DEFAULT 0,
          quantity INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          total REAL NOT NULL,
          payment_status TEXT NOT NULL DEFAULT 'paid',
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          sale_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          unit_cost REAL NOT NULL,
          line_total REAL NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_purchases (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          supplier_id TEXT NOT NULL,
          invoice_number TEXT,
          purchase_date TEXT NOT NULL,
          total_amount REAL NOT NULL DEFAULT 0,
          paid_amount REAL NOT NULL DEFAULT 0,
          remaining_balance REAL NOT NULL DEFAULT 0,
          payment_status TEXT NOT NULL DEFAULT 'unpaid',
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Desktop Phase 4 Clothing Store Validation', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Unsold inventory: 4 trousers @ 2,000 DZD
      await db.insert('products', {
        'id': 'p_trouser_1',
        'company_id': testCompanyId,
        'name': 'Trouser Model Classic',
        'cost_price': 2000.0,
        'purchase_price': 2000.0,
        'sale_price': 3000.0,
        'stock_quantity': 4,
        'quantity': 4,
        'created_at': '${today}T08:00:00Z',
      });

      // 2. Purchases: 10 trousers @ 2,000 DZD = 20,000 DZD in supplier_purchases
      await db.insert('supplier_purchases', {
        'id': 'sp_001',
        'company_id': testCompanyId,
        'supplier_id': 'supp_001',
        'purchase_date': today,
        'total_amount': 20000.0,
        'paid_amount': 20000.0,
        'remaining_balance': 0.0,
        'payment_status': 'paid',
        'created_at': '${today}T09:00:00Z',
      });

      // 3. Sales: 6 trousers @ 3,000 DZD = 18,000 DZD
      await db.insert('sales', {
        'id': 'sale_001',
        'company_id': testCompanyId,
        'total': 18000.0,
        'payment_status': 'paid',
        'sold_at': '${today}T14:00:00Z',
        'created_at': '${today}T14:00:00Z',
      });

      await db.insert('sale_items', {
        'id': 'si_001',
        'sale_id': 'sale_001',
        'product_id': 'p_trouser_1',
        'product_name': 'Trouser Model Classic',
        'quantity': 6,
        'unit_price': 3000.0,
        'unit_cost': 2000.0,
        'line_total': 18000.0,
      });

      // 4. Salaries: 5,000 DZD
      await db.insert('expenses', {
        'id': 'exp_sal_001',
        'company_id': testCompanyId,
        'amount': 5000.0,
        'category': 'Salaries',
        'description': 'Staff monthly payroll',
        'date': today,
        'created_at': '${today}T10:00:00Z',
      });

      // 5. Rent & Electricity: 2,000 DZD
      await db.insert('expenses', {
        'id': 'exp_op_001',
        'company_id': testCompanyId,
        'amount': 2000.0,
        'category': 'Rent & Electricity',
        'description': 'Store monthly utilities',
        'date': today,
        'created_at': '${today}T11:00:00Z',
      });

      final summary = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: testCompanyId,
        date: today,
        customDb: db,
      );

      // Verify Rule 1: Revenue = 18,000 DZD
      expect(summary.periodRevenue, 18000.0);

      // Verify Rule 2: Gross Profit = 18,000 - 12,000 = 6,000 DZD
      expect(summary.periodCogs, 12000.0);
      expect(summary.periodGrossProfit, 6000.0);

      // Verify Rule 3: Total Expenses = 20,000 + 5,000 + 2,000 = 27,000 DZD
      expect(summary.periodExpenses, 27000.0);

      // Verify Rule 4: Net Profit = 18,000 - 27,000 = -9,000 DZD (Loss)
      expect(summary.periodNetProfit, -9000.0);

      // Verify Remaining Inventory Value = 4 * 2,000 = 8,000 DZD
      expect(summary.inventoryValue, 8000.0);

      // Verify expensesByCategory includes "Product Purchases"
      final hasProductPurchases = summary.expensesByCategory.any(
        (e) => e['category'] == 'Product Purchases' && (e['amount'] as num) == 20000.0,
      );
      expect(hasProductPurchases, true);
    });
  });
}
