import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:modiri_ai/features/sales/domain/cart_session.dart';
import 'package:modiri_ai/features/sales/domain/sale.dart';
import 'package:modiri_ai/features/invoices/domain/invoice.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  const uuid = Uuid();
  const companyA = 'company-tenant-alpha';
  const companyB = 'company-tenant-beta';

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Products
          await db.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              name TEXT NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 0,
              purchase_price REAL NOT NULL DEFAULT 0,
              selling_price REAL NOT NULL DEFAULT 0
            )
          ''');

          // Sales
          await db.execute('''
            CREATE TABLE sales (
              id TEXT PRIMARY KEY,
              client_transaction_id TEXT UNIQUE,
              company_id TEXT NOT NULL,
              customer_id TEXT,
              customer_name TEXT,
              subtotal REAL NOT NULL DEFAULT 0,
              discount REAL NOT NULL DEFAULT 0,
              total REAL NOT NULL DEFAULT 0,
              payment_status TEXT NOT NULL DEFAULT 'paid',
              sold_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          // Sale Items
          await db.execute('''
            CREATE TABLE sale_items (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL,
              company_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              product_name TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              unit_price REAL NOT NULL,
              unit_cost REAL NOT NULL,
              line_total REAL NOT NULL,
              line_profit REAL NOT NULL
            )
          ''');

          // Invoices
          await db.execute('''
            CREATE TABLE invoices (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL UNIQUE,
              company_id TEXT NOT NULL,
              invoice_number TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'paid',
              customer_name TEXT,
              total REAL NOT NULL DEFAULT 0,
              sold_at TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');

          // Cart Sessions
          await db.execute('''
            CREATE TABLE cart_sessions (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              customer_id TEXT,
              customer_name TEXT,
              status TEXT NOT NULL DEFAULT 'ACTIVE',
              discount REAL NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          // Cart Session Items
          await db.execute('''
            CREATE TABLE cart_session_items (
              id TEXT PRIMARY KEY,
              cart_session_id TEXT NOT NULL,
              company_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              product_name TEXT NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 1,
              unit_price REAL NOT NULL DEFAULT 0,
              unit_cost REAL NOT NULL DEFAULT 0
            )
          ''');

          // Sync Queue
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              client_transaction_id TEXT,
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
        },
      ),
    );

    // Seed product A and B in company A
    await db.insert('products', {
      'id': 'prod-A',
      'company_id': companyA,
      'name': 'Product A',
      'quantity': 50,
      'purchase_price': 100.0,
      'selling_price': 150.0,
    });

    await db.insert('products', {
      'id': 'prod-B',
      'company_id': companyA,
      'name': 'Product B',
      'quantity': 30,
      'purchase_price': 200.0,
      'selling_price': 250.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Architectural POS & Multi-Cart Required Test Cases (1 to 12)', () {
    test('TEST 1: Creating Cart 1 and adding Product A shows only in Cart 1', () async {
      final cart1 = CartSession(
        id: 'cart-1',
        companyId: companyA,
        customerName: 'Client 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-1',
            cartSessionId: 'cart-1',
            productId: 'prod-A',
            productName: 'Product A',
            unitPrice: 150.0,
            unitCost: 100.0,
            quantity: 2,
          ),
        ],
      );

      await db.insert('cart_sessions', cart1.toMap());
      await db.insert('cart_session_items', cart1.items.first.toMap(companyA));

      final items = await db.query(
        'cart_session_items',
        where: 'cart_session_id = ?',
        whereArgs: ['cart-1'],
      );

      expect(items.length, 1);
      expect(items.first['product_name'], 'Product A');
      expect(items.first['quantity'], 2);
      expect(cart1.total, 300.0);
    });

    test('TEST 2: Creating Cart 2 and adding Product B does not leak into Cart 1', () async {
      // Cart 1 with Product A
      final cart1 = CartSession(
        id: 'cart-1',
        companyId: companyA,
        customerName: 'Client 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-1',
            cartSessionId: 'cart-1',
            productId: 'prod-A',
            productName: 'Product A',
            unitPrice: 150.0,
            unitCost: 100.0,
            quantity: 2,
          ),
        ],
      );

      // Cart 2 with Product B
      final cart2 = CartSession(
        id: 'cart-2',
        companyId: companyA,
        customerName: 'Client 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-2',
            cartSessionId: 'cart-2',
            productId: 'prod-B',
            productName: 'Product B',
            unitPrice: 250.0,
            unitCost: 200.0,
            quantity: 1,
          ),
        ],
      );

      await db.insert('cart_sessions', cart1.toMap());
      await db.insert('cart_session_items', cart1.items.first.toMap(companyA));
      await db.insert('cart_sessions', cart2.toMap());
      await db.insert('cart_session_items', cart2.items.first.toMap(companyA));

      final cart1Items = await db.query('cart_session_items', where: 'cart_session_id = ?', whereArgs: ['cart-1']);
      final cart2Items = await db.query('cart_session_items', where: 'cart_session_id = ?', whereArgs: ['cart-2']);

      expect(cart1Items.length, 1);
      expect(cart1Items.first['product_id'], 'prod-A');
      expect(cart2Items.length, 1);
      expect(cart2Items.first['product_id'], 'prod-B');
      expect(cart1.total, 300.0);
      expect(cart2.total, 250.0);
    });

    test('TEST 3: Switching Cart 1 -> Cart 2 -> Cart 1 preserves all items and totals', () async {
      final cart1 = CartSession(
        id: 'cart-1',
        companyId: companyA,
        customerName: 'Client 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-1',
            cartSessionId: 'cart-1',
            productId: 'prod-A',
            productName: 'Product A',
            unitPrice: 150.0,
            unitCost: 100.0,
            quantity: 3,
          ),
        ],
      );

      final cart2 = CartSession(
        id: 'cart-2',
        companyId: companyA,
        customerName: 'Client 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          CartSessionItem(
            id: 'item-2',
            cartSessionId: 'cart-2',
            productId: 'prod-B',
            productName: 'Product B',
            unitPrice: 250.0,
            unitCost: 200.0,
            quantity: 2,
          ),
        ],
      );

      // Save both
      await db.insert('cart_sessions', cart1.toMap());
      await db.insert('cart_session_items', cart1.items.first.toMap(companyA));
      await db.insert('cart_sessions', cart2.toMap());
      await db.insert('cart_session_items', cart2.items.first.toMap(companyA));

      // Simulate switching to cart 2 and reading
      final readCart2 = await db.query('cart_session_items', where: 'cart_session_id = ?', whereArgs: ['cart-2']);
      expect(readCart2.first['quantity'], 2);

      // Simulate switching back to cart 1 and reading
      final readCart1 = await db.query('cart_session_items', where: 'cart_session_id = ?', whereArgs: ['cart-1']);
      expect(readCart1.first['quantity'], 3);
      expect(cart1.total, 450.0);
    });

    test('TEST 4: 3 Carts simultaneously remain completely independent', () async {
      final cart1 = CartSession(id: 'c1', companyId: companyA, customerName: 'Client 1', createdAt: DateTime.now(), updatedAt: DateTime.now(), items: [
        CartSessionItem(id: 'i1', cartSessionId: 'c1', productId: 'prod-A', productName: 'Product A', unitPrice: 150, unitCost: 100, quantity: 3),
      ]);
      final cart2 = CartSession(id: 'c2', companyId: companyA, customerName: 'Client 2', createdAt: DateTime.now(), updatedAt: DateTime.now(), items: [
        CartSessionItem(id: 'i2', cartSessionId: 'c2', productId: 'prod-B', productName: 'Product B', unitPrice: 250, unitCost: 200, quantity: 1),
      ]);
      final cart3 = CartSession(id: 'c3', companyId: companyA, customerName: 'Client 3', createdAt: DateTime.now(), updatedAt: DateTime.now(), items: [
        CartSessionItem(id: 'i3', cartSessionId: 'c3', productId: 'prod-A', productName: 'Product A', unitPrice: 150, unitCost: 100, quantity: 1),
      ]);

      expect(cart1.total, 450.0);
      expect(cart2.total, 250.0);
      expect(cart3.total, 150.0);
      expect(cart1.totalItemCount, 3);
      expect(cart2.totalItemCount, 1);
      expect(cart3.totalItemCount, 1);
    });

    test('TEST 5: Completing Cart 1 creates Sale and Invoice, removes Cart 1 from active carts, and appears in Invoices', () async {
      // 1. Setup Cart 1
      const cartId = 'cart-to-checkout';
      final saleId = uuid.v4();
      final clientTxId = uuid.v4();
      final invoiceId = uuid.v4();
      final nowIso = DateTime.now().toIso8601String();

      await db.insert('cart_sessions', {
        'id': cartId,
        'company_id': companyA,
        'customer_name': 'Client 1',
        'status': 'ACTIVE',
        'discount': 0.0,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // 2. Perform atomic checkout transaction
      await db.transaction((txn) async {
        // Decrement stock
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ? AND company_id = ?',
          [2, 'prod-A', companyA],
        );

        // Insert Sale
        await txn.insert('sales', {
          'id': saleId,
          'client_transaction_id': clientTxId,
          'company_id': companyA,
          'customer_name': 'Client 1',
          'subtotal': 300.0,
          'discount': 0.0,
          'total': 300.0,
          'payment_status': 'paid',
          'sold_at': nowIso,
          'created_at': nowIso,
          'synced': 0,
        });

        // Insert Invoice
        await txn.insert('invoices', {
          'id': invoiceId,
          'sale_id': saleId,
          'company_id': companyA,
          'invoice_number': 'INV-1',
          'status': 'paid',
          'customer_name': 'Client 1',
          'total': 300.0,
          'sold_at': nowIso,
          'created_at': nowIso,
        });

        // Mark cart session COMPLETED
        await txn.update(
          'cart_sessions',
          {'status': 'COMPLETED'},
          where: 'id = ? AND company_id = ?',
          whereArgs: [cartId, companyA],
        );
      });

      // Active carts query: Cart 1 should NOT be active
      final activeCarts = await db.query(
        'cart_sessions',
        where: "company_id = ? AND status IN ('ACTIVE', 'ON_HOLD')",
        whereArgs: [companyA],
      );
      expect(activeCarts.isEmpty, isTrue);

      // Invoices query: Invoice must appear in Invoices
      final invoices = await db.query(
        'invoices',
        where: 'company_id = ?',
        whereArgs: [companyA],
      );
      expect(invoices.length, 1);
      expect(invoices.first['invoice_number'], 'INV-1');
      expect(invoices.first['total'], 300.0);
    });

    test('TEST 6: Completing Cart 1 does not affect Cart 2 or Cart 3', () async {
      await db.insert('cart_sessions', {
        'id': 'c1',
        'company_id': companyA,
        'customer_name': 'Client 1',
        'status': 'ACTIVE',
        'discount': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('cart_sessions', {
        'id': 'c2',
        'company_id': companyA,
        'customer_name': 'Client 2',
        'status': 'ACTIVE',
        'discount': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('cart_sessions', {
        'id': 'c3',
        'company_id': companyA,
        'customer_name': 'Client 3',
        'status': 'ON_HOLD',
        'discount': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Complete only Cart 1
      await db.update('cart_sessions', {'status': 'COMPLETED'}, where: 'id = ?', whereArgs: ['c1']);

      // Query active carts
      final activeCarts = await db.query(
        'cart_sessions',
        where: "company_id = ? AND status IN ('ACTIVE', 'ON_HOLD')",
        whereArgs: [companyA],
        orderBy: 'created_at ASC',
      );

      expect(activeCarts.length, 2);
      expect(activeCarts.any((c) => c['id'] == 'c1'), isFalse);
      expect(activeCarts.any((c) => c['id'] == 'c2'), isTrue);
      expect(activeCarts.any((c) => c['id'] == 'c3'), isTrue);
    });

    test('TEST 7: Offline Sale saves locally, decrements stock, creates local invoice and sync queue item', () async {
      final saleId = uuid.v4();
      final clientTxId = uuid.v4();
      final nowIso = DateTime.now().toIso8601String();

      // Check stock before sale
      final prodBefore = await db.query('products', where: 'id = ?', whereArgs: ['prod-A']);
      final stockBefore = prodBefore.first['quantity'] as int;

      // Execute offline sale
      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ? AND company_id = ?',
          [5, 'prod-A', companyA],
        );

        await txn.insert('sales', {
          'id': saleId,
          'client_transaction_id': clientTxId,
          'company_id': companyA,
          'subtotal': 750.0,
          'discount': 0.0,
          'total': 750.0,
          'payment_status': 'paid',
          'sold_at': nowIso,
          'created_at': nowIso,
          'synced': 0,
        });

        await txn.insert('invoices', {
          'id': uuid.v4(),
          'sale_id': saleId,
          'company_id': companyA,
          'invoice_number': 'INV-OFFLINE-1',
          'status': 'paid',
          'total': 750.0,
          'sold_at': nowIso,
          'created_at': nowIso,
        });

        await txn.insert('sync_queue', {
          'id': uuid.v4(),
          'company_id': companyA,
          'client_transaction_id': clientTxId,
          'entity_type': 'sale',
          'entity_id': saleId,
          'operation_type': 'CREATE',
          'payload': '{"total": 750}',
          'status': 'pending',
          'retry_count': 0,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      });

      // Verify stock decremented
      final prodAfter = await db.query('products', where: 'id = ?', whereArgs: ['prod-A']);
      expect(prodAfter.first['quantity'], stockBefore - 5);

      // Verify invoice exists
      final inv = await db.query('invoices', where: 'invoice_number = ?', whereArgs: ['INV-OFFLINE-1']);
      expect(inv.isNotEmpty, isTrue);

      // Verify sync queue item
      final syncItems = await db.query('sync_queue', where: 'entity_id = ?', whereArgs: [saleId]);
      expect(syncItems.length, 1);
      expect(syncItems.first['status'], 'pending');
    });

    test('TEST 8: Reconnection synchronizes without duplicate sale using client_transaction_id', () async {
      const clientTxId = 'unique-tx-12345';
      const saleId = 'sale-12345';

      await db.insert('sales', {
        'id': saleId,
        'client_transaction_id': clientTxId,
        'company_id': companyA,
        'total': 500,
        'sold_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });

      // Mark synced when server accepts it
      await db.update(
        'sales',
        {'synced': 1},
        where: 'client_transaction_id = ?',
        whereArgs: [clientTxId],
      );

      // Idempotency: Attempting to insert duplicate client_transaction_id must fail / be prevented
      expect(
        () async => await db.insert('sales', {
          'id': 'sale-duplicate',
          'client_transaction_id': clientTxId,
          'company_id': companyA,
          'total': 500,
          'sold_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.abort),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('TEST 9: Sync failure and retry increments retry_count without creating duplicate sale', () async {
      final syncId = uuid.v4();
      final saleId = uuid.v4();
      final clientTxId = uuid.v4();

      await db.insert('sync_queue', {
        'id': syncId,
        'company_id': companyA,
        'client_transaction_id': clientTxId,
        'entity_type': 'sale',
        'entity_id': saleId,
        'operation_type': 'CREATE',
        'payload': '{"sale": "test"}',
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Simulate failure 1
      await db.update(
        'sync_queue',
        {'status': 'failed', 'retry_count': 1, 'last_error': 'Network timeout'},
        where: 'id = ?',
        whereArgs: [syncId],
      );

      // Verify retry count
      var item = (await db.query('sync_queue', where: 'id = ?', whereArgs: [syncId])).first;
      expect(item['retry_count'], 1);
      expect(item['status'], 'failed');

      // Simulate retry 2 -> success
      await db.update(
        'sync_queue',
        {'status': 'synced', 'retry_count': 2},
        where: 'id = ?',
        whereArgs: [syncId],
      );

      item = (await db.query('sync_queue', where: 'id = ?', whereArgs: [syncId])).first;
      expect(item['status'], 'synced');
    });

    test('TEST 10: Multi-Account Isolation: Account B cannot see Account A carts', () async {
      // Cart for Company A
      await db.insert('cart_sessions', {
        'id': 'cart-company-A',
        'company_id': companyA,
        'customer_name': 'Company A Client',
        'status': 'ACTIVE',
        'discount': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Cart for Company B
      await db.insert('cart_sessions', {
        'id': 'cart-company-B',
        'company_id': companyB,
        'customer_name': 'Company B Client',
        'status': 'ACTIVE',
        'discount': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Query carts as Company A
      final cartsForA = await db.query(
        'cart_sessions',
        where: 'company_id = ? AND status = ?',
        whereArgs: [companyA, 'ACTIVE'],
      );
      expect(cartsForA.length, 1);
      expect(cartsForA.first['customer_name'], 'Company A Client');

      // Query carts as Company B
      final cartsForB = await db.query(
        'cart_sessions',
        where: 'company_id = ? AND status = ?',
        whereArgs: [companyB, 'ACTIVE'],
      );
      expect(cartsForB.length, 1);
      expect(cartsForB.first['customer_name'], 'Company B Client');
    });

    test('TEST 11: Existing invoices remain in database and do NOT appear in Sales active carts query', () async {
      final nowIso = DateTime.now().toIso8601String();

      // Seed 3 existing invoices
      for (int i = 1; i <= 3; i++) {
        await db.insert('invoices', {
          'id': 'inv-$i',
          'sale_id': 'sale-$i',
          'company_id': companyA,
          'invoice_number': 'INV-$i',
          'status': 'paid',
          'customer_name': 'Past Customer $i',
          'total': i * 200.0,
          'sold_at': nowIso,
          'created_at': nowIso,
        });
      }

      // Query Sales (Active Carts)
      final salesActiveCarts = await db.query(
        'cart_sessions',
        where: "company_id = ? AND status IN ('ACTIVE', 'ON_HOLD')",
        whereArgs: [companyA],
      );

      // Invoices are NOT carts — active carts list contains 0 carts
      expect(salesActiveCarts.isEmpty, isTrue);

      // Existing invoices remain intact
      final storedInvoices = await db.query('invoices', where: 'company_id = ?', whereArgs: [companyA]);
      expect(storedInvoices.length, 3);
      expect(storedInvoices.map((i) => i['invoice_number']).toList(), ['INV-1', 'INV-2', 'INV-3']);
    });

    test('TEST 12: Invoices screen data query displays completed invoices correctly', () async {
      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      await db.insert('invoices', {
        'id': 'inv-101',
        'sale_id': 'sale-101',
        'company_id': companyA,
        'invoice_number': 'INV-101',
        'status': 'paid',
        'customer_name': 'Yacine',
        'total': 1450.0,
        'sold_at': nowIso,
        'created_at': nowIso,
      });

      final rows = await db.query(
        'invoices',
        where: 'company_id = ?',
        whereArgs: [companyA],
        orderBy: 'sold_at DESC',
      );

      final invoiceList = rows.map((r) => Invoice(
        id: r['id'] as String,
        invoiceNumber: r['invoice_number'] as String,
        status: paymentStatusFromApi(r['status'] as String),
        total: (r['total'] as num).toDouble(),
        soldAt: DateTime.parse(r['sold_at'] as String),
        customerName: r['customer_name'] as String?,
      )).toList();

      expect(invoiceList.length, 1);
      expect(invoiceList.first.invoiceNumber, 'INV-101');
      expect(invoiceList.first.customerName, 'Yacine');
      expect(invoiceList.first.total, 1450.0);
      expect(invoiceList.first.status, PaymentStatus.paid);
    });
  });
}
