import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:modiri_ai/core/connectivity/connectivity_service.dart';
import 'package:modiri_ai/core/database/app_database.dart';
import 'package:modiri_ai/core/network/api_client.dart';
import 'package:modiri_ai/core/network/api_exception.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/features/auth/data/auth_repository.dart';
import 'package:modiri_ai/features/settings/presentation/widgets/clear_application_data_dialog.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';
import 'package:modiri_ai/core/sync/sync_service.dart';
import 'package:modiri_ai/features/products/data/products_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockConnectivityNotifier extends StateNotifier<ConnectionStatus>
    implements ConnectivityNotifier {
  _MockConnectivityNotifier(super.initial);

  void setStatus(ConnectionStatus status) => state = status;

  @override
  Future<void> checkNow() async {}

  @override
  void setSyncing(bool syncing) {}
}

class _MockSessionNotifier extends StateNotifier<Session> implements SessionNotifier {
  _MockSessionNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockApiClient extends Fake implements ApiClient {
  bool clearBusinessDataCalled = false;
  Map<String, dynamic>? lastBody;
  bool shouldFailWithInvalidPassword = false;
  bool failWithHttp500 = false;
  bool failWithNetworkException = false;
  int clearBusinessDataCallCount = 0;
  int productsPostCallCount = 0;
  int salesPostCallCount = 0;
  int productsGetCallCount = 0;
  List<Map<String, dynamic>> mockProducts = [];

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? timeout,
    http.Client? client,
  }) async {
    if (path == '/companies/me/clear-business-data') {
      clearBusinessDataCalled = true;
      clearBusinessDataCallCount++;
      lastBody = body is Map<String, dynamic> ? body : null;
      if (failWithHttp500) {
        throw ApiException(
          statusCode: 500,
          code: 'INTERNAL_SERVER_ERROR',
          message: 'Server failed to clear database',
        );
      }
      if (failWithNetworkException) {
        throw http.ClientException('Network connection failed');
      }
      if (shouldFailWithInvalidPassword) {
        throw ApiException(
          statusCode: 400,
          code: 'INVALID_PASSWORD',
          message: 'Password is incorrect',
        );
      }
      return {
        'success': true,
        'message': 'Business data cleared successfully',
      };
    } else if (path == '/products') {
      productsPostCallCount++;
      final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
      return {
        'data': {
          'id': map['id'] ?? 'server-prod-1',
          'name': map['name'] ?? 'Product',
        },
      };
    } else if (path == '/sales') {
      salesPostCallCount++;
      return {
        'data': {
          'id': 'server-sale-1',
        },
      };
    }
    return {'data': true};
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path == '/companies/me') {
      return {
        'data': {'id': 'comp-1', 'name': 'Test Company'},
      };
    } else if (path == '/products') {
      productsGetCallCount++;
      return {'data': mockProducts};
    } else if (path == '/sales') {
      return {'data': []};
    }
    return {'data': []};
  }
}

