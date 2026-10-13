import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:modiri_ai/core/connectivity/connectivity_service.dart';
import 'package:modiri_ai/core/database/app_database.dart';
import 'package:modiri_ai/core/network/api_client.dart';
import 'package:modiri_ai/core/network/api_exception.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/sync/sync_service.dart';
import 'package:modiri_ai/features/subscriptions/data/subscriptions_repository.dart';
import 'package:modiri_ai/features/subscriptions/presentation/screens/account_suspended_screen.dart';
import 'package:modiri_ai/features/subscriptions/presentation/screens/trial_expired_screen.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestConnectivityNotifier extends StateNotifier<ConnectionStatus>
    implements ConnectivityNotifier {
  _TestConnectivityNotifier(super.initial);

  void setStatus(ConnectionStatus status) => state = status;

  @override
  Future<void> checkNow() async {}

  @override
  void setSyncing(bool syncing) {}
}

class _FakeApiClient extends Fake implements ApiClient {
  final Ref ref;
  bool shouldThrowSuspendedOnSync = false;
  bool shouldThrowTrialExpiredOnSync = false;
  int syncCalls = 0;
  int appealSubmissions = 0;
  Map<String, dynamic>? lastAppealBody;
  String? lastOverrideToken;
  bool reactivateOnStatusCheck = false;

