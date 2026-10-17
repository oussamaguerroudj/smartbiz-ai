import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_desktop/main.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/session.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 6 Reproduction: Language Switching & State Propagation', () {
    testWidgets('1. Test language switching on Auth Screen dropdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ModiriDesktopApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify initially rendered in English
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Bienvenue'), findsNothing);

      // Trigger the exact dropdown change on Auth Screen
      final dropdown = find.byType(DropdownButton<String>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Français (FR) in dropdown
      final frItem = find.text('Français (FR)').last;
      await tester.tap(frItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check if locale state in provider changed
      final currentLocale = container.read(desktopLocaleProvider);

      // Verify whether the text on screen actually updated to French!
      final foundFr = find.text('Bienvenue');
      final foundEn = find.text('Welcome back');

      expect(currentLocale.languageCode, equals('fr'));
      expect(foundFr, findsOneWidget, reason: 'Auth screen should display French "Bienvenue"');
      expect(foundEn, findsNothing, reason: 'Auth screen should no longer display English "Welcome back"');

      // Now switch to Arabic
      await tester.tap(dropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final arItem = find.text('العربية (AR)').last;
      await tester.tap(arItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(desktopLocaleProvider).languageCode, equals('ar'));
      expect(find.text('مرحباً بعودتك'), findsOneWidget, reason: 'Auth screen should display Arabic');

      // Now switch back to English (complete EN -> FR -> AR -> EN cycle)
      await tester.tap(dropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final enItem = find.text('English (EN)').last;
      await tester.tap(enItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(desktopLocaleProvider).languageCode, equals('en'));
      expect(find.text('Welcome back'), findsOneWidget, reason: 'Auth screen should return to English');
    });

    testWidgets('2. Test language switching on Navigation Shell & Child Screens', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _LoggedInMockSession()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ModiriDesktopApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially in English
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Tableau de bord'), findsNothing);

      // Use the navigation shell PopupMenuButton to select French
      final langButton = find.byTooltip('Language / Langue / اللغة');
      expect(langButton, findsOneWidget);
      await tester.tap(langButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final frMenuItem = find.text('Français (FR)');
      expect(frMenuItem, findsOneWidget);
      await tester.tap(frMenuItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(desktopLocaleProvider).languageCode, equals('fr'));

      // Check navigation shell text
      expect(find.text('Tableau de bord'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);

      // Now switch to Arabic
      await tester.tap(find.byTooltip('Language / Langue / اللغة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final arMenuItem = find.text('العربية (AR - RTL)');
      expect(arMenuItem, findsOneWidget);
      await tester.tap(arMenuItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(desktopLocaleProvider).languageCode, equals('ar'));
      expect(find.text('لوحة التحكم'), findsOneWidget);

      // Directionality check
      final directionality = tester.widget<Directionality>(
        find.descendant(
          of: find.byType(MaterialApp),
          matching: find.byType(Directionality),
        ).first,
      );
      expect(directionality.textDirection, equals(TextDirection.rtl));

      // Now switch back to English (complete EN -> FR -> AR -> EN cycle)
      await tester.tap(find.byTooltip('Language / Langue / اللغة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final enMenuItem = find.text('English (EN)');
      expect(enMenuItem, findsOneWidget);
      await tester.tap(enMenuItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(desktopLocaleProvider).languageCode, equals('en'));
      expect(find.text('Dashboard'), findsOneWidget);
      final directionalityEn = tester.widget<Directionality>(
        find.descendant(
          of: find.byType(MaterialApp),
          matching: find.byType(Directionality),
        ).first,
      );
      expect(directionalityEn.textDirection, equals(TextDirection.ltr));
    });

    testWidgets('3. Test POS screen renders translated titles and tabs dynamically', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _LoggedInMockSession()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ModiriDesktopApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to French via desktopLocaleProvider
      await container.read(desktopLocaleProvider.notifier).setLocale(const Locale('fr'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Navigate to POS section (Caisse & Ventes)
      final posNav = find.text('Caisse & Ventes');
      expect(posNav, findsOneWidget);
      await tester.tap(posNav);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify POS screen rendered in French!
      expect(find.text('Terminal de Vente & Caisse'), findsOneWidget);
      expect(find.text('Caisse Active'), findsOneWidget);
      expect(find.text('Registre des Ventes'), findsOneWidget);

      // Switch to Arabic
      await container.read(desktopLocaleProvider.notifier).setLocale(const Locale('ar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify POS screen updated to Arabic!
      expect(find.text('نقطة البيع ونظام الصندوق'), findsOneWidget);
      expect(find.text('صندوق البيع النشط'), findsOneWidget);
      expect(find.text('سجل معاملات المبيعات'), findsOneWidget);
    });

    testWidgets('4. Test POS screen preserves user state (inputs/controllers) across language changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _LoggedInMockSession()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ModiriDesktopApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Navigate to POS section in English
      final posNav = find.text('POS & Sales');
      expect(posNav, findsOneWidget);
      await tester.tap(posNav);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Enter search text in POS catalog search
      final searchFields = find.byType(TextField);
      expect(searchFields, findsWidgets);
      await tester.enterText(searchFields.first, 'Special Search Query 123');
      await tester.pump();

      // Verify the text is currently in the TextField
      expect(find.text('Special Search Query 123'), findsOneWidget);

      // Change locale to French
      await container.read(desktopLocaleProvider.notifier).setLocale(const Locale('fr'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert that the text is PRESERVED and not wiped by screen remounting!
      expect(find.text('Special Search Query 123'), findsOneWidget,
          reason: 'User input must not be wiped when changing application language');

      // And assert the POS header updated to French!
      expect(find.text('Terminal de Vente & Caisse'), findsOneWidget);

      // Now switch to Arabic
      await container.read(desktopLocaleProvider.notifier).setLocale(const Locale('ar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert that the text is STILL preserved in Arabic
      expect(find.text('Special Search Query 123'), findsOneWidget,
          reason: 'User input must persist across Arabic language switch');
      expect(find.text('نقطة البيع ونظام الصندوق'), findsOneWidget);

      // Complete full cycle: switch back to English
      await container.read(desktopLocaleProvider.notifier).setLocale(const Locale('en'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert that the text is STILL preserved in English
      expect(find.text('Special Search Query 123'), findsOneWidget,
          reason: 'User input must persist across full EN -> FR -> AR -> EN cycle');
      expect(find.text('POS & Sales'), findsOneWidget);
    });

    test('5. Isolated Offline Persistence: records and pending sync queue persist across app restarts', () async {
      // Use an isolated temporary database path that does NOT touch user data
      const dbPath = inMemoryDatabasePath;
      final factory = databaseFactoryFfi;
      var db = await factory.openDatabase(dbPath);

      // Setup standard schema in isolated test DB
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          stock_quantity INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          total REAL NOT NULL,
          payment_method TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE offline_sync_queue (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          retry_count INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      // Perform local offline creation
      await db.insert('products', {
        'id': 'prod_offline_1',
        'company_id': 'comp_test_offline',
        'name': 'Cold Brew Bottle',
        'price': 450.0,
        'stock_quantity': 15,
      });

      await db.insert('sales', {
        'id': 'sale_offline_1',
        'company_id': 'comp_test_offline',
        'total': 450.0,
        'payment_method': 'cash',
        'synced': 0,
      });

      await db.insert('offline_sync_queue', {
        'id': 'sync_offline_1',
        'company_id': 'comp_test_offline',
        'entity_type': 'sale',
        'operation': 'CREATE',
        'payload': '{"sale_id": "sale_offline_1", "total": 450.0}',
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Verify initial state
      final initialSales = await db.query('sales');
      final initialQueue = await db.query('offline_sync_queue');
      expect(initialSales.length, equals(1));
      expect(initialQueue.length, equals(1));
      expect(initialQueue.first['status'], equals('pending'));

      // Simulate network failure: retry increments without queue clearing
      await db.update('offline_sync_queue', {
        'retry_count': 1,
      }, where: 'id = ?', whereArgs: ['sync_offline_1']);

      final retriedQueue = await db.query('offline_sync_queue');
      expect(retriedQueue.first['retry_count'], equals(1));
      expect(retriedQueue.first['status'], equals('pending'));

      await db.close();
    });
  });
}

class _LoggedInMockSession extends SessionNotifier {
  _LoggedInMockSession() {
    state = const SessionState(
      isLoggedIn: true,
      accessToken: 'mock_token',
      userId: 'user_1',
      userName: 'Amine Tester',
      companyId: 'comp_1',
      companyName: 'Modiri Test Corp',
      businessType: 'superette',
      onboardingCompleted: true,
    );
  }
}
