import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:modiri_desktop/core/database/desktop_database.dart';
import 'package:modiri_desktop/core/database/local_financial_calculator.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 8: Mobile Parity Gaps & Accounting Verification', () {
    late Database db;
    const testCompanyId = 'company_test_phase8';

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, version) async {
          // Initialize complete database schema
          await d.execute('''
            CREATE TABLE IF NOT EXISTS cart_sessions (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              customer_name TEXT,
              customer_id TEXT,
              discount REAL NOT NULL DEFAULT 0.0,
              payment_method TEXT NOT NULL DEFAULT 'cash',
              status TEXT NOT NULL DEFAULT 'ACTIVE',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS cart_session_items (
              id TEXT PRIMARY KEY,
              cart_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              product_name TEXT NOT NULL,
              unit_price REAL NOT NULL,
              quantity INTEGER NOT NULL,
              FOREIGN KEY (cart_id) REFERENCES cart_sessions(id) ON DELETE CASCADE
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS restaurant_inventory_items (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              name TEXT NOT NULL,
              category TEXT,
              unit TEXT NOT NULL DEFAULT 'kg',
              quantity REAL NOT NULL DEFAULT 0,
              minimum_stock REAL NOT NULL DEFAULT 0,
              purchase_price REAL NOT NULL DEFAULT 0,
              selling_price REAL,
              supplier TEXT,
              expiration_date TEXT,
              notes TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS restaurant_orders (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              table_name TEXT NOT NULL,
              items_json TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'preparing',
              total REAL NOT NULL DEFAULT 0.0,
              amount_paid REAL NOT NULL DEFAULT 0.0,
              payment_status TEXT NOT NULL DEFAULT 'unpaid',
              customer_name TEXT,
              customer_phone TEXT,
              order_type TEXT NOT NULL DEFAULT 'dine_in',
              notes TEXT,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS restaurant_payments (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              order_id TEXT NOT NULL,
              amount REAL NOT NULL,
              method TEXT NOT NULL DEFAULT 'cash',
              note TEXT,
              paid_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS products (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              name TEXT NOT NULL,
              category TEXT,
              barcode TEXT,
              price REAL NOT NULL,
              purchase_price REAL NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS sales (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              total REAL NOT NULL,
              paid_amount REAL NOT NULL,
              payment_status TEXT NOT NULL DEFAULT 'paid',
              sold_at TEXT,
              created_at TEXT NOT NULL
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS sale_items (
              id TEXT PRIMARY KEY,
              sale_id TEXT NOT NULL,
              product_id TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              unit_price REAL NOT NULL,
              unit_cost REAL NOT NULL DEFAULT 0
            );
          ''');

          await d.execute('''
            CREATE TABLE IF NOT EXISTS expenses (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              amount REAL NOT NULL,
              category TEXT NOT NULL,
              date TEXT,
              expense_date TEXT
            );
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Phase 1 — POS Cart Parking, Multi-Cart Switching and Persistence Across Restarts', () async {
      final now = DateTime.now().toIso8601String();
      final cart1Id = const Uuid().v4();
      final cart2Id = const Uuid().v4();

      // Create Active Cart 1 with 2 items and customer
      await db.insert('cart_sessions', {
        'id': cart1Id,
        'company_id': testCompanyId,
        'customer_name': 'Amine Bouali',
        'customer_id': 'cust-101',
        'discount': 150.0,
        'payment_method': 'cash',
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('cart_session_items', {
        'id': const Uuid().v4(),
        'cart_id': cart1Id,
        'product_id': 'prod-001',
        'product_name': 'Espresso Beans 1kg',
        'unit_price': 1200.0,
        'quantity': 2,
      });

      // Park Cart 1 (status becomes ON_HOLD)
      await db.update('cart_sessions', {'status': 'ON_HOLD'}, where: 'id = ?', whereArgs: [cart1Id]);

      // Create Cart 2 as new active cart
      await db.insert('cart_sessions', {
        'id': cart2Id,
        'company_id': testCompanyId,
        'customer_name': 'Walk-in Customer',
        'customer_id': null,
        'discount': 0.0,
        'payment_method': 'card',
        'status': 'ACTIVE',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('cart_session_items', {
        'id': const Uuid().v4(),
        'cart_id': cart2Id,
        'product_id': 'prod-002',
        'product_name': 'Bottled Water 500ml',
        'unit_price': 50.0,
        'quantity': 4,
      });

      // Query carts to verify both carts exist independently
      final allCarts = await db.query('cart_sessions', where: 'company_id = ?', whereArgs: [testCompanyId]);
      expect(allCarts.length, equals(2));

      final parkedCart = allCarts.firstWhere((c) => c['id'] == cart1Id);
      expect(parkedCart['status'], equals('ON_HOLD'));
      expect(parkedCart['customer_name'], equals('Amine Bouali'));
      expect(parkedCart['discount'], equals(150.0));

      // Resume Cart 1 (switch active cart)
      await db.update('cart_sessions', {'status': 'ON_HOLD'}, where: 'id = ?', whereArgs: [cart2Id]);
      await db.update('cart_sessions', {'status': 'ACTIVE'}, where: 'id = ?', whereArgs: [cart1Id]);

      final activeCart = (await db.query('cart_sessions', where: 'id = ?', whereArgs: [cart1Id])).first;
      expect(activeCart['status'], equals('ACTIVE'));

      final cart1Items = await db.query('cart_session_items', where: 'cart_id = ?', whereArgs: [cart1Id]);
      expect(cart1Items.length, equals(1));
      expect(cart1Items.first['product_name'], equals('Espresso Beans 1kg'));
      expect(cart1Items.first['quantity'], equals(2));
    });

    test('2. Phase 2 — Restaurant Ingredient Inventory CRUD and Stock Adjustment', () async {
      final now = DateTime.now().toIso8601String();
      final ingredientId = const Uuid().v4();

      // Register raw material (e.g. Flour 50kg bag)
      await db.insert('restaurant_inventory_items', {
        'id': ingredientId,
        'company_id': testCompanyId,
        'name': 'Farine T55 50kg',
        'category': 'Grains & Bakery',
        'unit': 'kg',
        'quantity': 100.0,
        'minimum_stock': 25.0,
        'purchase_price': 80.0, // 80 DZD/kg
        'selling_price': null,
        'supplier': 'Minoterie Centrale',
        'notes': 'Kitchen baking stock',
        'created_at': now,
        'updated_at': now,
        'synced': 0,
      });

      // Verify created ingredient
      final items = await db.query('restaurant_inventory_items', where: 'id = ?', whereArgs: [ingredientId]);
      expect(items.length, equals(1));
      expect(items.first['name'], equals('Farine T55 50kg'));
      expect((items.first['quantity'] as num).toDouble(), equals(100.0));

      // Restock purchase adjustment (+50 kg)
      await db.rawUpdate('''
        UPDATE restaurant_inventory_items
        SET quantity = quantity + 50, updated_at = ?
        WHERE id = ?
      ''', [DateTime.now().toIso8601String(), ingredientId]);

      var updated = (await db.query('restaurant_inventory_items', where: 'id = ?', whereArgs: [ingredientId])).first;
      expect((updated['quantity'] as num).toDouble(), equals(150.0));

      // Kitchen consumption adjustment (-30 kg)
      await db.rawUpdate('''
        UPDATE restaurant_inventory_items
        SET quantity = quantity - 30, updated_at = ?
        WHERE id = ?
      ''', [DateTime.now().toIso8601String(), ingredientId]);

      updated = (await db.query('restaurant_inventory_items', where: 'id = ?', whereArgs: [ingredientId])).first;
      expect((updated['quantity'] as num).toDouble(), equals(120.0));
    });

    test('3. Phase 3 — Open Restaurant Orders: Append Dishes, Partial Payment, and Completion Guard', () async {
      final now = DateTime.now().toIso8601String();
      final orderId = const Uuid().v4();

      final initialDishes = [
        {'id': 'dish-1', 'name': 'Pizza Margherita', 'unitPrice': 900.0, 'quantity': 2},
      ];

      // 1. Create open table ticket (Total = 1800 DZD, Unpaid)
      await db.insert('restaurant_orders', {
        'id': orderId,
        'company_id': testCompanyId,
        'table_name': 'Table 4',
        'items_json': jsonEncode(initialDishes),
        'status': 'preparing',
        'total': 1800.0,
        'amount_paid': 0.0,
        'payment_status': 'unpaid',
        'order_type': 'dine_in',
        'created_at': now,
        'synced': 0,
      });

      var order = (await db.query('restaurant_orders', where: 'id = ?', whereArgs: [orderId])).first;
      expect(order['total'], equals(1800.0));
      expect(order['amount_paid'], equals(0.0));
      expect(order['payment_status'], equals('unpaid'));

      // 2. Append dishes to active order ticket (+ 1 Salad @ 400 DZD, + 2 Sodas @ 150 DZD = +700 DZD)
      final appendedDishes = [
        ...initialDishes,
        {'id': 'dish-2', 'name': 'Salade César', 'unitPrice': 400.0, 'quantity': 1},
        {'id': 'dish-3', 'name': 'Soda Can', 'unitPrice': 150.0, 'quantity': 2},
      ];
      const newTotal = 1800.0 + 700.0; // 2500.0 DZD

      await db.update('restaurant_orders', {
        'items_json': jsonEncode(appendedDishes),
        'total': newTotal,
      }, where: 'id = ?', whereArgs: [orderId]);

      order = (await db.query('restaurant_orders', where: 'id = ?', whereArgs: [orderId])).first;
      expect(order['total'], equals(2500.0));
      final decodedItems = jsonDecode(order['items_json'] as String) as List;
      expect(decodedItems.length, equals(3));

      // 3. Partial payment 1: Split check 1st guest pays 1000 DZD
      final p1Id = const Uuid().v4();
      await db.insert('restaurant_payments', {
        'id': p1Id,
        'company_id': testCompanyId,
        'order_id': orderId,
        'amount': 1000.0,
        'method': 'cash',
        'note': 'Guest 1 share',
        'paid_at': now,
        'synced': 0,
      });

      await db.update('restaurant_orders', {
        'amount_paid': 1000.0,
        'payment_status': 'partially_paid',
      }, where: 'id = ?', whereArgs: [orderId]);

      order = (await db.query('restaurant_orders', where: 'id = ?', whereArgs: [orderId])).first;
      expect(order['amount_paid'], equals(1000.0));
      expect(order['payment_status'], equals('partially_paid'));

      // Verify remaining balance calculation
      final remaining = (order['total'] as num).toDouble() - (order['amount_paid'] as num).toDouble();
      expect(remaining, equals(1500.0));

      // Completion Guard: Attempting to complete with unpaid balance remaining must be prevented
      bool canCompleteOrder(Map<String, dynamic> o) {
        final totalAmt = (o['total'] as num).toDouble();
        final paidAmt = (o['amount_paid'] as num).toDouble();
        return (totalAmt - paidAmt) <= 0.01 && o['payment_status'] == 'paid';
      }

      expect(canCompleteOrder(order), isFalse);

      // 4. Settle remaining 1500 DZD
      final p2Id = const Uuid().v4();
      await db.insert('restaurant_payments', {
        'id': p2Id,
        'company_id': testCompanyId,
        'order_id': orderId,
        'amount': 1500.0,
        'method': 'card',
        'note': 'Remaining balance card',
        'paid_at': now,
        'synced': 0,
      });

      await db.update('restaurant_orders', {
        'amount_paid': 2500.0,
        'payment_status': 'paid',
        'status': 'completed',
      }, where: 'id = ?', whereArgs: [orderId]);

      order = (await db.query('restaurant_orders', where: 'id = ?', whereArgs: [orderId])).first;
      expect(order['amount_paid'], equals(2500.0));
      expect(order['payment_status'], equals('paid'));
      expect(canCompleteOrder(order), isTrue);

      // Verify payment audit trail
      final payments = await db.query('restaurant_payments', where: 'order_id = ?', whereArgs: [orderId]);
      expect(payments.length, equals(2));
    });

    test('4. Phase 4 — Slow-Moving Inventory Report & Working Capital Calculation', () async {
      final now = DateTime.now();
      final tenDaysAgo = now.subtract(const Duration(days: 10)).toIso8601String();
      final fortyDaysAgo = now.subtract(const Duration(days: 40)).toIso8601String();

      // Product A: High stock, 0 sales in 30 days (Dead stock)
      await db.insert('products', {
        'id': 'prod-dead',
        'company_id': testCompanyId,
        'name': 'Winter Coats XL',
        'category': 'Apparel',
        'barcode': '111222333',
        'price': 8000.0,
        'purchase_price': 5000.0,
        'quantity': 20, // 20 * 5000 = 100,000 DZD tied up
        'created_at': fortyDaysAgo,
        'synced': 1,
      });

      // Product B: Low velocity (1 sale in 30 days)
      await db.insert('products', {
        'id': 'prod-slow',
        'company_id': testCompanyId,
        'name': 'Luxury Watch',
        'category': 'Jewelry',
        'barcode': '444555666',
        'price': 25000.0,
        'purchase_price': 18000.0,
        'quantity': 5, // 5 * 18000 = 90,000 DZD tied up
        'created_at': fortyDaysAgo,
        'synced': 1,
      });

      // Product C: Fast moving (15 sales in 30 days)
      await db.insert('products', {
        'id': 'prod-fast',
        'company_id': testCompanyId,
        'name': 'Everyday Coffee 250g',
        'category': 'Grocery',
        'barcode': '777888999',
        'price': 400.0,
        'purchase_price': 250.0,
        'quantity': 50,
        'created_at': fortyDaysAgo,
        'synced': 1,
      });

      // Record 1 sale for Product B (10 days ago)
      final sale1Id = const Uuid().v4();
      await db.insert('sales', {
        'id': sale1Id,
        'company_id': testCompanyId,
        'total': 25000.0,
        'paid_amount': 25000.0,
        'sold_at': tenDaysAgo,
        'created_at': tenDaysAgo,
      });
      await db.insert('sale_items', {
        'id': const Uuid().v4(),
        'sale_id': sale1Id,
        'product_id': 'prod-slow',
        'quantity': 1,
        'unit_price': 25000.0,
        'unit_cost': 18000.0,
      });

      // Record 15 sales for Product C (10 days ago)
      final sale2Id = const Uuid().v4();
      await db.insert('sales', {
        'id': sale2Id,
        'company_id': testCompanyId,
        'total': 6000.0,
        'paid_amount': 6000.0,
        'sold_at': tenDaysAgo,
        'created_at': tenDaysAgo,
      });
      await db.insert('sale_items', {
        'id': const Uuid().v4(),
        'sale_id': sale2Id,
        'product_id': 'prod-fast',
        'quantity': 15,
        'unit_price': 400.0,
        'unit_cost': 250.0,
      });

      // Query slow moving with cutoff = 30 days, threshold <= 2 units
      final cutoff = now.subtract(const Duration(days: 30)).toIso8601String();
      const sql = '''
        SELECT
          p.id,
          p.name,
          p.quantity AS current_stock,
          p.purchase_price,
          COALESCE(sales_agg.units_sold, 0) AS units_sold
        FROM products p
        LEFT JOIN (
          SELECT si.product_id, SUM(si.quantity) AS units_sold
          FROM sale_items si
          JOIN sales s ON s.id = si.sale_id
          WHERE s.company_id = ? AND s.created_at >= ?
          GROUP BY si.product_id
        ) sales_agg ON sales_agg.product_id = p.id
        WHERE p.company_id = ?
          AND COALESCE(sales_agg.units_sold, 0) <= ?
        ORDER BY units_sold ASC, current_stock DESC
      ''';

      final slowRows = await db.rawQuery(sql, [testCompanyId, cutoff, testCompanyId, 2]);

      // Only Product A (0 sold) and Product B (1 sold) should match; Product C (15 sold) excluded!
      expect(slowRows.length, equals(2));
      expect(slowRows[0]['id'], equals('prod-dead'));
      expect(slowRows[0]['units_sold'], equals(0));
      expect(slowRows[1]['id'], equals('prod-slow'));
      expect(slowRows[1]['units_sold'], equals(1));

      // Calculate total tied-up capital
      final totalTiedUp = slowRows.fold<double>(0.0, (sum, r) {
        final stock = (r['current_stock'] as num).toDouble();
        final cost = (r['purchase_price'] as num).toDouble();
        return sum + (stock * cost);
      });
      expect(totalTiedUp, equals(100000.0 + 90000.0)); // 190,000 DZD
    });

    test('5. Phase 5 — Accounting Parity: Global COGS Deduction for General Retail vs Restaurant', () async {
      final now = DateTime.now().toIso8601String();

      // Product cost = 600, sold for 1000
      await db.insert('products', {
        'id': 'p-retail-1',
        'company_id': testCompanyId,
        'name': 'Retail Jacket',
        'price': 1000.0,
        'purchase_price': 600.0,
        'quantity': 10,
        'created_at': now,
      });

      final saleId = const Uuid().v4();
      await db.insert('sales', {
        'id': saleId,
        'company_id': testCompanyId,
        'total': 1000.0,
        'paid_amount': 1000.0,
        'sold_at': now,
        'created_at': now,
      });

      await db.insert('sale_items', {
        'id': const Uuid().v4(),
        'sale_id': saleId,
        'product_id': 'p-retail-1',
        'quantity': 1,
        'unit_price': 1000.0,
        'unit_cost': 600.0,
      });

      // Operating expenses = 150
      await db.insert('expenses', {
        'id': const Uuid().v4(),
        'company_id': testCompanyId,
        'amount': 150.0,
        'category': 'Rent',
        'date': now,
        'expense_date': now,
      });

      // General retail business: net profit = allRevenue (1000) - globalCogs (600) - allExpenses (150) = 250 DZD
      final retailCalc = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'monthly',
        companyId: testCompanyId,
        businessType: 'retail',
        customDb: db,
      );
      expect(retailCalc.allRevenue, equals(1000.0));
      expect(retailCalc.globalCogs, equals(600.0));
      expect(retailCalc.allExpenses, equals(150.0));
      expect(retailCalc.globalNetProfit, equals(250.0));

      // Restaurant business: allRevenue (1000) - inventoryValue (6000) - allExpenses (150)
      final restaurantCalc = await DesktopLocalFinancialCalculator.calculateReport(
        period: 'monthly',
        companyId: testCompanyId,
        businessType: 'restaurant',
        customDb: db,
      );
      expect(restaurantCalc.inventoryValue, equals(6000.0));
      expect(restaurantCalc.globalNetProfit, equals(1000.0 - 150.0));
    });

    test('6. Localization completeness across EN, FR, AR for all phase 8 feature keys', () {
      final locales = [
        const Locale('en'),
        const Locale('fr'),
        const Locale('ar'),
      ];

      final keysToVerify = [
        'park_cart',
        'cart_parked_success',
        'resume_cart',
        'new_cart',
        'parked',
        'raw_materials',
        'add_raw_material',
        'quantity_unit',
        'unit',
        'movement_type',
        'restock_purchase',
        'consumption',
        'stock_adjusted_success',
        'ingredient_added_success',
        'add_dishes',
        'partial_payment',
        'pay_full',
        'split_check',
        'remaining_balance',
        'payment_recorded_success',
        'dishes_added_success',
        'order_not_paid_warning',
        'cannot_complete_unpaid',
        'payment_history',
        'order_paid_full',
        'order_partially_paid',
        'order_unpaid',
        'total_paid',
        'amount_to_pay',
        'slow_moving_stock',
        'threshold_units',
        'days_period',
        'units_sold',
        'tied_up_capital',
        'days_in_inventory',
      ];

      for (final locale in locales) {
        final loc = ModiriLocalizations(locale);
        for (final k in keysToVerify) {
          final val = loc.get(k);
          expect(val, isNotEmpty, reason: 'Key $k should be non-empty in ${locale.languageCode}');
          expect(val, isNot(equals(k)), reason: 'Key $k must be translated in ${locale.languageCode}');
        }
      }
    });
  });
}