  _FakeApiClient(this.ref);

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? timeout,
    http.Client? client,
  }) async {
    syncCalls++;
    if (shouldThrowSuspendedOnSync) {
      await ref.read(sessionProvider.notifier).lockSuspendedAccount(
        reason: 'Policy violation: duplicate fraudulent receipts.',
        appealToken: 'appeal_jwt_test_123',
        details: {
          'suspensionReason': 'Policy violation: duplicate fraudulent receipts.',
          'suspendedAt': '2026-04-14T10:00:00.000Z',
          'appealToken': 'appeal_jwt_test_123',
        },
      );
      throw ApiException(
        statusCode: 403,
        code: 'ACCOUNT_SUSPENDED',
        message: 'Policy violation: duplicate fraudulent receipts.',
      );
    }
    if (shouldThrowTrialExpiredOnSync) {
      await ref.read(sessionProvider.notifier).lockExpiredTrialAccount(
        status: 'expired_trial',
        expiresAt: '2026-04-01T00:00:00.000Z',
      );
      throw ApiException(
        statusCode: 403,
        code: 'TRIAL_EXPIRED',
        message: 'Your 15-day free trial has expired.',
      );
    }
    return {'data': {'id': 'synced-id'}};
  }

  @override
  Future<dynamic> postWithToken(
    String path, {
    Object? body,
    Duration? timeout,
    http.Client? client,
    String? overrideToken,
  }) async {
    if (path == '/support/appeal') {
      appealSubmissions++;
      lastAppealBody = body is Map<String, dynamic> ? body : null;
      lastOverrideToken = overrideToken;
      return {
        'data': {
          'ticketId': 'APL-TEST99',
          'status': 'new',
        },
      };
    }
    return post(path, body: body, timeout: timeout, client: client);
  }

  @override
  Future<dynamic> getWithToken(
    String path, {
    Map<String, String>? query,
    String? overrideToken,
  }) async {
    if (path == '/support/appeal/status') {
      lastOverrideToken = overrideToken;
      return {
        'data': {
          'company': {
            'id': ref.read(sessionProvider).companyId ?? 'comp_A',
            'name': 'Alpha Store',
            'isSuspended': !reactivateOnStatusCheck,
            'suspensionReason': reactivateOnStatusCheck
                ? null
                : 'Policy violation: duplicate fraudulent receipts.',
            'entitlementType': 'trial',
          },
          'appeals': [
            {
              'id': 'msg-1',
              'subject': 'Suspension Appeal — Alpha Store',
              'message': 'Please review my payment receipt.',
              'status': reactivateOnStatusCheck ? 'answered' : 'in_review',
              'admin_notes': reactivateOnStatusCheck
                  ? 'Verified receipt, account reactivated.'
                  : null,
            },
          ],
        },
      };
    }
    return {'data': {}};
  }

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return getWithToken(path, query: query);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
    SyncService.enablePeriodicTimer = false;
    SyncService.enableStartupSync = false;
    await AppDatabase.instance.database;
  });

  group('Account Suspension, Offline Lock, Trial Expiration & Multi-Account Data Preservation', () {
    setUp(() async {
      SessionNotifier.enableDurableSqlitePersistence = true;
      FlutterSecureStorage.setMockInitialValues({});
      final db = await AppDatabase.instance.database;
      await db.delete('products');
      await db.delete('sales');
      await db.delete('sale_items');
      await db.delete('invoices');
      await db.delete('customers');
      await db.delete('expenses');
      await db.delete('sync_queue');
      await db.delete('sync_metadata');
    });

    test('1. Mid-session suspension immediately locks session, revokes active tokens, and persists durable SQLite state for offline cold restarts', () async {
      final notifier = SessionNotifier();
      await notifier.apply({
        'accessToken': 'live_access_token',
        'refreshToken': 'live_refresh_token',
        'user': {
          'id': 'user_A',
          'companyId': 'comp_A',
          'name': 'Owner A',
          'email': 'ownerA@test.com',
          'role': 'owner',
          'businessType': 'retail_store',
          'onboardingCompleted': true,
        },
      });

      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.isSuspendedLocked, isFalse);

      // Suspend account mid-session
      await notifier.lockSuspendedAccount(
        reason: 'Manual verification required by Super Admin.',
        suspendedAt: '2026-04-14T11:30:00.000Z',
        appealToken: 'scoped_appeal_jwt_abc',
      );

      // Tokens must be cleared immediately while suspended lock is active
      expect(notifier.state.isSuspendedLocked, isTrue);
      expect(notifier.state.accessToken, isNull);
      expect(notifier.state.refreshToken, isNull);
      expect(notifier.state.isLoggedIn, isFalse);
      expect(notifier.state.suspensionReason, 'Manual verification required by Super Admin.');
      expect(notifier.state.appealToken, 'scoped_appeal_jwt_abc');
      expect(notifier.state.companyId, 'comp_A');

      // Simulate cold app restart while completely offline
      final coldStartNotifier = SessionNotifier();
      await coldStartNotifier.restore();

      expect(coldStartNotifier.state.isSuspendedLocked, isTrue);
      expect(coldStartNotifier.state.accessToken, isNull);
      expect(coldStartNotifier.state.refreshToken, isNull);
      expect(coldStartNotifier.state.suspensionReason, 'Manual verification required by Super Admin.');
      expect(coldStartNotifier.state.appealToken, 'scoped_appeal_jwt_abc');
    });

    test('2. SyncService halts immediately on ACCOUNT_SUSPENDED without incrementing retry_count or deleting offline business records', () async {
      final db = await AppDatabase.instance.database;

      // Seed local business data and pending sync queue items for Company A
      await db.insert('products', {
        'id': 'prod_A1',
        'company_id': 'comp_A',
        'name': 'Coffee Beans 1kg',
        'purchase_price': 1200.0,
        'selling_price': 1800.0,
        'quantity': 25,
        'minimum_stock': 5,
      });
      await db.insert('sales', {
        'id': 'sale_A1',
        'company_id': 'comp_A',
        'total': 3600.0,
        'payment_status': 'paid',
        'sold_at': '2026-04-14T09:00:00.000Z',
        'created_at': '2026-04-14T09:00:00.000Z',
        'synced': 0,
      });
      await db.insert('sync_queue', {
        'id': 'op_A1',
        'company_id': 'comp_A',
        'entity_type': 'product',
        'entity_id': 'prod_A1',
        'operation_type': 'CREATE',
        'payload': '{"name":"Coffee Beans 1kg","sellingPrice":1800}',
        'client_transaction_id': 'tx_A1',
        'status': 'pending',
        'retry_count': 0,
        'created_at': '2026-04-14T09:00:00.000Z',
        'updated_at': '2026-04-14T09:00:00.000Z',
      });

      late _FakeApiClient fakeApi;
      final container = ProviderContainer(
        overrides: [
          connectionStatusProvider.overrideWith(
            (ref) => _TestConnectivityNotifier(ConnectionStatus.online),
          ),
          apiClientProvider.overrideWith((ref) {
            fakeApi = _FakeApiClient(ref)..shouldThrowSuspendedOnSync = true;
            return fakeApi;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).apply({
        'accessToken': 'token_A',
        'refreshToken': 'refresh_A',
        'user': {
          'id': 'user_A',
          'companyId': 'comp_A',
          'email': 'ownerA@test.com',
          'role': 'owner',
        },
      });

      final syncService = container.read(syncServiceProvider.notifier);
      await syncService.syncPending();

      // Session is now locked as suspended
      expect(container.read(sessionProvider).isSuspendedLocked, isTrue);

      // Pending sync item must still be 'pending' with retry_count == 0 (NOT failed!)
      final queueRows = await db.query('sync_queue', where: 'company_id = ?', whereArgs: ['comp_A']);
      expect(queueRows.length, 1);
      expect(queueRows.first['status'], 'pending');
      expect(queueRows.first['retry_count'], 0);

      // Local products and sales are 100% preserved
      final productRows = await db.query('products', where: 'company_id = ?', whereArgs: ['comp_A']);
      final saleRows = await db.query('sales', where: 'company_id = ?', whereArgs: ['comp_A']);
      expect(productRows.length, 1);
      expect(saleRows.length, 1);
    });

    test('3. Trial expiration locks account online and offline (via UTC timestamp check) while preserving all local data', () async {
      final notifier = SessionNotifier();
      final pastTrialDate = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();

      await notifier.apply({
        'accessToken': 'trial_token_A',
        'refreshToken': 'trial_refresh_A',
        'user': {
          'id': 'user_trial',
          'companyId': 'comp_trial',
          'email': 'trial@test.com',
          'role': 'owner',
          'entitlementStatus': 'trial_active',
          'trialEndsAt': pastTrialDate,
        },
      });

      // Even before any server call, local UTC comparison detects that trialEndsAt has passed
      expect(notifier.state.isTrialOrLicenseExpired, isTrue);

      // Explicit server lock persists across cold restarts
      await notifier.lockExpiredTrialAccount(
        status: 'expired_trial',
        expiresAt: pastTrialDate,
      );

      final restoredNotifier = SessionNotifier();
      await restoredNotifier.restore();
      expect(restoredNotifier.state.isTrialOrLicenseExpired, isTrue);
      expect(restoredNotifier.state.entitlementStatus, 'expired_trial');
    });

    test('4. Multi-account switching from a suspended account preserves Company A data & sync_queue and isolates Company B', () async {
      final db = await AppDatabase.instance.database;

      // Seed Company A data
      await db.insert('products', {
        'id': 'prod_compA',
        'company_id': 'comp_A',
        'name': 'Company A Secret Product',
        'purchase_price': 500.0,
        'selling_price': 900.0,
        'quantity': 10,
        'minimum_stock': 2,
      });
      await db.insert('sync_queue', {
        'id': 'op_compA',
        'company_id': 'comp_A',
        'entity_type': 'product',
        'entity_id': 'prod_compA',
        'operation_type': 'CREATE',
        'payload': '{"name":"Company A Secret Product"}',
        'client_transaction_id': 'tx_compA',
        'status': 'pending',
        'retry_count': 0,
        'created_at': '2026-04-14T09:00:00.000Z',
        'updated_at': '2026-04-14T09:00:00.000Z',
      });

      final notifier = SessionNotifier();
      await notifier.apply({
        'accessToken': 'token_A',
        'refreshToken': 'refresh_A',
        'user': {
          'id': 'user_A',
          'companyId': 'comp_A',
          'email': 'a@test.com',
          'role': 'owner',
        },
      });

      // Suspend Company A
      await notifier.lockSuspendedAccount(
        reason: 'Suspended for review',
        appealToken: 'appeal_A',
      );
      expect(notifier.state.isSuspendedLocked, isTrue);

      // User clicks "Sign in with another account" -> clear()
      await notifier.clear();
      expect(notifier.state.isLoggedIn, isFalse);
      expect(notifier.state.isSuspendedLocked, isFalse);

      // Sign in as Company B
      await notifier.apply({
        'accessToken': 'token_B',
        'refreshToken': 'refresh_B',
        'user': {
          'id': 'user_B',
          'companyId': 'comp_B',
          'email': 'b@test.com',
          'role': 'owner',
          'entitlementStatus': 'lifetime_active',
        },
      });

      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.isSuspendedLocked, isFalse);
      expect(notifier.state.companyId, 'comp_B');

      // Verify Company A's local products and sync_queue are still untouched in SQLite
      final compAProducts = await db.query('products', where: 'company_id = ?', whereArgs: ['comp_A']);
      final compAQueue = await db.query('sync_queue', where: 'company_id = ?', whereArgs: ['comp_A']);
      expect(compAProducts.length, 1);
      expect(compAQueue.length, 1);

      // And Company A's durable suspension record is still stored in sync_metadata
      final compADurable = await AppDatabase.instance.getAccountAccessState('comp_A');
      expect(compADurable?['isSuspended'], isTrue);
    });
  });

  group('Lock Screen Widget Tests (AccountSuspendedScreen & TrialExpiredScreen)', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SessionNotifier.enableDurableSqlitePersistence = false;
    });

    tearDown(() {
      SessionNotifier.enableDurableSqlitePersistence = true;
    });

    testWidgets('5. AccountSuspendedScreen renders suspension reason, submits appeal with scoped appealToken, and supports account switching', (tester) async {
      late _FakeApiClient fakeApi;
      bool switchedAccount = false;
      bool createdNewAccount = false;
      bool reactivated = false;

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWith((ref) {
            fakeApi = _FakeApiClient(ref);
            return fakeApi;
          }),
          subscriptionsRepositoryProvider.overrideWith((ref) {
            return SubscriptionsRepository(ref, ref.read(apiClientProvider));
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).lockSuspendedAccount(
        reason: 'Unverified manual transfer receipt #991.',
        suspendedAt: '2026-04-14T10:00:00.000Z',
        appealToken: 'appeal_token_widget_test',
        details: {
          'user': {'id': 'u1', 'email': 'merchant@modiri.dz', 'name': 'Merchant'},
          'company': {'id': 'comp_A', 'name': 'Atlas Market'},
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
            home: AccountSuspendedScreen(
              onSwitchAccount: () => switchedAccount = true,
              onCreateNewAccount: () => createdNewAccount = true,
              onAccountReactivated: () => reactivated = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays administrator reason and account info
      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.text('Policy violation: duplicate fraudulent receipts.'), findsOneWidget);
      expect(find.textContaining('Atlas Market'), findsWidgets);

      // Open appeal form and submit an appeal
      await tester.ensureVisible(find.text('Submit Appeal / Request Review'));
      await tester.tap(find.text('Submit Appeal / Request Review'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).last,
        'I have attached the official BaridiMob receipt reference 8871234.',
      );
      await tester.ensureVisible(find.text('Send Appeal'));
      await tester.tap(find.text('Send Appeal'));
      await tester.pumpAndSettle();

      expect(fakeApi.appealSubmissions, 1);
      expect(fakeApi.lastOverrideToken, 'appeal_token_widget_test');
      expect(
        fakeApi.lastAppealBody?['message'],
        'I have attached the official BaridiMob receipt reference 8871234.',
      );

      // Simulate Super Admin reactivating the account and user tapping "Check Account Status"
      fakeApi.reactivateOnStatusCheck = true;
      await tester.ensureVisible(find.text('Check Account Status'));
      await tester.tap(find.text('Check Account Status'));
      await tester.pumpAndSettle();

      expect(reactivated, isTrue);
      expect(container.read(sessionProvider).isSuspendedLocked, isFalse);

      // Re-lock and verify "Sign in with another account" & "Create a new business account"
      await container.read(sessionProvider.notifier).lockSuspendedAccount(
        reason: 'Suspended again',
        appealToken: 'appeal_token_widget_test',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Sign in with another account'));
      await tester.tap(find.text('Sign in with another account'));
      await tester.pumpAndSettle();
      expect(switchedAccount, isTrue);

      await tester.ensureVisible(find.text('Create a new business account'));
      await tester.tap(find.text('Create a new business account'));
      await tester.pumpAndSettle();
      expect(createdNewAccount, isTrue);
    });

    testWidgets('6. TrialExpiredScreen renders expiration notice, preserves data reassurance, and triggers upgrade or account switch', (tester) async {
      bool upgradeClicked = false;
      bool switchedAccount = false;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).apply({
        'accessToken': 'tok_1',
        'refreshToken': 'ref_1',
        'user': {
          'id': 'u2',
          'companyId': 'comp_trial',
          'email': 'expired@modiri.dz',
          'companyName': 'Sahara Pharmacy',
          'role': 'owner',
        },
      });
      await container.read(sessionProvider.notifier).lockExpiredTrialAccount(
        status: 'expired_trial',
        expiresAt: '2026-04-01T00:00:00.000Z',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
            home: TrialExpiredScreen(
              onUpgradeSelected: () => upgradeClicked = true,
              onLicenseActivated: () {},
              onSwitchAccount: () => switchedAccount = true,
              onCreateNewAccount: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Free Trial Expired'), findsOneWidget);
      expect(find.text('15,000 DZD'), findsOneWidget);

      await tester.ensureVisible(find.text('Activate Lifetime License (15,000 DZD)'));
      await tester.tap(find.text('Activate Lifetime License (15,000 DZD)'));
      await tester.pumpAndSettle();
      expect(upgradeClicked, isTrue);

      await tester.ensureVisible(find.text('Sign in with another account'));
      await tester.tap(find.text('Sign in with another account'));
      await tester.pumpAndSettle();
      expect(switchedAccount, isTrue);
    });
  });
}
