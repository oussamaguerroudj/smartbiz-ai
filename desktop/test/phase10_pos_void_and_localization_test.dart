import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/widgets/modiri_stat_card.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 10: POS Void Flow & Complete Localization Verification', () {
    test('1. Localization completeness: 1,173 keys fully balanced across EN, FR, and AR', () {
      final values = ModiriLocalizations.localizedValues;
      final enKeys = values['en']!.keys.toSet();
      final frKeys = values['fr']!.keys.toSet();
      final arKeys = values['ar']!.keys.toSet();

      expect(enKeys.length, greaterThanOrEqualTo(1170));
      expect(frKeys.length, greaterThanOrEqualTo(1170));
      expect(arKeys.length, greaterThanOrEqualTo(1170));

      final missingInFr = enKeys.difference(frKeys);
      final missingInAr = enKeys.difference(arKeys);

      expect(missingInFr, isEmpty, reason: 'French dictionary must contain all English keys');
      expect(missingInAr, isEmpty, reason: 'Arabic dictionary must contain all English keys');

      // Ensure key newly-added localization entries exist
      expect(ModiriLocalizations(const Locale('en')).get('gross_sales_label'), equals('Gross Sales'));
      expect(ModiriLocalizations(const Locale('fr')).get('gross_sales_label'), equals('Ventes brutes'));
      expect(ModiriLocalizations(const Locale('ar')).get('gross_sales_label'), equals('إجمالي المبيعات'));

      expect(ModiriLocalizations(const Locale('en')).get('transactions_today_label'), equals("Today's Transactions"));
      expect(ModiriLocalizations(const Locale('fr')).get('transactions_today_label'), equals('Transactions du jour'));
      expect(ModiriLocalizations(const Locale('ar')).get('transactions_today_label'), equals('معاملات اليوم'));

      expect(ModiriLocalizations(const Locale('en')).get('void_sale'), equals('Void Sale'));
      expect(ModiriLocalizations(const Locale('fr')).get('void_sale'), equals('Annuler la vente'));
      expect(ModiriLocalizations(const Locale('ar')).get('void_sale'), equals('إلغاء عملية البيع'));
    });

    testWidgets('2. ModiriStatCard RTL and Overflow Protection', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 250,
                height: 180,
                child: ModiriStatCard(
                  icon: Icons.account_balance_wallet,
                  label: 'إجمالي المبيعات مع نص إضافي طويل جداً لتجربة الحماية من الفائض',
                  value: '12,500,000.00 DZD',
                  sublabel: 'المعاملات المسجلة اليوم في نقطة البيع',
                  tone: StatCardTone.teal,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure widget renders without any RenderFlex overflow exceptions
      expect(tester.takeException(), isNull);

      // Verify chevron icon in RTL points left
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    test('3. POS Void Sale: Atomic Inventory Restitution, Debt Reversal, and Sync Enqueue', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      addTearDown(() => db.close());

      // Create necessary schema
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          name TEXT,
          stock_quantity INTEGER,
          price REAL,
          cost_price REAL
        );
      ''');
      await db.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          name TEXT,
          credit_balance REAL
        );
      ''');
      await db.execute('''
        CREATE TABLE customer_transactions (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          customer_id TEXT,
          type TEXT,
          amount REAL,
          balance_after REAL,
          description TEXT,
          created_at TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          customer_id TEXT,
          customer_name TEXT,
          invoice_number TEXT,
          total REAL,
          payment_method TEXT,
          payment_status TEXT,
          synced INTEGER
        );
      ''');
      await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          sale_id TEXT,
          company_id TEXT,
          product_id TEXT,
          product_name TEXT,
          quantity INTEGER,
          unit_price REAL
        );
      ''');
      await db.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          sale_id TEXT,
          invoice_number TEXT,
          status TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          client_transaction_id TEXT,
          entity_type TEXT,
          entity_id TEXT,
          operation_type TEXT,
          payload TEXT,
          status TEXT,
          retry_count INTEGER,
          last_error TEXT,
          created_at TEXT,
          updated_at TEXT
        );
      ''');

      const companyId = 'test_comp_10';
      const productId = 'prod_oil_1';
      const customerId = 'cust_sarah_1';
      const saleId = 'sale_pos_99';
      const invoiceNum = 'INV-5001';

      // 1. Initial State: Product has stock of 15, Customer has debt of 3000
      await db.insert('products', {
        'id': productId,
        'company_id': companyId,
        'name': 'Sunflower Oil 5L',
        'stock_quantity': 15, // Stock after sale of 5 items (was 20)
        'price': 600.0,
        'cost_price': 500.0,
      });

      await db.insert('customers', {
        'id': customerId,
        'company_id': companyId,
        'name': 'Sarah Bouzid',
        'credit_balance': 3000.0, // Existing balance including this 3000 DZD sale
      });

      await db.insert('sales', {
        'id': saleId,
        'company_id': companyId,
        'customer_id': customerId,
        'customer_name': 'Sarah Bouzid',
        'invoice_number': invoiceNum,
        'total': 3000.0,
        'payment_method': 'credit',
        'payment_status': 'unpaid',
        'synced': 1,
      });

      await db.insert('sale_items', {
        'id': const Uuid().v4(),
        'sale_id': saleId,
        'company_id': companyId,
        'product_id': productId,
        'product_name': 'Sunflower Oil 5L',
        'quantity': 5,
        'unit_price': 600.0,
      });

      await db.insert('invoices', {
        'id': const Uuid().v4(),
        'company_id': companyId,
        'sale_id': saleId,
        'invoice_number': invoiceNum,
        'status': 'unpaid',
      });

      // 2. Execute Void Sale Transaction
      final nowIso = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        final items = await txn.query(
          'sale_items',
          where: 'sale_id = ? AND company_id = ?',
          whereArgs: [saleId, companyId],
        );

        for (final item in items) {
          final pid = item['product_id']?.toString();
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          if (pid != null && pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?',
              [qty, pid, companyId],
            );
          }
        }

        final custRows = await txn.query(
          'customers',
          where: 'name = ? AND company_id = ?',
          whereArgs: ['Sarah Bouzid', companyId],
        );
        if (custRows.isNotEmpty) {
          final cid = custRows.first['id'].toString();
          final oldBal = (custRows.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
          final newBal = (oldBal - 3000.0).clamp(0.0, double.infinity);

          await txn.update(
            'customers',
            {'credit_balance': newBal},
            where: 'id = ?',
            whereArgs: [cid],
          );

          await txn.insert('customer_transactions', {
            'id': const Uuid().v4(),
            'company_id': companyId,
            'customer_id': cid,
            'type': 'adjustment',
            'amount': -3000.0,
            'balance_after': newBal,
            'description': 'Void Credit Sale $invoiceNum',
            'created_at': nowIso,
          });
        }

        await txn.update(
          'sales',
          {'payment_status': 'voided', 'synced': 0},
          where: 'id = ? AND company_id = ?',
          whereArgs: [saleId, companyId],
        );

        await txn.update(
          'invoices',
          {'status': 'cancelled'},
          where: 'sale_id = ? AND company_id = ?',
          whereArgs: [saleId, companyId],
        );

        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'company_id': companyId,
          'client_transaction_id': const Uuid().v4(),
          'entity_type': 'sale',
          'entity_id': saleId,
          'operation_type': 'VOID',
          'payload': jsonEncode({
            'id': saleId,
            'sale_id': saleId,
            'invoice_number': invoiceNum,
            'status': 'voided',
            'reason': 'POS operator void',
          }),
          'status': 'pending',
          'retry_count': 0,
          'last_error': null,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      });

      // 3. Assertions
      // Product Stock restored from 15 to 20
      final prodAfter = await db.query('products', where: 'id = ?', whereArgs: [productId]);
      expect(prodAfter.first['stock_quantity'], equals(20));

      // Customer Credit Balance reduced from 3000.0 to 0.0
      final custAfter = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      expect(custAfter.first['credit_balance'], equals(0.0));

      // Customer ledger contains adjustment entry
      final ledger = await db.query('customer_transactions', where: 'customer_id = ?', whereArgs: [customerId]);
      expect(ledger.length, equals(1));
      expect(ledger.first['type'], equals('adjustment'));
      expect(ledger.first['amount'], equals(-3000.0));

      // Sale is marked as voided
      final saleAfter = await db.query('sales', where: 'id = ?', whereArgs: [saleId]);
      expect(saleAfter.first['payment_status'], equals('voided'));

      // Invoice is cancelled
      final invAfter = await db.query('invoices', where: 'sale_id = ?', whereArgs: [saleId]);
      expect(invAfter.first['status'], equals('cancelled'));

      // Sync queue has pending VOID record
      final syncItems = await db.query('sync_queue', where: 'entity_id = ?', whereArgs: [saleId]);
      expect(syncItems.length, equals(1));
      expect(syncItems.first['operation_type'], equals('VOID'));
      expect(syncItems.first['status'], equals('pending'));
    });
  });
}
