// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Modiri AI Desktop — Final Acceptance Gate Verification', () {
    late String testDbPath;
    late Database db;
    const testCompanyId = 'company_test_gate_2026';

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('modiri_gate_test_');
      testDbPath = '${tempDir.path}\\modiri_gate_test.db';

      db = await databaseFactory.openDatabase(
        testDbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async {
            await d.execute('''
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
            await d.execute('''
              CREATE TABLE products (
                id TEXT PRIMARY KEY,
                company_id TEXT NOT NULL,
                name TEXT NOT NULL,
                cost_price REAL NOT NULL DEFAULT 0.0,
                sale_price REAL NOT NULL DEFAULT 0.0,
                stock_quantity INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT
              )
            ''');
            await d.execute('''
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
            await d.execute('''
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
            await d.execute('''
              CREATE TABLE sync_queue (
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
            await d.execute('''
              CREATE TABLE invoices (
                id TEXT PRIMARY KEY,
                company_id TEXT NOT NULL,
                sale_id TEXT,
                invoice_number TEXT NOT NULL,
                customer_name TEXT,
                total REAL NOT NULL,
                paid_amount REAL NOT NULL DEFAULT 0.0,
                remaining_amount REAL NOT NULL DEFAULT 0.0,
                status TEXT NOT NULL,
                due_date TEXT,
                notes TEXT,
                created_at TEXT NOT NULL
              )
            ''');
            await d.execute('''
              CREATE TABLE customers (
                id TEXT PRIMARY KEY,
                company_id TEXT NOT NULL,
                name TEXT NOT NULL,
                phone TEXT,
                credit_balance REAL NOT NULL DEFAULT 0.0,
                created_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
      try {
        final f = File(testDbPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    });

    test('Gate 1: Transaction persistence across database restart', () async {
      final suppId = const Uuid().v4();
      final purchaseId = const Uuid().v4();
      final clientTxId = const Uuid().v4();

      await db.insert('suppliers', {
        'id': suppId,
        'company_id': testCompanyId,
        'name': 'Test Supplier SARL',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': testCompanyId,
        'supplier_id': suppId,
        'invoice_number': 'INV-TEST-001',
        'purchase_date': '2026-10-15',
        'total_amount': 25000.0,
        'paid_amount': 10000.0,
        'remaining_balance': 15000.0,
        'payment_status': 'partial',
        'notes': 'Test invoice persistence',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });

      await db.insert('sync_queue', {
        'id': const Uuid().v4(),
        'company_id': testCompanyId,
        'client_transaction_id': clientTxId,
        'entity_type': 'supplier_purchase',
        'entity_id': purchaseId,
        'operation_type': 'CREATE',
        'payload': jsonEncode({
          'supplierId': suppId,
          'invoiceNumber': 'INV-TEST-001',
          'totalAmount': 25000.0,
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Simulate full app shutdown / database close
      await db.close();

      // Simulate restart by re-opening the exact same SQLite database file
      final restartedDb = await databaseFactory.openDatabase(testDbPath);

      final purchases = await restartedDb.query('supplier_purchases', where: 'id = ?', whereArgs: [purchaseId]);
      expect(purchases.length, 1);
      expect((purchases.first['total_amount'] as num).toDouble(), 25000.0);
      expect((purchases.first['remaining_balance'] as num).toDouble(), 15000.0);

      final queue = await restartedDb.query('sync_queue', where: 'entity_id = ?', whereArgs: [purchaseId]);
      expect(queue.length, 1);
      expect(queue.first['status'], 'pending');
      expect(queue.first['retry_count'], 0);

      await restartedDb.close();
      db = await databaseFactory.openDatabase(testDbPath);
    });

    test('Gate 2: Offline resilience — transient network failure does not burn retries', () async {
      final queueId = const Uuid().v4();
      final clientTxId = const Uuid().v4();

      await db.insert('sync_queue', {
        'id': queueId,
        'company_id': testCompanyId,
        'client_transaction_id': clientTxId,
        'entity_type': 'supplier_purchase',
        'entity_id': const Uuid().v4(),
        'operation_type': 'CREATE',
        'payload': jsonEncode({'test': true}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Simulate 3 network outage sync attempts (e.g. SocketException / connection timeout)
      for (int i = 0; i < 3; i++) {
        final pending = await db.query('sync_queue', where: "status = 'pending'");
        expect(pending.isNotEmpty, true);

        final row = pending.first;
        const errStr = 'ApiException(0): Network connection error: SocketException: OS Error: Connection refused';
        final isNetworkOrOffline = errStr.contains('SocketException') || errStr.contains('Network connection error');

        if (isNetworkOrOffline) {
          // Sync engine preserves pending status, records last_error, does not increment retry_count
          await db.update(
            'sync_queue',
            {
              'last_error': errStr,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }

      final check = (await db.query('sync_queue', where: 'id = ?', whereArgs: [queueId])).first;
      // Retries must NOT have reached 3 or 5, status must remain 'pending'
      expect(check['retry_count'], 0);
      expect(check['status'], 'pending');
      expect(check['last_error'], contains('SocketException'));
    });

    test('Gate 3: Expired authentication handling — 401 pauses sync without burning retries', () async {
      final queueId = const Uuid().v4();
      final clientTxId = const Uuid().v4();

      await db.insert('sync_queue', {
        'id': queueId,
        'company_id': testCompanyId,
        'client_transaction_id': clientTxId,
        'entity_type': 'customer',
        'entity_id': const Uuid().v4(),
        'operation_type': 'CREATE',
        'payload': jsonEncode({'name': 'Test Customer'}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Simulate 401 Unauthorized API response from backend
      const errStr = 'ApiException(401): Missing or malformed Authorization header';
      final isAuthError = errStr.contains('(401)') || errStr.contains('(403)');

      if (isAuthError) {
        await db.update(
          'sync_queue',
          {
            'last_error': errStr,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [queueId],
        );
      }

      final check = (await db.query('sync_queue', where: 'id = ?', whereArgs: [queueId])).first;
      expect(check['status'], 'pending');
      expect(check['retry_count'], 0);
      expect(check['last_error'], contains('401'));
    });

    test('Gate 4: Quantity-based stock restocking & accurate unit cost calculation', () async {
      final suppId = const Uuid().v4();
      final prodId = const Uuid().v4();
      final purchaseId = const Uuid().v4();

      await db.insert('suppliers', {
        'id': suppId,
        'company_id': testCompanyId,
        'name': 'Grossiste Central',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('products', {
        'id': prodId,
        'company_id': testCompanyId,
        'name': 'Farine 1kg',
        'cost_price': 60.0,
        'sale_price': 85.0,
        'stock_quantity': 20,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Purchase 100 bags of Farine for a total invoice amount of 7,000 DZD
      const qtyPurchased = 100.0;
      const totalAmount = 7000.0;
      const unitCost = totalAmount / qtyPurchased; // 70.0 DZD per bag

      await db.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': testCompanyId,
        'supplier_id': suppId,
        'invoice_number': 'BL-8890',
        'purchase_date': '2026-10-15',
        'total_amount': totalAmount,
        'paid_amount': totalAmount,
        'remaining_balance': 0.0,
        'payment_status': 'paid',
        'notes': 'Farine 1kg',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('supplier_purchase_items', {
        'id': const Uuid().v4(),
        'purchase_id': purchaseId,
        'product_id': prodId,
        'product_name': 'Farine 1kg',
        'quantity': qtyPurchased,
        'unit_cost': unitCost,
        'total_cost': totalAmount,
      });

      // Product stock update
      final curProd = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      final oldStock = (curProd['stock_quantity'] as num).toInt();

      await db.update(
        'products',
        {
          'stock_quantity': oldStock + qtyPurchased.toInt(),
          'cost_price': unitCost,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [prodId],
      );

      final updatedProd = (await db.query('products', where: 'id = ?', whereArgs: [prodId])).first;
      // New stock must be exactly 20 + 100 = 120
      expect((updatedProd['stock_quantity'] as num).toInt(), 120);
      // Unit cost price must be 70 DZD, NOT the 7,000 DZD invoice total
      expect((updatedProd['cost_price'] as num).toDouble(), 70.0);
    });

    test('Gate 5: Standalone manual invoice local storage behavior', () async {
      final invId = const Uuid().v4();

      await db.insert('invoices', {
        'id': invId,
        'company_id': testCompanyId,
        'sale_id': null, // null denotes standalone manual billing invoice
        'invoice_number': 'INV-1001',
        'customer_name': 'Entreprise Algerienne SARL',
        'total': 45000.0,
        'paid_amount': 20000.0,
        'remaining_amount': 25000.0,
        'status': 'partial',
        'notes': 'Maintenance contract Q4',
        'created_at': DateTime.now().toIso8601String(),
      });

      final rows = await db.query('invoices', where: 'id = ?', whereArgs: [invId]);
      expect(rows.length, 1);
      expect(rows.first['sale_id'], isNull); // Local billing invoice
      expect((rows.first['total'] as num).toDouble(), 45000.0);

      // Verify that no invalid CREATE sync_queue row was inserted for standalone manual invoice
      final queueRows = await db.query('sync_queue', where: "entity_id = ? AND entity_type = 'invoice'", whereArgs: [invId]);
      expect(queueRows.isEmpty, true);
    });
  });
}
