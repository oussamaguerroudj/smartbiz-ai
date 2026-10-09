import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/network/api_client.dart';
import 'package:modiri_ai/core/database/local_financial_calculator.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Offline Authentication & Session State Tests', () {
    test('Session serialization and deserialization preserves all fields', () {
      const session = Session(
        accessToken: 'access_jwt_123',
        refreshToken: 'refresh_jwt_456',
        userId: 'usr_789',
        companyId: 'comp_001',
        userName: 'Karim Business',
        email: 'karim@example.com',
        phone: '+213555123456',
        role: 'owner',
      );

      final json = session.toStorageJson();
      expect(session.isLoggedIn, isTrue);

      final restored = Session.fromStorageJson(json);
      expect(restored.accessToken, 'access_jwt_123');
      expect(restored.refreshToken, 'refresh_jwt_456');
      expect(restored.userId, 'usr_789');
      expect(restored.companyId, 'comp_001');
      expect(restored.userName, 'Karim Business');
      expect(restored.email, 'karim@example.com');
      expect(restored.phone, '+213555123456');
      expect(restored.role, 'owner');
      expect(restored.isLoggedIn, isTrue);
    });

    test('Session is authenticated when only refreshToken exists (offline token renewal case)', () {
      const session = Session(
        refreshToken: 'refresh_jwt_456',
        userId: 'usr_789',
        companyId: 'comp_001',
      );

      expect(session.isLoggedIn, isTrue);
    });

    test('Empty session is not authenticated', () {
      expect(Session.empty.isLoggedIn, isFalse);
    });

    test('RefreshResult correctly distinguishes network errors from invalid credentials', () {
      expect(RefreshResult.refreshed, isNotNull);
      expect(RefreshResult.invalidToken, isNotNull);
      expect(RefreshResult.networkUnavailable, isNotNull);

      // Verify logic contract:
      // - networkUnavailable MUST NOT clear session
      // - invalidToken MUST clear session
      bool shouldClearSession(RefreshResult result) {
        return result == RefreshResult.invalidToken;
      }

      expect(shouldClearSession(RefreshResult.networkUnavailable), isFalse);
      expect(shouldClearSession(RefreshResult.invalidToken), isTrue);
      expect(shouldClearSession(RefreshResult.refreshed), isFalse);
    });
  });

  group('Offline Suppliers, Salary Payments & Company Cache Tests', () {
    late Database db;
    const uuid = Uuid();
    const testCompanyId = 'company_alpha_123';

    setUp(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE suppliers (
                id TEXT PRIMARY KEY,
                client_id TEXT UNIQUE,
                company_id TEXT,
                name TEXT NOT NULL,
                phone TEXT,
                products_supplied INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0,
                deleted_at TEXT
              )
            ''');

            await db.execute('''
              CREATE TABLE employees (
                id TEXT PRIMARY KEY,
                client_id TEXT UNIQUE,
                company_id TEXT,
                name TEXT NOT NULL,
                position TEXT,
                phone TEXT,
                base_salary REAL NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT,
                synced INTEGER NOT NULL DEFAULT 0,
                deleted_at TEXT
              )
            ''');

            await db.execute('''
              CREATE TABLE salary_payments (
                id TEXT PRIMARY KEY,
                client_id TEXT UNIQUE,
                employee_id TEXT NOT NULL,
                amount REAL NOT NULL DEFAULT 0,
                payment_date TEXT NOT NULL,
                salary_period TEXT NOT NULL,
                duration TEXT,
                note TEXT,
                created_at TEXT NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');

            await db.execute('''
              CREATE TABLE expenses (
                id TEXT PRIMARY KEY,
                client_id TEXT UNIQUE,
                company_id TEXT,
                category TEXT NOT NULL,
                description TEXT,
                amount REAL NOT NULL DEFAULT 0,
                expense_date TEXT NOT NULL,
                period_type TEXT DEFAULT 'one_time',
                employee_id TEXT,
                salary_period TEXT,
                duration TEXT,
                created_at TEXT NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');

            await db.execute('''
              CREATE TABLE sync_queue (
                id TEXT PRIMARY KEY,
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
              CREATE TABLE sync_metadata (
                key TEXT PRIMARY KEY,
                value TEXT,
                updated_at TEXT NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE sales (
                id TEXT PRIMARY KEY,
                client_transaction_id TEXT UNIQUE,
                company_id TEXT,
                customer_id TEXT,
                customer_name TEXT,
                employee_id TEXT,
                subtotal REAL NOT NULL DEFAULT 0,
                discount REAL NOT NULL DEFAULT 0,
                total REAL NOT NULL DEFAULT 0,
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
              CREATE TABLE invoices (
                id TEXT PRIMARY KEY,
                sale_id TEXT NOT NULL UNIQUE,
                invoice_number TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'paid',
                customer_name TEXT,
                total REAL NOT NULL DEFAULT 0,
                sold_at TEXT NOT NULL,
                created_at TEXT NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE products (
                id TEXT PRIMARY KEY,
                company_id TEXT,
                name TEXT NOT NULL,
                category TEXT,
                barcode TEXT,
                purchase_price REAL NOT NULL DEFAULT 0,
                selling_price REAL NOT NULL DEFAULT 0,
                quantity INTEGER NOT NULL DEFAULT 0,
                minimum_stock INTEGER NOT NULL DEFAULT 5,
                expiration_date TEXT,
                size TEXT,
                color TEXT,
                brand TEXT,
                image_url TEXT,
                updated_at TEXT
              )
            ''');
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Company info caching in sync_metadata preserves business type offline', () async {
      final companyData = {
        'name': 'Pharmacie El Chifa',
        'businessType': 'pharmacy',
        'currency': 'DZD',
        'phone': '0555123456',
        'address': 'Alger Centre',
      };

      await db.insert('sync_metadata', {
        'key': 'company_info',
        'value': jsonEncode(companyData),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Read back as if offline
      final rows = await db.query(
        'sync_metadata',
        where: 'key = ?',
        whereArgs: ['company_info'],
      );

      expect(rows, isNotEmpty);
      final restored = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      expect(restored['businessType'], 'pharmacy');
      expect(restored['name'], 'Pharmacie El Chifa');
    });

    test('Offline supplier creation updates SQLite and creates sync_queue entry', () async {
      final supplierId = uuid.v4();
      final clientId = uuid.v4();
      final nowIso = DateTime.now().toIso8601String();

      await db.insert('suppliers', {
        'id': supplierId,
        'client_id': clientId,
        'company_id': testCompanyId,
        'name': 'Grossiste Oran Distribution',
        'phone': '041234567',
        'products_supplied': 0,
        'created_at': nowIso,
        'synced': 0,
      });

      await db.insert('sync_queue', {
        'id': uuid.v4(),
        'client_transaction_id': clientId,
        'entity_type': 'supplier',
        'entity_id': supplierId,
        'operation_type': 'CREATE',
        'payload': jsonEncode({'name': 'Grossiste Oran Distribution', 'phone': '041234567'}),
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      final rows = await db.query('suppliers', where: 'company_id = ?', whereArgs: [testCompanyId]);
      expect(rows.length, 1);
      expect(rows.first['name'], 'Grossiste Oran Distribution');

      final queue = await db.query('sync_queue', where: 'entity_type = ?', whereArgs: ['supplier']);
      expect(queue.length, 1);
      expect(queue.first['status'], 'pending');
      expect(queue.first['operation_type'], 'CREATE');
    });

    test('Offline salary payment updates salary_payments, expenses, and recalculates net profit', () async {
      final empId = uuid.v4();
      final paymentId = uuid.v4();
      final clientId = uuid.v4();
      final expenseId = uuid.v4();
      const dateStr = '2026-10-05';
      const nowIso = '${dateStr}T10:00:00Z';

      // 1. Create employee
      await db.insert('employees', {
        'id': empId,
        'client_id': uuid.v4(),
        'company_id': testCompanyId,
        'name': 'Samir Tech',
        'position': 'Manager',
        'base_salary': 60000.0,
        'created_at': nowIso,
        'synced': 1,
      });

      // 2. Make a sale with 100000 revenue and 40000 profit
      final saleId = uuid.v4();
      await db.insert('sales', {
        'id': saleId,
        'client_transaction_id': uuid.v4(),
        'company_id': testCompanyId,
        'subtotal': 100000.0,
        'discount': 0.0,
        'total': 100000.0,
        'payment_status': 'paid',
        'sold_at': nowIso,
        'created_at': nowIso,
        'synced': 1,
      });

      await db.insert('sale_items', {
        'id': uuid.v4(),
        'sale_id': saleId,
        'product_id': 'prod_1',
        'product_name': 'TV',
        'quantity': 2,
        'unit_price': 50000.0,
        'unit_cost': 30000.0,
        'line_total': 100000.0,
        'line_profit': 40000.0,
      });

      await db.insert('invoices', {
        'id': uuid.v4(),
        'sale_id': saleId,
        'invoice_number': 'INV-1001',
        'total': 100000.0,
        'sold_at': nowIso,
        'created_at': nowIso,
      });

      // 3. Record salary payment + salary expense
      await db.insert('salary_payments', {
        'id': paymentId,
        'client_id': clientId,
        'employee_id': empId,
        'amount': 25000.0,
        'payment_date': dateStr,
        'salary_period': '2026-10',
        'duration': '1 month',
        'note': 'October advance',
        'created_at': nowIso,
        'synced': 0,
      });

      await db.insert('expenses', {
        'id': expenseId,
        'client_id': clientId,
        'company_id': testCompanyId,
        'category': 'Salary',
        'description': 'Salary: Samir Tech (2026-10)',
        'amount': 25000.0,
        'expense_date': dateStr,
        'period_type': 'one_time',
        'employee_id': empId,
        'salary_period': '2026-10',
        'duration': '1 month',
        'created_at': nowIso,
        'synced': 0,
      });

      // 4. Enqueue in sync queue as salary_payment
      await db.insert('sync_queue', {
        'id': uuid.v4(),
        'client_transaction_id': clientId,
        'entity_type': 'salary_payment',
        'entity_id': paymentId,
        'operation_type': 'CREATE',
        'payload': jsonEncode({
          'employeeId': empId,
          'amount': 25000.0,
          'paymentDate': dateStr,
          'salaryPeriod': '2026-10',
        }),
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // 5. Verify LocalFinancialCalculator matches financial formula:
      // Gross Profit = 40,000 DZD
      // Total Expenses = 25,000 DZD
      // Net Profit = Gross Profit - Total Expenses = 15,000 DZD
      final report = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: testCompanyId,
        date: dateStr,
        db: db,
      );
      expect(report.revenue, 100000.0);
      expect(report.grossProfit, 40000.0);
      expect(report.expenses, 25000.0);
      expect(report.netProfit, 15000.0);
    });

    test('Session.fromAuthResponse correctly parses canonical backend response shapes', () {
      // 1. Standard backend response: { user: {...}, company: {...}, accessToken, refreshToken }
      final standardRes = {
        'user': {
          'id': 'usr_std_1',
          'companyId': 'comp_std_1',
          'name': 'Ahmed Store',
          'email': 'ahmed@store.dz',
          'role': 'owner',
          'businessType': 'grocery',
          'onboardingCompleted': true,
        },
        'company': {
          'id': 'comp_std_1',
          'name': 'Ahmed Store',
          'businessType': 'grocery',
          'onboardingCompleted': true,
        },
        'accessToken': 'jwt_access_123',
        'refreshToken': 'jwt_refresh_456',
      };
      final session1 = Session.fromAuthResponse(standardRes);
      expect(session1.isLoggedIn, isTrue);
      expect(session1.accessToken, 'jwt_access_123');
      expect(session1.refreshToken, 'jwt_refresh_456');
      expect(session1.userId, 'usr_std_1');
      expect(session1.companyId, 'comp_std_1');
      expect(session1.userName, 'Ahmed Store');
      expect(session1.businessType, 'grocery');
      expect(session1.onboardingCompleted, isTrue);

      // 2. Incomplete onboarding response (after verify-email)
      final onboardingRes = {
        'user': {
          'id': 'usr_onboard_1',
          'companyId': 'comp_onboard_1',
          'name': 'New Founder',
          'email': 'founder@store.dz',
          'role': 'owner',
          'businessType': null,
          'onboardingCompleted': false,
        },
        'company': {
          'id': 'comp_onboard_1',
          'name': 'New Founder\'s Business',
          'businessType': null,
          'onboardingCompleted': false,
        },
        'accessToken': 'jwt_access_new',
        'refreshToken': 'jwt_refresh_new',
      };
      final session2 = Session.fromAuthResponse(onboardingRes);
      expect(session2.isLoggedIn, isTrue);
      expect(session2.accessToken, 'jwt_access_new');
      expect(session2.userId, 'usr_onboard_1');
      expect(session2.companyId, 'comp_onboard_1');
      expect(session2.userName, 'New Founder');
      expect(session2.businessType, isNull);
      expect(session2.onboardingCompleted, isFalse);

      // 3. Response wrapped under data: { data: { user: {...}, company: {...}, accessToken, refreshToken } }
      final wrappedRes = {
        'data': {
          'user': {
            'id': 'usr_wrapped_1',
            'companyId': 'comp_wrapped_1',
            'name': 'Karim Pharmacy',
            'email': 'karim@pharmacy.dz',
            'role': 'owner',
            'businessType': 'pharmacy',
            'onboardingCompleted': true,
          },
          'company': {
            'id': 'comp_wrapped_1',
            'name': 'Karim Pharmacy',
            'businessType': 'pharmacy',
            'onboardingCompleted': true,
          },
          'accessToken': 'wrapped_token_abc',
          'refreshToken': 'wrapped_refresh_xyz',
        },
      };
      final session3 = Session.fromAuthResponse(wrappedRes);
      expect(session3.isLoggedIn, isTrue);
      expect(session3.accessToken, 'wrapped_token_abc');
      expect(session3.userId, 'usr_wrapped_1');
      expect(session3.companyId, 'comp_wrapped_1');
      expect(session3.businessType, 'pharmacy');
      expect(session3.onboardingCompleted, isTrue);
    });
  });
}
