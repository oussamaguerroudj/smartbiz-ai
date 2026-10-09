import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Sales Sync Payload Serialization & Deserialization Regression Test', () {
    test('Proves old string interpolation produces invalid JSON and throws FormatException', () {
      final verifiedItems = [
        {
          'product_id': 'prod-001',
          'quantity': 2,
          'unit_price': 200.0,
          'unit_cost': 150.0,
          'total': 400.0,
        },
        {
          'product_id': 'prod-002',
          'quantity': 1,
          'unit_price': 100.0,
          'unit_cost': 80.0,
          'total': 100.0,
        },
      ];

      // Buggy implementation before fix:
      // '"items": ${verifiedItems.map((item) => {"product_id": item["product_id"], ...}).toList()}'
      final mappedList = verifiedItems.map((item) => {
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'unit_cost': item['unit_cost'],
        'total': item['total'],
      }).toList();

      final buggyPayloadString = '''{
        "client_transaction_id": "tx-12345",
        "items": $mappedList,
        "subtotal": 500.0,
        "discount": 0.0,
        "total": 500.0,
        "payment_status": "paid",
        "sold_at": "2026-10-09T00:00:00.000Z"
      }''';

      // Old representation has unquoted keys like [{product_id: prod-001, ...}]
      expect(
        () => jsonDecode(buggyPayloadString),
        throwsA(isA<FormatException>()),
        reason: 'Dart Map.toString() does not produce valid JSON and breaks sync_service jsonDecode',
      );
    });

    test('Proves jsonEncode generates strictly valid JSON with Arabic names and nested items', () {
      final verifiedItems = [
        {
          'product_id': 'prod-001',
          'quantity': 2,
          'unit_price': 200.0,
          'unit_cost': 150.0,
          'total': 400.0,
          'product_name': 'حليب كامل الدسم',
        },
        {
          'product_id': 'prod-002',
          'quantity': 1,
          'unit_price': 100.0,
          'unit_cost': 80.0,
          'total': 100.0,
          'product_name': 'Eau Minérale 1.5L',
        },
      ];

      final itemsPayload = verifiedItems.map((item) => {
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'unit_cost': item['unit_cost'],
        'total': item['total'],
      }).toList();

      final payloadMap = {
        'client_transaction_id': 'tx-12345',
        'items': itemsPayload,
        'subtotal': 500.0,
        'discount': 0.0,
        'total': 500.0,
        'payment_status': 'paid',
        'sold_at': '2026-10-09T00:00:00.000Z',
      };

      // Fixed implementation using jsonEncode
      final validPayloadString = jsonEncode(payloadMap);

      // Decoding as sync_service does:
      final dynamic decoded = jsonDecode(validPayloadString);
      expect(decoded, isA<Map<String, dynamic>>());
      final Map<String, dynamic> decodedMap = decoded as Map<String, dynamic>;

      expect(decodedMap['client_transaction_id'], 'tx-12345');
      expect(decodedMap['total'], 500.0);
      expect(decodedMap['items'], isA<List>());
      final List items = decodedMap['items'] as List;
      expect(items.length, 2);
      expect(items[0]['product_id'], 'prod-001');
      expect(items[0]['quantity'], 2);
      expect(items[0]['unit_price'], 200.0);
      expect(items[1]['product_id'], 'prod-002');
      expect(items[1]['quantity'], 1);
    });

    test('Sync payload survives SQLite sync_queue storage and deserializes safely', () {
      final saleData = {
        'client_transaction_id': 'tx-uuid-789',
        'items': [
          {
            'product_id': 'p-coffee',
            'quantity': 3,
            'unit_price': 150.0,
            'unit_cost': 70.0,
            'total': 450.0,
          }
        ],
        'subtotal': 450.0,
        'discount': 0.0,
        'total': 450.0,
        'payment_status': 'paid',
        'sold_at': DateTime.now().toIso8601String(),
      };

      final serialized = jsonEncode(saleData);

      // Simulate sync_queue row retrieval
      final syncQueueRow = {
        'id': 1,
        'client_id': 'tx-uuid-789',
        'endpoint': '/sales',
        'method': 'POST',
        'payload': serialized,
        'status': 'pending',
      };

      final retrievedPayload = syncQueueRow['payload'] as String;
      final parsed = jsonDecode(retrievedPayload) as Map<String, dynamic>;

      expect(parsed['client_transaction_id'], 'tx-uuid-789');
      expect(parsed['items'], hasLength(1));
      expect(parsed['total'], 450.0);
    });

    test('Self-heals malformed legacy sale queue payload using local SQLite sales and sale_items', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Create minimal tables
      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          discount REAL,
          payment_status TEXT,
          customer_id TEXT,
          employee_id TEXT,
          sold_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          sale_id TEXT,
          company_id TEXT,
          product_id TEXT,
          quantity INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          entity_type TEXT,
          entity_id TEXT,
          operation_type TEXT,
          payload TEXT,
          status TEXT,
          retry_count INTEGER,
          last_error TEXT,
          updated_at TEXT
        )
      ''');

      const compId = 'comp-100';
      const saleId = 'sale-legacy-123';
      const opId = 'op-001';

      // Insert local sale and items
      await db.insert('sales', {
        'id': saleId,
        'company_id': compId,
        'discount': 50.0,
        'payment_status': 'paid',
        'customer_id': 'cust-77',
        'employee_id': 'emp-88',
        'sold_at': '2026-10-09T00:00:00.000Z',
      });
      await db.insert('sale_items', {
        'id': 'si-1',
        'sale_id': saleId,
        'company_id': compId,
        'product_id': 'prod-A',
        'quantity': 3,
      });

      // Insert malformed legacy queue payload (unquoted Dart representation)
      const malformedPayload = '{"items": [{productId: prod-A, quantity: 3}], "discount": 50.0}';
      await db.insert('sync_queue', {
        'id': opId,
        'company_id': compId,
        'entity_type': 'sale',
        'entity_id': saleId,
        'operation_type': 'CREATE',
        'payload': malformedPayload,
        'status': 'pending',
        'retry_count': 0,
      });

      // Simulate recovery logic from sync_service
      final op = (await db.query('sync_queue', where: 'id = ?', whereArgs: [opId])).first;
      Map<String, dynamic> payload;
      final rawPayload = op['payload'] as String? ?? '';
      try {
        payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      } catch (decodeErr) {
        final saleRows = await db.query('sales', where: 'id = ? AND company_id = ?', whereArgs: [op['entity_id'], compId]);
        final itemRows = await db.query('sale_items', where: 'sale_id = ? AND company_id = ?', whereArgs: [op['entity_id'], compId]);

        expect(saleRows.isNotEmpty, true);
        expect(itemRows.isNotEmpty, true);

        final saleRow = saleRows.first;
        final reconstructedItems = itemRows.map((ir) => {
          'productId': ir['product_id'],
          'quantity': (ir['quantity'] as num).toInt(),
        }).toList();

        payload = {
          'items': reconstructedItems,
          'discount': (saleRow['discount'] as num?)?.toDouble() ?? 0.0,
          'paymentStatus': saleRow['payment_status']?.toString() ?? 'paid',
          if (saleRow['customer_id'] != null) 'customerId': saleRow['customer_id'].toString(),
          if (saleRow['employee_id'] != null) 'employeeId': saleRow['employee_id'].toString(),
        };

        await db.update(
          'sync_queue',
          {'payload': jsonEncode(payload), 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [opId],
        );
      }

      // Verify payload was self-healed into valid JSON
      expect(payload['items'], hasLength(1));
      expect(payload['items'][0]['productId'], 'prod-A');
      expect(payload['items'][0]['quantity'], 3);
      expect(payload['discount'], 50.0);
      expect(payload['customerId'], 'cust-77');

      final healedRow = (await db.query('sync_queue', where: 'id = ?', whereArgs: [opId])).first;
      final decodedHealed = jsonDecode(healedRow['payload'] as String);
      expect(decodedHealed, isA<Map<String, dynamic>>());

      await db.close();
    });

    test('Malformed payload with missing local sale marks queue row failed without crashing later ops', () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          entity_type TEXT,
          entity_id TEXT,
          operation_type TEXT,
          payload TEXT,
          status TEXT,
          retry_count INTEGER,
          last_error TEXT
        )
      ''');

      // 1. Broken op with missing local row
      await db.insert('sync_queue', {
        'id': 'op-corrupt',
        'company_id': 'comp-100',
        'entity_type': 'sale',
        'entity_id': 'missing-sale-id',
        'operation_type': 'CREATE',
        'payload': 'NOT_JSON',
        'status': 'pending',
        'retry_count': 0,
      });

      // 2. Subsequent valid op
      await db.insert('sync_queue', {
        'id': 'op-valid',
        'company_id': 'comp-100',
        'entity_type': 'customer',
        'entity_id': 'cust-1',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'name': 'Nadia'}),
        'status': 'pending',
        'retry_count': 0,
      });

      final pendingOps = await db.query('sync_queue', orderBy: 'id ASC');
      final processedOps = <String>[];

      for (final op in pendingOps) {
        final opId = op['id'] as String;
        final currentRetry = (op['retry_count'] as num?)?.toInt() ?? 0;
        try {
          try {
            jsonDecode(op['payload'] as String);
          } catch (e) {
            // Missing local data throws FormatException
            throw FormatException('Malformed payload: $e');
          }
          processedOps.add(opId);
        } catch (e) {
          // Op error handled safely per-operation
          await db.update(
            'sync_queue',
            {
              'status': 'failed',
              'retry_count': currentRetry + 1,
              'last_error': e.toString(),
            },
            where: 'id = ?',
            whereArgs: [opId],
          );
        }
      }

      // Valid op succeeded even though earlier op was corrupt
      expect(processedOps, contains('op-valid'));

      // Corrupt op is preserved (NOT deleted) and marked failed with error details
      final corruptRow = (await db.query('sync_queue', where: 'id = ?', whereArgs: ['op-corrupt'])).first;
      expect(corruptRow['status'], 'failed');
      expect(corruptRow['retry_count'], 1);
      expect(corruptRow['last_error'], contains('FormatException'));

      await db.close();
    });
  });
}
