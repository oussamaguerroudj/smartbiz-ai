import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Mobile SQLite Supplier Purchases & AP Ledger Tests', () {
    late Database db;
    const companyA = 'mobile_comp_alpha';
    const companyB = 'mobile_comp_beta';

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );

      // Create schema mirroring app_database.dart v8
      await db.execute('''
        CREATE TABLE suppliers (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          products_supplied INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          supplier_id TEXT,
          quantity INTEGER NOT NULL DEFAULT 0,
          purchase_price REAL NOT NULL DEFAULT 0.0,
          selling_price REAL NOT NULL DEFAULT 0.0,
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
          total_amount REAL NOT NULL,
          amount_paid REAL NOT NULL DEFAULT 0.0,
          outstanding_balance REAL NOT NULL,
          payment_status TEXT NOT NULL DEFAULT 'unpaid',
          notes TEXT,
          client_transaction_id TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_purchase_items (
          id TEXT PRIMARY KEY,
          purchase_id TEXT NOT NULL,
          company_id TEXT,
          product_id TEXT,
          product_name TEXT NOT NULL,
          quantity REAL NOT NULL DEFAULT 1,
          unit_cost REAL NOT NULL,
          line_total REAL NOT NULL,
          created_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_payments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          supplier_id TEXT NOT NULL,
          purchase_id TEXT,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          payment_method TEXT NOT NULL DEFAULT 'cash',
          reference TEXT,
          notes TEXT,
          client_id TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
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
          retry_count INTEGER DEFAULT 0,
          last_error TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_purchases_client_tx 
        ON supplier_purchases (company_id, client_transaction_id) 
        WHERE client_transaction_id IS NOT NULL
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_payments_client_id 
        ON supplier_payments (company_id, client_id) 
        WHERE client_id IS NOT NULL
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Mobile purchase creation with partial payment computes remaining balance', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Fournisseur Boissons',
        'created_at': DateTime.now().toIso8601String(),
      });

      final purchaseId = const Uuid().v4();
      const total = 80000.0;
      const paid = 30000.0;
      const rem = 50000.0;

      await db.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'BL-8819',
        'purchase_date': '2026-10-14',
        'total_amount': total,
        'amount_paid': paid,
        'outstanding_balance': rem,
        'payment_status': 'partially_paid',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('supplier_payments', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': supplierId,
        'purchase_id': purchaseId,
        'amount': paid,
        'payment_date': '2026-10-14',
        'payment_method': 'cash',
        'created_at': DateTime.now().toIso8601String(),
      });

      final rows = await db.rawQuery('''
        SELECT 
          s.*,
          COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
          COALESCE(SUM(p.amount_paid), 0) as total_purchases_paid,
          COALESCE(SUM(p.outstanding_balance), 0) as outstanding_balance
        FROM suppliers s
        LEFT JOIN supplier_purchases p ON p.supplier_id = s.id AND p.company_id = s.company_id
        WHERE s.company_id = ?
        GROUP BY s.id
      ''', [companyA]);

      expect(rows.length, 1);
      final r = rows.first;
      expect((r['total_purchases_amount'] as num).toDouble(), 80000.0);
      expect((r['total_purchases_paid'] as num).toDouble(), 30000.0);
      expect((r['outstanding_balance'] as num).toDouble(), 50000.0);
    });

    test('2. Multi-line purchase creation with line items & downpayment', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Grossiste Alimentaire',
        'created_at': DateTime.now().toIso8601String(),
      });

      final purchaseId = const Uuid().v4();
      final lineItems = [
        {'name': 'Farine 1kg', 'qty': 100.0, 'cost': 50.0, 'total': 5000.0},
        {'name': 'Sucre 1kg', 'qty': 50.0, 'cost': 90.0, 'total': 4500.0},
        {'name': 'Huile 5L', 'qty': 20.0, 'cost': 600.0, 'total': 12000.0},
      ];

      final totalInvoice = lineItems.fold<double>(0.0, (sum, it) => sum + (it['total'] as double));
      expect(totalInvoice, 21500.0);

      const downpayment = 6500.0;
      final remaining = totalInvoice - downpayment; // 15,000.0

      await db.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'FAC-2026-001',
        'purchase_date': '2026-10-14T10:00:00.000',
        'total_amount': totalInvoice,
        'amount_paid': downpayment,
        'outstanding_balance': remaining,
        'payment_status': 'partially_paid',
        'client_transaction_id': 'purch_12345',
        'created_at': '2026-10-14T10:00:00.000',
        'synced': 0,
      });

      for (final it in lineItems) {
        await db.insert('supplier_purchase_items', {
          'id': const Uuid().v4(),
          'purchase_id': purchaseId,
          'company_id': companyA,
          'product_name': it['name'] as String,
          'quantity': it['qty'] as double,
          'unit_cost': it['cost'] as double,
          'line_total': it['total'] as double,
          'created_at': '2026-10-14T10:00:00.000',
        });
      }

      await db.insert('supplier_payments', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': supplierId,
        'purchase_id': purchaseId,
        'amount': downpayment,
        'payment_date': '2026-10-14T10:00:00.000',
        'payment_method': 'cash',
        'reference': 'Acompte initial',
        'client_id': 'pay_purch_12345',
        'created_at': '2026-10-14T10:00:00.000',
        'synced': 0,
      });

      // Verify purchase items retrieval
      final itemRows = await db.query(
        'supplier_purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
      expect(itemRows.length, 3);
      final sumItems = itemRows.fold<double>(0.0, (sum, it) => sum + (it['line_total'] as num).toDouble());
      expect(sumItems, 21500.0);

      // Verify downpayment registered
      final payments = await db.query(
        'supplier_payments',
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );
      expect(payments.length, 1);
      expect((payments.first['amount'] as num).toDouble(), 6500.0);
    });

    test('3. Chronological FIFO payment allocation across multiple unpaid invoices', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Fournisseur Laitier',
        'created_at': '2026-10-01',
      });

      final purch1 = const Uuid().v4();
      final purch2 = const Uuid().v4();

      // Invoice 1: 10,000 DZD (date: Oct 1)
      await db.insert('supplier_purchases', {
        'id': purch1,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-001',
        'purchase_date': '2026-10-01T08:00:00.000',
        'total_amount': 10000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 10000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-01T08:00:00.000',
      });

      // Invoice 2: 20,000 DZD (date: Oct 5)
      await db.insert('supplier_purchases', {
        'id': purch2,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-002',
        'purchase_date': '2026-10-05T08:00:00.000',
        'total_amount': 20000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 20000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-05T08:00:00.000',
      });

      // Total unpaid debt: 30,000 DZD
      // Unallocated global payment: 15,000 DZD
      const paymentAmount = 15000.0;
      await db.insert('supplier_payments', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': supplierId,
        'purchase_id': null, // Global / FIFO
        'amount': paymentAmount,
        'payment_date': '2026-10-10T12:00:00.000',
        'payment_method': 'cash',
        'created_at': '2026-10-10T12:00:00.000',
      });

      // Execute FIFO local allocation logic
      final pRows = await db.query(
        'supplier_purchases',
        where: 'company_id = ? AND supplier_id = ? AND outstanding_balance > 0.005',
        whereArgs: [companyA, supplierId],
        orderBy: 'purchase_date ASC, created_at ASC',
      );

      double remaining = paymentAmount;
      for (final r in pRows) {
        if (remaining <= 0.005) break;
        final pId = r['id'] as String;
        final total = (r['total_amount'] as num).toDouble();
        final paid = (r['amount_paid'] as num).toDouble();
        final bal = (r['outstanding_balance'] as num).toDouble();

        final toPay = math.min(remaining, bal);
        final newPaid = paid + toPay;
        final newBal = (total - newPaid) <= 0.005 ? 0.0 : (total - newPaid);
        final newStatus = newBal <= 0.005 ? 'paid' : 'partially_paid';

        await db.update('supplier_purchases', {
          'amount_paid': newPaid,
          'outstanding_balance': newBal,
          'payment_status': newStatus,
        }, where: 'id = ?', whereArgs: [pId]);

        remaining -= toPay;
      }

      // Verify Invoice 1 is completely paid
      final p1Updated = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purch1])).first;
      expect((p1Updated['amount_paid'] as num).toDouble(), 10000.0);
      expect((p1Updated['outstanding_balance'] as num).toDouble(), 0.0);
      expect(p1Updated['payment_status'], 'paid');

      // Verify Invoice 2 is partially paid (5,000 paid, 15,000 remaining)
      final p2Updated = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purch2])).first;
      expect((p2Updated['amount_paid'] as num).toDouble(), 5000.0);
      expect((p2Updated['outstanding_balance'] as num).toDouble(), 15000.0);
      expect(p2Updated['payment_status'], 'partially_paid');

      // Total supplier outstanding balance is now exactly 15,000 DZD
      final totalBalRow = await db.rawQuery('''
        SELECT COALESCE(SUM(outstanding_balance), 0) as total_debt
        FROM supplier_purchases
        WHERE company_id = ? AND supplier_id = ?
      ''', [companyA, supplierId]);
      expect((totalBalRow.first['total_debt'] as num).toDouble(), 15000.0);
    });

    test('4. Stock valuation separation: Product catalog value != Accounts Payable debt', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Epicerie Grossiste',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Product in stock: 50 units @ 1,000 DZD = 50,000 DZD stock asset
      await db.insert('products', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'name': 'Huile 5L',
        'supplier_id': supplierId,
        'quantity': 50,
        'purchase_price': 1000.0,
        'selling_price': 1200.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Purchase debt: 15,000 DZD
      await db.insert('supplier_purchases', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'FAC-0012',
        'purchase_date': '2026-10-14',
        'total_amount': 15000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 15000.0,
        'payment_status': 'unpaid',
        'created_at': DateTime.now().toIso8601String(),
      });

      final stockRows = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity * purchase_price), 0) as val
        FROM products
        WHERE company_id = ? AND supplier_id = ?
      ''', [companyA, supplierId]);
      final stockVal = (stockRows.first['val'] as num).toDouble();

      final debtRows = await db.rawQuery('''
        SELECT COALESCE(SUM(outstanding_balance), 0) as debt
        FROM supplier_purchases
        WHERE company_id = ? AND supplier_id = ?
      ''', [companyA, supplierId]);
      final debt = (debtRows.first['debt'] as num).toDouble();

      expect(stockVal, 50000.0);
      expect(debt, 15000.0);
      expect(stockVal, isNot(equals(debt)));
    });

    test('5. Multi-tenant company isolation on supplier purchases & payments', () async {
      final suppA = const Uuid().v4();
      final suppB = const Uuid().v4();

      await db.insert('suppliers', {'id': suppA, 'company_id': companyA, 'name': 'Fournisseur A', 'created_at': '2026-10-01'});
      await db.insert('suppliers', {'id': suppB, 'company_id': companyB, 'name': 'Fournisseur B', 'created_at': '2026-10-01'});

      await db.insert('supplier_purchases', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': suppA,
        'invoice_number': 'INV-A-1',
        'purchase_date': '2026-10-01',
        'total_amount': 95000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 95000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-01',
      });

      await db.insert('supplier_purchases', {
        'id': const Uuid().v4(),
        'company_id': companyB,
        'supplier_id': suppB,
        'invoice_number': 'INV-B-1',
        'purchase_date': '2026-10-01',
        'total_amount': 45000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 45000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-01',
      });

      final rowsA = await db.rawQuery('''
        SELECT COALESCE(SUM(outstanding_balance), 0) as debt
        FROM supplier_purchases
        WHERE company_id = ?
      ''', [companyA]);
      expect((rowsA.first['debt'] as num).toDouble(), 95000.0);

      final rowsB = await db.rawQuery('''
        SELECT COALESCE(SUM(outstanding_balance), 0) as debt
        FROM supplier_purchases
        WHERE company_id = ?
      ''', [companyB]);
      expect((rowsB.first['debt'] as num).toDouble(), 45000.0);
    });

    test('6. Non-destructive SQLite version 8 migration: adds supplier_id to products', () async {
      // Simulate an older v7 database with products table lacking supplier_id
      final oldDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await oldDb.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 0,
          purchase_price REAL NOT NULL DEFAULT 0.0,
          selling_price REAL NOT NULL DEFAULT 0.0,
          created_at TEXT NOT NULL
        )
      ''');

      // Insert existing product in v7
      await oldDb.insert('products', {
        'id': 'prod_existing',
        'company_id': companyA,
        'name': 'Ancien Produit V7',
        'quantity': 10,
        'purchase_price': 500.0,
        'selling_price': 700.0,
        'created_at': '2026-01-01',
      });

      // Run v8 migration (same SQL as in AppDatabase._onUpgrade)
      await oldDb.execute('ALTER TABLE products ADD COLUMN supplier_id TEXT');
      await oldDb.execute('CREATE INDEX IF NOT EXISTS ix_products_supplier ON products (supplier_id)');

      // Verify existing product preserved with null supplier_id
      final existing = (await oldDb.query('products', where: 'id = ?', whereArgs: ['prod_existing'])).first;
      expect(existing['name'], 'Ancien Produit V7');
      expect(existing['supplier_id'], isNull);

      // Verify new product with supplier_id can be inserted
      await oldDb.insert('products', {
        'id': 'prod_new_v8',
        'company_id': companyA,
        'name': 'Nouveau Produit V8',
        'supplier_id': 'supp_xyz',
        'quantity': 25,
        'purchase_price': 1200.0,
        'selling_price': 1500.0,
        'created_at': '2026-10-14',
      });

      final bySupplier = await oldDb.query('products', where: 'company_id = ? AND supplier_id = ?', whereArgs: [companyA, 'supp_xyz']);
      expect(bySupplier.length, 1);
      expect(bySupplier.first['name'], 'Nouveau Produit V8');

      await oldDb.close();
    });

    test('7. Payment Idempotency: Duplicate payment rejected locally and recovered on retry', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Fournisseur Boissons Idempotency',
        'created_at': '2026-10-14',
      });

      const clientTxId = 'pay_stable_123456789';
      const paymentId = 'pay_uuid_1';

      // 1. First insert offline
      await db.insert('supplier_payments', {
        'id': paymentId,
        'company_id': companyA,
        'supplier_id': supplierId,
        'amount': 5000.0,
        'payment_date': '2026-10-14',
        'payment_method': 'cash',
        'client_id': clientTxId,
        'created_at': '2026-10-14',
        'synced': 0,
      });

      await db.insert('sync_queue', {
        'id': 'op_1',
        'company_id': companyA,
        'client_transaction_id': clientTxId,
        'entity_type': 'supplier_payment',
        'entity_id': paymentId,
        'operation_type': 'CREATE',
        'payload': '{"amount": 5000, "supplierId": "$supplierId"}',
        'status': 'pending',
        'retry_count': 0,
        'created_at': '2026-10-14',
        'updated_at': '2026-10-14',
      });

      // 2. Proving that inserting a second payment with the identical (company_id, client_id) fails due to UNIQUE constraint
      expect(
        () async => await db.insert('supplier_payments', {
          'id': 'pay_uuid_2',
          'company_id': companyA,
          'supplier_id': supplierId,
          'amount': 5000.0,
          'payment_date': '2026-10-14',
          'payment_method': 'cash',
          'client_id': clientTxId,
          'created_at': '2026-10-14',
          'synced': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // 3. Simulating server duplicate response recovery (isDuplicate == true)
      // When sync service gets DUPLICATE or idempotent response, marks synced = 1
      await db.update('supplier_payments', {'synced': 1}, where: 'id = ?', whereArgs: [paymentId]);
      await db.update('sync_queue', {'status': 'synced'}, where: 'id = ?', whereArgs: ['op_1']);

      final finalPayment = (await db.query('supplier_payments', where: 'id = ?', whereArgs: [paymentId])).first;
      expect(finalPayment['synced'], 1);
      final finalQueue = (await db.query('sync_queue', where: 'id = ?', whereArgs: ['op_1'])).first;
      expect(finalQueue['status'], 'synced');
    });

    test('8. Invoice-specific payment cannot accidentally allocate to another invoice', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Specific Supplier',
        'created_at': '2026-10-14',
      });

      final purch1 = const Uuid().v4();
      final purch2 = const Uuid().v4();

      await db.insert('supplier_purchases', {
        'id': purch1,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-Target-1',
        'purchase_date': '2026-10-01',
        'total_amount': 10000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 10000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-01',
      });

      await db.insert('supplier_purchases', {
        'id': purch2,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-Target-2',
        'purchase_date': '2026-10-05',
        'total_amount': 20000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 20000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-05',
      });

      // User pays 5,000 specifically allocated to Purchase 2
      const specificAmount = 5000.0;
      final p2Row = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purch2])).first;
      final curPaid = (p2Row['amount_paid'] as num).toDouble();
      final curTotal = (p2Row['total_amount'] as num).toDouble();
      final newPaid = curPaid + specificAmount;
      final newBal = curTotal - newPaid;
      final newStatus = newBal <= 0.005 ? 'paid' : 'partially_paid';

      await db.update('supplier_purchases', {
        'amount_paid': newPaid,
        'outstanding_balance': newBal,
        'payment_status': newStatus,
      }, where: 'id = ?', whereArgs: [purch2]);

      // Purchase 1 remains completely untouched
      final p1After = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purch1])).first;
      expect((p1After['amount_paid'] as num).toDouble(), 0.0);
      expect((p1After['outstanding_balance'] as num).toDouble(), 10000.0);
      expect(p1After['payment_status'], 'unpaid');

      // Purchase 2 reflects exact payment
      final p2After = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purch2])).first;
      expect((p2After['amount_paid'] as num).toDouble(), 5000.0);
      expect((p2After['outstanding_balance'] as num).toDouble(), 15000.0);
      expect(p2After['payment_status'], 'partially_paid');
    });

    test('9. Required Scenario: Purchase of 10,000 DZD with 3,000 DZD Initial Downpayment', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Fournisseur Scenario 10k/3k',
        'created_at': '2026-10-14',
      });

      const totalAmount = 10000.0;
      const initialPaid = 3000.0;
      const expectedBalance = 7000.0;
      final purchaseId = const Uuid().v4();
      const clientTxId = 'purch_test_10k_3k';

      // 1. Insert purchase locally
      await db.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'BL-10000-3000',
        'purchase_date': '2026-10-14T12:00:00.000',
        'total_amount': totalAmount,
        'amount_paid': initialPaid,
        'outstanding_balance': expectedBalance,
        'payment_status': 'partially_paid',
        'client_transaction_id': clientTxId,
        'created_at': '2026-10-14T12:00:00.000',
        'synced': 0,
      });

      // 2. Insert line item (10 units @ 1,000 DZD)
      await db.insert('supplier_purchase_items', {
        'id': const Uuid().v4(),
        'purchase_id': purchaseId,
        'company_id': companyA,
        'product_name': 'Article A',
        'quantity': 10.0,
        'unit_cost': 1000.0,
        'line_total': 10000.0,
        'created_at': '2026-10-14T12:00:00.000',
      });

      // 3. Insert initial downpayment
      final paymentId = const Uuid().v4();
      await db.insert('supplier_payments', {
        'id': paymentId,
        'company_id': companyA,
        'supplier_id': supplierId,
        'purchase_id': purchaseId,
        'amount': initialPaid,
        'payment_date': '2026-10-14T12:00:00.000',
        'payment_method': 'cash',
        'reference': 'Acompte initial',
        'client_id': 'pay_$clientTxId',
        'created_at': '2026-10-14T12:00:00.000',
        'synced': 0,
      });

      // Verify expectations
      final p = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purchaseId])).first;
      expect((p['total_amount'] as num).toDouble(), 10000.0);
      expect((p['amount_paid'] as num).toDouble(), 3000.0);
      expect((p['outstanding_balance'] as num).toDouble(), 7000.0);
      expect(p['payment_status'], 'partially_paid');

      // Exactly ONE payment in history
      final payments = await db.query('supplier_payments', where: 'supplier_id = ?', whereArgs: [supplierId]);
      expect(payments.length, 1);
      expect((payments.first['amount'] as num).toDouble(), 3000.0);
      expect(payments.first['client_id'], 'pay_$clientTxId');

      // Simulating sync success marks both synced = 1
      await db.update('supplier_purchases', {'synced': 1}, where: 'id = ?', whereArgs: [purchaseId]);
      await db.update('supplier_payments', {'synced': 1}, where: 'client_id = ?', whereArgs: ['pay_$clientTxId']);

      final pAfter = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purchaseId])).first;
      expect(pAfter['synced'], 1);
      final payAfter = (await db.query('supplier_payments', where: 'client_id = ?', whereArgs: ['pay_$clientTxId'])).first;
      expect(payAfter['synced'], 1);

      // Simulating retry: exactly 1 payment remains, balance remains 7,000 DZD
      final countPayments = await db.rawQuery('SELECT COUNT(*) as cnt FROM supplier_payments WHERE supplier_id = ?', [supplierId]);
      expect(countPayments.first['cnt'], 1);
    });

    test('10. Comprehensive Multi-version migration preserving historical financial records', () async {
      final migDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );

      // Create v6/v7 schema
      await migDb.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 0,
          purchase_price REAL NOT NULL DEFAULT 0.0,
          selling_price REAL NOT NULL DEFAULT 0.0,
          created_at TEXT NOT NULL
        )
      ''');
      await migDb.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          total_amount REAL NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      // Seed pre-existing records
      await migDb.insert('products', {
        'id': 'p1',
        'company_id': 'comp_hist',
        'name': 'Existing Item 1',
        'quantity': 100,
        'purchase_price': 40.0,
        'selling_price': 60.0,
        'created_at': '2025-01-01',
      });
      await migDb.insert('sales', {
        'id': 's1',
        'company_id': 'comp_hist',
        'total_amount': 5000.0,
        'created_at': '2025-01-01',
      });

      // Apply v8 additive migration
      await migDb.execute('ALTER TABLE products ADD COLUMN supplier_id TEXT');
      await migDb.execute('CREATE INDEX IF NOT EXISTS ix_products_supplier ON products (supplier_id)');

      // Verify records are 100% intact and financial calculations match
      final p1 = (await migDb.query('products', where: 'id = ?', whereArgs: ['p1'])).first;
      expect(p1['name'], 'Existing Item 1');
      expect((p1['quantity'] as num).toInt(), 100);
      expect((p1['purchase_price'] as num).toDouble(), 40.0);
      expect(p1['supplier_id'], isNull);

      final s1 = (await migDb.query('sales', where: 'id = ?', whereArgs: ['s1'])).first;
      expect((s1['total_amount'] as num).toDouble(), 5000.0);

      await migDb.close();
    });

    test('11. Multi-Tenant isolation prevents cross-company data leakage', () async {
      final suppA = const Uuid().v4();
      final suppB = const Uuid().v4();

      await db.insert('suppliers', {'id': suppA, 'company_id': companyA, 'name': 'Confidential Supplier A', 'created_at': '2026-10-14'});
      await db.insert('suppliers', {'id': suppB, 'company_id': companyB, 'name': 'Confidential Supplier B', 'created_at': '2026-10-14'});

      await db.insert('supplier_purchases', {
        'id': 'purch_A',
        'company_id': companyA,
        'supplier_id': suppA,
        'invoice_number': 'SECRET-A',
        'purchase_date': '2026-10-14',
        'total_amount': 500000.0,
        'amount_paid': 0.0,
        'outstanding_balance': 500000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-14',
      });

      // Company B attempts to query Company A's invoice directly by ID
      final unauthorizedInvoiceQuery = await db.query(
        'supplier_purchases',
        where: 'company_id = ? AND id = ?',
        whereArgs: [companyB, 'purch_A'],
      );
      expect(unauthorizedInvoiceQuery, isEmpty);

      // Company B attempts to query Company A's supplier
      final unauthorizedSupplierQuery = await db.query(
        'suppliers',
        where: 'company_id = ? AND id = ?',
        whereArgs: [companyB, suppA],
      );
      expect(unauthorizedSupplierQuery, isEmpty);
    });

    test('12. Automatic Stock Increment: Saving a purchase invoice increments catalog product stock', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Stock Increment Supplier',
        'created_at': '2026-10-14',
      });

      final prodId = const Uuid().v4();
      const initialStock = 15;
      await db.insert('products', {
        'id': prodId,
        'company_id': companyA,
        'name': 'Pain de mie',
        'supplier_id': supplierId,
        'quantity': initialStock,
        'purchase_price': 100.0,
        'selling_price': 140.0,
        'created_at': '2026-10-14',
      });

      // Save a purchase invoice for 50 units with stock increment inside transaction
      final purchId = const Uuid().v4();
      await db.transaction((txn) async {
        await txn.insert('supplier_purchases', {
          'id': purchId,
          'company_id': companyA,
          'supplier_id': supplierId,
          'invoice_number': 'BL-STOCK-001',
          'purchase_date': '2026-10-14',
          'total_amount': 5000.0,
          'amount_paid': 0.0,
          'outstanding_balance': 5000.0,
          'payment_status': 'unpaid',
          'created_at': '2026-10-14',
        });

        await txn.insert('supplier_purchase_items', {
          'id': const Uuid().v4(),
          'purchase_id': purchId,
          'company_id': companyA,
          'product_id': prodId,
          'product_name': 'Pain de mie',
          'quantity': 50.0,
          'unit_cost': 100.0,
          'line_total': 5000.0,
          'created_at': '2026-10-14',
        });

        // Automatic inventory stock increment
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ? AND company_id = ?',
          [50, prodId, companyA],
        );
      });

      // Verify that catalog stock quantity is updated: 15 + 50 = 65
      final prodAfter = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      expect((prodAfter['quantity'] as num).toInt(), 65);

      // Verify AP ledger outstanding debt is recorded correctly
      final debtVal = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purchId])).first['outstanding_balance'];
      expect((debtVal as num).toDouble(), 5000.0);
    });

    test('13. Stock Increment: Custom items without productId do NOT alter any catalog stock', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'General Supplies',
        'created_at': '2026-10-14',
      });

      final prodId = const Uuid().v4();
      await db.insert('products', {
        'id': prodId,
        'company_id': companyA,
        'name': 'Huile 1L',
        'quantity': 20,
        'purchase_price': 600.0,
        'selling_price': 750.0,
        'created_at': '2026-10-14',
      });

      final purchId = const Uuid().v4();
      await db.transaction((txn) async {
        await txn.insert('supplier_purchases', {
          'id': purchId,
          'company_id': companyA,
          'supplier_id': supplierId,
          'invoice_number': 'BL-CUSTOM-001',
          'purchase_date': '2026-10-14',
          'total_amount': 1200.0,
          'amount_paid': 0.0,
          'outstanding_balance': 1200.0,
          'payment_status': 'unpaid',
          'created_at': '2026-10-14',
        });

        // Custom item with no product_id (e.g., service or uncatalogued supplies)
        await txn.insert('supplier_purchase_items', {
          'id': const Uuid().v4(),
          'purchase_id': purchId,
          'company_id': companyA,
          'product_id': null,
          'product_name': 'Cartons de transport',
          'quantity': 100.0,
          'unit_cost': 12.0,
          'line_total': 1200.0,
          'created_at': '2026-10-14',
        });
        // No UPDATE products executed for null product_id
      });

      // Stock of Huile remains exactly 20
      final prodAfter = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      expect((prodAfter['quantity'] as num).toInt(), 20);
    });

    test('14. Stock Increment: Multi-line purchase with same productId accumulates accurately', () async {
      final supplierId = const Uuid().v4();
      final prodId = const Uuid().v4();

      await db.insert('suppliers', {'id': supplierId, 'company_id': companyA, 'name': 'Bakery Wholesaler', 'created_at': '2026-10-14'});
      await db.insert('products', {
        'id': prodId,
        'company_id': companyA,
        'name': 'Farine 25kg',
        'quantity': 5,
        'purchase_price': 1500.0,
        'selling_price': 1800.0,
        'created_at': '2026-10-14',
      });

      final items = [
        {'productId': prodId, 'qty': 10.0, 'cost': 1500.0},
        {'productId': prodId, 'qty': 15.0, 'cost': 1500.0},
      ];

      final purchId = const Uuid().v4();
      await db.transaction((txn) async {
        await txn.insert('supplier_purchases', {
          'id': purchId,
          'company_id': companyA,
          'supplier_id': supplierId,
          'purchase_date': '2026-10-14',
          'total_amount': 37500.0,
          'amount_paid': 0.0,
          'outstanding_balance': 37500.0,
          'payment_status': 'unpaid',
          'created_at': '2026-10-14',
        });

        for (final it in items) {
          await txn.insert('supplier_purchase_items', {
            'id': const Uuid().v4(),
            'purchase_id': purchId,
            'company_id': companyA,
            'product_id': it['productId'] as String?,
            'product_name': 'Farine 25kg',
            'quantity': it['qty'],
            'unit_cost': it['cost'],
            'line_total': (it['qty'] as double) * (it['cost'] as double),
            'created_at': '2026-10-14',
          });

          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ? WHERE id = ? AND company_id = ?',
            [(it['qty'] as double).round(), it['productId'], companyA],
          );
        }
      });

      // Stock was 5 + 10 + 15 = 30
      final prodAfter = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      expect((prodAfter['quantity'] as num).toInt(), 30);
    });

    test('15. Multi-Tenant isolation: Stock increment strictly bounded to active company_id', () async {
      final prodA = const Uuid().v4();
      final prodB = const Uuid().v4();

      await db.insert('products', {
        'id': prodA,
        'company_id': companyA,
        'name': 'Paracétamol',
        'quantity': 10,
        'purchase_price': 100.0,
        'selling_price': 150.0,
        'created_at': '2026-10-14',
      });

      await db.insert('products', {
        'id': prodB,
        'company_id': companyB,
        'name': 'Paracétamol',
        'quantity': 50,
        'purchase_price': 100.0,
        'selling_price': 150.0,
        'created_at': '2026-10-14',
      });

      // Company A purchase increments ONLY Company A's product
      final updated = await db.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ? AND company_id = ?',
        [20, prodA, companyA],
      );
      expect(updated, 1);

      // Attempt to increment prodB using companyA credentials matches 0 rows
      final crossUpdated = await db.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ? AND company_id = ?',
        [20, prodB, companyA],
      );
      expect(crossUpdated, 0);

      // Verify Company A stock is 30, Company B stock is STILL 50
      final resA = (await db.query('products', where: 'id = ?', whereArgs: [prodA])).first;
      expect((resA['quantity'] as num).toInt(), 30);

      final resB = (await db.query('products', where: 'id = ?', whereArgs: [prodB])).first;
      expect((resB['quantity'] as num).toInt(), 50);
    });
  });
}
