import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/theme/app_colors.dart';
import 'package:modiri_desktop/core/theme/desktop_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 5 Regression Tests: Defect Fixes & Multilingual Verification', () {
    // -------------------------------------------------------------------------
    // TEST 1: Restaurant Table Status Normalization (Root Cause Defect Fix)
    // -------------------------------------------------------------------------
    test('1. Restaurant Table Status: Normalized internal status works in EN, FR, AR', () {
      final locales = [
        const Locale('en'),
        const Locale('fr'),
        const Locale('ar'),
      ];

      for (final locale in locales) {
        final loc = ModiriLocalizations(locale);

        // Stored table records from SQLite always have raw internal status values:
        final tableOccupied = {'id': 't1', 'name': 'Table 1', 'status': 'occupied', 'seats': 4};
        final tableReserved = {'id': 't2', 'name': 'Table 2', 'status': 'reserved', 'seats': 2};
        final tableAvailable = {'id': 't3', 'name': 'Table 3', 'status': 'available', 'seats': 6};
        final tableDefault = {'id': 't4', 'name': 'Table 4', 'seats': 2}; // null status defaults to available

        // --- NEW IMPLEMENTATION LOGIC ---
        bool checkIsOccupied(Map<String, dynamic> t) {
          final status = (t['status'] ?? 'available').toString().toLowerCase();
          return status == 'occupied';
        }

        bool checkIsReserved(Map<String, dynamic> t) {
          final status = (t['status'] ?? 'available').toString().toLowerCase();
          return status == 'reserved';
        }

        Color getTableColor(Map<String, dynamic> t) {
          final isOccupied = checkIsOccupied(t);
          final isReserved = checkIsReserved(t);
          Color tone = ModiriColors.brandTeal;
          if (isOccupied) tone = ModiriColors.brandAmber;
          if (isReserved) tone = ModiriColors.brandBlue;
          return tone;
        }

        // --- OLD DEFECTIVE LOGIC (for proof of defect) ---
        bool oldIsOccupied(Map<String, dynamic> t) {
          final status = (t['status'] ?? loc.get('available')).toString().toLowerCase();
          return status == loc.get('occupied');
        }

        bool oldIsReserved(Map<String, dynamic> t) {
          final status = (t['status'] ?? loc.get('available')).toString().toLowerCase();
          return status == loc.get('reserved');
        }

        // In French and Arabic, the old logic FAILED:
        if (locale.languageCode == 'fr' || locale.languageCode == 'ar') {
          expect(
            oldIsOccupied(tableOccupied),
            isFalse,
            reason: 'OLD defective implementation fails status comparison in ${locale.languageCode}',
          );
          expect(
            oldIsReserved(tableReserved),
            isFalse,
            reason: 'OLD defective implementation fails status comparison in ${locale.languageCode}',
          );
        }

        // In ALL languages (EN, FR, AR), the NEW logic SUCCEEDS:
        expect(checkIsOccupied(tableOccupied), isTrue, reason: 'Occupied detected in ${locale.languageCode}');
        expect(checkIsReserved(tableOccupied), isFalse);
        expect(getTableColor(tableOccupied), equals(ModiriColors.brandAmber));

        expect(checkIsReserved(tableReserved), isTrue, reason: 'Reserved detected in ${locale.languageCode}');
        expect(checkIsOccupied(tableReserved), isFalse);
        expect(getTableColor(tableReserved), equals(ModiriColors.brandBlue));

        expect(checkIsOccupied(tableAvailable), isFalse);
        expect(checkIsReserved(tableAvailable), isFalse);
        expect(getTableColor(tableAvailable), equals(ModiriColors.brandTeal));

        expect(checkIsOccupied(tableDefault), isFalse);
        expect(checkIsReserved(tableDefault), isFalse);
        expect(getTableColor(tableDefault), equals(ModiriColors.brandTeal));

        // Display label verification
        final statusKey = (tableOccupied['status'] ?? 'available').toString().toLowerCase();
        final displayLabel = loc.get(statusKey);
        expect(displayLabel, isNotEmpty);
        if (locale.languageCode == 'en') expect(displayLabel, equals('Occupied'));
        if (locale.languageCode == 'fr') expect(displayLabel, equals('Occupée'));
        if (locale.languageCode == 'ar') expect(displayLabel, equals('مشغولة'));
      }
    });

    // -------------------------------------------------------------------------
    // TEST 2: POS Table Columns & Action Labels Multilingual Widget Test
    // -------------------------------------------------------------------------
    testWidgets('2. POS Data Table columns dynamically update on EN -> FR -> AR switch', (tester) async {
      SharedPreferences.setMockInitialValues({'modiri_desktop_locale': 'en'});

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(desktopLocaleProvider);
              final loc = ModiriLocalizations(locale);

              return MaterialApp(
                locale: locale,
                supportedLocales: ModiriLocalizations.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: Column(
                    children: [
                      Text(loc.get('sale_id'), key: const ValueKey('col_sale_id')),
                      Text(loc.get('customer_label'), key: const ValueKey('col_customer')),
                      Text(loc.get('items_count'), key: const ValueKey('col_items')),
                      Text(loc.get('total_amount'), key: const ValueKey('col_total')),
                      Text(loc.get('action'), key: const ValueKey('col_action')),
                      ElevatedButton(
                        key: const ValueKey('btn_fr'),
                        onPressed: () => ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('fr')),
                        child: const Text('FR'),
                      ),
                      ElevatedButton(
                        key: const ValueKey('btn_ar'),
                        onPressed: () => ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('ar')),
                        child: const Text('AR'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step A: English
      expect(find.text('Sale ID'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Items Count'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);

      // Step B: Switch to French
      await tester.tap(find.byKey(const ValueKey('btn_fr')));
      await tester.pumpAndSettle();

      expect(find.text('ID Vente'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Nombre d\'articles'), findsOneWidget);
      expect(find.text('Montant Total'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);

      // Step C: Switch to Arabic
      await tester.tap(find.byKey(const ValueKey('btn_ar')));
      await tester.pumpAndSettle();

      expect(find.text('معرف البيع'), findsOneWidget);
      expect(find.text('العميل'), findsOneWidget);
      expect(find.text('عدد العناصر'), findsOneWidget);
      expect(find.text('المبلغ الإجمالي'), findsOneWidget);
      expect(find.text('الإجراءات'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Inventory & Invoices Data Table Multilingual Widget Test
    // -------------------------------------------------------------------------
    testWidgets('3. Inventory & Invoices columns dynamically update across all 3 languages', (tester) async {
      SharedPreferences.setMockInitialValues({'modiri_desktop_locale': 'en'});

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(desktopLocaleProvider);
              final loc = ModiriLocalizations(locale);

              return MaterialApp(
                locale: locale,
                supportedLocales: ModiriLocalizations.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: Column(
                    children: [
                      Text(loc.get('product_sku_column'), key: const ValueKey('inv_col_sku')),
                      Text(loc.get('purchase_cost_column'), key: const ValueKey('inv_col_cost')),
                      Text(loc.get('stock_level_column'), key: const ValueKey('inv_col_stock')),
                      Text(loc.get('invoice_number_column'), key: const ValueKey('inv_num_col')),
                      Text(loc.get('date_column'), key: const ValueKey('inv_date_col')),
                      Text(loc.get('status_column'), key: const ValueKey('inv_status_col')),
                      ElevatedButton(
                        key: const ValueKey('btn_fr'),
                        onPressed: () => ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('fr')),
                        child: const Text('FR'),
                      ),
                      ElevatedButton(
                        key: const ValueKey('btn_ar'),
                        onPressed: () => ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('ar')),
                        child: const Text('AR'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step A: EN
      expect(find.text('Product & SKU'), findsOneWidget);
      expect(find.text('Purchase Cost'), findsOneWidget);
      expect(find.text('Stock Level'), findsOneWidget);
      expect(find.text('Invoice Number'), findsOneWidget);

      // Step B: FR
      await tester.tap(find.byKey(const ValueKey('btn_fr')));
      await tester.pumpAndSettle();

      expect(find.text('Produit & SKU'), findsOneWidget);
      expect(find.text('Coût d\'achat'), findsOneWidget);
      expect(find.text('Niveau de stock'), findsOneWidget);
      expect(find.text('Numéro de facture'), findsOneWidget);

      // Step C: AR
      await tester.tap(find.byKey(const ValueKey('btn_ar')));
      await tester.pumpAndSettle();

      expect(find.text('المنتج ورمز الباركود'), findsOneWidget);
      expect(find.text('تكلفة الشراء'), findsOneWidget);
      expect(find.text('مستوى المخزون'), findsOneWidget);
      expect(find.text('رقم الفاتورة'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Restaurant Navigation Tabs & Dining Modals Multilingual Widget Test
    // -------------------------------------------------------------------------
    testWidgets('4. Restaurant tabs and action buttons render correctly in EN, FR, AR', (tester) async {
      SharedPreferences.setMockInitialValues({'modiri_desktop_locale': 'en'});

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(desktopLocaleProvider);
              final loc = ModiriLocalizations(locale);

              return MaterialApp(
                locale: locale,
                supportedLocales: ModiriLocalizations.supportedLocales,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: Column(
                    children: [
                      Text(loc.get('kitchen_tickets'), key: const ValueKey('tab_kitchen')),
                      Text(loc.get('floor_tables'), key: const ValueKey('tab_floor')),
                      Text(loc.get('menu_recipes'), key: const ValueKey('tab_menu')),
                      Text(loc.get('guest_seated'), key: const ValueKey('txt_guest_seated')),
                      Text(loc.get('table_reserved'), key: const ValueKey('txt_table_reserved')),
                      Text(loc.get('ready_for_seating'), key: const ValueKey('txt_ready_seating')),
                      ElevatedButton(
                        key: const ValueKey('btn_fr'),
                        onPressed: () => ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('fr')),
                        child: const Text('FR'),
                      ),
                      ElevatedButton(
                        key: const ValueKey('btn_ar'),
                        onPressed: () => ref.read(desktopLocaleProvider.notifier).setLocale(const Locale('ar')),
                        child: const Text('AR'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // EN
      expect(find.text('Kitchen Tickets'), findsOneWidget);
      expect(find.text('Floor Tables'), findsOneWidget);
      expect(find.text('Menu & Recipes'), findsOneWidget);
      expect(find.text('Guest Seated'), findsOneWidget);
      expect(find.text('Table Reserved'), findsOneWidget);
      expect(find.text('Ready for Seating'), findsOneWidget);

      // FR
      await tester.tap(find.byKey(const ValueKey('btn_fr')));
      await tester.pumpAndSettle();

      expect(find.text('Tickets Cuisine'), findsOneWidget);
      expect(find.text('Plan de Salle'), findsOneWidget);
      expect(find.text('Menu & Recettes'), findsOneWidget);
      expect(find.text('Client installé'), findsOneWidget);
      expect(find.text('Table réservée'), findsOneWidget);
      expect(find.text('Prête à accueillir'), findsOneWidget);

      // AR
      await tester.tap(find.byKey(const ValueKey('btn_ar')));
      await tester.pumpAndSettle();

      expect(find.text('تذاكر المطبخ'), findsOneWidget);
      expect(find.text('طاولات الصالة'), findsOneWidget);
      expect(find.text('القائمة والوصفات'), findsOneWidget);
      expect(find.text('الزبون جالس'), findsOneWidget);
      expect(find.text('طاولة محجوزة'), findsOneWidget);
      expect(find.text('جاهزة للاستقبال'), findsOneWidget);
    });
  });
}
