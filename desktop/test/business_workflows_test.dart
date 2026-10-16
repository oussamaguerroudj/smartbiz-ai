import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_desktop/core/database/local_financial_calculator.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/features/products/domain/product.dart';
import 'package:modiri_desktop/features/pos_sales/presentation/desktop_pos_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('1. POS Cart & Sales Financial Invariants', () {
    test('Calculates line totals and grand total accurately', () {
      final p1 = Product(id: 'p1', companyId: 'comp_1', name: 'Product A', price: 25.0, costPrice: 15.0, stockQuantity: 50, barcode: '111', category: 'General');
      final p2 = Product(id: 'p2', companyId: 'comp_1', name: 'Product B', price: 10.0, costPrice: 6.0, stockQuantity: 20, barcode: '222', category: 'General');

      final line1 = CartLine(product: p1, quantity: 2);
      final line2 = CartLine(product: p2, quantity: 3);

      expect(line1.total, equals(50.0));
      expect(line2.total, equals(30.0));

      final subtotal = line1.total + line2.total;
      expect(subtotal, equals(80.0));
    });

    test('Profit margin calculation matches mathematical invariants', () {
      final p = Product(id: 'p1', companyId: 'comp_1', name: 'Coffee', price: 20.0, costPrice: 12.0, stockQuantity: 10, barcode: '123', category: 'Cafe');
      final margin = ((p.price - p.costPrice) / p.price) * 100;
      expect(margin, equals(40.0));
    });
  });

  group('2. Tenant-Isolated Financial Calculator Invariants', () {
    late Database db;

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

      // Create isolated schema
      await db.execute('''
        CREATE TABLE sales (
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
        CREATE TABLE sale_items (
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
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Strict tenant isolation: Company A transactions never leak into Company B', () async {
      const compA = 'company_alpha';
      const compB = 'company_beta';
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // Insert Company A transactions
      await db.insert('sales', {
        'id': 's1',
        'company_id': compA,
        'total': 1000.0,
        'subtotal': 1000.0,
        'sold_at': '$todayStr 10:00:00',
        'created_at': '$todayStr 10:00:00',
        'payment_status': 'paid',
      });
      await db.insert('sale_items', {
        'id': 'si1',
        'company_id': compA,
        'sale_id': 's1',
        'product_id': 'p1',
        'product_name': 'Item 1',
        'quantity': 10,
        'unit_price': 100.0,
        'unit_cost': 60.0,
        'line_total': 1000.0,
      });
      await db.insert('expenses', {
        'id': 'e1',
        'company_id': compA,
        'category': 'Rent',
        'amount': 200.0,
        'date': todayStr,
        'created_at': todayStr,
      });

      // Insert Company B transactions
      await db.insert('sales', {
        'id': 's2',
        'company_id': compB,
        'total': 5000.0,
        'subtotal': 5000.0,
        'sold_at': '$todayStr 11:00:00',
        'created_at': '$todayStr 11:00:00',
        'payment_status': 'paid',
      });
      await db.insert('sale_items', {
        'id': 'si2',
        'company_id': compB,
        'sale_id': 's2',
        'product_id': 'p2',
        'product_name': 'Item 2',
        'quantity': 50,
        'unit_price': 100.0,
        'unit_cost': 50.0,
        'line_total': 5000.0,
      });

      // Calculate for Company A
      final summaryA = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compA,
        date: todayStr,
        customDb: db,
      );

      expect(summaryA.allRevenue, equals(1000.0));
      expect(summaryA.periodRevenue, equals(1000.0));
      expect(summaryA.periodCogs, equals(600.0)); // 10 * 60
      expect(summaryA.periodGrossProfit, equals(400.0)); // 1000 - 600
      expect(summaryA.periodExpenses, equals(200.0));
      expect(summaryA.periodNetProfit, equals(200.0)); // 400 - 200
      expect(summaryA.profitMargin, equals(20.0)); // (200 / 1000) * 100
      expect(summaryA.salesCount, equals(1));

      // Calculate for Company B (must NOT include Company A's 1000 or 200)
      final summaryB = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: compB,
        date: todayStr,
        customDb: db,
      );

      expect(summaryB.allRevenue, equals(5000.0));
      expect(summaryB.periodRevenue, equals(5000.0));
      expect(summaryB.periodCogs, equals(2500.0)); // 50 * 50
      expect(summaryB.periodGrossProfit, equals(2500.0)); // 5000 - 2500
      expect(summaryB.periodExpenses, equals(0.0));
      expect(summaryB.periodNetProfit, equals(2500.0));
      expect(summaryB.profitMargin, equals(50.0));
      expect(summaryB.salesCount, equals(1));
    });

    test('Verifies financial invariants: Net Profit = Revenue - COGS - Expenses', () async {
      const comp = 'company_invariant';
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      await db.insert('sales', {
        'id': 's_inv',
        'company_id': comp,
        'total': 1500.0,
        'subtotal': 1500.0,
        'sold_at': '$todayStr 12:00:00',
        'created_at': '$todayStr 12:00:00',
        'payment_status': 'paid',
      });
      await db.insert('sale_items', {
        'id': 'si_inv',
        'company_id': comp,
        'sale_id': 's_inv',
        'product_id': 'p_inv',
        'product_name': 'Inv Item',
        'quantity': 15,
        'unit_price': 100.0,
        'unit_cost': 40.0,
        'line_total': 1500.0,
      });
      await db.insert('expenses', {
        'id': 'e_inv',
        'company_id': comp,
        'category': 'Utilities',
        'amount': 300.0,
        'date': todayStr,
        'created_at': todayStr,
      });

      final res = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: comp,
        date: todayStr,
        customDb: db,
      );

      // Verify invariant equations
      expect(res.periodGrossProfit, equals(res.periodRevenue - res.periodCogs));
      expect(res.periodNetProfit, equals(res.periodGrossProfit - res.periodExpenses));
      expect(res.globalNetProfit, equals(res.allRevenue - res.globalCogs - res.allExpenses));
    });
  });

  group('3. Business Types & Session State Management', () {
    test('SessionState correctly retains business type and tenant identifiers', () {
      const state = SessionState(
        isLoggedIn: true,
        accessToken: 'jwt_token_sample',
        userId: 'usr_42',
        companyId: 'comp_pharmacy_99',
        companyName: 'Modiri Pharmacy & Parapharmacie',
        businessType: 'pharmacy',
      );

      expect(state.isLoggedIn, isTrue);
      expect(state.companyId, equals('comp_pharmacy_99'));
      expect(state.businessType, equals('pharmacy'));

      final modified = state.copyWith(businessType: 'restaurant');
      expect(modified.businessType, equals('restaurant'));
      expect(modified.companyId, equals('comp_pharmacy_99'));
    });
  });

  group('4. Multilingual & RTL Alignment', () {
    test('Arabic dictionary strings and RTL layout detection', () {
      final locAr = ModiriLocalizations(const Locale('ar'));
      expect(ModiriLocalizations.isRtl(const Locale('ar')), isTrue);
      expect(locAr.get('dashboard'), equals('لوحة التحكم'));
      expect(locAr.get('pos'), equals('نقطة البيع والصندوق'));
      expect(locAr.get('inventory'), equals('المخزون والمنتجات'));

      final locEn = ModiriLocalizations(const Locale('en'));
      expect(ModiriLocalizations.isRtl(const Locale('en')), isFalse);
      expect(locEn.get('dashboard'), equals('Dashboard'));

      final locFr = ModiriLocalizations(const Locale('fr'));
      expect(ModiriLocalizations.isRtl(const Locale('fr')), isFalse);
      expect(locFr.get('dashboard'), equals('Tableau de bord'));
    });
  });

  group('5. Specialized Business Verticals Offline Persistence', () {
    late Database db;

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE appointments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_name TEXT NOT NULL,
          service_type TEXT NOT NULL,
          appointment_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'confirmed',
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE restaurant_tables (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          seats INTEGER NOT NULL DEFAULT 4,
          status TEXT NOT NULL DEFAULT 'available',
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE restaurant_orders (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          table_name TEXT NOT NULL,
          items_json TEXT NOT NULL DEFAULT '[]',
          status TEXT NOT NULL DEFAULT 'preparing',
          total REAL NOT NULL DEFAULT 0.0,
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE enterprise_projects (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          client_name TEXT NOT NULL,
          budget REAL NOT NULL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'in_progress',
          notes TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE pharmacy_batches (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          product_id TEXT,
          batch_number TEXT NOT NULL,
          medicine_name TEXT NOT NULL,
          expiration_date TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Appointments: insert, update status, and tenant filter work offline', () async {
      await db.insert('appointments', {
        'id': 'apt_1',
        'company_id': 'comp_clinic',
        'customer_name': 'Fatima Zahra',
        'service_type': 'Cardiology Consultation',
        'appointment_date': '2026-10-15 10:30',
        'status': 'confirmed',
        'notes': 'Check ECG records',
        'created_at': '2026-10-12 10:00',
        'synced': 0,
      });

      final rows = await db.query('appointments', where: 'company_id = ?', whereArgs: ['comp_clinic']);
      expect(rows.length, equals(1));
      expect(rows.first['customer_name'], equals('Fatima Zahra'));

      // Status update
      await db.update('appointments', {'status': 'completed'}, where: 'id = ?', whereArgs: ['apt_1']);
      final updated = await db.query('appointments', where: 'id = ?', whereArgs: ['apt_1']);
      expect(updated.first['status'], equals('completed'));
    });

    test('Restaurant: dining tables and kitchen orders persist with full payload', () async {
      await db.insert('restaurant_tables', {
        'id': 'tbl_4',
        'company_id': 'comp_rest',
        'name': 'Terrace Table 4',
        'seats': 6,
        'status': 'occupied',
        'created_at': '2026-10-12 10:00',
        'synced': 0,
      });

      await db.insert('restaurant_orders', {
        'id': 'ord_101',
        'company_id': 'comp_rest',
        'table_name': 'Terrace Table 4',
        'items_json': '[{"name":"Tajine Zitoun","quantity":2,"unitPrice":950.0}]',
        'status': 'preparing',
        'total': 1900.0,
        'notes': 'No salt',
        'created_at': '2026-10-12 10:05',
        'synced': 0,
      });

      final ordRows = await db.query('restaurant_orders', where: 'company_id = ?', whereArgs: ['comp_rest']);
      expect(ordRows.length, equals(1));
      expect(ordRows.first['total'], equals(1900.0));
      expect(ordRows.first['items_json'], contains('Tajine Zitoun'));
    });

    test('Enterprise & Pharmacy: project budget and medication expiry persist locally', () async {
      await db.insert('enterprise_projects', {
        'id': 'proj_1',
        'company_id': 'comp_ent',
        'name': 'Cloud Infrastructure Upgrade',
        'client_name': 'Sonatrach Tech',
        'budget': 450000.0,
        'status': 'in_progress',
        'notes': 'Q4 Milestone delivery',
        'created_at': '2026-10-12 10:00',
        'synced': 0,
      });

      await db.insert('pharmacy_batches', {
        'id': 'batch_1',
        'company_id': 'comp_pharm',
        'batch_number': 'LOT-2026-99',
        'medicine_name': 'Amoxicillin 500mg',
        'expiration_date': '2026-11-05',
        'quantity': 120,
        'created_at': '2026-10-12 10:00',
        'synced': 0,
      });

      final proj = await db.query('enterprise_projects', where: 'company_id = ?', whereArgs: ['comp_ent']);
      expect(proj.first['budget'], equals(450000.0));

      final batch = await db.query('pharmacy_batches', where: 'company_id = ?', whereArgs: ['comp_pharm']);
      expect(batch.first['quantity'], equals(120));
      expect(batch.first['batch_number'], equals('LOT-2026-99'));
    });
  });
}
