import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Desktop SQLite Supplier Purchases & AP Ledger Tests', () {
    late Database db;
    const companyA = 'comp_alpha';
    const companyB = 'comp_beta';

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Create full schema mirroring desktop_database.dart
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
          supplier_name TEXT,
          stock_quantity INTEGER NOT NULL DEFAULT 0,
          purchase_price REAL NOT NULL DEFAULT 0.0,
          sale_price REAL NOT NULL DEFAULT 0.0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_purchases (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          supplier_id TEXT NOT NULL,
          invoice_number TEXT NOT NULL,
          purchase_date TEXT NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0.0,
          remaining_balance REAL NOT NULL,
          payment_status TEXT NOT NULL DEFAULT 'unpaid',
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_purchase_items (
          id TEXT PRIMARY KEY,
          purchase_id TEXT NOT NULL,
          product_id TEXT,
          product_name TEXT NOT NULL,
          quantity REAL NOT NULL DEFAULT 1,
          unit_cost REAL NOT NULL,
          total_cost REAL NOT NULL
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
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Creating a purchase invoice with initial partial payment records balance accurately', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Grossiste Central',
        'created_at': DateTime.now().toIso8601String(),
      });

      final purchaseId = const Uuid().v4();
      const totalAmount = 50000.0;
      const initialPaid = 20000.0;
      const remaining = 30000.0;

      await db.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-2026-001',
        'purchase_date': '2026-10-14',
        'total_amount': totalAmount,
        'paid_amount': initialPaid,
        'remaining_balance': remaining,
        'payment_status': 'partial',
        'notes': 'Initial stock order',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      await db.insert('supplier_payments', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': supplierId,
        'purchase_id': purchaseId,
        'amount': initialPaid,
        'payment_date': '2026-10-14',
        'payment_method': 'cash',
        'reference': 'Acompte',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      final rows = await db.rawQuery('''
        SELECT 
          s.*,
          COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
          COALESCE(SUM(p.paid_amount), 0) as total_purchases_paid,
          COALESCE(SUM(p.remaining_balance), 0) as outstanding_balance
        FROM suppliers s
        LEFT JOIN supplier_purchases p ON p.supplier_id = s.id AND p.company_id = s.company_id
        WHERE s.company_id = ?
        GROUP BY s.id
      ''', [companyA]);

      expect(rows.length, 1);
      final r = rows.first;
      expect((r['total_purchases_amount'] as num).toDouble(), 50000.0);
      expect((r['total_purchases_paid'] as num).toDouble(), 20000.0);
      expect((r['outstanding_balance'] as num).toDouble(), 30000.0);
    });

    test('2. Strict separation: stock asset valuation vs accounts payable debt', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Pharmalab',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Product assigned to supplier: 100 units @ 250 DZD = 25,000 DZD stock asset
      await db.insert('products', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'name': 'Paracetamol 500mg',
        'supplier_id': supplierId,
        'stock_quantity': 100,
        'purchase_price': 250.0,
        'sale_price': 350.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Real purchase debt invoice: 10,000 DZD total, 0 paid -> 10,000 DZD AP debt
      await db.insert('supplier_purchases', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-PHARM-01',
        'purchase_date': '2026-10-14',
        'total_amount': 10000.0,
        'paid_amount': 0.0,
        'remaining_balance': 10000.0,
        'payment_status': 'unpaid',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      // Compute stock valuation
      final stockValRows = await db.rawQuery('''
        SELECT COALESCE(SUM(stock_quantity * purchase_price), 0) as val
        FROM products
        WHERE company_id = ? AND supplier_id = ?
      ''', [companyA, supplierId]);
      final stockValuation = (stockValRows.first['val'] as num).toDouble();

      // Compute debt
      final debtRows = await db.rawQuery('''
        SELECT COALESCE(SUM(remaining_balance), 0) as debt
        FROM supplier_purchases
        WHERE company_id = ? AND supplier_id = ?
      ''', [companyA, supplierId]);
      final debt = (debtRows.first['debt'] as num).toDouble();

      expect(stockValuation, 25000.0);
      expect(debt, 10000.0);
      expect(stockValuation, isNot(equals(debt)));
    });

    test('3. FIFO payment allocation clears oldest purchase first and updates status to paid', () async {
      final supplierId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supplierId,
        'company_id': companyA,
        'name': 'Alimentation Générale Grossiste',
        'created_at': DateTime.now().toIso8601String(),
      });

      final p1Id = const Uuid().v4();
      final p2Id = const Uuid().v4();

      // Invoice 1: 15,000 DZD unpaid
      await db.insert('supplier_purchases', {
        'id': p1Id,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-001',
        'purchase_date': '2026-10-01',
        'total_amount': 15000.0,
        'paid_amount': 0.0,
        'remaining_balance': 15000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-01T10:00:00',
        'synced': 1,
      });

      // Invoice 2: 25,000 DZD unpaid
      await db.insert('supplier_purchases', {
        'id': p2Id,
        'company_id': companyA,
        'supplier_id': supplierId,
        'invoice_number': 'INV-002',
        'purchase_date': '2026-10-05',
        'total_amount': 25000.0,
        'paid_amount': 0.0,
        'remaining_balance': 25000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-05T10:00:00',
        'synced': 1,
      });

      // User makes a payment of 20,000 DZD -> Should fully pay INV-001 (15,000) and 5,000 toward INV-002
      const paymentAmount = 20000.0;
      final unpaid = await db.query(
        'supplier_purchases',
        where: 'company_id = ? AND supplier_id = ? AND remaining_balance > 0',
        whereArgs: [companyA, supplierId],
        orderBy: 'purchase_date ASC, created_at ASC',
      );

      double remainingToAlloc = paymentAmount;
      for (final p in unpaid) {
        if (remainingToAlloc <= 0) break;
        final pId = p['id']?.toString() ?? '';
        final pPaid = ((p['paid_amount'] ?? 0.0) as num).toDouble();
        final pRem = ((p['remaining_balance'] ?? 0.0) as num).toDouble();

        final alloc = remainingToAlloc < pRem ? remainingToAlloc : pRem;
        final newPaid = pPaid + alloc;
        final newRem = pRem - alloc;
        final newStatus = newRem <= 0.001 ? 'paid' : 'partial';

        await db.update(
          'supplier_purchases',
          {
            'paid_amount': newPaid,
            'remaining_balance': newRem < 0 ? 0 : newRem,
            'payment_status': newStatus,
          },
          where: 'id = ?',
          whereArgs: [pId],
        );
        remainingToAlloc -= alloc;
      }

      await db.insert('supplier_payments', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': supplierId,
        'amount': paymentAmount,
        'payment_date': '2026-10-14',
        'payment_method': 'bank_transfer',
        'reference': 'VIR-0921',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      final updatedP1 = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [p1Id])).first;
      expect((updatedP1['paid_amount'] as num).toDouble(), 15000.0);
      expect((updatedP1['remaining_balance'] as num).toDouble(), 0.0);
      expect(updatedP1['payment_status'], 'paid');

      final updatedP2 = (await db.query('supplier_purchases', where: 'id = ?', whereArgs: [p2Id])).first;
      expect((updatedP2['paid_amount'] as num).toDouble(), 5000.0);
      expect((updatedP2['remaining_balance'] as num).toDouble(), 20000.0);
      expect(updatedP2['payment_status'], 'partial');
    });

    test('4. Cross-company multi-tenant isolation', () async {
      final suppA = const Uuid().v4();
      final suppB = const Uuid().v4();

      await db.insert('suppliers', {'id': suppA, 'company_id': companyA, 'name': 'Fournisseur A', 'created_at': '2026-10-01'});
      await db.insert('suppliers', {'id': suppB, 'company_id': companyB, 'name': 'Fournisseur B', 'created_at': '2026-10-01'});

      await db.insert('supplier_purchases', {
        'id': const Uuid().v4(),
        'company_id': companyA,
        'supplier_id': suppA,
        'invoice_number': 'INV-A',
        'purchase_date': '2026-10-01',
        'total_amount': 70000.0,
        'paid_amount': 0.0,
        'remaining_balance': 70000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-01',
      });

      await db.insert('supplier_purchases', {
        'id': const Uuid().v4(),
        'company_id': companyB,
        'supplier_id': suppB,
        'invoice_number': 'INV-B',
        'purchase_date': '2026-10-01',
        'total_amount': 30000.0,
        'paid_amount': 0.0,
        'remaining_balance': 30000.0,
        'payment_status': 'unpaid',
        'created_at': '2026-10-01',
      });

      final rowsA = await db.rawQuery('''
        SELECT COALESCE(SUM(remaining_balance), 0) as debt
        FROM supplier_purchases
        WHERE company_id = ?
      ''', [companyA]);
      expect((rowsA.first['debt'] as num).toDouble(), 70000.0);

      final rowsB = await db.rawQuery('''
        SELECT COALESCE(SUM(remaining_balance), 0) as debt
        FROM supplier_purchases
        WHERE company_id = ?
      ''', [companyB]);
      expect((rowsB.first['debt'] as num).toDouble(), 30000.0);
    });

    test('5. Quantity-based stock replenishment and accurate unit cost calculation', () async {
      final suppId = const Uuid().v4();
      final prodId = const Uuid().v4();

      await db.insert('suppliers', {'id': suppId, 'company_id': companyA, 'name': 'Distributeur Boissons', 'created_at': '2026-10-01'});
      await db.insert('products', {
        'id': prodId,
        'company_id': companyA,
        'name': 'Jus Orange 1L',
        'supplier_id': suppId,
        'stock_quantity': 10,
        'purchase_price': 180.0,
        'sale_price': 250.0,
        'created_at': '2026-10-01',
      });

      // User purchases 50 bottles for a total amount of 10,000 DZD (unit cost = 200 DZD)
      const qtyPurchased = 50.0;
      const totalInvoiceAmt = 10000.0;
      const unitCost = totalInvoiceAmt / qtyPurchased;
      final purchaseId = const Uuid().v4();

      await db.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': companyA,
        'supplier_id': suppId,
        'invoice_number': 'FAC-2026-009',
        'purchase_date': '2026-10-15',
        'total_amount': totalInvoiceAmt,
        'paid_amount': totalInvoiceAmt,
        'remaining_balance': 0.0,
        'payment_status': 'paid',
        'notes': 'Jus Orange 1L',
        'created_at': '2026-10-15',
      });

      await db.insert('supplier_purchase_items', {
        'id': const Uuid().v4(),
        'purchase_id': purchaseId,
        'product_id': prodId,
        'product_name': 'Jus Orange 1L',
        'quantity': qtyPurchased,
        'unit_cost': unitCost,
        'total_cost': totalInvoiceAmt,
      });

      // Update product inventory
      final curProd = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      final oldStock = (curProd['stock_quantity'] as num).toInt();
      await db.update(
        'products',
        {
          'stock_quantity': oldStock + qtyPurchased.toInt(),
          'purchase_price': unitCost,
        },
        where: 'id = ?',
        whereArgs: [prodId],
      );

      final updatedProd = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      // Stock must be 10 + 50 = 60
      expect((updatedProd['stock_quantity'] as num).toInt(), 60);
      // Unit purchase cost must be 200 DZD (NOT 10,000 DZD!)
      expect((updatedProd['purchase_price'] as num).toDouble(), 200.0);

      // Verify purchase item records
      final pItems = await db.query('supplier_purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
      expect(pItems.length, 1);
      expect((pItems.first['quantity'] as num).toDouble(), 50.0);
      expect((pItems.first['unit_cost'] as num).toDouble(), 200.0);
      expect((pItems.first['total_cost'] as num).toDouble(), 10000.0);
    });
  });
}
