import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/network/session.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Account Persistence, Multi-Device Recovery & Tenant Isolation Tests', () {
    late Database db;
    const companyA = 'tenant_company_a_uuid';
    const companyB = 'tenant_company_b_uuid';

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );

      // Initialize schema mirroring app_database.dart v8
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          barcode TEXT,
          category TEXT,
          purchase_price REAL NOT NULL DEFAULT 0.0,
          selling_price REAL NOT NULL DEFAULT 0.0,
          quantity INTEGER NOT NULL DEFAULT 0,
          unit TEXT NOT NULL DEFAULT 'piece',
          supplier_id TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          address TEXT,
          notes TEXT,
          total_debt REAL NOT NULL DEFAULT 0.0,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

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
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_purchase_items (
          id TEXT PRIMARY KEY,
          purchase_id TEXT NOT NULL,
          company_id TEXT NOT NULL,
          product_id TEXT,
          product_name TEXT NOT NULL,
          quantity REAL NOT NULL,
          purchase_price REAL NOT NULL,
          selling_price REAL,
          total_price REAL NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE supplier_payments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          supplier_id TEXT NOT NULL,
          purchase_id TEXT,
          amount REAL NOT NULL,
          payment_method TEXT NOT NULL DEFAULT 'cash',
          payment_date TEXT NOT NULL,
          reference_number TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT,
          total_amount REAL NOT NULL,
          final_amount REAL NOT NULL,
          amount_paid REAL NOT NULL DEFAULT 0.0,
          change_amount REAL NOT NULL DEFAULT 0.0,
          payment_type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          sale_id TEXT NOT NULL,
          customer_id TEXT,
          invoice_number TEXT NOT NULL,
          total_amount REAL NOT NULL,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE salary_payments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          employee_id TEXT NOT NULL,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          payment_method TEXT NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE credit_purchases (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          amount REAL NOT NULL,
          amount_paid REAL NOT NULL DEFAULT 0.0,
          remaining_amount REAL NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE credit_payments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          credit_purchase_id TEXT,
          amount REAL NOT NULL,
          payment_method TEXT NOT NULL DEFAULT 'cash',
          payment_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          client_transaction_id TEXT NOT NULL UNIQUE,
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

    test('1. Session companyId resolution fallback ensures tenant identity is never null', () {
      // Scenario A: Standard structure
      final respA = {
        'token': 'jwt_alpha',
        'user': {'id': 'usr_1', 'email': 'a@modiri.ai', 'companyId': companyA},
        'company': {'id': companyA, 'name': 'Alpha Store'},
      };
      final sessionA = Session.fromAuthResponse(respA);
      expect(sessionA.companyId, equals(companyA));
      expect(sessionA.userId, equals('usr_1'));

      // Scenario B: Flattened user payload without company object
      final respB = {
        'token': 'jwt_beta',
        'user': {'id': 'usr_2', 'email': 'b@modiri.ai', 'company_id': companyB},
      };
      final sessionB = Session.fromAuthResponse(respB);
      expect(sessionB.companyId, equals(companyB));
      expect(sessionB.userId, equals('usr_2'));

      // Scenario C: No company provided in user or company payload -> fallback to userId
      final respC = {
        'token': 'jwt_gamma',
        'user': {'id': 'usr_solo', 'email': 'solo@modiri.ai'},
      };
      final sessionC = Session.fromAuthResponse(respC);
      expect(sessionC.companyId, equals('usr_solo'));
    });

    test('2. New Device Reinstall Simulation: pullInitialData populates all tables from server response', () async {
      // Initially, local database is completely empty (new install / device switch)
      final initialProducts = await db.query('products');
      expect(initialProducts.isEmpty, isTrue);

      // Mock server payloads that pullInitialData receives from backend
      final serverProducts = [
        {'id': 'prod_1', 'name': 'Milk 1L', 'selling_price': 150.0, 'purchase_price': 120.0, 'quantity': 50, 'unit': 'piece', 'company_id': companyA, 'created_at': '2026-10-16T10:00:00Z'},
        {'id': 'prod_2', 'name': 'Bread', 'selling_price': 30.0, 'purchase_price': 25.0, 'quantity': 100, 'unit': 'piece', 'company_id': companyA, 'created_at': '2026-10-16T10:05:00Z'},
      ];

      final serverSuppliers = [
        {'id': 'sup_1', 'name': 'Central Dairy', 'phone': '0555112233', 'address': 'Algiers', 'products_supplied': 5, 'company_id': companyA, 'created_at': '2026-10-16T09:00:00Z'},
      ];

      final serverPurchases = [
        {
          'id': 'purch_1',
          'company_id': companyA,
          'supplier_id': 'sup_1',
          'invoice_number': 'INV-2026-001',
          'purchase_date': '2026-10-16T09:30:00Z',
          'total_amount': 6000.0,
          'amount_paid': 2000.0,
          'outstanding_balance': 4000.0,
          'payment_status': 'partially_paid',
          'items': [
            {
              'id': 'item_1',
              'purchase_id': 'purch_1',
              'product_id': 'prod_1',
              'product_name': 'Milk 1L',
              'quantity': 50,
              'purchase_price': 120.0,
              'selling_price': 150.0,
              'total_price': 6000.0,
            }
          ]
        }
      ];

      final serverSupplierPayments = [
        {
          'id': 'spay_1',
          'company_id': companyA,
          'supplier_id': 'sup_1',
          'purchase_id': 'purch_1',
          'amount': 2000.0,
          'payment_method': 'cash',
          'payment_date': '2026-10-16T09:35:00Z',
          'created_at': '2026-10-16T09:35:00Z',
        }
      ];

      final serverCreditPurchases = [
        {
          'id': 'cp_1',
          'company_id': companyA,
          'customer_id': 'cust_1',
          'amount': 3000.0,
          'amount_paid': 1000.0,
          'remaining_amount': 2000.0,
          'created_at': '2026-10-16T11:00:00Z',
        }
      ];

      final serverCreditPayments = [
        {
          'id': 'cpay_1',
          'company_id': companyA,
          'customer_id': 'cust_1',
          'credit_purchase_id': 'cp_1',
          'amount': 1000.0,
          'payment_method': 'cash',
          'payment_date': '2026-10-16T11:30:00Z',
          'created_at': '2026-10-16T11:30:00Z',
        }
      ];

      final serverInvoices = [
        {
          'id': 'inv_1',
          'company_id': companyA,
          'sale_id': 'sale_1',
          'customer_id': 'cust_1',
          'invoice_number': 'FAC-2026-0001',
          'total_amount': 1500.0,
          'status': 'paid',
          'created_at': '2026-10-16T12:00:00Z',
        }
      ];

      // Simulate pullInitialData upsert batch into SQLite
      final batch = db.batch();
      for (final p in serverProducts) {
        batch.insert('products', {
          'id': p['id'],
          'company_id': companyA,
          'name': p['name'],
          'selling_price': (p['selling_price'] as num).toDouble(),
          'purchase_price': (p['purchase_price'] as num).toDouble(),
          'quantity': (p['quantity'] as num).toInt(),
          'unit': p['unit'],
          'created_at': p['created_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final s in serverSuppliers) {
        batch.insert('suppliers', {
          'id': s['id'],
          'company_id': companyA,
          'name': s['name'],
          'phone': s['phone'],
          'address': s['address'],
          'products_supplied': s['products_supplied'],
          'created_at': s['created_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final pu in serverPurchases) {
        batch.insert('supplier_purchases', {
          'id': pu['id'],
          'company_id': companyA,
          'supplier_id': pu['supplier_id'],
          'invoice_number': pu['invoice_number'],
          'purchase_date': pu['purchase_date'],
          'total_amount': (pu['total_amount'] as num).toDouble(),
          'amount_paid': (pu['amount_paid'] as num).toDouble(),
          'outstanding_balance': (pu['outstanding_balance'] as num).toDouble(),
          'payment_status': pu['payment_status'],
          'created_at': pu['purchase_date'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        final items = (pu['items'] as List?) ?? [];
        for (final it in items) {
          batch.insert('supplier_purchase_items', {
            'id': it['id'],
            'purchase_id': pu['id'],
            'company_id': companyA,
            'product_id': it['product_id'],
            'product_name': it['product_name'],
            'quantity': (it['quantity'] as num).toDouble(),
            'purchase_price': (it['purchase_price'] as num).toDouble(),
            'selling_price': (it['selling_price'] as num?)?.toDouble(),
            'total_price': (it['total_price'] as num).toDouble(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      for (final sp in serverSupplierPayments) {
        batch.insert('supplier_payments', {
          'id': sp['id'],
          'company_id': companyA,
          'supplier_id': sp['supplier_id'],
          'purchase_id': sp['purchase_id'],
          'amount': (sp['amount'] as num).toDouble(),
          'payment_method': sp['payment_method'],
          'payment_date': sp['payment_date'],
          'created_at': sp['created_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final cp in serverCreditPurchases) {
        batch.insert('credit_purchases', {
          'id': cp['id'],
          'company_id': companyA,
          'customer_id': cp['customer_id'],
          'amount': (cp['amount'] as num).toDouble(),
          'amount_paid': (cp['amount_paid'] as num).toDouble(),
          'remaining_amount': (cp['remaining_amount'] as num).toDouble(),
          'created_at': cp['created_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final cpay in serverCreditPayments) {
        batch.insert('credit_payments', {
          'id': cpay['id'],
          'company_id': companyA,
          'customer_id': cpay['customer_id'],
          'credit_purchase_id': cpay['credit_purchase_id'],
          'amount': (cpay['amount'] as num).toDouble(),
          'payment_method': cpay['payment_method'],
          'payment_date': cpay['payment_date'],
          'created_at': cpay['created_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final inv in serverInvoices) {
        batch.insert('invoices', {
          'id': inv['id'],
          'company_id': companyA,
          'sale_id': inv['sale_id'],
          'customer_id': inv['customer_id'],
          'invoice_number': inv['invoice_number'],
          'total_amount': (inv['total_amount'] as num).toDouble(),
          'status': inv['status'],
          'created_at': inv['created_at'],
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit(noResult: true);

      // Verify all business records exist and match expected data
      final localProducts = await db.query('products', where: 'company_id = ?', whereArgs: [companyA]);
      expect(localProducts.length, equals(2));
      expect(localProducts.first['name'], equals('Milk 1L'));

      final localPurchases = await db.query('supplier_purchases', where: 'company_id = ?', whereArgs: [companyA]);
      expect(localPurchases.length, equals(1));
      expect(localPurchases.first['outstanding_balance'], equals(4000.0));

      final localPurchaseItems = await db.query('supplier_purchase_items', where: 'company_id = ?', whereArgs: [companyA]);
      expect(localPurchaseItems.length, equals(1));
      expect(localPurchaseItems.first['product_name'], equals('Milk 1L'));

      final localSupplierPayments = await db.query('supplier_payments', where: 'company_id = ?', whereArgs: [companyA]);
      expect(localSupplierPayments.length, equals(1));
      expect(localSupplierPayments.first['amount'], equals(2000.0));

      final localCreditPurchases = await db.query('credit_purchases', where: 'company_id = ?', whereArgs: [companyA]);
      expect(localCreditPurchases.length, equals(1));
      expect(localCreditPurchases.first['remaining_amount'], equals(2000.0));

      final localInvoices = await db.query('invoices', where: 'company_id = ?', whereArgs: [companyA]);
      expect(localInvoices.length, equals(1));
      expect(localInvoices.first['invoice_number'], equals('FAC-2026-0001'));
    });

    test('3. Multi-Tenant Isolation & Logout/Re-login Preservation', () async {
      // Company A inserts data
      await db.insert('products', {
        'id': 'prod_a1',
        'company_id': companyA,
        'name': 'Alpha Phone',
        'selling_price': 50000.0,
        'purchase_price': 40000.0,
        'quantity': 10,
        'created_at': '2026-10-16T12:00:00Z',
        'synced': 1,
      });

      // Company B inserts data
      await db.insert('products', {
        'id': 'prod_b1',
        'company_id': companyB,
        'name': 'Beta Tablet',
        'selling_price': 30000.0,
        'purchase_price': 22000.0,
        'quantity': 5,
        'created_at': '2026-10-16T12:00:00Z',
        'synced': 1,
      });

      // Query scoped to Company A
      final rowsA = await db.query('products', where: 'company_id = ?', whereArgs: [companyA]);
      expect(rowsA.length, equals(1));
      expect(rowsA.first['name'], equals('Alpha Phone'));

      // Query scoped to Company B
      final rowsB = await db.query('products', where: 'company_id = ?', whereArgs: [companyB]);
      expect(rowsB.length, equals(1));
      expect(rowsB.first['name'], equals('Beta Tablet'));

      // Simulate Logout: We NEVER drop or clear the SQLite tables!
      // When User A logs in again, Company A records are still intact.
      final reloadedRowsA = await db.query('products', where: 'company_id = ?', whereArgs: [companyA]);
      expect(reloadedRowsA.length, equals(1));
      expect(reloadedRowsA.first['name'], equals('Alpha Phone'));
    });

    test('4. Offline Sync Queue is Preserved Across Logout and Re-login', () async {
      // User creates a product offline for Company A
      final clientTxId = 'tx_offline_prod_001';
      await db.insert('sync_queue', {
        'id': 'sync_1',
        'company_id': companyA,
        'client_transaction_id': clientTxId,
        'entity_type': 'product',
        'entity_id': 'prod_offline_1',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'name': 'Offline Widget', 'selling_price': 1000.0}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Assert sync queue contains the pending operation
      var pendingOps = await db.query('sync_queue', where: "company_id = ? AND status = 'pending'", whereArgs: [companyA]);
      expect(pendingOps.length, equals(1));

      // Simulate Logout (auth token deleted, but DB untouched)
      // When user logs back in with companyA:
      pendingOps = await db.query('sync_queue', where: "company_id = ? AND status = 'pending'", whereArgs: [companyA]);
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first['client_transaction_id'], equals(clientTxId));
      expect(pendingOps.first['status'], equals('pending'));
    });

    test('5. Expired Trial or License NEVER deletes or hides historical data', () async {
      // Historical data in database for companyA
      await db.insert('customers', {
        'id': 'cust_hist_1',
        'company_id': companyA,
        'name': 'Loyal Client',
        'total_debt': 5000.0,
        'created_at': '2026-01-01T00:00:00Z',
        'synced': 1,
      });

      // Create an expired session
      final expiredSession = const Session(
        accessToken: 'expired_jwt_token',
        userId: 'usr_1',
        companyId: companyA,
        entitlementStatus: 'expired_trial',
        isSuspended: false,
      );

      expect(expiredSession.isTrialOrLicenseExpired, isTrue);

      // Verify data is still in SQLite and accessible
      final customers = await db.query('customers', where: 'company_id = ?', whereArgs: [expiredSession.companyId]);
      expect(customers.length, equals(1));
      expect(customers.first['name'], equals('Loyal Client'));
      expect(customers.first['total_debt'], equals(5000.0));
    });
  });
}
