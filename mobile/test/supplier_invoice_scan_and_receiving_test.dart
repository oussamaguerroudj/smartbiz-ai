import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:modiri_ai/core/database/app_database.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/theme/app_theme.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';
import 'package:modiri_ai/features/suppliers/presentation/screens/suppliers_screen.dart';
import 'package:modiri_ai/features/suppliers/presentation/screens/supplier_details_screen.dart';
import 'package:modiri_ai/features/suppliers/presentation/screens/supplier_invoice_scan_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Supplier Invoice Scan & Inventory Receiving — Database Flow', () {
    late Database db;
    const companyId = 'test_comp_123';
    const supplierId = 'sup_test_001';

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );

      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          category TEXT,
          quantity INTEGER NOT NULL DEFAULT 0,
          purchase_price REAL NOT NULL DEFAULT 0.0,
          selling_price REAL NOT NULL DEFAULT 0.0,
          minimum_stock INTEGER NOT NULL DEFAULT 5,
          supplier_id TEXT,
          barcode TEXT,
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
          client_transaction_id TEXT UNIQUE,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
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
          created_at TEXT NOT NULL
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
          client_id TEXT UNIQUE,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Seed an existing product
      await db.insert('products', {
        'id': 'prod_existing_1',
        'company_id': companyId,
        'name': 'Huile de table 5L',
        'category': 'Alimentation',
        'quantity': 5,
        'purchase_price': 600.0,
        'selling_price': 750.0,
        'minimum_stock': 5,
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Receiving invoice increments existing stock and creates new products', () async {
      final nowIso = DateTime.now().toIso8601String();
      final purchaseId = const Uuid().v4();
      const clientTxId = 'purch_test_1';

      // 1. Line 1: Existing product (10 units @ 620 DZD)
      // 2. Line 2: Brand new product (20 units @ 90 DZD)
      final newProdId = const Uuid().v4();

      await db.transaction((txn) async {
        // Line 1: Increment existing stock
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ?, purchase_price = ? WHERE id = ? AND company_id = ?',
          [10, 620.0, 'prod_existing_1', companyId],
        );

        // Line 2: Insert new product with initial received quantity
        await txn.insert('products', {
          'id': newProdId,
          'company_id': companyId,
          'name': 'Sucre blanc 1kg',
          'category': 'Alimentation',
          'quantity': 20,
          'purchase_price': 90.0,
          'selling_price': 120.0,
          'minimum_stock': 5,
          'supplier_id': supplierId,
          'created_at': nowIso,
          'synced': 0,
        });

        // Record purchase
        const total = (10 * 620.0) + (20 * 90.0); // 6200 + 1800 = 8000
        const downPayment = 3000.0;
        const outstanding = total - downPayment; // 5000

        await txn.insert('supplier_purchases', {
          'id': purchaseId,
          'company_id': companyId,
          'supplier_id': supplierId,
          'invoice_number': 'FAC-2026-001',
          'purchase_date': '2026-10-15',
          'total_amount': total,
          'amount_paid': downPayment,
          'outstanding_balance': outstanding,
          'payment_status': 'partially_paid',
          'notes': 'Test scanned invoice receipt',
          'client_transaction_id': clientTxId,
          'created_at': nowIso,
          'synced': 0,
        });

        // Record items
        await txn.insert('supplier_purchase_items', {
          'id': const Uuid().v4(),
          'purchase_id': purchaseId,
          'company_id': companyId,
          'product_id': 'prod_existing_1',
          'product_name': 'Huile de table 5L',
          'quantity': 10,
          'unit_cost': 620.0,
          'line_total': 6200.0,
          'created_at': nowIso,
        });

        await txn.insert('supplier_purchase_items', {
          'id': const Uuid().v4(),
          'purchase_id': purchaseId,
          'company_id': companyId,
          'product_id': newProdId,
          'product_name': 'Sucre blanc 1kg',
          'quantity': 20,
          'unit_cost': 90.0,
          'line_total': 1800.0,
          'created_at': nowIso,
        });

        // Record down payment
        await txn.insert('supplier_payments', {
          'id': const Uuid().v4(),
          'company_id': companyId,
          'supplier_id': supplierId,
          'purchase_id': purchaseId,
          'amount': downPayment,
          'payment_date': '2026-10-15',
          'payment_method': 'cash',
          'reference': 'Invoice FAC-2026-001',
          'notes': 'Initial invoice payment',
          'client_id': 'pay_$clientTxId',
          'created_at': nowIso,
          'synced': 0,
        });
      });

      // Verify existing product stock: initial 5 + 10 received = 15
      final p1 = await db.query('products', where: 'id = ?', whereArgs: ['prod_existing_1']);
      expect(p1.first['quantity'], equals(15));
      expect(p1.first['purchase_price'], equals(620.0));

      // Verify new product created: quantity = 20
      final p2 = await db.query('products', where: 'id = ?', whereArgs: [newProdId]);
      expect(p2.length, equals(1));
      expect(p2.first['name'], equals('Sucre blanc 1kg'));
      expect(p2.first['quantity'], equals(20));
      expect(p2.first['selling_price'], equals(120.0));

      // Verify purchase record
      final purch = await db.query('supplier_purchases', where: 'id = ?', whereArgs: [purchaseId]);
      expect(purch.first['total_amount'], equals(8000.0));
      expect(purch.first['amount_paid'], equals(3000.0));
      expect(purch.first['outstanding_balance'], equals(5000.0));
      expect(purch.first['payment_status'], equals('partially_paid'));

      // Verify payment record
      final pay = await db.query('supplier_payments', where: 'purchase_id = ?', whereArgs: [purchaseId]);
      expect(pay.length, equals(1));
      expect(pay.first['amount'], equals(3000.0));
      expect(pay.first['client_id'], equals('pay_$clientTxId'));
    });

    test('Duplicate invoice check detects existing invoice number', () async {
      await db.insert('supplier_purchases', {
        'id': 'existing_purch_1',
        'company_id': companyId,
        'supplier_id': supplierId,
        'invoice_number': 'INV-999',
        'purchase_date': '2026-10-10',
        'total_amount': 5000.0,
        'amount_paid': 5000.0,
        'outstanding_balance': 0.0,
        'payment_status': 'paid',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      final existing = await db.query(
        'supplier_purchases',
        where: 'company_id = ? AND supplier_id = ? AND invoice_number = ?',
        whereArgs: [companyId, supplierId, 'INV-999'],
      );

      expect(existing.isNotEmpty, isTrue);
      expect(existing.first['id'], equals('existing_purch_1'));
    });
  });

  group('Supplier UI & Scanner Widgets Tests', () {
    final testSupplier = Supplier(
      id: 'sup_ui_001',
      name: 'SARL Agro Distribution',
      phone: '0555123456',
      productsSupplied: 8,
      outstandingBalance: 15000.0,
      totalPurchasesAmount: 65000.0,
    );

    testWidgets('SupplierInvoiceScanScreen renders viewfinder and loads demo invoice review', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierFake(
              const Session(
                companyId: 'comp_test',
                companyName: 'Test Business',
                email: 'test@modiri.ai',
              ),
            )),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: SupplierInvoiceScanScreen(supplier: testSupplier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check capture screen elements
      expect(find.text('SARL Agro Distribution'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

      // Tap demo invoice button to enter review mode
      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pumpAndSettle();

      // Verify Review screen elements
      expect(find.byType(SupplierInvoiceScanScreen), findsOneWidget);
      expect(find.text('Huile de table 5L'), findsOneWidget);
      expect(find.text('Sucre blanc 1kg'), findsOneWidget);
      expect(find.text('Farine T55 10kg'), findsOneWidget);
      expect(find.text('Confirm & Receive Inventory'), findsOneWidget);
    });

    testWidgets('SupplierDetailsScreen displays simplified header, 3-column financial card, and actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => SessionNotifierFake(
              const Session(
                companyId: 'comp_test',
                companyName: 'Test Business',
                email: 'test@modiri.ai',
              ),
            )),
            supplierProfileProvider(testSupplier).overrideWith((ref) => Future.value(
              SupplierProfileData(
                supplier: testSupplier,
                products: [],
                totalStockUnits: 25,
                totalPurchaseValue: 45000.0,
                totalPurchasesAmount: 65000.0,
                totalPurchasesPaid: 50000.0,
                outstandingBalance: 15000.0,
                purchasesCount: 3,
                paymentsCount: 2,
                purchases: [],
                payments: [],
              ),
            )),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: SupplierDetailsScreen(supplier: testSupplier),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Supplier Header
      expect(find.text('SARL Agro Distribution'), findsWidgets);
      expect(find.text('0555123456'), findsOneWidget);

      // Compact 3-Column Financial Card
      expect(find.text('65000 DZD'), findsOneWidget); // Total purchases
      expect(find.text('50000 DZD'), findsOneWidget); // Total paid
      expect(find.text('15000 DZD'), findsWidgets); // Outstanding balance

      // Primary & Secondary Actions
      expect(find.text('Scan Invoice'), findsOneWidget);
      expect(find.text('Add Purchase Manually'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);

      // Overflow menu icon exists
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Tapping "Scan Invoice" navigates to SupplierInvoiceScanScreen
      await tester.tap(find.text('Scan Invoice'));
      await tester.pumpAndSettle();

      expect(find.byType(SupplierInvoiceScanScreen), findsOneWidget);
    });
  });
}

class SessionNotifierFake extends StateNotifier<Session> implements SessionNotifier {
  SessionNotifierFake(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

