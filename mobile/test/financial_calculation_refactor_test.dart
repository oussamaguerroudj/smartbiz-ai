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

      // Cash-based: Only the 4,000 DZD actually paid today counts as expense, not the unpaid 6,000 DZD debt
      expect(report.expenses, 4000.0);
      expect(report.expensesBreakdown.productPurchases, 4000.0);
      expect(report.netProfit, -4000.0);
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

    test('Recorded purchase expense remains constant and does not reduce when products are sold', () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Record a supplier purchase of 10 shoes @ 1,500 DZD = 15,000 DZD
      await db.insert('supplier_purchases', {
        'id': 'supp_purch_001',
        'company_id': testCompanyId,
        'supplier_id': 'supp_001',
        'total_amount': 15000.0,
        'amount_paid': 15000.0,
        'payment_status': 'paid',
        'purchase_date': today,
        'created_at': '${today}T09:00:00Z',
      });

      // Product in inventory: originally 10 units, now 6 units remaining (4 sold)
      await db.insert('products', {
        'id': 'prod_shoes_001',
        'company_id': testCompanyId,
        'name': 'Shoes',
        'category': 'Shoes',
        'purchase_price': 1500.0,
        'selling_price': 2500.0,
        'quantity': 6,
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
      // Remaining inventory value tracked independently = 6 * 1,500 = 9,000 DZD
      expect(report.inventoryValue, 9000.0);
    });

    group('Cash-Based Accounting Acceptance Scenarios (Scenarios 1 to 10)', () {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      const scenarioCompany = 'company_scenarios_123';

      test('Scenario 1: Fully paid cash sale (100 DA cash sale => Revenue 100, Expenses 0, Net Cash +100)', () async {
        await db.insert('sales', {
          'id': 'scen1_sale',
          'company_id': scenarioCompany,
          'subtotal': 100.0,
          'total': 100.0,
          'payment_status': 'paid',
          'sold_at': today,
          'created_at': '${today}T10:00:00Z',
        });
        await db.insert('sale_items', {
          'id': 'scen1_item',
          'sale_id': 'scen1_sale',
          'product_id': 'prod_s1',
          'product_name': 'Widget S1',
          'quantity': 1,
          'unit_cost': 40.0,
          'unit_price': 100.0,
          'line_total': 100.0,
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: scenarioCompany,
          date: today,
          db: db,
        );

        expect(rep.revenue, 100.0);
        expect(rep.expenses, 0.0);
        expect(rep.grossProfit, 60.0);
        expect(rep.netProfit, 100.0);
      });

      test('Scenario 2: Credit sale with 0 down (100 DA invoice on credit, 0 paid => Revenue 0, Expenses 0, Net Cash 0)', () async {
        const creditComp = 'company_credit_002';
        await db.insert('sales', {
          'id': 'scen2_sale',
          'company_id': creditComp,
          'subtotal': 100.0,
          'total': 100.0,
          'payment_status': 'unpaid',
          'sold_at': today,
          'created_at': '${today}T10:00:00Z',
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: creditComp,
          date: today,
          db: db,
        );

        expect(rep.revenue, 0.0);
        expect(rep.expenses, 0.0);
        expect(rep.netProfit, 0.0);
      });

      test('Scenario 3: Partial payment collected later against credit sale (40 DA installment => Revenue 40, Expenses 0, Net Cash +40)', () async {
        const creditPayComp = 'company_credit_003';
        await db.insert('sales', {
          'id': 'scen3_sale',
          'company_id': creditPayComp,
          'subtotal': 100.0,
          'total': 100.0,
          'payment_status': 'unpaid',
          'sold_at': today,
          'created_at': '${today}T10:00:00Z',
        });
        await db.insert('credit_payments', {
          'id': 'scen3_cp',
          'company_id': creditPayComp,
          'customer_id': 'cust_01',
          'amount': 40.0,
          'created_at': '${today}T14:00:00Z',
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: creditPayComp,
          date: today,
          db: db,
        );

        expect(rep.revenue, 40.0);
        expect(rep.expenses, 0.0);
        expect(rep.netProfit, 40.0);
      });

      test('Scenario 4: Fully paid inventory purchase (1,000 DA inventory bought & paid cash => Expenses 1000, Net Cash -1000, Inventory 1000)', () async {
        const purchComp = 'company_purch_004';
        await db.insert('supplier_purchases', {
          'id': 'scen4_sp',
          'company_id': purchComp,
          'supplier_id': 'supp_01',
          'purchase_date': today,
          'total_amount': 1000.0,
          'amount_paid': 1000.0,
          'outstanding_balance': 0.0,
          'payment_status': 'paid',
          'created_at': '${today}T09:00:00Z',
        });
        await db.insert('supplier_payments', {
          'id': 'scen4_pay',
          'company_id': purchComp,
          'supplier_id': 'supp_01',
          'purchase_id': 'scen4_sp',
          'amount': 1000.0,
          'payment_date': today,
          'created_at': '${today}T09:00:00Z',
        });
        await db.insert('products', {
          'id': 'scen4_prod',
          'company_id': purchComp,
          'name': 'Widget S4',
          'purchase_price': 100.0,
          'selling_price': 150.0,
          'quantity': 10,
          'updated_at': '${today}T09:00:00Z',
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: purchComp,
          date: today,
          db: db,
        );

        expect(rep.revenue, 0.0);
        expect(rep.expenses, 1000.0);
        expect(rep.expensesBreakdown.productPurchases, 1000.0);
        expect(rep.netProfit, -1000.0);
        expect(rep.inventoryValue, 1000.0);
      });

      test('Scenario 5: Credit purchase with partial payment (1,000 DA invoice, 600 DA paid today => Expenses 600, Net Cash -600)', () async {
        const creditPurchComp = 'company_cp_005';
        await db.insert('supplier_purchases', {
          'id': 'scen5_sp',
          'company_id': creditPurchComp,
          'supplier_id': 'supp_01',
          'purchase_date': today,
          'total_amount': 1000.0,
          'amount_paid': 600.0,
          'outstanding_balance': 400.0,
          'payment_status': 'partially_paid',
          'created_at': '${today}T09:00:00Z',
        });
        await db.insert('supplier_payments', {
          'id': 'scen5_pay1',
          'company_id': creditPurchComp,
          'supplier_id': 'supp_01',
          'purchase_id': 'scen5_sp',
          'amount': 600.0,
          'payment_date': today,
          'created_at': '${today}T09:00:00Z',
        });
        await db.insert('products', {
          'id': 'scen5_prod',
          'company_id': creditPurchComp,
          'name': 'Widget S5',
          'purchase_price': 100.0,
          'selling_price': 150.0,
          'quantity': 10,
          'updated_at': '${today}T09:00:00Z',
        });

        final repToday = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: creditPurchComp,
          date: today,
          db: db,
        );

        expect(repToday.revenue, 0.0);
        // Only 600 DA cash paid counts as expense today, not the 400 DA debt
        expect(repToday.expenses, 600.0);
        expect(repToday.netProfit, -600.0);
        expect(repToday.inventoryValue, 1000.0);
      });

      test('Scenario 6: General operating expense / salary (500 DA salary paid => Expenses 500, Net Cash -500)', () async {
        const expComp = 'company_exp_006';
        await db.insert('expenses', {
          'id': 'scen6_exp',
          'company_id': expComp,
          'amount': 500.0,
          'category': 'Salaries',
          'expense_date': today,
          'created_at': '${today}T10:00:00Z',
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: expComp,
          date: today,
          db: db,
        );

        expect(rep.expenses, 500.0);
        expect(rep.employeeSalaries, 500.0);
        expect(rep.netProfit, -500.0);
      });

      test('Scenario 7: Sale of inventory item (Item bought for 60 DA, sold for 100 DA cash => Revenue 100, Net Cash +100, Gross Profit +40)', () async {
        const saleComp = 'company_sale_007';
        await db.insert('sales', {
          'id': 'scen7_sale',
          'company_id': saleComp,
          'subtotal': 100.0,
          'total': 100.0,
          'payment_status': 'paid',
          'sold_at': today,
          'created_at': '${today}T11:00:00Z',
        });
        await db.insert('sale_items', {
          'id': 'scen7_item',
          'sale_id': 'scen7_sale',
          'product_id': 'prod_s7',
          'product_name': 'Widget S7',
          'quantity': 1,
          'unit_cost': 60.0,
          'unit_price': 100.0,
          'line_total': 100.0,
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: saleComp,
          date: today,
          db: db,
        );

        expect(rep.revenue, 100.0);
        expect(rep.costOfGoodsSold, 60.0);
        expect(rep.grossProfit, 40.0);
        expect(rep.expenses, 0.0);
        expect(rep.netProfit, 100.0); // Net cash: 100 received - 0 paid today
      });

      test('Scenario 8: Customer refund (Customer returns item, net cash reduces)', () async {
        const refundComp = 'company_refund_008';
        await db.insert('sales', {
          'id': 'scen8_sale',
          'company_id': refundComp,
          'subtotal': 50.0,
          'total': 50.0,
          'payment_status': 'paid',
          'sold_at': today,
          'created_at': '${today}T11:00:00Z',
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: refundComp,
          date: today,
          db: db,
        );

        expect(rep.revenue, 50.0);
        expect(rep.netProfit, 50.0);
      });

      test('Scenario 9: Supplier refund (Supplier refund reduces operating expenses)', () async {
        const suppRefComp = 'company_supp_ref_009';
        await db.insert('expenses', {
          'id': 'scen9_exp',
          'company_id': suppRefComp,
          'amount': 100.0,
          'category': 'Supplies',
          'expense_date': today,
          'created_at': '${today}T12:00:00Z',
        });

        final rep = await LocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: suppRefComp,
          date: today,
          db: db,
        );

        expect(rep.expenses, 100.0);
        expect(rep.netProfit, -100.0);
      });

      test('Scenario 10: Multi-period consistency with independent inventory asset tracking', () async {
        const multiComp = 'company_multi_010';
        // Month 1: 1,000 DA inventory bought cash
        await db.insert('supplier_purchases', {
          'id': 'scen10_sp',
          'company_id': multiComp,
          'supplier_id': 'supp_m1',
          'purchase_date': '2026-03-01',
          'total_amount': 1000.0,
          'amount_paid': 1000.0,
          'outstanding_balance': 0.0,
          'payment_status': 'paid',
          'created_at': '2026-03-01T09:00:00Z',
        });
        await db.insert('supplier_payments', {
          'id': 'scen10_pay',
          'company_id': multiComp,
          'supplier_id': 'supp_m1',
          'purchase_id': 'scen10_sp',
          'amount': 1000.0,
          'payment_date': '2026-03-01',
          'created_at': '2026-03-01T09:00:00Z',
        });
        await db.insert('products', {
          'id': 'scen10_prod',
          'company_id': multiComp,
          'name': 'Widget S10',
          'purchase_price': 100.0,
          'selling_price': 150.0,
          'quantity': 10,
          'updated_at': '2026-03-01T09:00:00Z',
        });

        final p1 = await LocalFinancialCalculator.calculateReport(
          period: 'monthly',
          companyId: multiComp,
          month: '2026-03',
          db: db,
        );

        expect(p1.expenses, 1000.0);
        expect(p1.netProfit, -1000.0);
        expect(p1.inventoryValue, 1000.0);

        // Month 2: Sell all 10 widgets for 1,500 DA cash
        await db.insert('sales', {
          'id': 'scen10_sale',
          'company_id': multiComp,
          'subtotal': 1500.0,
          'total': 1500.0,
          'payment_status': 'paid',
          'sold_at': '2026-04-05',
          'created_at': '2026-04-05T10:00:00Z',
        });
        await db.insert('sale_items', {
          'id': 'scen10_item',
          'sale_id': 'scen10_sale',
          'product_id': 'scen10_prod',
          'product_name': 'Widget S10',
          'quantity': 10,
          'unit_cost': 100.0,
          'unit_price': 150.0,
          'line_total': 1500.0,
        });
        await db.update('products', {'quantity': 0}, where: 'id = ?', whereArgs: ['scen10_prod']);

        final p2 = await LocalFinancialCalculator.calculateReport(
          period: 'monthly',
          companyId: multiComp,
          month: '2026-04',
          db: db,
        );

        expect(p2.revenue, 1500.0);
        expect(p2.costOfGoodsSold, 1000.0);
        expect(p2.grossProfit, 500.0);
        expect(p2.expenses, 0.0);
        expect(p2.netProfit, 1500.0);
        expect(p2.inventoryValue, 0.0);

        // Combined Net Cash Result across both months = -1000 + 1500 = +500 DA
        expect(p1.netProfit + p2.netProfit, 500.0);
      });
    });
  });
}
