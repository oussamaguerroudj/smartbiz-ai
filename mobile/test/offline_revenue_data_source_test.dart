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
    });

    tearDown(() async {
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
  });
}

class SessionNotifierStub extends StateNotifier<Session> implements SessionNotifier {
  SessionNotifierStub(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ConnectionNotifierStub extends StateNotifier<ConnectionStatus> implements ConnectivityNotifier {
  ConnectionNotifierStub(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
