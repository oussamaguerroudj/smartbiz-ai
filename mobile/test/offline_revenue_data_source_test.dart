import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/connectivity/connectivity_service.dart';
import 'package:modiri_ai/core/database/app_database.dart';
import 'package:modiri_ai/core/database/local_financial_calculator.dart';
import 'package:modiri_ai/core/network/api_client.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/features/reports/data/reports_repository.dart';
import 'package:modiri_ai/features/reports/domain/report.dart';
import 'package:modiri_ai/features/sales/data/sales_repository.dart';
import 'package:modiri_ai/features/sales/domain/sale.dart';
import 'package:http/http.dart' as http;
import 'package:modiri_ai/core/sync/sync_service.dart';
import 'package:modiri_ai/features/expenses/data/expenses_repository.dart';
import 'package:modiri_ai/features/expenses/domain/expense.dart';

const companyA = 'comp_alpha_offline_test';
const companyB = 'comp_beta_offline_test';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Offline Revenue Data Source, Refresh & Tenant Isolation Tests', () {
    late Database db;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Create full database schema required for sales, expenses, reports
      await db.execute('''
        CREATE TABLE sync_metadata (
          key TEXT PRIMARY KEY,
          value TEXT,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          category TEXT,
          purchase_price REAL NOT NULL,
          selling_price REAL NOT NULL,
          quantity INTEGER NOT NULL,
          minimum_stock INTEGER DEFAULT 5,
          barcode TEXT,
          expiration_date TEXT,
          size TEXT,
          color TEXT,
          brand TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          client_transaction_id TEXT,
          company_id TEXT NOT NULL,
          customer_id TEXT,
          customer_name TEXT,
          employee_id TEXT,
          subtotal REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0.0,
          total REAL NOT NULL,
          payment_status TEXT NOT NULL DEFAULT 'paid',
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          sale_id TEXT NOT NULL,
          company_id TEXT,
          product_id TEXT NOT NULL,
          product_name TEXT,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          unit_cost REAL NOT NULL,
          line_total REAL NOT NULL,
          line_profit REAL NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          client_id TEXT,
          company_id TEXT NOT NULL,
          employee_id TEXT,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          expense_date TEXT NOT NULL,
          period_type TEXT DEFAULT 'one_time',
          salary_period TEXT,
          duration TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE credit_payments (
          id TEXT PRIMARY KEY,
          client_id TEXT UNIQUE,
          company_id TEXT,
          customer_id TEXT NOT NULL,
          amount REAL NOT NULL DEFAULT 0,
          payment_date TEXT,
          note TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE restaurant_orders (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          table_id TEXT,
          order_number TEXT,
          customer_name TEXT,
          customer_phone TEXT,
          total_amount REAL NOT NULL,
          status TEXT NOT NULL DEFAULT 'completed',
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE invoices (
          id TEXT PRIMARY KEY,
          sale_id TEXT NOT NULL,
          company_id TEXT,
          invoice_number TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'paid',
          customer_name TEXT,
          total REAL NOT NULL,
          sold_at TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
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

      await db.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT,
          balance_due REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE appointments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          patient_name TEXT,
          status TEXT NOT NULL DEFAULT 'scheduled',
          scheduled_at TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      AppDatabase.setTestDatabase(db);
    });

    tearDown(() async {
      AppDatabase.setTestDatabase(null);
      await db.close();
    });

    test('1 & 2 & 3: Seed SQLite with known transactions, run report in offline mode, verify revenue matches local dataset', () async {
      // 1. Seed Company A with:
      // Sale 1: 15,000 DZD
      // Sale 2: 25,000 DZD
      // Credit payment (down payment/debt repay): 10,000 DZD
      // Cancelled Sale (should be excluded): 5,000 DZD
      await db.insert('sales', {
        'id': 'sale-1',
        'company_id': companyA,
        'total': 15000.0,
        'subtotal': 15000.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T10:00:00.000',
        'created_at': '${todayStr}T10:00:00.000',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-1',
        'sale_id': 'sale-1',
        'company_id': companyA,
        'product_id': 'p-1',
        'product_name': 'Item A',
        'quantity': 1,
        'unit_price': 15000.0,
        'unit_cost': 10000.0,
        'line_total': 15000.0,
        'line_profit': 5000.0,
      });

      await db.insert('sales', {
        'id': 'sale-2',
        'company_id': companyA,
        'total': 25000.0,
        'subtotal': 25000.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T12:00:00.000',
        'created_at': '${todayStr}T12:00:00.000',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-2',
        'sale_id': 'sale-2',
        'company_id': companyA,
        'product_id': 'p-2',
        'product_name': 'Item B',
        'quantity': 2,
        'unit_price': 12500.0,
        'unit_cost': 8000.0,
        'line_total': 25000.0,
        'line_profit': 9000.0,
      });

      await db.insert('credit_payments', {
        'id': 'cp-1',
        'company_id': companyA,
        'customer_id': 'cust-1',
        'amount': 10000.0,
        'created_at': '${todayStr}T14:00:00.000',
        'synced': 1,
      });

      // Cancelled sale
      await db.insert('sales', {
        'id': 'sale-cancelled',
        'company_id': companyA,
        'total': 5000.0,
        'subtotal': 5000.0,
        'payment_status': 'cancelled',
        'sold_at': '${todayStr}T09:00:00.000',
        'created_at': '${todayStr}T09:00:00.000',
        'synced': 1,
      });

      // Create a container with mocked session and offline connectivity
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => SessionNotifierStub(
            const Session(accessToken: 'fake-token', companyId: companyA, userId: 'user-a'),
          )),
          connectionStatusProvider.overrideWith((ref) => ConnectionNotifierStub(ConnectionStatus.offline)),
        ],
      );
      addTearDown(container.dispose);

      // Run report offline with our active SQLite database
      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyA,
        date: todayStr,
        db: db,
      );

      // Expected revenue: 15,000 + 25,000 + 10,000 (credit) = 50,000 (cancelled 5,000 excluded)
      expect(report.revenue, 50000.0);
      expect(report.allRevenue, 50000.0);
      expect(report.salesCount, 2);
    });

    test('Tenant isolation: Company B data never leaks into Company A revenue', () async {
      // Seed Company A: 20,000 DZD
      await db.insert('sales', {
        'id': 'sale-a-1',
        'company_id': companyA,
        'total': 20000.0,
        'subtotal': 20000.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T10:00:00.000',
        'created_at': '${todayStr}T10:00:00.000',
        'synced': 1,
      });

      // Seed Company B: 80,000 DZD
      await db.insert('sales', {
        'id': 'sale-b-1',
        'company_id': companyB,
        'total': 80000.0,
        'subtotal': 80000.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T11:00:00.000',
        'created_at': '${todayStr}T11:00:00.000',
        'synced': 1,
      });

      // Seed Company B expense: 15,000 DZD
      await db.insert('expenses', {
        'id': 'exp-b-1',
        'company_id': companyB,
        'category': 'rent',
        'amount': 15000.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T11:00:00.000',
        'synced': 1,
      });

      final reportA = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyA,
        date: todayStr,
        db: db,
      );

      final reportB = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyB,
        date: todayStr,
        db: db,
      );

      // Verify strict isolation
      expect(reportA.revenue, 20000.0);
      expect(reportA.expenses, 0.0);

      expect(reportB.revenue, 80000.0);
      expect(reportB.expenses, 15000.0);
      expect(reportB.netProfit, 65000.0);
    });

    test('Authoritative cache + unsynced mutations: Zero double counting', () async {
      // 1. Authoritative server report cached in sync_metadata for Company A
      final cachedReportJson = jsonEncode({
        'revenue': 100000.0,
        'expenses': 30000.0,
        'netProfit': 70000.0,
        'salesCount': 10,
        'itemsSold': 25,
        'averageBasket': 10000.0,
        'cashRevenue': 80000.0,
        'creditRevenue': 20000.0,
        'creditCollected': 0.0,
        'grossProfit': 85000.0,
        'grossMargin': 85.0,
        'period': 'daily',
        'periodStart': '${todayStr}T00:00:00.000Z',
        'periodEnd': '${todayStr}T23:59:59.999Z',
      });

      await db.insert('sync_metadata', {
        'key': 'report_cache_${companyA}_daily_$todayStr',
        'value': cachedReportJson,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Add an unsynced offline sale (synced = 0) of 12,000 DZD
      await db.insert('sales', {
        'id': 'offline-sale-unsynced',
        'company_id': companyA,
        'total': 12000.0,
        'subtotal': 12000.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T15:00:00.000',
        'created_at': '${todayStr}T15:00:00.000',
        'synced': 0,
      });

      // Verify that unsynced offline sale is queryable and properly identified
      final unsyncedSales = await db.query(
        'sales',
        where: 'company_id = ? AND synced = 0',
        whereArgs: [companyA],
      );
      expect(unsyncedSales.length, 1);
      expect(unsyncedSales.first['total'], 12000.0);

      // Once synced = 1 (after queue sync), it no longer counts as unsynced
      await db.update(
        'sales',
        {'synced': 1},
        where: "id = 'offline-sale-unsynced'",
      );
      final remainingUnsynced = await db.query(
        'sales',
        where: 'company_id = ? AND synced = 0',
        whereArgs: [companyA],
      );
      expect(remainingUnsynced, isEmpty);
    });

    test('Financial calculation parity: Revenue is Gross Sales, Profit is Margin minus Expenses', () async {
      // Selling price 200, unit cost (purchase price) 190, quantity 2.
      // Revenue = 200 * 2 = 400.
      // COGS = 190 * 2 = 380.
      // Gross Profit = 400 - 380 = 20.
      // Expense = 5.
      // Net Profit = 20 - 5 = 15.
      await db.insert('sales', {
        'id': 'sale-parity-1',
        'company_id': companyA,
        'total': 400.0,
        'subtotal': 400.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T11:00:00.000',
        'created_at': '${todayStr}T11:00:00.000',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-parity-1',
        'sale_id': 'sale-parity-1',
        'company_id': companyA,
        'product_id': 'p-parity-1',
        'product_name': 'Item Parity',
        'quantity': 2,
        'unit_price': 200.0,
        'unit_cost': 190.0,
        'line_total': 400.0,
        'line_profit': 20.0,
      });

      await db.insert('expenses', {
        'id': 'exp-parity-1',
        'company_id': companyA,
        'category': 'supplies',
        'amount': 5.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T11:30:00.000',
        'synced': 1,
      });

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyA,
        date: todayStr,
        db: db,
      );

      // Verify domain definitions:
      // Today Revenue MUST be gross sales (400.0), NOT margin/profit (20.0).
      expect(report.revenue, 400.0);
      expect(report.grossProfit, 20.0);
      expect(report.expenses, 5.0);
      expect(report.netProfit, 15.0);
    });

    test('ReportsRepository offline cached reconciliation with unsynced local mutations', () async {
      // 1. Authoritative cached server report
      final cachedJson = {
        'revenue': 1000.0,
        'grossProfit': 300.0,
        'grossMargin': 30.0,
        'expenses': 100.0,
        'netProfit': 200.0,
        'salesCount': 5,
        'itemsSold': 10,
        'averageBasket': 200.0,
        'cashRevenue': 800.0,
        'creditRevenue': 200.0,
        'creditCollected': 0.0,
        'expensesBreakdown': {
          'costOfGoodsSold': 700.0,
          'operatingExpenses': 100.0,
          'salaryExpenses': 0.0,
          'categoryBreakdown': <String, dynamic>{},
        },
        'period': 'daily',
        'periodStart': '${todayStr}T00:00:00.000Z',
        'periodEnd': '${todayStr}T23:59:59.999Z',
      };

      await db.insert('sync_metadata', {
        'key': 'report_cache_${companyA}_daily_${todayStr}__',
        'value': jsonEncode(cachedJson),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Unsynced local sale: total 400, cost 350 -> gross profit 50
      await db.insert('sales', {
        'id': 'sale-reconcile-unsynced',
        'company_id': companyA,
        'total': 400.0,
        'subtotal': 400.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T16:00:00.000',
        'created_at': '${todayStr}T16:00:00.000',
        'synced': 0,
      });
      await db.insert('sale_items', {
        'id': 'si-reconcile-1',
        'sale_id': 'sale-reconcile-unsynced',
        'company_id': companyA,
        'product_id': 'p-rec-1',
        'product_name': 'Item Rec',
        'quantity': 1,
        'unit_price': 400.0,
        'unit_cost': 350.0,
        'line_total': 400.0,
        'line_profit': 50.0,
      });

      // 3. Unsynced local expense: amount 30
      await db.insert('expenses', {
        'id': 'exp-reconcile-unsynced',
        'company_id': companyA,
        'category': 'maintenance',
        'amount': 30.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T16:30:00.000',
        'synced': 0,
      });

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => SessionNotifierStub(
            const Session(accessToken: 'fake-token', companyId: companyA, userId: 'user-a'),
          )),
          connectionStatusProvider.overrideWith((ref) => ConnectionNotifierStub(ConnectionStatus.offline)),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(reportsRepositoryProvider);
      final report = await repo.getReport(period: 'daily', date: todayStr, db: db);

      // Reconciled totals:
      // Revenue: 1000 + 400 = 1400
      // Gross Profit: 300 + (400 - 350) = 350
      // Expenses: 100 + 30 = 130
      // Net Profit: 350 - 130 = 220
      // Sales count: 5 + 1 = 6
      expect(report.revenue, 1400.0);
      expect(report.grossProfit, 350.0);
      expect(report.expenses, 130.0);
      expect(report.netProfit, 220.0);
      expect(report.salesCount, 6);
    });

    test('Offline expense sync lifecycle: server ID adoption and synced state update', () async {
      const localExpId = 'local-exp-uuid-99';
      const serverExpId = 'srv-exp-real-777';

      // 1. Create offline expense
      await db.insert('expenses', {
        'id': localExpId,
        'client_id': localExpId,
        'company_id': companyA,
        'category': 'logistics',
        'amount': 7500.0,
        'description': 'Offline fuel payment',
        'expense_date': todayStr,
        'created_at': '${todayStr}T12:00:00.000',
        'synced': 0,
      });

      // 2. Queue the expense operation
      await db.insert('sync_queue', {
        'id': 'queue-op-exp-1',
        'company_id': companyA,
        'client_transaction_id': localExpId,
        'entity_type': 'expense',
        'entity_id': localExpId,
        'operation_type': 'create',
        'payload': jsonEncode({
          'client_id': localExpId,
          'category': 'logistics',
          'amount': 7500.0,
          'expense_date': todayStr,
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': '${todayStr}T12:00:00.000',
        'updated_at': '${todayStr}T12:00:00.000',
      });

      // 3. Simulate backend sync acknowledgment: server returns new server ID
      await db.update(
        'expenses',
        {
          'id': serverExpId,
          'client_id': localExpId,
          'synced': 1,
        },
        where: 'id = ? OR client_id = ?',
        whereArgs: [localExpId, localExpId],
      );
      await db.update(
        'sync_queue',
        {
          'status': 'synced',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: "id = 'queue-op-exp-1'",
      );

      // Verify persistence:
      final expRows = await db.query('expenses', where: 'id = ?', whereArgs: [serverExpId]);
      expect(expRows.length, 1);
      expect(expRows.first['client_id'], localExpId);
      expect(expRows.first['synced'], 1);

      final queueRows = await db.query('sync_queue', where: "status = 'pending'");
      expect(queueRows, isEmpty);
    });

    test('Idempotent conflict resolution: 409 conflict marks queue and local entity as synced', () async {
      const localSalId = 'local-salary-uuid-409';

      await db.insert('expenses', {
        'id': localSalId,
        'client_id': localSalId,
        'company_id': companyA,
        'category': 'salary',
        'amount': 50000.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T10:00:00.000',
        'synced': 0,
      });

      await db.insert('sync_queue', {
        'id': 'queue-op-sal-409',
        'company_id': companyA,
        'client_transaction_id': localSalId,
        'entity_type': 'expense',
        'entity_id': localSalId,
        'operation_type': 'create',
        'payload': jsonEncode({
          'client_id': localSalId,
          'category': 'salary',
          'amount': 50000.0,
          'salary_period': '2026-10',
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': '${todayStr}T10:00:00.000',
        'updated_at': '${todayStr}T10:00:00.000',
      });

      // Simulate 409 Conflict handling in SyncService
      await db.update(
        'sync_queue',
        {'status': 'synced', 'updated_at': DateTime.now().toIso8601String()},
        where: "id = 'queue-op-sal-409'",
      );
      await db.update(
        'expenses',
        {'synced': 1},
        where: 'id = ? OR client_id = ?',
        whereArgs: [localSalId, localSalId],
      );

      final pendingRes = await db.rawQuery("SELECT COUNT(*) AS count FROM sync_queue WHERE status = 'pending'");
      final pendingCount = (pendingRes.first['count'] as num?)?.toInt() ?? 0;
      expect(pendingCount, 0);

      final exp = await db.query('expenses', where: 'id = ?', whereArgs: [localSalId]);
      expect(exp.first['synced'], 1);
    });

    test('Date parsing parity: ISO with Z, without Z, and offset dates match period', () async {
      await db.insert('sales', {
        'id': 'sale-z',
        'company_id': companyA,
        'total': 100.0,
        'subtotal': 100.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T10:00:00.000Z',
        'created_at': '${todayStr}T10:00:00.000Z',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-z',
        'sale_id': 'sale-z',
        'company_id': companyA,
        'product_id': 'p-z',
        'quantity': 1,
        'unit_price': 100.0,
        'unit_cost': 70.0,
        'line_total': 100.0,
        'line_profit': 30.0,
      });

      await db.insert('sales', {
        'id': 'sale-offset',
        'company_id': companyA,
        'total': 200.0,
        'subtotal': 200.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T10:00:00+01:00',
        'created_at': '${todayStr}T10:00:00+01:00',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-offset',
        'sale_id': 'sale-offset',
        'company_id': companyA,
        'product_id': 'p-offset',
        'quantity': 1,
        'unit_price': 200.0,
        'unit_cost': 140.0,
        'line_total': 200.0,
        'line_profit': 60.0,
      });

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyA,
        date: todayStr,
        db: db,
      );

      expect(report.revenue, 300.0);
      expect(report.salesCount, 2);
    });

    test('Exact Online/Offline Parity: product costs, quantities, discounts, credit payments, cancelled sales, expenses', () async {
      const parityCompany = 'comp_parity_test';

      // 1. Products
      await db.insert('products', {
        'id': 'prod-1',
        'company_id': parityCompany,
        'name': 'Widget Alpha',
        'purchase_price': 150.0,
        'selling_price': 250.0,
        'quantity': 100,
      });
      await db.insert('products', {
        'id': 'prod-2',
        'company_id': parityCompany,
        'name': 'Widget Beta',
        'purchase_price': 80.0,
        'selling_price': 120.0,
        'quantity': 50,
      });

      // 2. Sales:
      // Sale 1: Normal sale: 2 x Widget Alpha (subtotal 500), discount 50 -> total 450. COGS = 2 * 150 = 300.
      await db.insert('sales', {
        'id': 'sale-parity-1',
        'company_id': parityCompany,
        'subtotal': 500.0,
        'discount': 50.0,
        'total': 450.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T10:30:00.000Z',
        'created_at': '${todayStr}T10:30:00.000Z',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-parity-1',
        'sale_id': 'sale-parity-1',
        'company_id': parityCompany,
        'product_id': 'prod-1',
        'quantity': 2,
        'unit_price': 250.0,
        'unit_cost': 150.0,
        'line_total': 500.0,
        'line_profit': 200.0,
      });

      // Sale 2: Sale with missing/zero unit_cost in sale_items (relies on product purchase_price fallback)
      // 3 x Widget Beta: subtotal 360, discount 0 -> total 360. COGS = 3 * 80 = 240.
      await db.insert('sales', {
        'id': 'sale-parity-2',
        'company_id': parityCompany,
        'subtotal': 360.0,
        'discount': 0.0,
        'total': 360.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T11:00:00.000',
        'created_at': '${todayStr}T11:00:00.000',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-parity-2',
        'sale_id': 'sale-parity-2',
        'company_id': parityCompany,
        'product_id': 'prod-2',
        'quantity': 3,
        'unit_price': 120.0,
        'unit_cost': 0.0, // 0 in sale_items -> must fallback to product purchase_price (80.0)
        'line_total': 360.0,
        'line_profit': 120.0,
      });

      // Sale 3: Cancelled sale: 500 DZD (must be completely EXCLUDED from revenue and COGS)
      await db.insert('sales', {
        'id': 'sale-parity-cancelled',
        'company_id': parityCompany,
        'subtotal': 500.0,
        'discount': 0.0,
        'total': 500.0,
        'payment_status': 'cancelled',
        'sold_at': '${todayStr}T12:00:00.000',
        'created_at': '${todayStr}T12:00:00.000',
        'synced': 1,
      });
      await db.insert('sale_items', {
        'id': 'si-parity-cancelled',
        'sale_id': 'sale-parity-cancelled',
        'company_id': parityCompany,
        'product_id': 'prod-1',
        'quantity': 2,
        'unit_price': 250.0,
        'unit_cost': 150.0,
        'line_total': 500.0,
        'line_profit': 200.0,
      });

      // 3. Credit Payment: 120 DZD received today (counts towards revenue)
      await db.insert('credit_payments', {
        'id': 'cp-parity-1',
        'company_id': parityCompany,
        'customer_id': 'cust-p1',
        'amount': 120.0,
        'payment_date': '${todayStr}T13:00:00.000',
        'created_at': '${todayStr}T13:00:00.000',
        'synced': 1,
      });

      // 4. Expenses:
      // Operating expense: 70 DZD
      await db.insert('expenses', {
        'id': 'exp-parity-op',
        'company_id': parityCompany,
        'category': 'utilities',
        'amount': 70.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T14:00:00.000',
        'synced': 1,
      });
      // Salary expense: 100 DZD
      await db.insert('expenses', {
        'id': 'exp-parity-sal',
        'company_id': parityCompany,
        'category': 'salary',
        'amount': 100.0,
        'expense_date': todayStr,
        'created_at': '${todayStr}T14:30:00.000',
        'synced': 1,
      });

      // AUTHORITATIVE ONLINE FORMULAS (reproducing calculateFinancials):
      // coreSalesRevenue = 450 + 360 = 810 (cancelled 500 excluded)
      // creditRev = 120
      // onlineExpectedRevenue = 810 + 120 = 930
      // cogsTotal = (2 * 150) + (3 * 80) = 300 + 240 = 540 (cancelled excluded)
      // grossProfit = 930 - 540 = 390
      // operatingExpenses = 70
      // employeeSalaries = 100
      // totalExpenses = 70 + 100 = 170
      // netProfit = 390 - 170 = 220
      // salesCount = 2

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: parityCompany,
        date: todayStr,
        db: db,
      );

      expect(report.revenue, 930.0, reason: 'Revenue must match online calculation exactly');
      expect(report.expensesBreakdown.costOfGoodsSold, 540.0, reason: 'COGS must match online calculation with fallback');
      expect(report.grossProfit, 390.0, reason: 'Gross Profit must match online calculation');
      expect(report.operatingExpenses, 70.0);
      expect(report.employeeSalaries, 100.0);
      expect(report.expenses, 170.0);
      expect(report.netProfit, 220.0, reason: 'Net Profit must match online calculation');
      expect(report.salesCount, 2);

      // Verify calculateDashboard parity
      final dashboard = await LocalFinancialCalculator.calculateDashboard(
        companyId: parityCompany,
        db: db,
      );
      expect(dashboard.todayRevenue, 930.0);
      expect(dashboard.todayExpenses, 170.0);
      expect(dashboard.todayProfit, 220.0);
      expect(dashboard.todayGrossProfit, 390.0);
      expect(dashboard.salesCount, 2);
    });

    test('Online-to-offline synchronization deduplication: 1,000 DZD online vs 1,400 DZD duplicate bug', () async {
      final fakeApi = FakeSyncApiClient(
        onPost: (path, {body}) {
          if (path == '/sales') {
            return {
              'data': {
                'sale': {
                  'id': 'sale-srv-400',
                  'client_transaction_id': 'client-tx-400',
                  'total': 400.0,
                  'sold_at': '${todayStr}T11:00:00.000',
                  'payment_status': 'paid',
                },
                'items': [],
                'invoice': {
                  'id': 'inv-srv-400',
                  'invoice_number': 'INV-400',
                },
              },
            };
          }
          return {'data': true};
        },
        onGet: (path, {query}) {
          if (path == '/sales') {
            // Authoritative server sales: 1 pre-existing sale of 600 DZD + 1 sale of 400 DZD = 1,000 DZD total
            return {
              'data': [
                {
                  'id': 'sale-srv-600',
                  'client_transaction_id': 'client-tx-600',
                  'company_id': companyA,
                  'total': 600.0,
                  'subtotal': 600.0,
                  'discount': 0.0,
                  'payment_status': 'paid',
                  'sold_at': '${todayStr}T09:00:00.000',
                  'created_at': '${todayStr}T09:00:00.000',
                  'margin': 200.0,
                },
                {
                  'id': 'sale-srv-400',
                  'client_transaction_id': 'client-tx-400',
                  'company_id': companyA,
                  'total': 400.0,
                  'subtotal': 400.0,
                  'discount': 0.0,
                  'payment_status': 'paid',
                  'sold_at': '${todayStr}T11:00:00.000',
                  'created_at': '${todayStr}T11:00:00.000',
                  'margin': 150.0,
                },
              ],
            };
          }
          return {'data': []};
        },
      );

      final sessionStub = SessionNotifierStub(const Session(
        accessToken: 'token-a',
        refreshToken: 'refresh-a',
        userId: 'user-a',
        companyId: companyA,
        userName: 'Owner A',
        email: 'owner-a@modiri.dz',
        role: 'owner',
      ));
      final connStub = ConnectionNotifierStub(ConnectionStatus.online);

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => sessionStub),
          connectionStatusProvider.overrideWith((ref) => connStub),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      // 1. Create offline sale locally for 400 DZD
      await db.insert('sales', {
        'id': 'sale-local-400',
        'client_transaction_id': 'client-tx-400',
        'company_id': companyA,
        'customer_name': 'Offline Customer',
        'subtotal': 400.0,
        'discount': 0.0,
        'total': 400.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T11:00:00.000',
        'created_at': '${todayStr}T11:00:00.000',
        'synced': 0,
      });
      await db.insert('sale_items', {
        'id': 'si-local-400',
        'sale_id': 'sale-local-400',
        'company_id': companyA,
        'product_id': 'prod-1',
        'product_name': 'Item 1',
        'quantity': 1,
        'unit_price': 400.0,
        'unit_cost': 250.0,
        'line_total': 400.0,
        'line_profit': 150.0,
      });
      await db.insert('invoices', {
        'id': 'inv-local-400',
        'sale_id': 'sale-local-400',
        'company_id': companyA,
        'invoice_number': 'INV-LOCAL-1',
        'status': 'paid',
        'customer_name': 'Offline Customer',
        'total': 400.0,
        'sold_at': '${todayStr}T11:00:00.000',
        'created_at': '${todayStr}T11:00:00.000',
      });
      await db.insert('sync_queue', {
        'id': 'queue-op-sale-400',
        'company_id': companyA,
        'client_transaction_id': 'client-tx-400',
        'entity_type': 'sale',
        'entity_id': 'sale-local-400',
        'operation_type': 'CREATE',
        'payload': jsonEncode({
          'items': [{'productId': 'prod-1', 'quantity': 1}],
          'discount': 0.0,
          'paymentStatus': 'paid',
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': '${todayStr}T11:00:00.000',
        'updated_at': '${todayStr}T11:00:00.000',
      });

      // 2. Perform synchronization (syncPending uploads local sale, pullInitialData downloads server sales)
      final syncService = container.read(syncServiceProvider.notifier);
      await syncService.syncPending();
      await syncService.pullInitialData();

      // 3. Verify SQLite sales count and local financial calculation
      final localSales = await db.query(
        'sales',
        where: 'company_id = ? AND payment_status = ?',
        whereArgs: [companyA, 'paid'],
      );
      // There should only be 2 sales: the 600 DZD server sale and the 400 DZD sale.
      // WITHOUT the fix, there are 3 sales (sale-local-400 + sale-srv-400 + sale-srv-600), totaling 1,400 DZD!
      expect(localSales.length, 2, reason: 'Duplicate sale row must not coexist in SQLite');

      // Verify sale items and invoices are preserved under the new server sale ID
      final itemsForSrvSale = await db.query(
        'sale_items',
        where: 'sale_id = ? AND company_id = ?',
        whereArgs: ['sale-srv-400', companyA],
      );
      expect(itemsForSrvSale.length, 1, reason: 'Sale items must be preserved under server sale ID');
      expect(itemsForSrvSale.first['product_id'], 'prod-1');
      expect(itemsForSrvSale.first['product_name'], 'Item 1');
      expect((itemsForSrvSale.first['unit_price'] as num).toDouble(), 400.0);

      final invoicesForSrvSale = await db.query(
        'invoices',
        where: 'sale_id = ? AND company_id = ?',
        whereArgs: ['sale-srv-400', companyA],
      );
      expect(invoicesForSrvSale.length, 1, reason: 'Invoice reference must be preserved under server sale ID');
      expect(invoicesForSrvSale.first['customer_name'], 'Offline Customer');

      // Verify sync_queue entity_id was updated to server sale ID
      final queueRows = await db.query(
        'sync_queue',
        where: 'client_transaction_id = ? AND company_id = ?',
        whereArgs: ['client-tx-400', companyA],
      );
      expect(queueRows.first['entity_id'], 'sale-srv-400');
      expect(queueRows.first['status'], 'synced');

      // Verify tenant isolation: Company B sees 0 sales
      final compBSales = await db.query(
        'sales',
        where: 'company_id = ?',
        whereArgs: [companyB],
      );
      expect(compBSales, isEmpty, reason: 'Company B must have zero sales');

      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyA,
        date: todayStr,
        db: db,
      );

      // The true online revenue is 1,000 DZD, NOT 1,400 DZD!
      expect(report.revenue, 1000.0, reason: 'Revenue must be 1,000 DZD, not 1,400 DZD phantom duplicate');
      expect(report.salesCount, 2, reason: 'Sales count must be 2, not 3');

      // 4. Repeated synchronization must remain idempotent and NOT duplicate
      await syncService.pullInitialData();

      final reportAfterResync = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyA,
        date: todayStr,
        db: db,
      );
      expect(reportAfterResync.revenue, 1000.0, reason: 'Repeated sync must keep revenue at 1,000 DZD');
      expect(reportAfterResync.salesCount, 2);
    });

    test('Pre-sync pull resilience: pullInitialData before syncPending preserves pending state without duplication', () async {
      final fakeApi = FakeSyncApiClient(
        onPost: (path, {body}) {
          if (path == '/sales') {
            return {
              'data': {
                'sale': {
                  'id': 'sale-srv-400',
                  'client_transaction_id': 'client-tx-pre',
                  'total': 400.0,
                  'sold_at': '${todayStr}T11:00:00.000',
                  'payment_status': 'paid',
                },
                'items': [],
                'invoice': {
                  'id': 'inv-srv-400',
                  'invoice_number': 'INV-400',
                },
              },
            };
          }
          return {'data': true};
        },
        onGet: (path, {query}) {
          if (path == '/sales') {
            return {
              'data': [
                {
                  'id': 'sale-srv-600',
                  'client_transaction_id': 'client-tx-600',
                  'company_id': companyA,
                  'total': 600.0,
                  'subtotal': 600.0,
                  'payment_status': 'paid',
                  'sold_at': '${todayStr}T09:00:00.000',
                  'created_at': '${todayStr}T09:00:00.000',
                  'margin': 200.0,
                },
                {
                  'id': 'sale-srv-400',
                  'client_transaction_id': 'client-tx-pre',
                  'company_id': companyA,
                  'total': 400.0,
                  'subtotal': 400.0,
                  'payment_status': 'paid',
                  'sold_at': '${todayStr}T11:00:00.000',
                  'created_at': '${todayStr}T11:00:00.000',
                  'margin': 150.0,
                },
              ],
            };
          }
          return {'data': []};
        },
      );

      final sessionStub = SessionNotifierStub(const Session(
        accessToken: 'token-a',
        refreshToken: 'refresh-a',
        userId: 'user-a',
        companyId: companyA,
        userName: 'Owner A',
        email: 'owner-a@modiri.dz',
        role: 'owner',
      ));
      final connStub = ConnectionNotifierStub(ConnectionStatus.online);

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => sessionStub),
          connectionStatusProvider.overrideWith((ref) => connStub),
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      // Local unsynced sale
      await db.insert('sales', {
        'id': 'sale-local-pre',
        'client_transaction_id': 'client-tx-pre',
        'company_id': companyA,
        'customer_name': 'Pending Customer',
        'subtotal': 400.0,
        'discount': 0.0,
        'total': 400.0,
        'payment_status': 'paid',
        'sold_at': '${todayStr}T11:00:00.000',
        'created_at': '${todayStr}T11:00:00.000',
        'synced': 0,
      });
      await db.insert('sync_queue', {
        'id': 'queue-op-sale-pre',
        'company_id': companyA,
        'client_transaction_id': 'client-tx-pre',
        'entity_type': 'sale',
        'entity_id': 'sale-local-pre',
        'operation_type': 'CREATE',
        'payload': jsonEncode({
          'items': [],
          'discount': 0.0,
          'paymentStatus': 'paid',
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': '${todayStr}T11:00:00.000',
        'updated_at': '${todayStr}T11:00:00.000',
      });

      final syncService = container.read(syncServiceProvider.notifier);

      // 1. pullInitialData runs FIRST (before syncPending)
      await syncService.pullInitialData();

      // The pending local sale must NOT have been duplicated by pulling the server row with matching client_transaction_id!
      final countBeforeSync = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales WHERE company_id = ?',
        [companyA],
      );
      expect((countBeforeSync.first['count'] as num).toInt(), 2, reason: 'Pending sale + 1 other server sale = 2 sales');

      // 2. Now syncPending runs to upload the pending sale
      await syncService.syncPending();

      // 3. Final pullInitialData confirms stable deduplicated state
      await syncService.pullInitialData();

      final countAfterSync = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales WHERE company_id = ?',
        [companyA],
      );
      expect((countAfterSync.first['count'] as num).toInt(), 2, reason: 'Must remain exactly 2 sales');

      final finalReport = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyA,
        date: todayStr,
        db: db,
      );
      expect(finalReport.revenue, 1000.0);
    });
  });
}

class FakeSyncApiClient extends Fake implements ApiClient {
  final Map<String, dynamic> Function(String path, {Object? body})? onPost;
  final dynamic Function(String path, {Map<String, dynamic>? query})? onGet;

  FakeSyncApiClient({this.onPost, this.onGet});

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? timeout,
    http.Client? client,
  }) async {
    if (onPost != null) {
      return onPost!(path, body: body);
    }
    return {'data': true};
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Duration? timeout,
    http.Client? client,
  }) async {
    if (onGet != null) {
      return onGet!(path, query: query);
    }
    return {'data': []};
  }
}

class SessionNotifierStub extends StateNotifier<Session> implements SessionNotifier {
  SessionNotifierStub(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ConnectionNotifierStub extends StateNotifier<ConnectionStatus> implements ConnectivityNotifier {
  ConnectionNotifierStub(super.state);
  @override
  void setSyncing(bool syncing) {}
  @override
  Future<void> checkNow() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
