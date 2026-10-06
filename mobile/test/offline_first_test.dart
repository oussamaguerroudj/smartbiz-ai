import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/database/local_financial_calculator.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  const uuid = Uuid();

  setUp(() async {
    // Open an in-memory database using the exact schema from AppDatabase
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // 1. Products
          await db.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              company_id TEXT,
              name TEXT NOT NULL,
              category TEXT,
              barcode TEXT,
              purchase_price REAL NOT NULL DEFAULT 0,
              selling_price REAL NOT NULL DEFAULT 0,
              quantity INTEGER NOT NULL DEFAULT 0,
              minimum_stock INTEGER NOT NULL DEFAULT 5,
              expiration_date TEXT,
              size TEXT,
              color TEXT,
              brand TEXT,
              image_url TEXT,
              updated_at TEXT
            )
          ''');
          await db.execute('CREATE INDEX ix_products_barcode ON products (barcode)');

          // 2. Sales
          await db.execute('''
            CREATE TABLE sales (
              id TEXT PRIMARY KEY,
              client_transaction_id TEXT UNIQUE,
              company_id TEXT,
              customer_id TEXT,
              customer_name TEXT,
              employee_id TEXT,
              subtotal REAL NOT NULL DEFAULT 0,
              discount REAL NOT NULL DEFAULT 0,
              total REAL NOT NULL DEFAULT 0,
              payment_status TEXT NOT NULL DEFAULT 'paid',
              sold_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('CREATE INDEX ix_sales_sold_at ON sales (sold_at)');
          await db.execute('CREATE INDEX ix_sales_client_tx ON sales (client_transaction_id)');

          // 3. Sale Items
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
              line_profit REAL NOT NULL,
              FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
            )
          ''');

          // 4. Invoices
          await db.execute('''
            CREATE TABLE invoices (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL UNIQUE,
              company_id TEXT,
              invoice_number TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'paid',
              customer_name TEXT,
              total REAL NOT NULL DEFAULT 0,
              sold_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
            )
          ''');

          // 5. Expenses
          await db.execute('''
            CREATE TABLE expenses (
              id TEXT PRIMARY KEY,
              client_id TEXT UNIQUE,
              company_id TEXT,
              category TEXT NOT NULL,
              description TEXT,
              amount REAL NOT NULL DEFAULT 0,
              expense_date TEXT NOT NULL,
              period_type TEXT DEFAULT 'one_time',
              employee_id TEXT,
              salary_period TEXT,
              duration TEXT,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          // 6. Customers
          await db.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              client_id TEXT UNIQUE,
              company_id TEXT,
              name TEXT NOT NULL,
              phone TEXT,
              address TEXT,
              balance_due REAL NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          // 7. Sync Queue
          await db.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              entity_type TEXT NOT NULL,
              action TEXT NOT NULL,
              client_id TEXT UNIQUE NOT NULL,
              endpoint TEXT NOT NULL,
              method TEXT NOT NULL DEFAULT 'POST',
              payload TEXT NOT NULL,
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              status TEXT NOT NULL DEFAULT 'pending',
              created_at TEXT NOT NULL,
              synced_at TEXT
            )
          ''');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Offline-First Database Operations', () {
    test('Products caching, indexed barcode lookup, and stock decrement', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('products', {
        'id': 'prod-101',
        'name': 'Milk 1L',
        'barcode': '6191234567890',
        'selling_price': 150.0,
        'purchase_price': 120.0,
        'quantity': 25,
        'category': 'Dairy',
        'updated_at': now,
      });

      // Search by barcode
      final results = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: ['6191234567890'],
      );
      expect(results.length, 1);
      expect(results.first['name'], 'Milk 1L');
      expect(results.first['quantity'], 25);

      // Decrement stock in an atomic transaction
      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [5, 'prod-101'],
        );
      });

      final updated = await db.query('products', where: 'id = ?', whereArgs: ['prod-101']);
      expect(updated.first['quantity'], 20);
    });

    test('Offline sale transaction guarantees atomic creation and queueing', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('products', {
        'id': 'p1',
        'name': 'Soda Can',
        'barcode': '123456',
        'selling_price': 50.0,
        'purchase_price': 30.0,
        'quantity': 10,
        'updated_at': now,
      });

      final clientTxId = uuid.v4();
      final saleId = 'sale-$clientTxId';
      final invoiceId = 'inv-$clientTxId';
      const qtySold = 3;

      // Perform atomic sale
      await db.transaction((txn) async {
        // 1. Decrement stock
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [qtySold, 'p1'],
        );

        // 2. Insert sale
        await txn.insert('sales', {
          'id': saleId,
          'client_transaction_id': clientTxId,
          'total': 150.0,
          'subtotal': 150.0,
          'sold_at': now,
          'created_at': now,
          'synced': 0,
        });

        // 3. Insert sale item
        await txn.insert('sale_items', {
          'id': 'item-1',
          'sale_id': saleId,
          'product_id': 'p1',
          'product_name': 'Soda Can',
          'quantity': qtySold,
          'unit_price': 50.0,
          'unit_cost': 30.0,
          'line_total': 150.0,
          'line_profit': 60.0, // (50 - 30) * 3
        });

        // 4. Insert invoice
        await txn.insert('invoices', {
          'id': invoiceId,
          'sale_id': saleId,
          'invoice_number': 'INV-TEST-001',
          'total': 150.0,
          'sold_at': now,
          'created_at': now,
        });

        // 5. Enqueue sync
        await txn.insert('sync_queue', {
          'entity_type': 'sale',
          'action': 'create',
          'client_id': clientTxId,
          'endpoint': '/sales',
          'method': 'POST',
          'payload': '{"sale_id": "$saleId"}',
          'status': 'pending',
          'created_at': now,
        });
      });

      // Verify stock was reduced
      final prod = await db.query('products', where: 'id = ?', whereArgs: ['p1']);
      expect(prod.first['quantity'], 7);

      // Verify invoice exists offline immediately
      final inv = await db.query('invoices', where: 'sale_id = ?', whereArgs: [saleId]);
      expect(inv.length, 1);
      expect(inv.first['invoice_number'], 'INV-TEST-001');

      // Verify sync queue has pending item
      final queue = await db.query('sync_queue', where: 'client_id = ?', whereArgs: [clientTxId]);
      expect(queue.length, 1);
      expect(queue.first['status'], 'pending');
    });

    test('Offline customer creation and idempotency constraint', () async {
      final now = DateTime.now().toIso8601String();
      final clientId = uuid.v4();

      await db.insert('customers', {
        'id': 'cust-$clientId',
        'client_id': clientId,
        'name': 'Ahmed Benali',
        'phone': '0555123456',
        'created_at': now,
        'synced': 0,
      });

      final custs = await db.query('customers', where: 'client_id = ?', whereArgs: [clientId]);
      expect(custs.length, 1);
      expect(custs.first['name'], 'Ahmed Benali');

      // Attempting to insert duplicate client_id triggers DatabaseException
      expect(
        () async => await db.insert('customers', {
          'id': 'another-id',
          'client_id': clientId,
          'name': 'Duplicate',
          'created_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('LocalFinancialCalculator Tests (Matching Backend Math)', () {
    test('Daily revenue, cost, expenses, and net profit calculations', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String();
      final dateOnly = todayStr.substring(0, 10);

      // Product 1: unit_price 100, unit_cost 60 -> profit margin = 40 per unit
      // Sale 1: qty = 2 -> subtotal 200, cost 120 -> line_profit = 80
      const sale1Id = 's1';
      await db.insert('sales', {
        'id': sale1Id,
        'client_transaction_id': 'tx-1',
        'company_id': 'test-company',
        'total': 200.0,
        'subtotal': 200.0,
        'sold_at': todayStr,
        'created_at': todayStr,
      });
      await db.insert('sale_items', {
        'id': 'si-1',
        'sale_id': sale1Id,
        'product_id': 'p1',
        'product_name': 'Item A',
        'quantity': 2,
        'unit_price': 100.0,
        'unit_cost': 60.0,
        'line_total': 200.0,
        'line_profit': 80.0,
      });

      // Product 2: unit_price 50, unit_cost 30 -> profit margin = 20 per unit
      // Sale 2: qty = 1 -> subtotal 50, cost 30 -> line_profit = 20
      const sale2Id = 's2';
      await db.insert('sales', {
        'id': sale2Id,
        'client_transaction_id': 'tx-2',
        'company_id': 'test-company',
        'total': 50.0,
        'subtotal': 50.0,
        'sold_at': todayStr,
        'created_at': todayStr,
      });
      await db.insert('sale_items', {
        'id': 'si-2',
        'sale_id': sale2Id,
        'product_id': 'p2',
        'product_name': 'Item B',
        'quantity': 1,
        'unit_price': 50.0,
        'unit_cost': 30.0,
        'line_total': 50.0,
        'line_profit': 20.0,
      });

      // Invoices
      await db.insert('invoices', {
        'id': 'inv-1',
        'sale_id': sale1Id,
        'invoice_number': 'INV-001',
        'total': 200.0,
        'sold_at': todayStr,
        'created_at': todayStr,
      });
      await db.insert('invoices', {
        'id': 'inv-2',
        'sale_id': sale2Id,
        'invoice_number': 'INV-002',
        'total': 50.0,
        'sold_at': todayStr,
        'created_at': todayStr,
      });

      // Operating expenses today = 30 (Electricity) + 15 (Water) = 45
      await db.insert('expenses', {
        'id': 'exp-1',
        'client_id': 'cl-exp-1',
        'company_id': 'test-company',
        'category': 'Utilities',
        'description': 'Electricity',
        'amount': 30.0,
        'expense_date': dateOnly,
        'created_at': todayStr,
      });
      await db.insert('expenses', {
        'id': 'exp-2',
        'client_id': 'cl-exp-2',
        'company_id': 'test-company',
        'category': 'Utilities',
        'description': 'Water',
        'amount': 15.0,
        'expense_date': dateOnly,
        'created_at': todayStr,
      });

      // Product catalog for inventory valuation
      await db.insert('products', {
        'id': 'p1',
        'company_id': 'test-company',
        'name': 'Item A',
        'selling_price': 100.0,
        'purchase_price': 60.0,
        'quantity': 10,
        'updated_at': todayStr,
      });
      await db.insert('products', {
        'id': 'p2',
        'company_id': 'test-company',
        'name': 'Item B',
        'selling_price': 50.0,
        'purchase_price': 30.0,
        'quantity': 5,
        'updated_at': todayStr,
      });

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: 'test-company',
        date: dateOnly,
        db: db,
      );

      // Revenue = gross profit from sales = 80 + 20 = 100
      expect(report.revenue, 100.0);

      // expenses = operating (45) + salary (0) = 45
      expect(report.expenses, 45.0);

      // netProfit = totalRevenue - totalExpenses = 100 - 45 = 55
      expect(report.netProfit, 55.0);

      // inventoryValue = SUM(quantity * (selling_price - purchase_price)) = 10*(100-60) + 5*(50-30) = 400 + 100 = 500
      expect(report.inventoryValue, 500.0);

      // Top products verification
      expect(report.topProducts.length, 2);
      expect(report.topProducts.first.name, 'Item A');
      expect(report.topProducts.first.unitsSold, 2);

      // Expenses by category
      expect(report.expensesByCategory.length, 1);
      expect(report.expensesByCategory.first.category, 'Utilities');
      expect(report.expensesByCategory.first.amount, 45.0);

      // Activity summary
      expect(report.activitySummary.salesCount, 2);
      expect(report.activitySummary.expensesCount, 2);
      expect(report.activitySummary.invoicesCount, 2);
    });

    test('Monthly aggregation and net loss scenario', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String();
      final dateOnly = todayStr.substring(0, 10);
      final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Expense exceeding revenue
      await db.insert('expenses', {
        'id': 'exp-big',
        'client_id': 'cl-exp-big',
        'company_id': 'test-company',
        'category': 'Rent',
        'description': 'Shop Rent',
        'amount': 5000.0,
        'expense_date': dateOnly,
        'created_at': todayStr,
      });

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'monthly',
        companyId: 'test-company',
        month: monthStr,
        db: db,
      );

      expect(report.revenue, 0.0);
      expect(report.expenses, 5000.0);
      expect(report.netProfit, -5000.0); // Clean negative net loss
    });
  });

  group('Sync Queue Processing Logic', () {
    test('Sync queue marks items synced or increments retry on failure', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('sync_queue', {
        'entity_type': 'sale',
        'action': 'create',
        'client_id': 'tx-fail-test',
        'endpoint': '/sales',
        'method': 'POST',
        'payload': '{"sale_id": "test"}',
        'status': 'pending',
        'retry_count': 0,
        'created_at': now,
      });

      // Simulate failure increment
      await db.rawUpdate('''
        UPDATE sync_queue
        SET retry_count = retry_count + 1,
            last_error = ?,
            status = CASE WHEN retry_count + 1 >= 5 THEN 'failed' ELSE 'pending' END
        WHERE client_id = ?
      ''', ['Connection timeout', 'tx-fail-test']);

      var item = await db.query('sync_queue', where: 'client_id = ?', whereArgs: ['tx-fail-test']);
      expect(item.first['retry_count'], 1);
      expect(item.first['status'], 'pending');

      // Simulate success mark
      await db.update(
        'sync_queue',
        {
          'status': 'synced',
          'synced_at': DateTime.now().toIso8601String(),
        },
        where: 'client_id = ?',
        whereArgs: ['tx-fail-test'],
      );

      item = await db.query('sync_queue', where: 'client_id = ?', whereArgs: ['tx-fail-test']);
      expect(item.first['status'], 'synced');
    });
  });
}
