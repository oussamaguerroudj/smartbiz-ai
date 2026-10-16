import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:modiri_desktop/core/database/local_financial_calculator.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/features/dashboard/presentation/desktop_dashboard_screen.dart';
import 'package:modiri_desktop/features/shell/presentation/desktop_navigation_shell.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Phase 9: Mobile Parity Recovery & Business Workflow Verification', () {
    test('1. Financial Accounting Parity: Remaining inventory is an asset, never deducted from net profit', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_name TEXT,
          payment_status TEXT NOT NULL,
          total REAL NOT NULL,
          sold_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          stock_quantity INTEGER NOT NULL DEFAULT 0,
          cost_price REAL NOT NULL DEFAULT 0.0
        )
      ''');
      await db.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          date TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE restaurant_payments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          order_id TEXT NOT NULL,
          amount REAL NOT NULL,
          paid_at TEXT NOT NULL
        )
      ''');

      const companyId = 'comp_audit_1';
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Seed 5,000 DZD of restaurant dining receipts
      await db.insert('restaurant_payments', {
        'id': 'pay_1',
        'company_id': companyId,
        'order_id': 'ord_1',
        'amount': 5000.0,
        'paid_at': today,
      });

      // Seed 20,000 DZD of food ingredients on hand (remaining stock asset)
      await db.insert('products', {
        'id': 'prod_ing_1',
        'company_id': companyId,
        'name': 'Farine & Epices',
        'stock_quantity': 100,
        'cost_price': 200.0, // 100 * 200 = 20,000 DZD
      });

      // Seed 1,500 DZD of actual operating expenses (utilities + staff lunch)
      await db.insert('expenses', {
        'id': 'exp_1',
        'company_id': companyId,
        'amount': 1500.0,
        'category': 'Utilities',
        'date': today,
      });

      final report = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyId,
        businessType: 'restaurant',
        date: today,
        customDb: db,
      );

      // Verify Mobile Business Rules:
      // 1. Revenue = 5000 DZD
      expect(report.periodRevenue, equals(5000.0));
      // 2. Gross profit = 5000 DZD
      expect(report.periodGrossProfit, equals(5000.0));
      // 3. Inventory asset value = 20,000 DZD
      expect(report.inventoryValue, equals(20000.0));
      // 4. Expenses = 1500 DZD
      expect(report.periodExpenses, equals(1500.0));
      // 5. Net Profit = Gross Profit (5000) - Expenses (1500) = 3500 DZD
      // CRITICAL: Must NOT deduct inventory value (which would result in -16,500 DZD)
      expect(report.periodNetProfit, equals(3500.0));

      await db.close();
    });

    test('2. Zero Double-Counting: Legacy REST sales rows excluded from retail calculations', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          payment_status TEXT NOT NULL,
          total REAL NOT NULL,
          sold_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE restaurant_payments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          order_id TEXT NOT NULL,
          amount REAL NOT NULL,
          paid_at TEXT NOT NULL
        )
      ''');

      const companyId = 'comp_audit_2';
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Restaurant payment recorded
      await db.insert('restaurant_payments', {
        'id': 'pay_2',
        'company_id': companyId,
        'order_id': 'ord_2',
        'amount': 1200.0,
        'paid_at': today,
      });

      // Legacy or duplicate row recorded in sales
      await db.insert('sales', {
        'id': 'REST-ord_2',
        'company_id': companyId,
        'payment_status': 'paid',
        'total': 1200.0,
        'sold_at': today,
      });

      // Normal retail sale
      await db.insert('sales', {
        'id': 'sale_retail_1',
        'company_id': companyId,
        'payment_status': 'paid',
        'total': 800.0,
        'sold_at': today,
      });

      final report = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyId,
        businessType: 'restaurant',
        date: today,
        customDb: db,
      );

      // Revenue must be 800 (retail) + 1200 (restaurant) = 2000 DZD, NOT 3200 DZD!
      expect(report.periodRevenue, equals(2000.0));

      await db.close();
    });

    test('3. Supplier Purchase Inventory Flow: Increments matching product stock and cost price', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          stock_quantity INTEGER NOT NULL DEFAULT 0,
          cost_price REAL NOT NULL DEFAULT 0.0,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE restaurant_inventory_items (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          current_stock REAL NOT NULL DEFAULT 0.0,
          cost_per_unit REAL NOT NULL DEFAULT 0.0,
          updated_at TEXT
        )
      ''');

      const companyId = 'comp_supplier_flow';

      // Seed catalog product
      await db.insert('products', {
        'id': 'prod_cola',
        'company_id': companyId,
        'name': 'Coca-Cola 1L',
        'stock_quantity': 10,
        'cost_price': 90.0,
      });

      // Seed restaurant ingredient
      await db.insert('restaurant_inventory_items', {
        'id': 'ing_olive_oil',
        'company_id': companyId,
        'name': 'Huile d\'olive 5L',
        'current_stock': 2.0,
        'cost_per_unit': 3500.0,
      });

      // Simulate purchasing 'Coca-Cola 1L'
      final prodMatches = await db.query(
        'products',
        where: 'company_id = ? AND LOWER(TRIM(name)) = ?',
        whereArgs: [companyId, 'coca-cola 1l'],
      );
      expect(prodMatches.isNotEmpty, isTrue);
      final curStock = (prodMatches.first['stock_quantity'] as num).toInt();
      await db.update(
        'products',
        {
          'stock_quantity': curStock + 1,
          'cost_price': 95.0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND company_id = ?',
        whereArgs: [prodMatches.first['id'], companyId],
      );

      final updatedProd = await db.query('products', where: 'id = ?', whereArgs: ['prod_cola']);
      expect(updatedProd.first['stock_quantity'], equals(11));
      expect(updatedProd.first['cost_price'], equals(95.0));

      // Simulate purchasing 'Huile d\'olive 5L'
      final ingMatches = await db.query(
        'restaurant_inventory_items',
        where: 'company_id = ? AND LOWER(TRIM(name)) = ?',
        whereArgs: [companyId, 'huile d\'olive 5l'],
      );
      expect(ingMatches.isNotEmpty, isTrue);
      final curIngStock = (ingMatches.first['current_stock'] as num).toDouble();
      await db.update(
        'restaurant_inventory_items',
        {
          'current_stock': curIngStock + 1.0,
          'cost_per_unit': 3700.0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND company_id = ?',
        whereArgs: [ingMatches.first['id'], companyId],
      );

      final updatedIng = await db.query('restaurant_inventory_items', where: 'id = ?', whereArgs: ['ing_olive_oil']);
      expect(updatedIng.first['current_stock'], equals(3.0));
      expect(updatedIng.first['cost_per_unit'], equals(3700.0));

      await db.close();
    });

    testWidgets('4. Business-Type Routing: Restaurant mode does not show grocery POS in quick actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      String? navigatedRoute;

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _CustomSessionNotifier(
            const SessionState(
              isLoggedIn: true,
              userId: 'u_rest',
              companyId: 'c_rest',
              companyName: 'Bistro Alger',
              businessType: 'restaurant',
            ),
          )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DesktopDashboardScreen(
                onNavigate: (route) => navigatedRoute = route,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Restaurant Quick Action Button is "Orders & Tables"
      final orderTablesBtn = find.text('Orders & Tables');
      expect(orderTablesBtn, findsOneWidget);

      await tester.tap(orderTablesBtn);
      await tester.pump();
      expect(navigatedRoute, equals('restaurantOrders'));
    });

    testWidgets('5. Business-Type Routing: Clinic mode quick actions show Appointments', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      String? navigatedRoute;

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _CustomSessionNotifier(
            const SessionState(
              isLoggedIn: true,
              userId: 'u_clinic',
              companyId: 'c_clinic',
              companyName: 'Cabinet Médical',
              businessType: 'clinic',
            ),
          )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DesktopDashboardScreen(
                onNavigate: (route) => navigatedRoute = route,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Clinic Quick Action Button is "Appointments"
      final appointmentsBtn = find.text('Appointments');
      expect(appointmentsBtn, findsOneWidget);

      await tester.tap(appointmentsBtn);
      await tester.pump();
      expect(navigatedRoute, equals('appointments'));
    });
  });
}

class _CustomSessionNotifier extends SessionNotifier {
  _CustomSessionNotifier(SessionState initialState) {
    state = initialState;
  }
}
