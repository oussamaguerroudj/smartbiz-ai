import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/database/local_financial_calculator.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Financial Calculation Refactor - Offline SQLite Engine Tests', () {
    late Database db;
    const testCompanyId = 'company_clothing_store_001';
    const otherCompanyId = 'company_other_999';

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Create schema matching app_database.dart
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          category TEXT,
          purchase_price REAL NOT NULL,
          selling_price REAL NOT NULL,
          quantity INTEGER NOT NULL,
          minimum_stock INTEGER DEFAULT 5,
          barcode TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          client_transaction_id TEXT,
          company_id TEXT NOT NULL,
          customer_id TEXT,
          customer_name TEXT,
          employee_id TEXT,
          subtotal REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0.0,
          total REAL NOT NULL,
          payment_status TEXT NOT NULL DEFAULT 'paid',
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
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
          client_id TEXT UNIQUE,
          company_id TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          expense_date TEXT NOT NULL,
          payment_method TEXT,
          employee_id TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
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
          amount_paid REAL NOT NULL DEFAULT 0,
          outstanding_balance REAL NOT NULL DEFAULT 0,
          payment_status TEXT NOT NULL DEFAULT 'unpaid',
          notes TEXT,
          client_transaction_id TEXT UNIQUE,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_payments (
          id TEXT PRIMARY KEY,
          client_id TEXT UNIQUE,
          company_id TEXT NOT NULL,
          supplier_id TEXT NOT NULL,
          purchase_id TEXT,
          amount REAL NOT NULL DEFAULT 0,
          payment_date TEXT NOT NULL,
          payment_method TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE credit_payments (
          id TEXT PRIMARY KEY,
          client_id TEXT UNIQUE,
          company_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          amount REAL NOT NULL DEFAULT 0,
          note TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          sale_id TEXT NOT NULL,
          invoice_number TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Phase 4 Mandatory Clothing Store Numerical Validation', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // 1. Initial product setup: 4 trousers remain in inventory @ 2,000 DZD purchase price
      await db.insert('products', {
        'id': 'prod_trousers_1',
        'company_id': testCompanyId,
        'name': 'Trouser Model Classic',
        'category': 'Clothing',
        'purchase_price': 2000.0,
        'selling_price': 3000.0,
        'quantity': 4,
        'created_at': '${today}T08:00:00Z',
      });

      // 2. Purchases: 10 trousers @ 2,000 DZD = 20,000 DZD recorded in supplier_purchases
      await db.insert('supplier_purchases', {
        'id': 'sp_001',
        'company_id': testCompanyId,
        'supplier_id': 'supp_001',
        'purchase_date': today,
        'total_amount': 20000.0,
        'amount_paid': 20000.0,
        'outstanding_balance': 0.0,
        'payment_status': 'paid',
        'created_at': '${today}T09:00:00Z',
      });

      // 3. Sales: 6 trousers @ 3,000 DZD = 18,000 DZD total revenue
      await db.insert('sales', {
        'id': 'sale_001',
        'company_id': testCompanyId,
        'subtotal': 18000.0,
        'total': 18000.0,
        'payment_status': 'paid',
        'sold_at': '${today}T14:30:00Z',
        'created_at': '${today}T14:30:00Z',
      });

      await db.insert('sale_items', {
        'id': 'si_001',
        'sale_id': 'sale_001',
        'product_id': 'prod_trousers_1',
        'product_name': 'Trouser Model Classic',
        'quantity': 6,
        'unit_price': 3000.0,
        'unit_cost': 2000.0,
        'line_total': 18000.0,
      });

      // 4. Expenses: Salaries: 5,000 DZD
      await db.insert('expenses', {
        'id': 'exp_sal_001',
        'company_id': testCompanyId,
        'amount': 5000.0,
        'category': 'Salaries',
        'description': 'Staff monthly payroll',
        'expense_date': today,
        'created_at': '${today}T10:00:00Z',
      });

      // 5. Expenses: Rent & Electricity: 2,000 DZD
      await db.insert('expenses', {
        'id': 'exp_op_001',
        'company_id': testCompanyId,
        'amount': 2000.0,
        'category': 'Rent & Electricity',
        'description': 'Store monthly utilities',
        'expense_date': today,
        'created_at': '${today}T11:00:00Z',
      });

      // Calculate daily report
      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: testCompanyId,
        date: today,
        db: db,
      );

      // Verify Rule 1: Total Revenue = 18,000 DZD
      expect(report.revenue, 18000.0);

      // Verify Rule 2: Gross Profit = Revenue (18,000) - COGS (12,000) = 6,000 DZD
      expect(report.expensesBreakdown.costOfGoodsSold, 12000.0);
      expect(report.grossProfit, 6000.0);

      // Verify Rule 3: Total Expenses = Product Purchases (20,000) + Salaries (5,000) + Operating (2,000) = 27,000 DZD
      expect(report.expensesBreakdown.productPurchases, 20000.0);
      expect(report.employeeSalaries, 5000.0);
      expect(report.operatingExpenses, 2000.0);
      expect(report.expenses, 27000.0);

      // Verify Rule 4: Net Profit = Revenue (18,000) - Total Expenses (27,000) = -9,000 DZD (Loss)
      expect(report.netProfit, -9000.0);

      // Verify Remaining Inventory Value = 4 trousers * 2,000 DZD = 8,000 DZD
      expect(report.inventoryValue, 8000.0);

      // Verify expenses by category includes "Product Purchases"
      final purchaseCat = report.expensesByCategory.firstWhere(
        (c) => c.category == 'Product Purchases',
      );
      expect(purchaseCat.amount, 20000.0);
    });

    test('Anti-Duplication: Supplier payments must not increase Total Expenses', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Record a supplier purchase of 10,000 DZD
      await db.insert('supplier_purchases', {
        'id': 'sp_002',
        'company_id': testCompanyId,
        'supplier_id': 'supp_001',
        'purchase_date': today,
        'total_amount': 10000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 10000.0,
        'payment_status': 'unpaid',
        'created_at': '${today}T09:00:00Z',
      });

      // Pay off the debt partially with supplier_payments (4,000 DZD)
      await db.insert('supplier_payments', {
        'id': 'supp_pay_001',
        'company_id': testCompanyId,
        'supplier_id': 'supp_001',
        'purchase_id': 'sp_002',
        'amount': 4000.0,
        'payment_date': today,
        'created_at': '${today}T15:00:00Z',
      });

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: testCompanyId,
        date: today,
        db: db,
      );

      // Total expenses should be exactly the 10,000 DZD purchase cost, NOT 14,000 DZD
      expect(report.expenses, 10000.0);
      expect(report.expensesBreakdown.productPurchases, 10000.0);
      expect(report.netProfit, -10000.0);
    });

    test('Tenant Isolation: Queries for otherCompanyId return 0', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Insert data for testCompanyId
      await db.insert('sales', {
        'id': 'sale_isolated_001',
        'company_id': testCompanyId,
        'subtotal': 5000.0,
        'total': 5000.0,
        'payment_status': 'paid',
        'sold_at': today,
        'created_at': today,
      });

      // Query report for otherCompanyId
      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: otherCompanyId,
        date: today,
        db: db,
      );

      expect(report.revenue, 0.0);
      expect(report.expenses, 0.0);
      expect(report.netProfit, 0.0);
      expect(report.grossProfit, 0.0);
    });

    test('Cancelled sales are excluded from Revenue and COGS', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      await db.insert('sales', {
        'id': 'sale_cancelled_001',
        'company_id': testCompanyId,
        'subtotal': 15000.0,
        'total': 15000.0,
        'payment_status': 'cancelled',
        'sold_at': today,
        'created_at': today,
      });

      await db.insert('sale_items', {
        'id': 'si_cancelled_001',
        'sale_id': 'sale_cancelled_001',
        'product_id': 'prod_99',
        'product_name': 'Item',
        'quantity': 1,
        'unit_price': 15000.0,
        'unit_cost': 10000.0,
        'line_total': 15000.0,
      });

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: testCompanyId,
        date: today,
        db: db,
      );

      expect(report.revenue, 0.0);
      expect(report.expensesBreakdown.costOfGoodsSold, 0.0);
      expect(report.grossProfit, 0.0);
    });

    test('Direct product inventory addition (without supplier purchases) is added to productPurchases and total expenses', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // User adds a direct product in inventory with 10 units @ 1,500 DZD purchase price
      await db.insert('products', {
        'id': 'prod_direct_001',
        'company_id': testCompanyId,
        'name': 'Direct Inventory Shoes',
        'category': 'Shoes',
        'purchase_price': 1500.0,
        'selling_price': 2500.0,
        'quantity': 10,
        'updated_at': '${today}T10:00:00Z',
      });

      // Operating expense of 2,000 DZD
      await db.insert('expenses', {
        'id': 'exp_direct_001',
        'company_id': testCompanyId,
        'amount': 2000.0,
        'category': 'Electricity',
        'expense_date': today,
        'created_at': '${today}T10:00:00Z',
      });

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: testCompanyId,
        date: today,
        db: db,
      );

      // Direct inventory acquisition = 10 * 1,500 = 15,000 DZD
      expect(report.expensesBreakdown.productPurchases, 15000.0);
      expect(report.operatingExpenses, 2000.0);
      // Total expenses = 15,000 + 2,000 = 17,000 DZD
      expect(report.expenses, 17000.0);
      // Net Profit = 0 - 17,000 = -17,000 DZD
      expect(report.netProfit, -17000.0);
    });
  });
}