Future<Database> _createFullTestDb() async {
  return await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            email TEXT,
            first_name TEXT,
            last_name TEXT,
            role TEXT
          )
        ''');
        await d.execute('''
          CREATE TABLE companies (
            id TEXT PRIMARY KEY,
            name TEXT,
            business_type TEXT
          )
        ''');
        await d.execute('''
          CREATE TABLE current_user (
            id TEXT PRIMARY KEY,
            token TEXT,
            company_id TEXT,
            email TEXT,
            name TEXT,
            role TEXT,
            business_type TEXT
          )
        ''');
        await d.execute('''
          CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            company_id TEXT NOT NULL,
            client_transaction_id TEXT,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await d.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            company_id TEXT NOT NULL,
            name TEXT NOT NULL,
            category TEXT,
            purchase_price REAL DEFAULT 0,
            selling_price REAL DEFAULT 0,
            quantity INTEGER DEFAULT 0,
            minimum_stock INTEGER DEFAULT 5,
            barcode TEXT,
            expiration_date TEXT,
            image_url TEXT,
            size TEXT,
            color TEXT,
            brand TEXT,
            dosage TEXT,
            form TEXT,
            active_ingredient TEXT,
            batch_number TEXT,
            supplier_id TEXT,
            created_at TEXT,
            updated_at TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await d.execute('''
          CREATE TABLE sales (
            id TEXT PRIMARY KEY,
            client_transaction_id TEXT,
            company_id TEXT NOT NULL,
            subtotal REAL DEFAULT 0,
            discount REAL DEFAULT 0,
            total REAL DEFAULT 0,
            payment_status TEXT NOT NULL,
            sold_at TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0
          )
        ''');
        await d.execute('''
          CREATE TABLE sale_items (
            id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            company_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            product_name TEXT,
            quantity REAL DEFAULT 1,
            unit_price REAL DEFAULT 0,
            unit_cost REAL DEFAULT 0,
            line_total REAL DEFAULT 0,
            line_profit REAL DEFAULT 0
          )
        ''');
        await d.execute('''
          CREATE TABLE invoices (
            id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            company_id TEXT NOT NULL,
            invoice_number TEXT NOT NULL,
            status TEXT NOT NULL,
            total REAL DEFAULT 0,
            sold_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await d.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            company_id TEXT NOT NULL,
            category TEXT,
            amount REAL DEFAULT 0,
            created_at TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await d.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            company_id TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            address TEXT,
            created_at TEXT,
            updated_at TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await d.execute('''
          CREATE TABLE suppliers (
            id TEXT PRIMARY KEY,
            company_id TEXT NOT NULL,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            address TEXT,
            created_at TEXT,
            updated_at TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await d.execute('''
          CREATE TABLE sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    ),
  );
}

Widget _buildTestApp({
  required List<Override> overrides,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      locale: locale,
      home: const Scaffold(
        body: ClearApplicationDataDialog(),
      ),
    ),
  );
}

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SyncService.enablePeriodicTimer = false;
    SyncService.enableStartupSync = false;
  });

  setUp(() async {
    db = await _createFullTestDb();
    AppDatabase.setTestDatabase(db);
  });

  tearDown(() async {
    AppDatabase.setTestDatabase(null);
    await db.close();
  });

  group('Clear Business Data Feature & Localization Tests', () {
    test('Localization coverage for all clear data and gross profit strings across AR, EN, FR', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      final en = lookupAppLocalizations(const Locale('en'));
      final fr = lookupAppLocalizations(const Locale('fr'));

      // Titles
      expect(ar.clearDataTitle, equals('مسح بيانات النشاط'));
      expect(en.clearDataTitle, equals('Clear Business Data'));
      expect(fr.clearDataTitle, equals('Effacer les données d\'activité'));

      // Gross profit label
      expect(ar.reportGrossProfitLabel, equals('مجمل الربح'));
      expect(en.reportGrossProfitLabel, equals('Gross Profit'));
      expect(fr.reportGrossProfitLabel, equals('Marge brute'));

      // Warning and offline notice
      expect(ar.clearDataWarning.isNotEmpty, isTrue);
      expect(en.clearDataWarning.isNotEmpty, isTrue);
      expect(fr.clearDataWarning.isNotEmpty, isTrue);

      expect(ar.clearDataOfflineNotice.isNotEmpty, isTrue);
      expect(en.clearDataOfflineNotice.isNotEmpty, isTrue);
      expect(fr.clearDataOfflineNotice.isNotEmpty, isTrue);

      // Buttons and checkboxes
      expect(ar.clearDataConfirmCheckbox.isNotEmpty, isTrue);
      expect(en.clearDataConfirmCheckbox.isNotEmpty, isTrue);
      expect(fr.clearDataConfirmCheckbox.isNotEmpty, isTrue);

      expect(ar.clearDataPasswordPrompt.isNotEmpty, isTrue);
      expect(en.clearDataPasswordPrompt.isNotEmpty, isTrue);
      expect(fr.clearDataPasswordPrompt.isNotEmpty, isTrue);

      expect(ar.clearDataButton, equals('تأكيد ومسح بيانات النشاط'));
      expect(en.clearDataButton, equals('Confirm & Clear Business Data'));

      expect(ar.clearDataSuccess.isNotEmpty, isTrue);
      expect(en.clearDataSuccess.isNotEmpty, isTrue);
      expect(fr.clearDataSuccess.isNotEmpty, isTrue);

      // Failed banner & retry strings
      expect(ar.clearDataFailedBanner.isNotEmpty, isTrue);
      expect(en.clearDataFailedBanner.isNotEmpty, isTrue);
      expect(fr.clearDataFailedBanner.isNotEmpty, isTrue);

      expect(ar.clearDataRetryAction.isNotEmpty, isTrue);
      expect(en.clearDataRetryAction.isNotEmpty, isTrue);
      expect(fr.clearDataRetryAction.isNotEmpty, isTrue);

      expect(ar.clearDataRetrySuccess.isNotEmpty, isTrue);
      expect(en.clearDataRetrySuccess.isNotEmpty, isTrue);
      expect(fr.clearDataRetrySuccess.isNotEmpty, isTrue);
    });

    testWidgets('ClearApplicationDataDialog renders warning, checkbox, and password field',
        (tester) async {
      final connNotifier = _MockConnectivityNotifier(ConnectionStatus.online);
      final mockApi = _MockApiClient();

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => connNotifier),
            apiClientProvider.overrideWithValue(mockApi),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Clear Business Data'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Confirm button is disabled initially
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Confirm & Clear Business Data');
      expect(buttonFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(elevatedButton.onPressed, isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Clear button enables only when confirmed and password entered while online',
        (tester) async {
      final connNotifier = _MockConnectivityNotifier(ConnectionStatus.online);
      final mockApi = _MockApiClient();

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => connNotifier),
            apiClientProvider.overrideWithValue(mockApi),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Still disabled because password is empty
      var elevatedButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm & Clear Business Data'),
      );
      expect(elevatedButton.onPressed, isNull);

      // Enter password
      await tester.enterText(find.byType(TextField), 'Secret123');
      await tester.pump();

      // Now enabled
      elevatedButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm & Clear Business Data'),
      );
      expect(elevatedButton.onPressed, isNotNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Offline state shows offline notice and disables clearing data',
        (tester) async {
      final connNotifier = _MockConnectivityNotifier(ConnectionStatus.offline);
      final mockApi = _MockApiClient();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => connNotifier),
            apiClientProvider.overrideWithValue(mockApi),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Offline notice should be visible
      expect(find.text(l10n.clearDataOfflineNotice), findsOneWidget);

      // Check checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final tfFinder = find.byType(TextField);
      await tester.ensureVisible(tfFinder);
      await tester.enterText(tfFinder, 'Secret123');
      await tester.pump();

      // Button MUST remain disabled while offline
      final elevatedButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm & Clear Business Data'),
      );
      expect(elevatedButton.onPressed, isNull, reason: 'Confirm button must remain disabled when device is offline');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('Online-Only Clear Business Data - Safety & Tenant Isolation', () {
    test('Offline attempt does not clear local data, does not call backend, and does not queue CLEAR_DATA', () async {
      // Seed business data
      await db.insert('products', {
        'id': 'prod-1',
        'company_id': 'comp-1',
        'name': 'Existing Product',
        'selling_price': 100.0,
        'quantity': 10,
      });
      await db.insert('sales', {
        'id': 'sale-1',
        'client_transaction_id': 'tx-1',
        'company_id': 'comp-1',
        'total': 500.0,
        'payment_status': 'paid',
        'sold_at': '2026-10-10T10:00:00Z',
        'created_at': '2026-10-10T10:00:00Z',
      });
      await db.insert('sync_queue', {
        'id': 'sync-sale-1',
        'company_id': 'comp-1',
        'client_transaction_id': 'tx-1',
        'entity_type': 'sale',
        'entity_id': 'sale-1',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'total': 500.0}),
        'status': 'pending',
        'created_at': '2026-10-10T10:00:00Z',
        'updated_at': '2026-10-10T10:00:00Z',
      });

      final mockApi = _MockApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => _MockConnectivityNotifier(ConnectionStatus.offline)),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'retail_store',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final authRepo = container.read(authRepositoryProvider);

        // Attempting to clear while offline must throw NETWORK_REQUIRED ApiException
        expect(
          () => authRepo.clearBusinessData(password: 'Secret123'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_REQUIRED')),
        );

        // Verify backend was NOT called
        expect(mockApi.clearBusinessDataCalled, isFalse);

        // Verify local products and sales are 100% UNTOUCHED
        final products = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(products.length, equals(1));
        expect(products.first['name'], equals('Existing Product'));

        final sales = await db.query('sales', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(sales.length, equals(1));

        // Verify NO CLEAR_DATA row was inserted into sync_queue
        final clearOps = await db.query(
          'sync_queue',
          where: "entity_type = 'business_data' AND operation_type = 'CLEAR_DATA'",
        );
        expect(clearOps, isEmpty);

        // Verify unrelated pending sync operation is untouched
        final syncOps = await db.query('sync_queue', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(syncOps.length, equals(1));
        expect(syncOps.first['status'], equals('pending'));

        // Verify user session remains logged in
        final session = container.read(sessionProvider);
        expect(session.isLoggedIn, isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Failed backend call (wrong password HTTP 400) leaves local business data, session, and queue untouched', () async {
      await db.insert('products', {
        'id': 'prod-1',
        'company_id': 'comp-1',
        'name': 'Existing Product',
        'selling_price': 100.0,
        'quantity': 10,
      });

      final mockApi = _MockApiClient();
      mockApi.shouldFailWithInvalidPassword = true;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => _MockConnectivityNotifier(ConnectionStatus.online)),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'retail_store',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final authRepo = container.read(authRepositoryProvider);

        expect(
          () => authRepo.clearBusinessData(password: 'WrongPassword'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_PASSWORD')),
        );

        // Local data remains 100% untouched
        final products = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(products.length, equals(1));

        // Queue has no CLEAR_DATA
        final clearOps = await db.query('sync_queue');
        expect(clearOps, isEmpty);

        // User session intact
        final session = container.read(sessionProvider);
        expect(session.isLoggedIn, isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Failed backend call (server error HTTP 500) leaves local business data, session, and queue untouched', () async {
      await db.insert('products', {
        'id': 'prod-1',
        'company_id': 'comp-1',
        'name': 'Existing Product',
        'selling_price': 100.0,
        'quantity': 10,
      });

      final mockApi = _MockApiClient();
      mockApi.failWithHttp500 = true;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => _MockConnectivityNotifier(ConnectionStatus.online)),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'retail_store',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final authRepo = container.read(authRepositoryProvider);

        expect(
          () => authRepo.clearBusinessData(password: 'Secret123'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
        );

        // Local data remains 100% untouched
        final products = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(products.length, equals(1));

        // Queue has no CLEAR_DATA
        final clearOps = await db.query('sync_queue');
        expect(clearOps, isEmpty);

        // User session intact
        final session = container.read(sessionProvider);
        expect(session.isLoggedIn, isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Failed backend call (network drop / timeout / client exception) leaves local data untouched', () async {
      await db.insert('products', {
        'id': 'prod-1',
        'company_id': 'comp-1',
        'name': 'Existing Product',
        'selling_price': 100.0,
        'quantity': 10,
      });

      final mockApi = _MockApiClient();
      mockApi.failWithNetworkException = true;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => _MockConnectivityNotifier(ConnectionStatus.online)),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'retail_store',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final authRepo = container.read(authRepositoryProvider);

        expect(
          () => authRepo.clearBusinessData(password: 'Secret123'),
          throwsA(isA<http.ClientException>()),
        );

        // Local data remains 100% untouched
        final products = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(products.length, equals(1));

        final clearOps = await db.query('sync_queue');
        expect(clearOps, isEmpty);

        final session = container.read(sessionProvider);
        expect(session.isLoggedIn, isTrue);
      } finally {
        container.dispose();
      }
    });

    test('Successful backend call deletes local business data, preserves user session, and enforces tenant isolation', () async {
      // Company A data
      await db.insert('products', {
        'id': 'prod-A-1',
        'company_id': 'comp-A',
        'name': 'Product A',
        'selling_price': 100.0,
        'quantity': 10,
      });
      await db.insert('sales', {
        'id': 'sale-A-1',
        'client_transaction_id': 'tx-A',
        'company_id': 'comp-A',
        'total': 500.0,
        'payment_status': 'paid',
        'sold_at': '2026-10-10T10:00:00Z',
        'created_at': '2026-10-10T10:00:00Z',
      });
      await db.insert('sync_queue', {
        'id': 'sync-A-1',
        'company_id': 'comp-A',
        'client_transaction_id': 'tx-A',
        'entity_type': 'sale',
        'entity_id': 'sale-A-1',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'total': 500.0}),
        'status': 'pending',
        'created_at': '2026-10-10T10:00:00Z',
        'updated_at': '2026-10-10T10:00:00Z',
      });

      // Company B data
      await db.insert('products', {
        'id': 'prod-B-1',
        'company_id': 'comp-B',
        'name': 'Product B',
        'selling_price': 200.0,
        'quantity': 20,
      });
      await db.insert('sales', {
        'id': 'sale-B-1',
        'client_transaction_id': 'tx-B',
        'company_id': 'comp-B',
        'total': 1500.0,
        'payment_status': 'paid',
        'sold_at': '2026-10-10T10:00:00Z',
        'created_at': '2026-10-10T10:00:00Z',
      });
      await db.insert('sync_queue', {
        'id': 'sync-B-1',
        'company_id': 'comp-B',
        'client_transaction_id': 'tx-B',
        'entity_type': 'sale',
        'entity_id': 'sale-B-1',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'total': 1500.0}),
        'status': 'pending',
        'created_at': '2026-10-10T10:00:00Z',
        'updated_at': '2026-10-10T10:00:00Z',
      });

      final mockApi = _MockApiClient();

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => _MockConnectivityNotifier(ConnectionStatus.online)),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token-A',
              refreshToken: 'mock-refresh-token-A',
              userId: 'user-A',
              companyId: 'comp-A',
              userName: 'Owner A',
              email: 'ownerA@modiri.com',
              role: 'owner',
              businessType: 'retail_store',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final authRepo = container.read(authRepositoryProvider);
        final result = await authRepo.clearBusinessData(password: 'Secret123');

        expect(result['cleared'], isTrue);
        expect(result['isOffline'], isFalse);

        // Verify Company A data is wiped
        final prodsA = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-A']);
        final salesA = await db.query('sales', where: 'company_id = ?', whereArgs: ['comp-A']);
        final syncA = await db.query('sync_queue', where: 'company_id = ?', whereArgs: ['comp-A']);
        expect(prodsA, isEmpty);
        expect(salesA, isEmpty);
        expect(syncA, isEmpty);

        // Verify Company A user session is fully PRESERVED
        final currentSession = container.read(sessionProvider);
        expect(currentSession.isLoggedIn, isTrue);
        expect(currentSession.companyId, equals('comp-A'));
        expect(currentSession.accessToken, equals('mock-access-token-A'));

        // Verify Company B data is 100% UNTOUCHED
        final prodsB = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-B']);
        final salesB = await db.query('sales', where: 'company_id = ?', whereArgs: ['comp-B']);
        final syncB = await db.query('sync_queue', where: 'company_id = ?', whereArgs: ['comp-B']);
        expect(prodsB.length, equals(1));
        expect(prodsB.first['name'], equals('Product B'));
        expect(salesB.length, equals(1));
        expect(syncB.length, equals(1));
      } finally {
        container.dispose();
      }
    });
  });

  group('Legacy Queued CLEAR_DATA Operations Safety & Reconnection', () {
    test('Legacy queued CLEAR_DATA cannot delete backend data after reconnect and is reconciled to cancelled', () async {
      const clearCreatedAt = '2026-10-10T10:00:00.000Z';
      const postOpCreatedAt = '2026-10-10T10:05:00.000Z';

      // 1. Seed legacy queued CLEAR_DATA operation (status: pending)
      await db.insert('sync_queue', {
        'id': 'legacy-clear-op',
        'company_id': 'comp-1',
        'client_transaction_id': 'tx-legacy-clear',
        'entity_type': 'business_data',
        'entity_id': 'business_data',
        'operation_type': 'CLEAR_DATA',
        'payload': jsonEncode({'password': 'old_pass'}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': clearCreatedAt,
        'updated_at': clearCreatedAt,
      });

      // 2. Seed post-reset legitimate product CREATE operation
      await db.insert('products', {
        'id': 'post-prod-1',
        'company_id': 'comp-1',
        'name': 'New Product',
        'selling_price': 150.0,
        'quantity': 10,
        'synced': 0,
      });
      await db.insert('sync_queue', {
        'id': 'sync-post-prod-1',
        'company_id': 'comp-1',
        'client_transaction_id': 'tx-post-prod',
        'entity_type': 'product',
        'entity_id': 'post-prod-1',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'name': 'New Product', 'price': 150.0}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': postOpCreatedAt,
        'updated_at': postOpCreatedAt,
      });

      final mockApi = _MockApiClient();
      final connNotifier = _MockConnectivityNotifier(ConnectionStatus.online);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => connNotifier),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'retail_store',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final syncService = container.read(syncServiceProvider.notifier);

        // Process pending queue upon reconnecting online
        await syncService.syncPending();

        // Verify: Server CLEAR_DATA endpoint was NEVER CALLED!
        expect(mockApi.clearBusinessDataCallCount, equals(0),
            reason: 'Legacy queued CLEAR_DATA must never execute against the backend upon reconnecting');

        // Verify legacy CLEAR_DATA row was safely reconciled to 'cancelled'
        final legacyClearRow = await db.query('sync_queue', where: "id = 'legacy-clear-op'");
        expect(legacyClearRow.first['status'], equals('cancelled'));
        expect(legacyClearRow.first['last_error'], contains('Legacy offline CLEAR_DATA cancelled'));

        // Verify subsequent product CREATE operation was NOT blocked and synced successfully
        expect(mockApi.productsPostCallCount, equals(1));
        final prodOpRow = await db.query('sync_queue', where: "id = 'sync-post-prod-1'");
        expect(prodOpRow.first['status'], equals('synced'));

        // Local product remains intact
        final localProds = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(localProds.length, equals(1));
        expect(localProds.first['name'], equals('New Product'));
      } finally {
        container.dispose();
      }
    });

    test('reconcileLegacyClearDataOps cancels legacy failed CLEAR_DATA and retryFailedReset unblocks sync queue', () async {
      // Seed failed legacy CLEAR_DATA
      await db.insert('sync_queue', {
        'id': 'legacy-failed-clear',
        'company_id': 'comp-1',
        'client_transaction_id': 'tx-failed',
        'entity_type': 'business_data',
        'entity_id': 'business_data',
        'operation_type': 'CLEAR_DATA',
        'payload': jsonEncode({'password': 'pass'}),
        'status': 'failed',
        'retry_count': 5,
        'last_error': 'Server error: 500',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed pending product
      await db.insert('sync_queue', {
        'id': 'pending-prod-op',
        'company_id': 'comp-1',
        'client_transaction_id': 'tx-prod',
        'entity_type': 'product',
        'entity_id': 'prod-1',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'name': 'Item'}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final mockApi = _MockApiClient();
      final connNotifier = _MockConnectivityNotifier(ConnectionStatus.online);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => connNotifier),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'retail_store',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final syncService = container.read(syncServiceProvider.notifier);

        // Calling retryFailedReset safely reconciles legacy CLEAR_DATA to cancelled
        final retried = await syncService.retryFailedReset(companyId: 'comp-1');
        expect(retried, isTrue);

        final clearRow = await db.query('sync_queue', where: "id = 'legacy-failed-clear'");
        expect(clearRow.first['status'], equals('cancelled'));

        // Sync pending operations
        await syncService.syncPending();

        // Product was dispatched, CLEAR_DATA was not dispatched
        expect(mockApi.productsPostCallCount, equals(1));
        expect(mockApi.clearBusinessDataCallCount, equals(0));
      } finally {
        container.dispose();
      }
    });
  });

  group('Pull Path Guard (Finding 1) and Atomic Deletion (Finding 2)', () {
    test('Finding 1: Repository and Sync pull paths are blocked while uncancelled CLEAR_DATA is pending and unblock once cancelled', () async {
      // Seed pending CLEAR_DATA for comp-1
      await db.insert('sync_queue', {
        'id': 'clear-op-1',
        'company_id': 'comp-1',
        'client_transaction_id': 'tx-clear-1',
        'entity_type': 'business_data',
        'entity_id': 'business_data',
        'operation_type': 'CLEAR_DATA',
        'payload': '{}',
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(await AppDatabase.instance.hasUncompletedClearData('comp-1'), isTrue);

      final mockApi = _MockApiClient();
      mockApi.mockProducts = [
        {
          'id': 'server-prod-10',
          'name': 'Sneakers',
          'category': 'Shoes',
          'purchase_price': 50.0,
          'selling_price': 100.0,
          'quantity': 10,
        }
      ];

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          connectionStatusProvider.overrideWith((ref) => _MockConnectivityNotifier(ConnectionStatus.online)),
          sessionProvider.overrideWith((ref) {
            final notifier = SessionNotifier();
            notifier.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'clothing',
              onboardingCompleted: true,
            );
            return notifier;
          }),
        ],
      );

      try {
        final sub = container.listen(productsRepositoryProvider, (_, __) {});

        // 1. ProductsRepository.load() must NOT fetch or upsert backend data
        final repo = container.read(productsRepositoryProvider.notifier);
        await repo.load();
        expect(mockApi.productsGetCallCount, equals(0));

        // 2. SyncService.pullInitialData() must also return early
        final syncService = container.read(syncServiceProvider.notifier);
        await syncService.pullInitialData();
        expect(mockApi.productsGetCallCount, equals(0));

        // 3. Reconcile legacy CLEAR_DATA to cancelled
        await syncService.reconcileLegacyClearDataOps(companyId: 'comp-1');
        expect(await AppDatabase.instance.hasUncompletedClearData('comp-1'), isFalse);

        // 4. Now repo.load() can proceed normally
        await repo.load();
        expect(mockApi.productsGetCallCount, equals(1));
        final prodsAfterSync = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-1']);
        expect(prodsAfterSync.length, equals(1));
        expect(prodsAfterSync.first['name'], equals('Sneakers'));

        sub.close();
      } finally {
        container.dispose();
      }
    });

    test('Finding 2: clearCompanyBusinessData atomically deletes company data in single transaction', () async {
      await db.insert('products', {
        'id': 'prod-1',
        'company_id': 'comp-1',
        'name': 'Existing Product',
        'selling_price': 150.0,
        'quantity': 5,
      });
      await db.insert('sales', {
        'id': 'sale-1',
        'client_transaction_id': 'tx-1',
        'company_id': 'comp-1',
        'total': 300.0,
        'payment_status': 'paid',
        'sold_at': '2026-10-10T10:00:00Z',
        'created_at': '2026-10-10T10:00:00Z',
      });
      await db.insert('customers', {
        'id': 'cust-1',
        'company_id': 'comp-1',
        'name': 'Existing Customer',
      });

      // Tenant 2 data
      await db.insert('products', {
        'id': 'prod-2',
        'company_id': 'comp-2',
        'name': 'Tenant 2 Product',
        'selling_price': 250.0,
        'quantity': 8,
      });

      await AppDatabase.instance.clearCompanyBusinessData('comp-1');

      // comp-1 wiped
      final prods1 = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-1']);
      expect(prods1, isEmpty);
      final sales1 = await db.query('sales', where: 'company_id = ?', whereArgs: ['comp-1']);
      expect(sales1, isEmpty);
      final custs1 = await db.query('customers', where: 'company_id = ?', whereArgs: ['comp-1']);
      expect(custs1, isEmpty);

      // comp-2 untouched
      final prods2 = await db.query('products', where: 'company_id = ?', whereArgs: ['comp-2']);
      expect(prods2.length, equals(1));
      expect(prods2.first['name'], equals('Tenant 2 Product'));
    });

    test('Finding 3: retryFailedReset cancels legacy failed CLEAR_DATA operation and safely unblocks tenant sync queue', () async {
      // Seed failed CLEAR_DATA operation
      await db.insert('sync_queue', {
        'id': 'failed-clear-op',
        'company_id': 'comp-1',
        'client_transaction_id': 'tx-failed',
        'entity_type': 'business_data',
        'entity_id': 'business_data',
        'operation_type': 'CLEAR_DATA',
        'payload': jsonEncode({'password': 'pass'}),
        'status': 'failed',
        'retry_count': 5,
        'last_error': 'Server 500 Error',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final connNotifier = _MockConnectivityNotifier(ConnectionStatus.online);
      final mockApi = _MockApiClient();

      final container = ProviderContainer(
        overrides: [
          connectionStatusProvider.overrideWith((ref) => connNotifier),
          apiClientProvider.overrideWithValue(mockApi),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier();
            n.state = const Session(
              accessToken: 'mock-access-token',
              refreshToken: 'mock-refresh-token',
              userId: 'user-1',
              companyId: 'comp-1',
              userName: 'Test User',
              email: 'test@modiri.com',
              role: 'owner',
              businessType: 'clothing',
              onboardingCompleted: true,
            );
            return n;
          }),
        ],
      );

      try {
        final syncService = container.read(syncServiceProvider.notifier);
        final retried = await syncService.retryFailedReset(companyId: 'comp-1');
        expect(retried, isTrue);

        final updatedOps = await db.query('sync_queue', where: "id = 'failed-clear-op'");
        expect(updatedOps.first['status'], equals('cancelled'));
      } finally {
        container.dispose();
      }
    });
  });
}
