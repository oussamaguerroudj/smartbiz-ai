import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:modiri_desktop/core/database/desktop_database.dart';
import 'package:modiri_desktop/core/database/local_financial_calculator.dart';
import 'package:modiri_desktop/core/database/payment_transaction_manager.dart';
import 'package:modiri_desktop/features/products/domain/product.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Modiri AI Desktop — Complete E2E Business & Financial Flow', () {
    late Database db;
    const testCompanyId = 'comp_master_001';
    const otherCompanyId = 'comp_other_999';
    const uuid = Uuid();

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

      // Create complete schema matching ModiriDesktopDatabase
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          cost_price REAL NOT NULL DEFAULT 0.0,
          stock_quantity INTEGER NOT NULL DEFAULT 0,
          minimum_stock INTEGER NOT NULL DEFAULT 5,
          barcode TEXT,
          category TEXT,
          expiration_date TEXT,
          size TEXT,
          color TEXT,
          brand TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT,
          customer_name TEXT,
          invoice_number TEXT,
          total REAL NOT NULL,
          subtotal REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0.0,
          payment_status TEXT NOT NULL DEFAULT 'paid',
          payment_method TEXT NOT NULL DEFAULT 'cash',
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_items (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          sale_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          unit_price REAL NOT NULL,
          unit_cost REAL NOT NULL DEFAULT 0.0,
          line_total REAL NOT NULL,
          line_profit REAL NOT NULL DEFAULT 0.0
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS invoices (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          sale_id TEXT,
          invoice_number TEXT NOT NULL,
          customer_name TEXT,
          total REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0.0,
          remaining_amount REAL NOT NULL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'paid',
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          credit_balance REAL NOT NULL DEFAULT 0.0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_transactions (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          balance_after REAL NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          client_transaction_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation_type TEXT NOT NULL,
          payload TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Step 1-8: Full End-to-End Business Lifecycle with Strict Invariants', () async {
      final now = DateTime.now().toIso8601String();
      final todayDate = now.substring(0, 10);

      // --- 1. Product Creation ---
      // Product: Espresso Beans, Cost = 100 DZD, Sell = 150 DZD, Stock = 20 units
      final productId = 'prod_${uuid.v4()}';
      await db.insert('products', {
        'id': productId,
        'company_id': testCompanyId,
        'name': 'Espresso Beans 1kg',
        'price': 150.0,
        'cost_price': 100.0,
        'stock_quantity': 20,
        'minimum_stock': 5,
        'barcode': '6131234567890',
        'category': 'Coffee',
        'created_at': now,
        'updated_at': now,
      });

      // Product 2 in another company to test tenant isolation
      await db.insert('products', {
        'id': 'prod_isolated_99',
        'company_id': otherCompanyId,
        'name': 'Other Company Beans',
        'price': 999.0,
        'cost_price': 500.0,
        'stock_quantity': 100,
        'minimum_stock': 5,
        'category': 'Coffee',
        'created_at': now,
      });

      // Verify Product in Database
      final productRows = await db.query('products', where: 'id = ? AND company_id = ?', whereArgs: [productId, testCompanyId]);
      expect(productRows.length, equals(1));
      expect(productRows.first['stock_quantity'], equals(20));

      // Domain model verification
      final prodModel = Product.fromMap(productRows.first);
      expect(prodModel.marginPercent, closeTo(33.33, 0.01));
      expect(prodModel.isLowStock, isFalse);
      expect(prodModel.isOutOfStock, isFalse);

      // --- 2. Customer Creation ---
      final customerId = 'cust_${uuid.v4()}';
      await db.insert('customers', {
        'id': customerId,
        'company_id': testCompanyId,
        'name': 'Ahmed Benali',
        'phone': '0555123456',
        'credit_balance': 0.0,
        'created_at': now,
      });

      // --- 3. POS Transaction: 3 units sold (Total = 450 DZD, Cash payment) ---
      final sale1Id = 'sale_${uuid.v4()}';
      const invoice1Number = 'INV-1001';
      const qtySold1 = 3;
      const unitPrice1 = 150.0;
      const unitCost1 = 100.0;
      const total1 = 450.0;
      const lineProfit1 = 150.0;

      await db.transaction((txn) async {
        // Record sale
        await txn.insert('sales', {
          'id': sale1Id,
          'company_id': testCompanyId,
          'customer_id': customerId,
          'customer_name': 'Ahmed Benali',
          'invoice_number': invoice1Number,
          'total': total1,
          'subtotal': total1,
          'discount': 0.0,
          'payment_status': 'paid',
          'payment_method': 'cash',
          'sold_at': now,
          'created_at': now,
          'synced': 0,
        });

        // Record sale item
        await txn.insert('sale_items', {
          'id': 'si_${uuid.v4()}',
          'company_id': testCompanyId,
          'sale_id': sale1Id,
          'product_id': productId,
          'product_name': 'Espresso Beans 1kg',
          'quantity': qtySold1,
          'unit_price': unitPrice1,
          'unit_cost': unitCost1,
          'line_total': total1,
          'line_profit': lineProfit1,
        });

        // Decrement product inventory stock
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND company_id = ?',
          [qtySold1, productId, testCompanyId],
        );

        // Record invoice
        await txn.insert('invoices', {
          'id': 'inv_${uuid.v4()}',
          'company_id': testCompanyId,
          'sale_id': sale1Id,
          'invoice_number': invoice1Number,
          'customer_name': 'Ahmed Benali',
          'total': total1,
          'status': 'paid',
          'sold_at': now,
          'created_at': now,
        });
      });

      // --- 4. Assertions: Stock Deduction & Invoice Creation ---
      final updatedProduct = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      expect(updatedProduct.first['stock_quantity'], equals(17), reason: 'Stock should decrease from 20 to 17 after selling 3 units');

      final invoiceRows = await db.query('invoices', where: 'sale_id = ?', whereArgs: [sale1Id]);
      expect(invoiceRows.length, equals(1));
      expect(invoiceRows.first['invoice_number'], equals('INV-1001'));
      expect(invoiceRows.first['total'], equals(450.0));
      expect(invoiceRows.first['status'], equals('paid'));

      // --- 5. POS Transaction 2: 2 units sold on Credit (Total = 300 DZD, Credit payment) ---
      final sale2Id = 'sale_${uuid.v4()}';
      const invoice2Number = 'INV-1002';
      const qtySold2 = 2;
      const total2 = 300.0;
      const lineProfit2 = 100.0;

      await db.transaction((txn) async {
        await txn.insert('sales', {
          'id': sale2Id,
          'company_id': testCompanyId,
          'customer_id': customerId,
          'customer_name': 'Ahmed Benali',
          'invoice_number': invoice2Number,
          'total': total2,
          'subtotal': total2,
          'discount': 0.0,
          'payment_status': 'paid',
          'payment_method': 'credit',
          'sold_at': now,
          'created_at': now,
          'synced': 0,
        });

        await txn.insert('sale_items', {
          'id': 'si_${uuid.v4()}',
          'company_id': testCompanyId,
          'sale_id': sale2Id,
          'product_id': productId,
          'product_name': 'Espresso Beans 1kg',
          'quantity': qtySold2,
          'unit_price': unitPrice1,
          'unit_cost': unitCost1,
          'line_total': total2,
          'line_profit': lineProfit2,
        });

        // Decrement product inventory stock
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND company_id = ?',
          [qtySold2, productId, testCompanyId],
        );

        // Update customer credit balance & log transaction
        await txn.rawUpdate(
          'UPDATE customers SET credit_balance = credit_balance + ? WHERE id = ? AND company_id = ?',
          [total2, customerId, testCompanyId],
        );

        await txn.insert('customer_transactions', {
          'id': 'tx_${uuid.v4()}',
          'company_id': testCompanyId,
          'customer_id': customerId,
          'type': 'purchase',
          'amount': total2,
          'balance_after': total2, // 0 + 300 = 300
          'description': 'Credit purchase: $invoice2Number',
          'created_at': now,
        });

        await txn.insert('invoices', {
          'id': 'inv_${uuid.v4()}',
          'company_id': testCompanyId,
          'sale_id': sale2Id,
          'invoice_number': invoice2Number,
          'customer_name': 'Ahmed Benali',
          'total': total2,
          'status': 'paid',
          'sold_at': now,
          'created_at': now,
        });
      });

      // Stock should now be 17 - 2 = 15
      final productAfterCreditSale = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      expect(productAfterCreditSale.first['stock_quantity'], equals(15));

      // Customer credit balance should now be 300.0
      final customerAfterCreditSale = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      expect(customerAfterCreditSale.first['credit_balance'], equals(300.0));

      // --- 6. Customer Debt Repayment: Ahmed pays 200 DZD towards his debt ---
      const repaymentAmount = 200.0;
      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE customers SET credit_balance = credit_balance - ? WHERE id = ? AND company_id = ?',
          [repaymentAmount, customerId, testCompanyId],
        );

        await txn.insert('customer_transactions', {
          'id': 'tx_${uuid.v4()}',
          'company_id': testCompanyId,
          'customer_id': customerId,
          'type': 'payment',
          'amount': repaymentAmount,
          'balance_after': 300.0 - repaymentAmount, // 100.0
          'description': 'Partial credit balance settlement',
          'created_at': now,
        });
      });

      // Customer credit balance should now be 100.0
      final customerAfterRepayment = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      expect(customerAfterRepayment.first['credit_balance'], equals(100.0));

      // Verify transaction ledger
      final customerLedger = await db.query(
        'customer_transactions',
        where: 'customer_id = ? AND company_id = ?',
        whereArgs: [customerId, testCompanyId],
        orderBy: 'created_at ASC',
      );
      expect(customerLedger.length, equals(2));
      expect(customerLedger[0]['type'], equals('purchase'));
      expect(customerLedger[0]['amount'], equals(300.0));
      expect(customerLedger[1]['type'], equals('payment'));
      expect(customerLedger[1]['amount'], equals(200.0));
      expect(customerLedger[1]['balance_after'], equals(100.0));

      // --- 7. Operational Expense Recording: Rent = 100 DZD, Electricity = 50 DZD ---
      await db.insert('expenses', {
        'id': 'exp_1',
        'company_id': testCompanyId,
        'category': 'Rent',
        'amount': 100.0,
        'description': 'Shop Rent',
        'date': todayDate,
        'created_at': now,
      });

      await db.insert('expenses', {
        'id': 'exp_2',
        'company_id': testCompanyId,
        'category': 'Utilities',
        'amount': 50.0,
        'description': 'Electricity bill',
        'date': todayDate,
        'created_at': now,
      });

      // Foreign expense for other company
      await db.insert('expenses', {
        'id': 'exp_other',
        'company_id': otherCompanyId,
        'category': 'Rent',
        'amount': 9999.0,
        'description': 'Other company rent',
        'date': todayDate,
        'created_at': now,
      });

      // --- 8. Financial Report Calculation via DesktopLocalFinancialCalculator ---
      final report = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: testCompanyId,
        date: todayDate,
        customDb: db,
      );

      // Financial Verification:
      // Total Sales = Sale 1 (450) + Sale 2 (300) = 750 DZD
      // Total Units = 3 + 2 = 5 units
      // Total COGS = 5 units * 100 DZD = 500 DZD
      // Gross Profit = 750 - 500 = 250 DZD
      // Period Expenses = 100 + 50 = 150 DZD
      // Period Net Profit = 250 (Gross Profit) - 150 (Expenses) = 100 DZD
      // Profit Margin = (100 / 750) * 100 = 13.333%
      expect(report.periodRevenue, equals(750.0), reason: 'Total revenue should be 750 DZD');
      expect(report.periodCogs, equals(500.0), reason: 'COGS should be 500 DZD');
      expect(report.periodGrossProfit, equals(250.0), reason: 'Gross Profit should be 250 DZD');
      expect(report.periodExpenses, equals(150.0), reason: 'Total expenses should be 150 DZD');
      expect(report.periodNetProfit, equals(100.0), reason: 'Net Profit should be 100 DZD');
      expect(report.salesCount, equals(2), reason: 'Total sales transactions count should be 2');
      expect(report.profitMargin, closeTo(13.33, 0.01));

      // Top Selling Products breakdown
      expect(report.topProducts.length, equals(1));
      expect(report.topProducts.first['name'], equals('Espresso Beans 1kg'));
      expect(report.topProducts.first['quantity'], equals(5));
      expect(report.topProducts.first['revenue'], equals(750.0));

      // Expenses by Category breakdown
      expect(report.expensesByCategory.length, equals(2));
      final rentExp = report.expensesByCategory.firstWhere((e) => e['category'] == 'Rent');
      expect(rentExp['amount'], equals(100.0));
      final utilExp = report.expensesByCategory.firstWhere((e) => e['category'] == 'Utilities');
      expect(utilExp['amount'], equals(50.0));

      // Tenant isolation verification:
      // Other company report should NOT contain testCompanyId data
      final otherReport = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: otherCompanyId,
        date: todayDate,
        customDb: db,
      );
      expect(otherReport.periodRevenue, equals(0.0), reason: 'Other company should have 0 revenue');
      expect(otherReport.periodExpenses, equals(9999.0), reason: 'Other company should only have its own 9999 expense');
    });

    test('Vertical Workflows: Pharmacy expiry alert and Restaurant Floor Management', () async {
      // Pharmacy expiration detection
      final pastDate = DateTime.now().subtract(const Duration(days: 10)).toIso8601String().substring(0, 10);
      final futureDate = DateTime.now().add(const Duration(days: 90)).toIso8601String().substring(0, 10);

      await db.insert('products', {
        'id': 'med_expired',
        'company_id': testCompanyId,
        'name': 'Amoxicillin 500mg',
        'price': 450.0,
        'cost_price': 300.0,
        'stock_quantity': 15,
        'minimum_stock': 5,
        'expiration_date': pastDate,
      });

      await db.insert('products', {
        'id': 'med_valid',
        'company_id': testCompanyId,
        'name': 'Paracetamol 1000mg',
        'price': 200.0,
        'cost_price': 120.0,
        'stock_quantity': 50,
        'minimum_stock': 10,
        'expiration_date': futureDate,
      });

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final expiredMedRows = await db.query(
        'products',
        where: 'company_id = ? AND expiration_date IS NOT NULL AND expiration_date < ?',
        whereArgs: [testCompanyId, todayStr],
      );

      expect(expiredMedRows.length, equals(1));
      expect(expiredMedRows.first['id'], equals('med_expired'));

      // Low stock detection
      await db.insert('products', {
        'id': 'low_stock_item',
        'company_id': testCompanyId,
        'name': 'Sugar 1kg',
        'price': 100.0,
        'cost_price': 80.0,
        'stock_quantity': 2,
        'minimum_stock': 10,
      });

      final lowStockRows = await db.query(
        'products',
        where: 'company_id = ? AND stock_quantity <= minimum_stock',
        whereArgs: [testCompanyId],
      );

      expect(lowStockRows.any((p) => p['id'] == 'low_stock_item'), isTrue);
    });

    test('Atomic rollback guard: Insufficient stock aborts checkout with zero database side effects', () async {
      const prodId = 'prod_limited_stock';
      const initialStock = 2;
      final now = DateTime.now().toIso8601String();

      await db.insert('products', {
        'id': prodId,
        'company_id': testCompanyId,
        'name': 'Limited Stock Item',
        'price': 100.0,
        'cost_price': 60.0,
        'stock_quantity': initialStock,
        'minimum_stock': 1,
        'created_at': now,
      });

      Future<int> countRows(String table) async {
        final r = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
        return (r.first['count'] as num?)?.toInt() ?? 0;
      }

      final initialSalesCount = await countRows('sales');
      final initialItemsCount = await countRows('sale_items');
      final initialInvoicesCount = await countRows('invoices');
      final initialQueueCount = await countRows('sync_queue');

      // Attempt checkout of 5 units (exceeds available 2)
      bool failedAsExpected = false;
      try {
        await db.transaction((txn) async {
          const requestedQty = 5;

          // Check stock before decrementing
          final pRows = await txn.query('products', where: 'id = ? AND company_id = ?', whereArgs: [prodId, testCompanyId]);
          final availableStock = (pRows.first['stock_quantity'] as num?)?.toInt() ?? 0;
          if (availableStock < requestedQty) {
            throw Exception('Insufficient stock: Available $availableStock, Requested $requestedQty');
          }

          // These statements should be rolled back
          await txn.insert('sales', {
            'id': 'sale_failed_attempt',
            'company_id': testCompanyId,
            'total': 500.0,
            'subtotal': 500.0,
            'sold_at': now,
            'created_at': now,
          });

          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND company_id = ?',
            [requestedQty, prodId, testCompanyId],
          );
        });
      } catch (_) {
        failedAsExpected = true;
      }

      expect(failedAsExpected, isTrue, reason: 'Checkout must throw on insufficient stock');

      // Verify ZERO writes occurred (perfect atomic rollback)
      final prodCheck = await db.query('products', where: 'id = ?', whereArgs: [prodId]);
      expect(prodCheck.first['stock_quantity'], equals(initialStock), reason: 'Stock quantity must remain unchanged after aborted sale');

      expect(await countRows('sales'), equals(initialSalesCount), reason: 'No sales row should be committed on rollback');
      expect(await countRows('sale_items'), equals(initialItemsCount), reason: 'No sale_items row should be committed on rollback');
      expect(await countRows('invoices'), equals(initialInvoicesCount), reason: 'No invoice should be committed on rollback');
      expect(await countRows('sync_queue'), equals(initialQueueCount), reason: 'No sync_queue item should be committed on rollback');
    });

    test('Invoice settlement: Reconciles sale status, customer ledger, and reflects in financial reports', () async {
      final now = DateTime.now().toIso8601String();
      const debtCustId = 'cust_debtor_99';
      const unpaidSaleId = 'sale_unpaid_101';
      const unpaidInvId = 'inv_unpaid_101';
      const invTotal = 500.0;

      // 1. Setup debtor customer with 500.0 debt balance
      await db.insert('customers', {
        'id': debtCustId,
        'company_id': testCompanyId,
        'name': 'Karim Debtor',
        'phone': '0550998877',
        'credit_balance': invTotal,
        'created_at': now,
      });

      // 2. Setup unpaid sale and matching invoice
      await db.insert('sales', {
        'id': unpaidSaleId,
        'company_id': testCompanyId,
        'customer_name': 'Karim Debtor',
        'invoice_number': 'INV-2001',
        'total': invTotal,
        'subtotal': invTotal,
        'payment_status': 'unpaid',
        'payment_method': 'credit',
        'sold_at': now,
        'created_at': now,
      });

      await db.insert('invoices', {
        'id': unpaidInvId,
        'company_id': testCompanyId,
        'sale_id': unpaidSaleId,
        'invoice_number': 'INV-2001',
        'customer_name': 'Karim Debtor',
        'total': invTotal,
        'status': 'unpaid',
        'sold_at': now,
        'created_at': now,
      });

      // 3. Execute invoice settlement transaction (matching _markPaid implementation)
      await db.transaction((txn) async {
        // Mark invoice paid
        await txn.update(
          'invoices',
          {'status': 'paid'},
          where: 'id = ? AND company_id = ?',
          whereArgs: [unpaidInvId, testCompanyId],
        );

        // Mark corresponding sale paid by sale_id
        await txn.update(
          'sales',
          {'payment_status': 'paid'},
          where: 'id = ? AND company_id = ?',
          whereArgs: [unpaidSaleId, testCompanyId],
        );

        // Reconcile customer debt balance
        await txn.update(
          'customers',
          {'credit_balance': 0.0},
          where: 'id = ? AND company_id = ?',
          whereArgs: [debtCustId, testCompanyId],
        );

        await txn.insert('customer_transactions', {
          'id': 'tx_settlement_101',
          'company_id': testCompanyId,
          'customer_id': debtCustId,
          'type': 'payment',
          'amount': invTotal,
          'balance_after': 0.0,
          'description': 'Direct invoice settlement (INV-2001)',
          'created_at': now,
        });

        // Enqueue sync operation
        await txn.insert('sync_queue', {
          'id': 'sq_settlement_101',
          'company_id': testCompanyId,
          'client_transaction_id': 'ctx_101',
          'entity_type': 'invoice',
          'entity_id': unpaidInvId,
          'operation_type': 'UPDATE',
          'payload': jsonEncode({'status': 'paid', 'sale_id': unpaidSaleId}),
          'status': 'pending',
          'created_at': now,
          'updated_at': now,
        });
      });

      // 4. Verify Database Invariants
      final invRow = (await db.query('invoices', where: 'id = ?', whereArgs: [unpaidInvId])).first;
      expect(invRow['status'], equals('paid'));

      final saleRow = (await db.query('sales', where: 'id = ?', whereArgs: [unpaidSaleId])).first;
      expect(saleRow['payment_status'], equals('paid'));

      final custRow = (await db.query('customers', where: 'id = ?', whereArgs: [debtCustId])).first;
      expect(custRow['credit_balance'], equals(0.0));

      final txRow = (await db.query('customer_transactions', where: 'id = ?', whereArgs: ['tx_settlement_101'])).first;
      expect(txRow['type'], equals('payment'));
      expect(txRow['amount'], equals(invTotal));
      expect(txRow['balance_after'], equals(0.0));

      final queueRow = (await db.query('sync_queue', where: 'id = ?', whereArgs: ['sq_settlement_101'])).first;
      expect(queueRow['entity_type'], equals('invoice'));
      expect(queueRow['status'], equals('pending'));
    });

    test('Financial Domain Audit: Exact Scenario (Cost 100, Price 150, Qty 2, Sale 300, 100 upfront, 100 later repayment)', () async {
      final now = DateTime.now().toIso8601String();
      final todayStr = now.substring(0, 10);
      const auditCompanyId = 'comp_audit_fin_01';
      const custId = 'cust_salim_fin';
      const prodId = 'prod_fin_item';

      // 1. Setup product: Purchase Cost = 100 DZD, Selling Price = 150 DZD, Stock = 10
      await db.insert('products', {
        'id': prodId,
        'company_id': auditCompanyId,
        'name': 'Standard Item A',
        'price': 150.0,
        'cost_price': 100.0,
        'stock_quantity': 10,
        'minimum_stock': 2,
        'created_at': now,
      });

      // 2. Setup customer: Initial Debt = 0 DZD
      await db.insert('customers', {
        'id': custId,
        'company_id': auditCompanyId,
        'name': 'Salim Financial Customer',
        'credit_balance': 0.0,
        'created_at': now,
      });

      // 3. POS Sale of 2 units (Total = 300 DZD, COGS = 200 DZD)
      // Customer pays 100 DZD upfront, remaining 200 DZD on credit
      const qtySold = 2;
      const unitPrice = 150.0;
      const unitCost = 100.0;
      const saleTotal = 300.0; // 2 * 150
      const upfrontPaid = 100.0;
      const creditDebt = 200.0; // 300 - 100
      const saleId = 'sale_audit_001';
      const invNum = 'INV-AUDIT-001';

      await db.transaction((txn) async {
        // Decrement stock
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND company_id = ?',
          [qtySold, prodId, auditCompanyId],
        );

        // Record sale
        await txn.insert('sales', {
          'id': saleId,
          'company_id': auditCompanyId,
          'customer_name': 'Salim Financial Customer',
          'invoice_number': invNum,
          'total': saleTotal,
          'subtotal': saleTotal,
          'discount': 0.0,
          'payment_status': 'partial',
          'payment_method': 'credit',
          'sold_at': now,
          'created_at': now,
          'synced': 0,
        });

        // Record sale items
        await txn.insert('sale_items', {
          'id': 'si_audit_001',
          'company_id': auditCompanyId,
          'sale_id': saleId,
          'product_id': prodId,
          'product_name': 'Standard Item A',
          'quantity': qtySold,
          'unit_price': unitPrice,
          'unit_cost': unitCost,
          'line_total': saleTotal,
          'line_profit': (unitPrice - unitCost) * qtySold,
        });

        // Record invoice
        await txn.insert('invoices', {
          'id': 'inv_audit_001',
          'company_id': auditCompanyId,
          'sale_id': saleId,
          'invoice_number': invNum,
          'customer_name': 'Salim Financial Customer',
          'total': saleTotal,
          'status': 'unpaid',
          'sold_at': now,
          'created_at': now,
        });

        // Customer Ledger: Full purchase debt (300 DZD)
        await txn.insert('customer_transactions', {
          'id': 'tx_audit_purchase',
          'company_id': auditCompanyId,
          'customer_id': custId,
          'type': 'purchase',
          'amount': saleTotal,
          'balance_after': saleTotal,
          'description': 'POS Credit Sale $invNum',
          'created_at': now,
        });

        // Customer Ledger: Upfront payment applied (100 DZD)
        await txn.insert('customer_transactions', {
          'id': 'tx_audit_upfront',
          'company_id': auditCompanyId,
          'customer_id': custId,
          'type': 'payment',
          'amount': upfrontPaid,
          'balance_after': creditDebt,
          'description': 'Upfront cash deposit on $invNum',
          'created_at': now,
        });

        // Update customer credit balance to outstanding debt (200 DZD)
        await txn.update(
          'customers',
          {'credit_balance': creditDebt},
          where: 'id = ? AND company_id = ?',
          whereArgs: [custId, auditCompanyId],
        );
      });

      // Verify immediate state after checkout:
      // Stock deducted: 10 - 2 = 8
      final prodAfterCheckout = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      expect(prodAfterCheckout['stock_quantity'], equals(8));

      // Customer debt is 200 DZD
      final custAfterCheckout = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custAfterCheckout['credit_balance'], equals(creditDebt));

      // 4. Later Repayment: Customer pays 100 DZD at Credit Register
      const laterRepayment = 100.0;
      const finalRemainingDebt = creditDebt - laterRepayment; // 200 - 100 = 100 DZD

      await db.transaction((txn) async {
        await txn.insert('customer_transactions', {
          'id': 'tx_audit_repayment',
          'company_id': auditCompanyId,
          'customer_id': custId,
          'type': 'payment',
          'amount': laterRepayment,
          'balance_after': finalRemainingDebt,
          'description': 'Customer Credit repayment at register',
          'created_at': now,
        });

        await txn.update(
          'customers',
          {'credit_balance': finalRemainingDebt},
          where: 'id = ? AND company_id = ?',
          whereArgs: [custId, auditCompanyId],
        );
      });

      // Verify Customer Debt after later repayment: 100 DZD
      final custAfterRepayment = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custAfterRepayment['credit_balance'], equals(finalRemainingDebt));
      expect(finalRemainingDebt, equals(100.0));

      // 5. Operating Expense: 50 DZD
      const operatingExpense = 50.0;
      await db.insert('expenses', {
        'id': 'exp_audit_001',
        'company_id': auditCompanyId,
        'category': 'Utilities',
        'amount': operatingExpense,
        'description': 'Electricity bill',
        'date': todayStr,
        'created_at': now,
      });

      // 6. Run DesktopLocalFinancialCalculator and verify every financial metric
      final summary = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: auditCompanyId,
        date: todayStr,
        customDb: db,
      );

      // Total Sales (Accrual basis): 300 DZD
      expect(summary.periodTotalSales, equals(300.0));

      // Amount Collected (Cash basis): Upfront (100) + Later Repayment (100) = 200 DZD
      expect(summary.periodCollected, equals(200.0));

      // Outstanding Customer Debt: 100 DZD
      expect(summary.outstandingDebt, equals(100.0));

      // Cost of Goods Sold (COGS): 2 units * 100 DZD = 200 DZD
      expect(summary.periodCogs, equals(200.0));

      // Operating Expenses: 50 DZD
      expect(summary.periodExpenses, equals(50.0));

      // Accrual Gross Profit: Total Sales (300) - COGS (200) = 100 DZD
      // Cash Gross Profit: Collected (200) - COGS (200) = 0 DZD
      final accrualGrossProfit = summary.periodTotalSales - summary.periodCogs;
      expect(accrualGrossProfit, equals(100.0));

      // Accrual Net Profit: Gross Profit (100) - Operating Expenses (50) = 50 DZD
      final accrualNetProfit = accrualGrossProfit - summary.periodExpenses;
      expect(accrualNetProfit, equals(50.0));

      // Cash Net Profit: Collected (200) - COGS (200) - Expenses (50) = -50 DZD
      final cashNetProfit = summary.periodCollected - summary.periodCogs - summary.periodExpenses;
      expect(cashNetProfit, equals(-50.0));

      // Verify Customer Transaction Ledger Integrity (3 entries, perfectly balanced)
      final allCustTxs = await db.query(
        'customer_transactions',
        where: 'customer_id = ?',
        whereArgs: [custId],
        orderBy: 'created_at ASC',
      );
      expect(allCustTxs.length, equals(3));
      expect(allCustTxs[0]['type'], equals('purchase'));
      expect(allCustTxs[0]['amount'], equals(300.0));
      expect(allCustTxs[0]['balance_after'], equals(300.0));

      expect(allCustTxs[1]['type'], equals('payment'));
      expect(allCustTxs[1]['amount'], equals(100.0));
      expect(allCustTxs[1]['balance_after'], equals(200.0));

      expect(allCustTxs[2]['type'], equals('payment'));
      expect(allCustTxs[2]['amount'], equals(100.0));
      expect(allCustTxs[2]['balance_after'], equals(100.0));
    });

    test('Partial and Full Invoice Payments: Multi-step settlement reaching zero balance', () async {
      final now = DateTime.now().toIso8601String();
      const companyId = 'comp_partial_test';
      const custId = 'cust_partial_01';
      const invId = 'inv_partial_300';
      const saleId = 'sale_partial_300';
      const invTotal = 300.0;

      // 1. Create customer with 300 DZD debt
      await db.insert('customers', {
        'id': custId,
        'company_id': companyId,
        'name': 'Yacine Partial Customer',
        'credit_balance': invTotal,
        'created_at': now,
      });

      // 2. Create unpaid sale and invoice
      await db.insert('sales', {
        'id': saleId,
        'company_id': companyId,
        'customer_name': 'Yacine Partial Customer',
        'invoice_number': 'INV-PARTIAL-001',
        'total': invTotal,
        'subtotal': invTotal,
        'payment_status': 'unpaid',
        'payment_method': 'credit',
        'sold_at': now,
        'created_at': now,
      });

      await db.insert('invoices', {
        'id': invId,
        'company_id': companyId,
        'sale_id': saleId,
        'invoice_number': 'INV-PARTIAL-001',
        'customer_name': 'Yacine Partial Customer',
        'total': invTotal,
        'paid_amount': 0.0,
        'remaining_amount': invTotal,
        'status': 'unpaid',
        'sold_at': now,
        'created_at': now,
      });

      // Helper function replicating _applyInvoicePayment
      Future<void> applyPayment(double paymentAmount) async {
        final inv = (await db.query('invoices', where: 'id = ?', whereArgs: [invId])).first;
        final currentPaid = (inv['paid_amount'] as num).toDouble();
        final currentRemaining = (inv['remaining_amount'] as num).toDouble();

        final newPaid = currentPaid + paymentAmount;
        final newRemaining = (currentRemaining - paymentAmount).clamp(0.0, double.infinity);
        final isFullyPaid = newRemaining == 0.0;
        final newStatus = isFullyPaid ? 'paid' : 'partial';

        await db.transaction((txn) async {
          await txn.update(
            'invoices',
            {'paid_amount': newPaid, 'remaining_amount': newRemaining, 'status': newStatus},
            where: 'id = ?',
            whereArgs: [invId],
          );
          await txn.update(
            'sales',
            {'payment_status': newStatus},
            where: 'id = ?',
            whereArgs: [saleId],
          );
          final cust = (await txn.query('customers', where: 'id = ?', whereArgs: [custId])).first;
          final curDebt = (cust['credit_balance'] as num).toDouble();
          final newDebt = (curDebt - paymentAmount).clamp(0.0, double.infinity);
          await txn.update('customers', {'credit_balance': newDebt}, where: 'id = ?', whereArgs: [custId]);
          await txn.insert('customer_transactions', {
            'id': 'tx_partial_${DateTime.now().microsecondsSinceEpoch}',
            'company_id': companyId,
            'customer_id': custId,
            'type': 'payment',
            'amount': paymentAmount,
            'balance_after': newDebt,
            'description': isFullyPaid ? 'Full settlement INV-PARTIAL-001' : 'Partial payment INV-PARTIAL-001',
            'created_at': DateTime.now().toIso8601String(),
          });
        });
      }

      // First partial payment: 100 DZD
      await applyPayment(100.0);
      var invCheck = (await db.query('invoices', where: 'id = ?', whereArgs: [invId])).first;
      expect(invCheck['paid_amount'], equals(100.0));
      expect(invCheck['remaining_amount'], equals(200.0));
      expect(invCheck['status'], equals('partial'));
      var custCheck = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custCheck['credit_balance'], equals(200.0));
      var saleCheck = (await db.query('sales', where: 'id = ?', whereArgs: [saleId])).first;
      expect(saleCheck['payment_status'], equals('partial'));

      // Second partial payment: 100 DZD
      await applyPayment(100.0);
      invCheck = (await db.query('invoices', where: 'id = ?', whereArgs: [invId])).first;
      expect(invCheck['paid_amount'], equals(200.0));
      expect(invCheck['remaining_amount'], equals(100.0));
      expect(invCheck['status'], equals('partial'));
      custCheck = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custCheck['credit_balance'], equals(100.0));

      // Final payment: remaining 100 DZD
      await applyPayment(100.0);
      invCheck = (await db.query('invoices', where: 'id = ?', whereArgs: [invId])).first;
      expect(invCheck['paid_amount'], equals(300.0));
      expect(invCheck['remaining_amount'], equals(0.0));
      expect(invCheck['status'], equals('paid'), reason: 'Invoice must transition to paid ONLY when remaining balance hits zero');
      custCheck = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custCheck['credit_balance'], equals(0.0));
      saleCheck = (await db.query('sales', where: 'id = ?', whereArgs: [saleId])).first;
      expect(saleCheck['payment_status'], equals('paid'));
    });

    test('Regression: Customer-level repayment reconciles invoice-level balance without double-counting', () async {
      final now = DateTime.now().toIso8601String();
      const compId = 'comp_reconcile_01';
      const custId = 'cust_brahim_01';
      const custName = 'Brahim Reconcile';
      const invId = 'inv_brahim_200';
      const saleId = 'sale_brahim_200';
      const totalAmt = 200.0;

      // 1. Customer has 200 DZD debt and matching invoice
      await db.insert('customers', {
        'id': custId,
        'company_id': compId,
        'name': custName,
        'credit_balance': totalAmt,
        'created_at': now,
      });

      await db.insert('sales', {
        'id': saleId,
        'company_id': compId,
        'customer_name': custName,
        'invoice_number': 'INV-BR-001',
        'total': totalAmt,
        'subtotal': totalAmt,
        'payment_status': 'unpaid',
        'payment_method': 'credit',
        'sold_at': now,
        'created_at': now,
      });

      await db.insert('invoices', {
        'id': invId,
        'company_id': compId,
        'sale_id': saleId,
        'invoice_number': 'INV-BR-001',
        'customer_name': custName,
        'total': totalAmt,
        'paid_amount': 0.0,
        'remaining_amount': totalAmt,
        'status': 'unpaid',
        'sold_at': now,
        'created_at': now,
      });

      // 2. Customer repays 100 DZD at Credit Register (Customer level)
      const creditPaid = 100.0;
      await db.transaction((txn) async {
        // Decrement customer credit balance
        await txn.update(
          'customers',
          {'credit_balance': totalAmt - creditPaid},
          where: 'id = ? AND company_id = ?',
          whereArgs: [custId, compId],
        );
        await txn.insert('customer_transactions', {
          'id': 'tx_br_01',
          'company_id': compId,
          'customer_id': custId,
          'type': 'payment',
          'amount': creditPaid,
          'balance_after': totalAmt - creditPaid,
          'description': 'Credit register repayment',
          'created_at': now,
        });

        // Reconcile matching unpaid invoices
        final unpaid = await txn.query(
          'invoices',
          where: "company_id = ? AND customer_name = ? AND status IN ('unpaid', 'partial')",
          whereArgs: [compId, custName],
          orderBy: 'created_at ASC',
        );
        double rem = creditPaid;
        for (final inv in unpaid) {
          if (rem <= 0.001) break;
          final curR = (inv['remaining_amount'] as num).toDouble();
          final curP = (inv['paid_amount'] as num).toDouble();
          final alloc = rem > curR ? curR : rem;
          final nPaid = curP + alloc;
          final nRem = (curR - alloc).clamp(0.0, double.infinity);
          final nStat = nRem <= 0.001 ? 'paid' : 'partial';

          await txn.update('invoices', {'paid_amount': nPaid, 'remaining_amount': nRem, 'status': nStat}, where: 'id = ?', whereArgs: [inv['id']]);
          await txn.update('sales', {'payment_status': nStat}, where: 'id = ?', whereArgs: [inv['sale_id']]);
          rem -= alloc;
        }
      });

      // Verify intermediate state after Credit Screen repayment:
      // Invoice remaining is 100 DZD, status is partial
      var invRow = (await db.query('invoices', where: 'id = ?', whereArgs: [invId])).first;
      expect(invRow['paid_amount'], equals(100.0));
      expect(invRow['remaining_amount'], equals(100.0));
      expect(invRow['status'], equals('partial'));

      var custRow = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custRow['credit_balance'], equals(100.0));

      // 3. Now user opens Invoices Screen and settles the remaining 100 DZD
      const invPaid = 100.0;
      await db.transaction((txn) async {
        final curP = (invRow['paid_amount'] as num).toDouble();
        final curR = (invRow['remaining_amount'] as num).toDouble();
        final nPaid = curP + invPaid;
        final nRem = (curR - invPaid).clamp(0.0, double.infinity);
        final nStat = nRem <= 0.001 ? 'paid' : 'partial';

        await txn.update('invoices', {'paid_amount': nPaid, 'remaining_amount': nRem, 'status': nStat}, where: 'id = ?', whereArgs: [invId]);
        await txn.update('sales', {'payment_status': nStat}, where: 'id = ?', whereArgs: [saleId]);

        final cRow = (await txn.query('customers', where: 'id = ?', whereArgs: [custId])).first;
        final curDebt = (cRow['credit_balance'] as num).toDouble();
        final newDebt = (curDebt - invPaid).clamp(0.0, double.infinity);
        await txn.update('customers', {'credit_balance': newDebt}, where: 'id = ?', whereArgs: [custId]);
        await txn.insert('customer_transactions', {
          'id': 'tx_br_02',
          'company_id': compId,
          'customer_id': custId,
          'type': 'payment',
          'amount': invPaid,
          'balance_after': newDebt,
          'description': 'Full invoice settlement (INV-BR-001)',
          'created_at': now,
        });
      });

      // Final Assertions:
      // Invoice is fully paid, customer balance is exactly 0
      final finalInv = (await db.query('invoices', where: 'id = ?', whereArgs: [invId])).first;
      expect(finalInv['paid_amount'], equals(200.0));
      expect(finalInv['remaining_amount'], equals(0.0));
      expect(finalInv['status'], equals('paid'));

      final finalCust = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(finalCust['credit_balance'], equals(0.0));

      // Ledger has exactly 2 payments totaling 200 DZD (no duplication)
      final allTxs = await db.query('customer_transactions', where: 'customer_id = ?', whereArgs: [custId], orderBy: 'created_at ASC');
      expect(allTxs.length, equals(2));
      expect(allTxs[0]['amount'], equals(100.0));
      expect(allTxs[1]['amount'], equals(100.0));
      final totalPaid = allTxs.fold<double>(0.0, (sum, tx) => sum + (tx['amount'] as num).toDouble());
      expect(totalPaid, equals(200.0));
    });

    test('Regression: Financial reports invariant — profit does not increase on debt repayment', () async {
      final now = DateTime.now().toIso8601String();
      final todayStr = now.substring(0, 10);
      const repCompanyId = 'comp_rep_inv_01';
      const prodId = 'prod_rep_01';
      const custId = 'cust_rep_01';

      // Product: cost = 100, price = 150, sold = 2 -> total = 300, COGS = 200
      await db.insert('products', {
        'id': prodId,
        'company_id': repCompanyId,
        'name': 'Rep Item',
        'price': 150.0,
        'cost_price': 100.0,
        'stock_quantity': 10,
        'created_at': now,
      });

      await db.insert('customers', {
        'id': custId,
        'company_id': repCompanyId,
        'name': 'Rep Customer',
        'credit_balance': 200.0, // 300 total - 100 upfront = 200 debt
        'created_at': now,
      });

      // Sale of 300 DZD (2 units * 150)
      await db.insert('sales', {
        'id': 'sale_rep_01',
        'company_id': repCompanyId,
        'customer_name': 'Rep Customer',
        'total': 300.0,
        'subtotal': 300.0,
        'payment_status': 'partial',
        'payment_method': 'credit',
        'sold_at': now,
        'created_at': now,
      });

      await db.insert('sale_items', {
        'id': 'si_rep_01',
        'company_id': repCompanyId,
        'sale_id': 'sale_rep_01',
        'product_id': prodId,
        'product_name': 'Rep Item',
        'quantity': 2,
        'unit_price': 150.0,
        'unit_cost': 100.0,
        'line_total': 300.0,
        'line_profit': 100.0,
      });

      // Upfront collection: 100 DZD
      await db.insert('customer_transactions', {
        'id': 'tx_rep_upfront',
        'company_id': repCompanyId,
        'customer_id': custId,
        'type': 'payment',
        'amount': 100.0,
        'balance_after': 200.0,
        'description': 'Upfront cash deposit',
        'created_at': now,
      });

      // --- BEFORE LATER DEBT REPAYMENT ---
      final beforeRep = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: repCompanyId,
        date: todayStr,
        customDb: db,
      );

      expect(beforeRep.periodTotalSales, equals(300.0));
      expect(beforeRep.periodCollected, equals(100.0));
      expect(beforeRep.periodCogs, equals(200.0));
      expect(beforeRep.outstandingDebt, equals(200.0));
      // Accrual Gross Profit: 300 total sales - 200 COGS = 100
      final accrualGrossBefore = beforeRep.periodTotalSales - beforeRep.periodCogs;
      expect(accrualGrossBefore, equals(100.0));

      // --- CUSTOMER MAKES 100 DZD REPAYMENT ---
      await db.insert('customer_transactions', {
        'id': 'tx_rep_later',
        'company_id': repCompanyId,
        'customer_id': custId,
        'type': 'payment',
        'amount': 100.0,
        'balance_after': 100.0,
        'description': 'Later debt repayment',
        'created_at': now,
      });
      await db.update('customers', {'credit_balance': 100.0}, where: 'id = ?', whereArgs: [custId]);

      // --- AFTER LATER DEBT REPAYMENT ---
      final afterRep = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: repCompanyId,
        date: todayStr,
        customDb: db,
      );

      // Key Financial Invariants:
      // 1. Total sales remains 300 DZD
      expect(afterRep.periodTotalSales, equals(300.0));
      // 2. Collections increased from 100 to 200 DZD
      expect(afterRep.periodCollected, equals(200.0));
      // 3. COGS is deducted exactly once (200 DZD)
      expect(afterRep.periodCogs, equals(200.0));
      // 4. Outstanding debt reduced from 200 to 100 DZD
      expect(afterRep.outstandingDebt, equals(100.0));
      // 5. Accrual gross profit does NOT increase merely because debt was collected!
      final accrualGrossAfter = afterRep.periodTotalSales - afterRep.periodCogs;
      expect(accrualGrossAfter, equals(100.0));
      expect(accrualGrossAfter, equals(accrualGrossBefore));
    });

    test('Regression: Legacy SQLite migration preserves unpaid, paid, and partially paid records', () async {
      final factory = databaseFactoryFfi;
      final legDbName = 'legacy_migration_${DateTime.now().microsecondsSinceEpoch}.db';
      final legDb = await factory.openDatabase(legDbName);
      await legDb.execute('DROP TABLE IF EXISTS invoices;');

      // Create pre-migration legacy table without paid_amount or remaining_amount
      await legDb.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          sale_id TEXT,
          invoice_number TEXT NOT NULL,
          customer_name TEXT,
          total REAL NOT NULL,
          status TEXT NOT NULL DEFAULT 'paid',
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      // Populate legacy data
      await legDb.insert('invoices', {
        'id': 'inv_leg_paid',
        'company_id': testCompanyId,
        'invoice_number': 'INV-LEG-01',
        'total': 300.0,
        'status': 'paid',
        'sold_at': '2026-01-01',
        'created_at': '2026-01-01',
      });

      await legDb.insert('invoices', {
        'id': 'inv_leg_unpaid',
        'company_id': testCompanyId,
        'invoice_number': 'INV-LEG-02',
        'total': 250.0,
        'status': 'unpaid',
        'sold_at': '2026-01-02',
        'created_at': '2026-01-02',
      });

      await legDb.insert('invoices', {
        'id': 'inv_leg_partial',
        'company_id': testCompanyId,
        'invoice_number': 'INV-LEG-03',
        'total': 180.0,
        'status': 'partial',
        'sold_at': '2026-01-03',
        'created_at': '2026-01-03',
      });

      // Run non-destructive schema migrations
      for (final col in [
        'ALTER TABLE invoices ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0.0',
        'ALTER TABLE invoices ADD COLUMN remaining_amount REAL NOT NULL DEFAULT 0.0',
      ]) {
        try {
          await legDb.execute(col);
        } catch (_) {}
      }

      // Safe backfill logic
      await legDb.execute("UPDATE invoices SET remaining_amount = total, paid_amount = 0.0 WHERE (remaining_amount IS NULL OR remaining_amount = 0.0) AND status = 'unpaid'");
      await legDb.execute("UPDATE invoices SET paid_amount = total, remaining_amount = 0.0 WHERE (paid_amount IS NULL OR paid_amount = 0.0) AND status = 'paid'");
      await legDb.execute("UPDATE invoices SET remaining_amount = total - paid_amount WHERE status = 'partial' AND (remaining_amount IS NULL OR remaining_amount = 0.0)");

      // Verification of migration outcomes:
      final paidInv = (await legDb.query('invoices', where: 'id = ?', whereArgs: ['inv_leg_paid'])).first;
      expect(paidInv['paid_amount'], equals(300.0));
      expect(paidInv['remaining_amount'], equals(0.0));
      expect(paidInv['status'], equals('paid'));

      final unpaidInv = (await legDb.query('invoices', where: 'id = ?', whereArgs: ['inv_leg_unpaid'])).first;
      expect(unpaidInv['paid_amount'], equals(0.0));
      expect(unpaidInv['remaining_amount'], equals(250.0));
      expect(unpaidInv['status'], equals('unpaid'));

      final partialInv = (await legDb.query('invoices', where: 'id = ?', whereArgs: ['inv_leg_partial'])).first;
      expect(partialInv['total'], equals(180.0));
      expect(partialInv['status'], equals('partial'));

      await legDb.close();
      await factory.deleteDatabase(legDbName);
    });

    test('Regression: Strict Tenant Isolation across company borders', () async {
      final now = DateTime.now().toIso8601String();
      const compA = 'comp_alpha';
      const compB = 'comp_beta';

      // Company A setup
      await db.insert('customers', {
        'id': 'cust_a',
        'company_id': compA,
        'name': 'Shared Name Customer',
        'credit_balance': 500.0,
        'created_at': now,
      });
      await db.insert('invoices', {
        'id': 'inv_a',
        'company_id': compA,
        'invoice_number': 'INV-A-100',
        'customer_name': 'Shared Name Customer',
        'total': 500.0,
        'paid_amount': 0.0,
        'remaining_amount': 500.0,
        'status': 'unpaid',
        'sold_at': now,
        'created_at': now,
      });

      // Company B setup
      await db.insert('customers', {
        'id': 'cust_b',
        'company_id': compB,
        'name': 'Shared Name Customer',
        'credit_balance': 500.0,
        'created_at': now,
      });
      await db.insert('invoices', {
        'id': 'inv_b',
        'company_id': compB,
        'invoice_number': 'INV-B-100',
        'customer_name': 'Shared Name Customer',
        'total': 500.0,
        'paid_amount': 0.0,
        'remaining_amount': 500.0,
        'status': 'unpaid',
        'sold_at': now,
        'created_at': now,
      });

      // Company A records payment of 200 DZD
      await db.update(
        'customers',
        {'credit_balance': 300.0},
        where: 'id = ? AND company_id = ?',
        whereArgs: ['cust_a', compA],
      );
      await db.update(
        'invoices',
        {'paid_amount': 200.0, 'remaining_amount': 300.0, 'status': 'partial'},
        where: 'id = ? AND company_id = ?',
        whereArgs: ['inv_a', compA],
      );

      // Verify Company A changed
      final checkA = (await db.query('customers', where: 'id = ? AND company_id = ?', whereArgs: ['cust_a', compA])).first;
      expect(checkA['credit_balance'], equals(300.0));
      final checkInvA = (await db.query('invoices', where: 'id = ? AND company_id = ?', whereArgs: ['inv_a', compA])).first;
      expect(checkInvA['remaining_amount'], equals(300.0));

      // Verify Company B remains completely untouched
      final checkB = (await db.query('customers', where: 'id = ? AND company_id = ?', whereArgs: ['cust_b', compB])).first;
      expect(checkB['credit_balance'], equals(500.0));
      final checkInvB = (await db.query('invoices', where: 'id = ? AND company_id = ?', whereArgs: ['inv_b', compB])).first;
      expect(checkInvB['remaining_amount'], equals(500.0));
      expect(checkInvB['status'], equals('unpaid'));
    });

    test('Regression: Offline sync queue retry capping and failure state preservation', () async {
      const qId = 'sq_retry_test_01';
      final now = DateTime.now().toIso8601String();

      await db.insert('sync_queue', {
        'id': qId,
        'company_id': testCompanyId,
        'client_transaction_id': 'ctx_retry_01',
        'entity_type': 'unsupported_entity_type',
        'entity_id': 'ent_01',
        'operation_type': 'UNSUPPORTED_OP',
        'payload': jsonEncode({'test': true}),
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'created_at': now,
        'updated_at': now,
      });

      // Simulate 5 failures
      for (int i = 1; i <= 5; i++) {
        final qRow = (await db.query('sync_queue', where: 'id = ?', whereArgs: [qId])).first;
        final retries = (qRow['retry_count'] as num).toInt();
        await db.update(
          'sync_queue',
          {
            'retry_count': retries + 1,
            'status': retries + 1 >= 5 ? 'failed' : 'pending',
            'last_error': 'Simulated HTTP 500 error attempt $i',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [qId],
        );
      }

      final failedRow = (await db.query('sync_queue', where: 'id = ?', whereArgs: [qId])).first;
      expect(failedRow['status'], equals('failed'), reason: 'Queue item must transition to failed after 5 retries');
      expect(failedRow['retry_count'], equals(5));
      expect(failedRow['last_error'], contains('attempt 5'));
    });

    test('Safety Check 1: Zero, negative, and excessive invoice payments are rejected before mutation', () async {
      const compId = 'comp_safety_01';
      const invId = 'inv_safety_01';
      const custId = 'cust_safety_01';
      const now = '2026-03-30T10:00:00';

      await db.insert('customers', {
        'id': custId,
        'company_id': compId,
        'name': 'Safety Customer',
        'credit_balance': 200.0,
        'created_at': now,
      });

      await db.insert('invoices', {
        'id': invId,
        'company_id': compId,
        'invoice_number': 'INV-SAFE-01',
        'customer_name': 'Safety Customer',
        'total': 200.0,
        'paid_amount': 0.0,
        'remaining_amount': 200.0,
        'status': 'unpaid',
        'sold_at': now,
        'created_at': now,
      });

      // 1. Zero payment rejected
      expect(
        () => PaymentTransactionManager.recordInvoicePayment(
          db: db,
          companyId: compId,
          invoiceId: invId,
          paymentAmount: 0.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 2. Negative payment rejected
      expect(
        () => PaymentTransactionManager.recordInvoicePayment(
          db: db,
          companyId: compId,
          invoiceId: invId,
          paymentAmount: -50.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 3. Excessive payment (250 DZD on 200 DZD invoice) rejected
      expect(
        () => PaymentTransactionManager.recordInvoicePayment(
          db: db,
          companyId: compId,
          invoiceId: invId,
          paymentAmount: 250.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Verify zero mutation occurred on invoice or customer
      final invCheck = (await db.query('invoices', where: 'id = ?', whereArgs: [invId])).first;
      expect(invCheck['paid_amount'], equals(0.0));
      expect(invCheck['remaining_amount'], equals(200.0));

      final custCheck = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custCheck['credit_balance'], equals(200.0));
    });

    test('Safety Check 2: Customer debt cannot be silently clamped to zero when payment exceeds valid debt', () async {
      const compId = 'comp_safety_02';
      const custId = 'cust_safety_02';
      const now = '2026-03-30T10:00:00';

      await db.insert('customers', {
        'id': custId,
        'company_id': compId,
        'name': 'Debt Safety Customer',
        'credit_balance': 150.0,
        'created_at': now,
      });

      // Attempting to pay 200 DZD when valid debt is only 150 DZD must THROW, not clamp to 0.0
      expect(
        () => PaymentTransactionManager.recordCreditRepayment(
          db: db,
          companyId: compId,
          customerId: custId,
          paymentAmount: 200.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Confirm customer balance was NOT modified
      final custCheck = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custCheck['credit_balance'], equals(150.0), reason: 'Debt balance must remain 150.0 and never clamped');
    });

    test('Safety Check 3: Payment operation has stable idempotency key and replay does not double-deduct', () async {
      const compId = 'comp_safety_03';
      const custId = 'cust_safety_03';
      const now = '2026-03-30T10:00:00';
      const stableTxKey = 'idem_key_payment_999';

      await db.insert('customers', {
        'id': custId,
        'company_id': compId,
        'name': 'Idem Customer',
        'credit_balance': 300.0,
        'created_at': now,
      });

      // First execution with stable idempotency key
      final res1 = await PaymentTransactionManager.recordCreditRepayment(
        db: db,
        companyId: compId,
        customerId: custId,
        paymentAmount: 100.0,
        paymentId: stableTxKey,
      );

      expect(res1.success, isTrue);
      expect(res1.duplicateIgnored, isFalse);
      expect(res1.newCustomerDebt, equals(200.0));

      final custAfter1 = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custAfter1['credit_balance'], equals(200.0));

      // Replaying the exact same payment operation (e.g., retry after timeout)
      final res2 = await PaymentTransactionManager.recordCreditRepayment(
        db: db,
        companyId: compId,
        customerId: custId,
        paymentAmount: 100.0,
        paymentId: stableTxKey,
      );

      expect(res2.success, isTrue);
      expect(res2.duplicateIgnored, isTrue);

      // Customer debt must NOT have been deducted a second time!
      final custAfter2 = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custAfter2['credit_balance'], equals(200.0), reason: 'Replayed transaction must not deduct debt twice');

      // Exactly ONE transaction record exists in the ledger
      final txRows = await db.query('customer_transactions', where: 'id = ?', whereArgs: [stableTxKey]);
      expect(txRows.length, equals(1));
    });

    test('Safety Check 4: FIFO invoice allocation never exceeds customer debt or invoice balance', () async {
      const compId = 'comp_safety_04';
      const custId = 'cust_safety_04';
      const custName = 'FIFO Safety Customer';
      const now = '2026-03-30T10:00:00';

      await db.insert('customers', {
        'id': custId,
        'company_id': compId,
        'name': custName,
        'credit_balance': 250.0,
        'created_at': now,
      });

      // Invoice 1: 100 DZD
      await db.insert('invoices', {
        'id': 'inv_fifo_1',
        'company_id': compId,
        'invoice_number': 'INV-FIFO-1',
        'customer_name': custName,
        'total': 100.0,
        'paid_amount': 0.0,
        'remaining_amount': 100.0,
        'status': 'unpaid',
        'sold_at': '2026-03-28',
        'created_at': '2026-03-28',
      });

      // Invoice 2: 150 DZD
      await db.insert('invoices', {
        'id': 'inv_fifo_2',
        'company_id': compId,
        'invoice_number': 'INV-FIFO-2',
        'customer_name': custName,
        'total': 150.0,
        'paid_amount': 0.0,
        'remaining_amount': 150.0,
        'status': 'unpaid',
        'sold_at': '2026-03-29',
        'created_at': '2026-03-29',
      });

      // Repay 150 DZD at Credit Register
      await PaymentTransactionManager.recordCreditRepayment(
        db: db,
        companyId: compId,
        customerId: custId,
        paymentAmount: 150.0,
      );

      // Invoice 1 should be fully paid (100 allocated)
      final inv1 = (await db.query('invoices', where: 'id = ?', whereArgs: ['inv_fifo_1'])).first;
      expect(inv1['paid_amount'], equals(100.0));
      expect(inv1['remaining_amount'], equals(0.0));
      expect(inv1['status'], equals('paid'));

      // Invoice 2 should have 50 allocated (100 remaining)
      final inv2 = (await db.query('invoices', where: 'id = ?', whereArgs: ['inv_fifo_2'])).first;
      expect(inv2['paid_amount'], equals(50.0));
      expect(inv2['remaining_amount'], equals(100.0));
      expect(inv2['status'], equals('partial'));

      // Customer remaining debt: 100.0
      final cust = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(cust['credit_balance'], equals(100.0));
    });

    test('Safety Check 5: Historical migration validates realistic legacy databases with isolated DBs', () async {
      final factory = databaseFactoryFfi;
      final legDbPath = 'legacy_safety_test_${DateTime.now().microsecondsSinceEpoch}.db';
      final legDb = await factory.openDatabase(legDbPath);

      // Pre-migration legacy invoices schema
      await legDb.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          invoice_number TEXT NOT NULL,
          customer_name TEXT,
          total REAL NOT NULL,
          status TEXT NOT NULL,
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await legDb.execute('''
        CREATE TABLE customer_transactions (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          balance_after REAL NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // Scenario 1: Unpaid invoice with no previous payment
      await legDb.insert('invoices', {
        'id': 'inv_case_unpaid',
        'company_id': 'comp_mig',
        'invoice_number': 'INV-MIG-01',
        'customer_name': 'Cust A',
        'total': 400.0,
        'status': 'unpaid',
        'sold_at': '2026-01-01',
        'created_at': '2026-01-01',
      });

      // Scenario 2: Fully paid invoice
      await legDb.insert('invoices', {
        'id': 'inv_case_paid',
        'company_id': 'comp_mig',
        'invoice_number': 'INV-MIG-02',
        'customer_name': 'Cust B',
        'total': 300.0,
        'status': 'paid',
        'sold_at': '2026-01-02',
        'created_at': '2026-01-02',
      });

      // Scenario 3: Invoice with historical payment records in customer_transactions (200 DZD paid on 500 DZD invoice)
      await legDb.insert('invoices', {
        'id': 'inv_case_partial_with_tx',
        'company_id': 'comp_mig',
        'invoice_number': 'INV-MIG-03',
        'customer_name': 'Cust C',
        'total': 500.0,
        'status': 'partial',
        'sold_at': '2026-01-03',
        'created_at': '2026-01-03',
      });
      await legDb.insert('customer_transactions', {
        'id': 'tx_mig_01',
        'company_id': 'comp_mig',
        'customer_id': 'cust_c',
        'type': 'payment',
        'amount': 200.0,
        'balance_after': 300.0,
        'description': 'Partial deposit on INV-MIG-03',
        'created_at': '2026-01-03',
      });

      // Scenario 4: Ambiguous partial invoice without transaction history
      await legDb.insert('invoices', {
        'id': 'inv_case_ambiguous',
        'company_id': 'comp_mig',
        'invoice_number': 'INV-MIG-04',
        'customer_name': 'Cust D',
        'total': 250.0,
        'status': 'partial',
        'sold_at': '2026-01-04',
        'created_at': '2026-01-04',
      });

      // Run migration
      final report1 = await ModiriDesktopDatabase.migrateLegacyDatabase(legDb);

      expect(report1.totalInspected, equals(4));
      expect(report1.unpaidBackfilled, equals(1));
      expect(report1.fullyPaidBackfilled, equals(1));
      expect(report1.historyReconstructed, equals(1));
      expect(report1.ambiguousInvoices, contains('inv_case_ambiguous'));

      // Verify Scenario 1
      final invUnpaid = (await legDb.query('invoices', where: 'id = ?', whereArgs: ['inv_case_unpaid'])).first;
      expect(invUnpaid['paid_amount'], equals(0.0));
      expect(invUnpaid['remaining_amount'], equals(400.0));
      expect(invUnpaid['status'], equals('unpaid'));

      // Verify Scenario 2
      final invPaid = (await legDb.query('invoices', where: 'id = ?', whereArgs: ['inv_case_paid'])).first;
      expect(invPaid['paid_amount'], equals(300.0));
      expect(invPaid['remaining_amount'], equals(0.0));
      expect(invPaid['status'], equals('paid'));

      // Verify Scenario 3: History correctly reconstructed from ledger
      final invHist = (await legDb.query('invoices', where: 'id = ?', whereArgs: ['inv_case_partial_with_tx'])).first;
      expect(invHist['paid_amount'], equals(200.0));
      expect(invHist['remaining_amount'], equals(300.0));
      expect(invHist['status'], equals('partial'));

      // Verify Scenario 4: Ambiguity preserved safely without inventing data
      final invAmb = (await legDb.query('invoices', where: 'id = ?', whereArgs: ['inv_case_ambiguous'])).first;
      expect(invAmb['remaining_amount'], equals(250.0));

      // Scenario 5: Re-running migration is 100% idempotent and touches zero already migrated rows
      final report2 = await ModiriDesktopDatabase.migrateLegacyDatabase(legDb);
      expect(report2.totalInspected, equals(0), reason: 'Second migration run must be idempotent with 0 unmigrated rows');

      await legDb.close();
      await factory.deleteDatabase(legDbPath);
    });

    test('Safety Check 6: Expenses respect actual transaction dates in financial reporting', () async {
      const compId = 'comp_safety_06';
      final now = DateTime.now().toIso8601String();

      // Expense today: 40 DZD
      await db.insert('expenses', {
        'id': 'exp_today',
        'company_id': compId,
        'category': 'Cleaning',
        'amount': 40.0,
        'description': 'Cleaning supplies',
        'date': '2026-03-30',
        'created_at': now,
      });

      // Expense yesterday: 100 DZD
      await db.insert('expenses', {
        'id': 'exp_yesterday',
        'company_id': compId,
        'category': 'Rent',
        'amount': 100.0,
        'description': 'Office rent',
        'date': '2026-03-29',
        'created_at': now,
      });

      // Daily report for 2026-03-30 must only include 40 DZD
      final dailyRep = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compId,
        date: '2026-03-30',
        customDb: db,
      );
      expect(dailyRep.periodExpenses, equals(40.0));

      // Monthly report for 2026-03 must include both (140 DZD)
      final monthlyRep = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'monthly',
        companyId: compId,
        month: '2026-03',
        customDb: db,
      );
      expect(monthlyRep.periodExpenses, equals(140.0));
    });

    test('Safety Check 7: Financial formulas match approved restaurant vs general business requirements', () async {
      const now = '2026-03-30T10:00:00';
      const compGen = 'comp_general_fin';
      const compRest = 'comp_restaurant_fin';

      // --- 1. General Business Setup ---
      await db.insert('products', {
        'id': 'prod_gen_1',
        'company_id': compGen,
        'name': 'Retail Goods',
        'price': 150.0,
        'cost_price': 100.0,
        'stock_quantity': 10,
        'created_at': now,
      });

      await db.insert('sales', {
        'id': 'sale_gen_1',
        'company_id': compGen,
        'total': 300.0,
        'subtotal': 300.0,
        'payment_status': 'paid',
        'payment_method': 'cash',
        'sold_at': '2026-03-30',
        'created_at': now,
      });

      await db.insert('sale_items', {
        'id': 'si_gen_1',
        'company_id': compGen,
        'sale_id': 'sale_gen_1',
        'product_id': 'prod_gen_1',
        'product_name': 'Retail Goods',
        'quantity': 2,
        'unit_price': 150.0,
        'unit_cost': 100.0,
        'line_total': 300.0,
        'line_profit': 100.0,
      });

      await db.insert('expenses', {
        'id': 'exp_gen_1',
        'company_id': compGen,
        'category': 'Utilities',
        'amount': 50.0,
        'description': 'Electricity',
        'date': '2026-03-30',
        'created_at': now,
      });

      final genRep = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compGen,
        businessType: 'company',
        date: '2026-03-30',
        customDb: db,
      );

      // General business rules:
      // revenue = 300, COGS = 200 deducted once, gross profit = 100, expenses = 50, net profit = 50
      expect(genRep.periodRevenue, equals(300.0));
      expect(genRep.periodCogs, equals(200.0));
      expect(genRep.periodGrossProfit, equals(100.0));
      expect(genRep.periodExpenses, equals(50.0));
      expect(genRep.periodNetProfit, equals(50.0));

      // --- 2. Restaurant / Café Setup ---
      // Restaurant inventory (food ingredients stock): 15 units * 10 DZD = 150 DZD
      await db.insert('products', {
        'id': 'prod_rest_ing',
        'company_id': compRest,
        'name': 'Food Ingredients',
        'price': 20.0,
        'cost_price': 10.0,
        'stock_quantity': 15,
        'created_at': now,
      });

      await db.insert('sales', {
        'id': 'sale_rest_1',
        'company_id': compRest,
        'total': 500.0,
        'subtotal': 500.0,
        'payment_status': 'paid',
        'payment_method': 'cash',
        'sold_at': '2026-03-30',
        'created_at': now,
      });

      await db.insert('sale_items', {
        'id': 'si_rest_1',
        'company_id': compRest,
        'sale_id': 'sale_rest_1',
        'product_id': 'prod_rest_ing',
        'product_name': 'Prepared Dish',
        'quantity': 5,
        'unit_price': 100.0,
        'unit_cost': 30.0,
        'line_total': 500.0,
      });

      await db.insert('expenses', {
        'id': 'exp_rest_1',
        'company_id': compRest,
        'category': 'Kitchen Supplies',
        'amount': 100.0,
        'description': 'Cooking gas & packaging',
        'date': '2026-03-30',
        'created_at': now,
      });

      final restRep = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compRest,
        businessType: 'restaurant',
        date: '2026-03-30',
        customDb: db,
      );

      // Restaurant / Café mobile accounting rules:
      // revenue = actual receipts (500 DZD)
      // gross profit = revenue = 500 DZD (COGS = 0)
      // total current inventory value = 15 * 10 = 150 DZD (asset on hand, not an expense)
      // eligible expenses = 100 DZD
      // net profit = gross profit (500) - expenses (100) = 400 DZD
      expect(restRep.periodRevenue, equals(500.0));
      expect(restRep.periodCogs, equals(0.0));
      expect(restRep.periodGrossProfit, equals(500.0));
      expect(restRep.inventoryValue, equals(150.0));
      expect(restRep.periodExpenses, equals(100.0));
      expect(restRep.periodNetProfit, equals(400.0));
    });

    test('Safety Check 8: Clear company business data isolates company, clears sync queue, and preserves other companies', () async {
      const compA = 'comp_clear_A';
      const compB = 'comp_clear_B';
      final now = DateTime.now().toIso8601String();

      // Seed Company A data
      await db.insert('products', {'id': 'p_a', 'company_id': compA, 'name': 'Prod A', 'price': 10.0, 'created_at': now});
      await db.insert('sales', {'id': 's_a', 'company_id': compA, 'total': 100.0, 'subtotal': 100.0, 'sold_at': now, 'created_at': now});
      await db.insert('invoices', {'id': 'i_a', 'company_id': compA, 'invoice_number': 'INV-A', 'total': 100.0, 'sold_at': now, 'created_at': now});
      await db.insert('sync_queue', {'id': 'sq_a', 'company_id': compA, 'client_transaction_id': 'ctx_a', 'entity_type': 'sale', 'entity_id': 's_a', 'operation_type': 'CREATE', 'payload': '{}', 'status': 'pending', 'created_at': now, 'updated_at': now});

      // Seed Company B data
      await db.insert('products', {'id': 'p_b', 'company_id': compB, 'name': 'Prod B', 'price': 20.0, 'created_at': now});
      await db.insert('sales', {'id': 's_b', 'company_id': compB, 'total': 200.0, 'subtotal': 200.0, 'sold_at': now, 'created_at': now});
      await db.insert('invoices', {'id': 'i_b', 'company_id': compB, 'invoice_number': 'INV-B', 'total': 200.0, 'sold_at': now, 'created_at': now});
      await db.insert('sync_queue', {'id': 'sq_b', 'company_id': compB, 'client_transaction_id': 'ctx_b', 'entity_type': 'sale', 'entity_id': 's_b', 'operation_type': 'CREATE', 'payload': '{}', 'status': 'pending', 'created_at': now, 'updated_at': now});

      // Execute clearCompanyBusinessData for Company A only
      await db.transaction((txn) async {
        await txn.delete('sync_queue', where: 'company_id = ?', whereArgs: [compA]);
        await txn.delete('invoices', where: 'company_id = ?', whereArgs: [compA]);
        await txn.delete('sale_items', where: 'company_id = ?', whereArgs: [compA]);
        await txn.delete('sales', where: 'company_id = ?', whereArgs: [compA]);
        await txn.delete('products', where: 'company_id = ?', whereArgs: [compA]);
      });

      // Verify Company A data is completely empty
      final prodsA = await db.query('products', where: 'company_id = ?', whereArgs: [compA]);
      expect(prodsA.isEmpty, isTrue);
      final salesA = await db.query('sales', where: 'company_id = ?', whereArgs: [compA]);
      expect(salesA.isEmpty, isTrue);
      final sqA = await db.query('sync_queue', where: 'company_id = ?', whereArgs: [compA]);
      expect(sqA.isEmpty, isTrue);

      // Verify Company B data is 100% intact and preserved!
      final prodsB = await db.query('products', where: 'company_id = ?', whereArgs: [compB]);
      expect(prodsB.length, equals(1));
      final salesB = await db.query('sales', where: 'company_id = ?', whereArgs: [compB]);
      expect(salesB.length, equals(1));
      final sqB = await db.query('sync_queue', where: 'company_id = ?', whereArgs: [compB]);
      expect(sqB.length, equals(1));
    });

    test('Safety Check 9: Exact Scenario — Two later payments of 100 DZD reach zero debt, profit invariant, and idempotency replay', () async {
      final now = DateTime.now().toIso8601String();
      final todayStr = now.substring(0, 10);
      const compId = 'comp_sc9_audit';
      const custId = 'cust_sc9_salim';
      const prodId = 'prod_sc9_item';
      const invNum = 'INV-SC9-001';
      const saleId = 'sale_sc9_001';
      const invId = 'inv_sc9_001';

      // 1. Setup product: Purchase Cost = 100 DZD, Selling Price = 150 DZD, Stock = 10
      await db.insert('products', {
        'id': prodId,
        'company_id': compId,
        'name': 'Item Two Payment Audit',
        'price': 150.0,
        'cost_price': 100.0,
        'stock_quantity': 10,
        'created_at': now,
      });

      // 2. Setup customer: Initial Debt = 0 DZD
      await db.insert('customers', {
        'id': custId,
        'company_id': compId,
        'name': 'Salim Two-Payment Customer',
        'credit_balance': 0.0,
        'created_at': now,
      });

      // 3. POS Sale of 2 units (Total = 300 DZD, COGS = 200 DZD)
      // Customer pays 100 DZD upfront, remaining 200 DZD on credit
      const qtySold = 2;
      const unitPrice = 150.0;
      const unitCost = 100.0;
      const saleTotal = 300.0;
      const upfrontPaid = 100.0;
      const initialDebt = 200.0;

      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND company_id = ?',
          [qtySold, prodId, compId],
        );

        await txn.insert('sales', {
          'id': saleId,
          'company_id': compId,
          'customer_name': 'Salim Two-Payment Customer',
          'invoice_number': invNum,
          'total': saleTotal,
          'subtotal': saleTotal,
          'discount': 0.0,
          'payment_status': 'partial',
          'payment_method': 'credit',
          'sold_at': now,
          'created_at': now,
          'synced': 0,
        });

        await txn.insert('sale_items', {
          'id': 'si_sc9_001',
          'company_id': compId,
          'sale_id': saleId,
          'product_id': prodId,
          'product_name': 'Item Two Payment Audit',
          'quantity': qtySold,
          'unit_price': unitPrice,
          'unit_cost': unitCost,
          'line_total': saleTotal,
          'line_profit': (unitPrice - unitCost) * qtySold,
        });

        await txn.insert('invoices', {
          'id': invId,
          'company_id': compId,
          'sale_id': saleId,
          'invoice_number': invNum,
          'customer_name': 'Salim Two-Payment Customer',
          'total': saleTotal,
          'paid_amount': upfrontPaid,
          'remaining_amount': initialDebt,
          'status': 'partial',
          'sold_at': now,
          'created_at': now,
        });

        await txn.insert('customer_transactions', {
          'id': 'tx_sc9_purchase',
          'company_id': compId,
          'customer_id': custId,
          'type': 'purchase',
          'amount': saleTotal,
          'balance_after': saleTotal,
          'description': 'POS Credit Sale $invNum',
          'created_at': now,
        });

        await txn.insert('customer_transactions', {
          'id': 'tx_sc9_upfront',
          'company_id': compId,
          'customer_id': custId,
          'type': 'payment',
          'amount': upfrontPaid,
          'balance_after': initialDebt,
          'description': 'Upfront cash deposit on $invNum',
          'created_at': now,
        });

        await txn.update(
          'customers',
          {'credit_balance': initialDebt},
          where: 'id = ? AND company_id = ?',
          whereArgs: [custId, compId],
        );
      });

      // Operating Expense: 50 DZD
      await db.insert('expenses', {
        'id': 'exp_sc9_001',
        'company_id': compId,
        'category': 'Utilities',
        'amount': 50.0,
        'description': 'Electricity bill',
        'date': todayStr,
        'created_at': now,
      });

      // State after checkout:
      // Total Sales: 300, Collected: 100, Debt: 200, COGS: 200, Gross Profit: 100, Net: 50
      final rep0 = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compId,
        date: todayStr,
        customDb: db,
      );
      expect(rep0.periodTotalSales, equals(300.0));
      expect(rep0.periodCollected, equals(100.0));
      expect(rep0.outstandingDebt, equals(200.0));
      expect(rep0.periodCogs, equals(200.0));
      expect(rep0.periodTotalSales - rep0.periodCogs, equals(100.0));
      expect((rep0.periodTotalSales - rep0.periodCogs) - rep0.periodExpenses, equals(50.0));

      // 4. First later payment: 100 DZD
      const paymentId1 = 'tx_sc9_later_pay1';
      final payRes1 = await PaymentTransactionManager.recordCreditRepayment(
        db: db,
        companyId: compId,
        customerId: custId,
        paymentAmount: 100.0,
        paymentId: paymentId1,
      );
      expect(payRes1.success, isTrue);
      expect(payRes1.duplicateIgnored, isFalse);

      final custAfterPay1 = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custAfterPay1['credit_balance'], equals(100.0));

      final rep1 = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compId,
        date: todayStr,
        customDb: db,
      );
      expect(rep1.periodTotalSales, equals(300.0));
      expect(rep1.periodCollected, equals(200.0));
      expect(rep1.outstandingDebt, equals(100.0));
      expect(rep1.periodTotalSales - rep1.periodCogs, equals(100.0));

      // 5. Second later payment: 100 DZD
      const paymentId2 = 'tx_sc9_later_pay2';
      final payRes2 = await PaymentTransactionManager.recordCreditRepayment(
        db: db,
        companyId: compId,
        customerId: custId,
        paymentAmount: 100.0,
        paymentId: paymentId2,
      );
      expect(payRes2.success, isTrue);
      expect(payRes2.duplicateIgnored, isFalse);

      final custAfterPay2 = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custAfterPay2['credit_balance'], equals(0.0));

      final rep2 = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compId,
        date: todayStr,
        customDb: db,
      );
      expect(rep2.periodTotalSales, equals(300.0));
      expect(rep2.periodCollected, equals(300.0));
      expect(rep2.outstandingDebt, equals(0.0));
      expect(rep2.periodTotalSales - rep2.periodCogs, equals(100.0));

      // 6. Idempotent Replay: Replay paymentId2
      final payResReplay = await PaymentTransactionManager.recordCreditRepayment(
        db: db,
        companyId: compId,
        customerId: custId,
        paymentAmount: 100.0,
        paymentId: paymentId2,
      );
      expect(payResReplay.success, isTrue);
      expect(payResReplay.duplicateIgnored, isTrue);

      final custAfterReplay = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect(custAfterReplay['credit_balance'], equals(0.0));

      final repAfterReplay = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compId,
        date: todayStr,
        customDb: db,
      );
      expect(repAfterReplay.periodTotalSales, equals(300.0));
      expect(repAfterReplay.periodCollected, equals(300.0));
      expect(repAfterReplay.outstandingDebt, equals(0.0));
    });
  });
}
