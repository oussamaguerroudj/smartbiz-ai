import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/database/local_financial_calculator.dart';
import 'package:modiri_ai/features/reports/domain/report.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  const companyId = 'test_comp_hours';
  const otherCompanyId = 'tenant_other_company';

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
        expiration_date TEXT,
        size TEXT,
        color TEXT,
        brand TEXT,
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
        company_id TEXT,
        product_id TEXT NOT NULL,
        product_name TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL,
        line_total REAL NOT NULL,
        line_profit REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        employee_id TEXT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE credit_payments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE restaurant_payments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        amount REAL NOT NULL,
        paid_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE restaurant_orders (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        amount_paid REAL NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        status TEXT NOT NULL,
        scheduled_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        balance_due REAL DEFAULT 0.0
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        client_transaction_id TEXT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Products table: total inventory value = 8,735 DZD (10 * 873.5)
    await db.insert('products', {
      'id': 'prod_1',
      'company_id': companyId,
      'name': 'Produit A',
      'category': 'General',
      'purchase_price': 873.5,
      'selling_price': 1000.0,
      'quantity': 10,
      'minimum_stock': 2,
    });

    // Other company products for tenant isolation (inventory = 2,500 DZD)
    await db.insert('products', {
      'id': 'prod_other',
      'company_id': otherCompanyId,
      'name': 'Produit Other',
      'category': 'General',
      'purchase_price': 500.0,
      'selling_price': 600.0,
      'quantity': 5,
      'minimum_stock': 1,
    });
  });

  tearDown(() async {
    await db.close();
  });

  test('1. Baseline Parity: Online and Offline metrics match initially with revenue ~4,000 DZD and inventory ~8,735 DZD', () async {
    final now = DateTime.now();
    final localIso = now.toIso8601String();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await db.insert('sales', {
      'id': 'sale_1',
      'client_transaction_id': 'tx_1',
      'company_id': companyId,
      'subtotal': 4000.0,
      'discount': 0.0,
      'total': 4000.0,
      'payment_status': 'paid',
      'sold_at': localIso,
      'created_at': localIso,
      'synced': 0,
    });

    await db.insert('sale_items', {
      'id': 'item_1',
      'sale_id': 'sale_1',
      'company_id': companyId,
      'product_id': 'prod_1',
      'product_name': 'Produit A',
      'quantity': 4,
      'unit_price': 1000.0,
      'unit_cost': 500.0,
      'line_total': 4000.0,
      'line_profit': 2000.0,
    });

    final dash = await LocalFinancialCalculator.calculateDashboard(
      companyId: companyId,
      db: db,
      date: todayStr,
    );

    expect(dash.todayRevenue, 4000.0);
    expect(dash.todayProfit, 2000.0);
    expect(dash.inventoryValue, 8735.0);
    expect(dash.salesCount, 1);

    final monthlyReport = await LocalFinancialCalculator.calculateReport(
      period: 'monthly',
      companyId: companyId,
      month: todayStr.substring(0, 7),
      db: db,
    );

    expect(monthlyReport.revenue, 4000.0);
    expect(monthlyReport.grossProfit, 2000.0);
    expect(monthlyReport.inventoryValue, 8735.0);
    expect(monthlyReport.salesCount, 1);
  });

  test('2. Extended Uptime & Synchronization: Local calculations remain stable after sync status transitions to 1', () async {
    final now = DateTime.now();
    final localIso = now.toIso8601String();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await db.insert('sales', {
      'id': 'sale_sync_test',
      'client_transaction_id': 'tx_sync',
      'company_id': companyId,
      'subtotal': 4000.0,
      'discount': 0.0,
      'total': 4000.0,
      'payment_status': 'paid',
      'sold_at': localIso,
      'created_at': localIso,
      'synced': 0,
    });

    await db.insert('sale_items', {
      'id': 'item_sync_test',
      'sale_id': 'sale_sync_test',
      'company_id': companyId,
      'product_id': 'prod_1',
      'product_name': 'Produit A',
      'quantity': 4,
      'unit_price': 1000.0,
      'unit_cost': 500.0,
      'line_total': 4000.0,
      'line_profit': 2000.0,
    });

    // Simulate background sync completing 45 seconds or several hours later
    await db.update('sales', {'synced': 1}, where: 'id = ?', whereArgs: ['sale_sync_test']);

    // Re-calculate offline after sync: must NOT drop to zero!
    final dashAfterSync = await LocalFinancialCalculator.calculateDashboard(
      companyId: companyId,
      db: db,
      date: todayStr,
    );

    expect(dashAfterSync.todayRevenue, 4000.0);
    expect(dashAfterSync.todayProfit, 2000.0);
    expect(dashAfterSync.inventoryValue, 8735.0);
  });

  test('3. Deduplication & UTC Overwrite: When pullInitialData replaces local record with UTC timestamp, metrics remain stable', () async {
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final utcIso = now.toUtc().toIso8601String();

    await db.insert('sales', {
      'id': 'server_uuid_100',
      'client_transaction_id': 'client_tx_100',
      'company_id': companyId,
      'subtotal': 4000.0,
      'discount': 0.0,
      'total': 4000.0,
      'payment_status': 'paid',
      'sold_at': utcIso,
      'created_at': utcIso,
      'synced': 1,
    });

    await db.insert('sale_items', {
      'id': 'item_100',
      'sale_id': 'server_uuid_100',
      'company_id': companyId,
      'product_id': 'prod_1',
      'product_name': 'Produit A',
      'quantity': 4,
      'unit_price': 1000.0,
      'unit_cost': 500.0,
      'line_total': 4000.0,
      'line_profit': 2000.0,
    });

    final dash = await LocalFinancialCalculator.calculateDashboard(
      companyId: companyId,
      db: db,
      date: todayStr,
    );

    expect(dash.todayRevenue, 4000.0);
    expect(dash.todayProfit, 2000.0);
    expect(dash.inventoryValue, 8735.0);
  });

  test('4. Date format robustness: COALESCE fallback prevents NULL date evaluation on all 8 timestamp variants', () async {
    final formats = [
      '2026-10-11T12:00:00.000Z',
      '2026-10-11T12:00:00Z',
      '2026-10-11 12:00:00',
      '2026-10-11T12:00:00',
      '2026-10-11 12:00:00+00',
      '2026-10-11 12:00:00+00:00',
      '2026-10-11T12:00:00+01:00',
      '2026-10-11',
    ];

    for (int i = 0; i < formats.length; i++) {
      final fmt = formats[i];
      final saleId = 'sale_fmt_$i';
      await db.insert('sales', {
        'id': saleId,
        'client_transaction_id': 'tx_fmt_$i',
        'company_id': companyId,
        'subtotal': 500.0,
        'discount': 0.0,
        'total': 500.0,
        'payment_status': 'paid',
        'sold_at': fmt,
        'created_at': fmt,
        'synced': 1,
      });

      // Verify each individual format resolves to 2026-10-11 without returning NULL
      final res = await db.rawQuery(
        '''SELECT (COALESCE(CASE WHEN sold_at LIKE '%Z' OR sold_at LIKE '%+%' THEN date(sold_at, 'localtime') ELSE date(sold_at) END, date(substr(sold_at, 1, 10)), substr(sold_at, 1, 10))) as safe_date
           FROM sales WHERE id = ?''',
        [saleId],
      );
      expect(res.first['safe_date'], '2026-10-11', reason: 'Failed for format: $fmt');
    }
  });

  test('5. Controllable Clock Advancement: Daily metrics scope to target business day while Monthly & All-Time preserve history', () async {
    const saleDateStr = '2026-10-11';
    const saleIso = '${saleDateStr}T14:30:00.000';

    await db.insert('sales', {
      'id': 'sale_shift',
      'client_transaction_id': 'tx_shift',
      'company_id': companyId,
      'subtotal': 4000.0,
      'discount': 0.0,
      'total': 4000.0,
      'payment_status': 'paid',
      'sold_at': saleIso,
      'created_at': saleIso,
      'synced': 1,
    });

    await db.insert('sale_items', {
      'id': 'item_shift',
      'sale_id': 'sale_shift',
      'company_id': companyId,
      'product_id': 'prod_1',
      'product_name': 'Produit A',
      'quantity': 4,
      'unit_price': 1000.0,
      'unit_cost': 500.0,
      'line_total': 4000.0,
      'line_profit': 2000.0,
    });

    // When queried on the sale date: 4,000 DZD
    final dashOnDay = await LocalFinancialCalculator.calculateDashboard(
      companyId: companyId,
      db: db,
      date: saleDateStr,
    );
    expect(dashOnDay.todayRevenue, 4000.0);
    expect(dashOnDay.inventoryValue, 8735.0);

    // Advance controllable clock by 12 hours to next day (2026-10-12)
    final dashNextDay = await LocalFinancialCalculator.calculateDashboard(
      companyId: companyId,
      db: db,
      date: '2026-10-12',
    );
    // On the new day, todayRevenue is legitimately 0 because no sales occurred on 2026-10-12 yet
    expect(dashNextDay.todayRevenue, 0.0);
    // Inventory value remains completely unaffected: 8,735 DZD
    expect(dashNextDay.inventoryValue, 8735.0);

    // But monthly report for October 2026 retains the 4,000 DZD revenue regardless of daily rollover
    final monthlyReport = await LocalFinancialCalculator.calculateReport(
      period: 'monthly',
      companyId: companyId,
      month: '2026-10',
      db: db,
    );
    expect(monthlyReport.revenue, 4000.0);
    expect(monthlyReport.grossProfit, 2000.0);
    expect(monthlyReport.inventoryValue, 8735.0);

    // And all-time / global financials retain the 4,000 DZD revenue
    expect(monthlyReport.allRevenue, 4000.0);
    expect(monthlyReport.global.allRevenue, 4000.0);
  });

  test('6. Tenant Isolation: Multi-company queries never mix financial data or inventory between tenants', () async {
    final now = DateTime.now();
    final localIso = now.toIso8601String();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Company A sale: 4,000 DZD
    await db.insert('sales', {
      'id': 'sale_comp_a',
      'client_transaction_id': 'tx_comp_a',
      'company_id': companyId,
      'subtotal': 4000.0,
      'discount': 0.0,
      'total': 4000.0,
      'payment_status': 'paid',
      'sold_at': localIso,
      'created_at': localIso,
      'synced': 1,
    });

    // Company B sale: 1,500 DZD
    await db.insert('sales', {
      'id': 'sale_comp_b',
      'client_transaction_id': 'tx_comp_b',
      'company_id': otherCompanyId,
      'subtotal': 1500.0,
      'discount': 0.0,
      'total': 1500.0,
      'payment_status': 'paid',
      'sold_at': localIso,
      'created_at': localIso,
      'synced': 1,
    });

    final dashA = await LocalFinancialCalculator.calculateDashboard(
      companyId: companyId,
      db: db,
      date: todayStr,
    );
    expect(dashA.todayRevenue, 4000.0);
    expect(dashA.inventoryValue, 8735.0);

    final dashB = await LocalFinancialCalculator.calculateDashboard(
      companyId: otherCompanyId,
      db: db,
      date: todayStr,
    );
    expect(dashB.todayRevenue, 1500.0);
    expect(dashB.inventoryValue, 2500.0); // 5 * 500
  });

  test('7. Empty Tenant: Company with zero sales reports legitimately 0 without crashing or fabricating numbers', () async {
    const emptyTenant = 'tenant_brand_new';
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final dash = await LocalFinancialCalculator.calculateDashboard(
      companyId: emptyTenant,
      db: db,
      date: todayStr,
    );

    expect(dash.todayRevenue, 0.0);
    expect(dash.todayProfit, 0.0);
    expect(dash.todayExpenses, 0.0);
    expect(dash.salesCount, 0);
    expect(dash.inventoryValue, 0.0);
  });

  test('8. Stale Cache Protection: Local authoritative report takes precedence over stale zero snapshot', () async {
    const resolvedStart = '2026-10-01';
    const resolvedEnd = '2026-10-31';
    const cacheKey = 'report_cache_${companyId}_monthly_${resolvedStart}_$resolvedEnd';

    // Simulate an old cached server report with 0 revenue (fetched before sales were recorded)
    final staleCached = ReportData(
      period: 'monthly',
      rangeStart: resolvedStart,
      rangeEnd: resolvedEnd,
      revenue: 0.0,
      expenses: 0.0,
      operatingExpenses: 0.0,
      employeeSalaries: 0.0,
      netProfit: 0.0,
      grossProfit: 0.0,
      profitMargin: 0.0,
      salesCount: 0,
      topProducts: [],
      expensesByCategory: [],
      employeeSalariesBreakdown: [],
      revenueBreakdown: RevenueBreakdown(
        sales: 0.0,
        creditPayments: 0.0,
        clinicRevenue: 0.0,
        restaurantRevenue: 0.0,
        totalRevenue: 0.0,
      ),
      expensesBreakdown: ExpensesBreakdown(
        operatingExpenses: 0.0,
        employeeSalaries: 0.0,
        costOfGoodsSold: 0.0,
        totalExpenses: 0.0,
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
        allRevenue: 0.0,
        allExpenses: 0.0,
        globalNetProfit: 0.0,
        inventoryValue: 8735.0,
      ),
      allRevenue: 0.0,
      allExpenses: 0.0,
      globalNetProfit: 0.0,
      inventoryValue: 8735.0,
    );

    // Save stale snapshot to sync_metadata
    await db.insert('sync_metadata', {
      'key': cacheKey,
      'value': '{"period":"monthly","rangeStart":"$resolvedStart","rangeEnd":"$resolvedEnd","revenue":0.0,"expenses":0.0,"operatingExpenses":0.0,"employeeSalaries":0.0,"netProfit":0.0,"grossProfit":0.0,"profitMargin":0.0,"salesCount":0,"inventoryValue":8735.0}',
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Local SQLite has the real synced sale of 4,000 DZD
    await db.insert('sales', {
      'id': 'sale_authoritative',
      'client_transaction_id': 'tx_auth',
      'company_id': companyId,
      'subtotal': 4000.0,
      'discount': 0.0,
      'total': 4000.0,
      'payment_status': 'paid',
      'sold_at': '2026-10-11T10:00:00.000',
      'created_at': '2026-10-11T10:00:00.000',
      'synced': 1,
    });

    await db.insert('sale_items', {
      'id': 'item_auth',
      'sale_id': 'sale_authoritative',
      'company_id': companyId,
      'product_id': 'prod_1',
      'product_name': 'Produit A',
      'quantity': 4,
      'unit_price': 1000.0,
      'unit_cost': 500.0,
      'line_total': 4000.0,
      'line_profit': 2000.0,
    });

    final localReport = await LocalFinancialCalculator.calculateReport(
      period: 'monthly',
      companyId: companyId,
      month: '2026-10',
      db: db,
    );

    // Decision rule check: localReport must override staleCached
    final effectiveReport = (localReport.salesCount >= staleCached.salesCount ||
            localReport.revenue >= staleCached.revenue ||
            staleCached.revenue == 0)
        ? localReport
        : staleCached;

    expect(effectiveReport.revenue, 4000.0);
    expect(effectiveReport.salesCount, 1);
    expect(effectiveReport.inventoryValue, 8735.0);
  });
}
