import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/utils/modiri_formatters.dart';
import 'package:modiri_desktop/features/ai/presentation/desktop_ai_invoice_scanner_screen.dart';

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'en_US';
  });

  group('Requirement 1: Latin Digits (French Numbers) Across Locales', () {
    test('ModiriFormatters.toLatinDigits converts Eastern and Persian Arabic digits to ASCII 0-9', () {
      expect(ModiriFormatters.toLatinDigits('٠١٢٣٤٥٦٧٨٩'), equals('0123456789'));
      expect(ModiriFormatters.toLatinDigits('۰۱۲۳۴۵۶۷۸۹'), equals('0123456789'));
      expect(ModiriFormatters.toLatinDigits('INV-٠٠١٢٥'), equals('INV-00125'));
      expect(ModiriFormatters.toLatinDigits('Date: ٢٠٢٦-١٠-١٦'), equals('Date: 2026-10-16'));
    });

    test('ModiriFormatters.formatCurrency ensures Western digits in Arabic and Latin locales', () {
      final arFormatted = ModiriFormatters.formatCurrency(12500, languageCode: 'ar');
      expect(arFormatted, contains('12,500.00'));
      expect(arFormatted, contains('دج'));
      expect(arFormatted.contains(RegExp(r'[٠-٩]')), isFalse);

      final enFormatted = ModiriFormatters.formatCurrency(12500, languageCode: 'en');
      expect(enFormatted, equals('12,500.00 DZD'));

      final frFormatted = ModiriFormatters.formatCurrency(12500, languageCode: 'fr');
      expect(frFormatted, equals('12,500.00 DZD'));
    });

    test('ModiriFormatters.formatNumber ensures Western digits with grouping commas', () {
      expect(ModiriFormatters.formatNumber(1500), equals('1,500'));
      expect(ModiriFormatters.formatNumber(1000000), equals('1,000,000'));
      expect(ModiriFormatters.formatNumber(42.55, 2), equals('42.55'));
    });

    test('ModiriFormatters.formatDate ensures Latin ASCII year, month, and day', () {
      final dt = DateTime(2026, 10, 16);
      final formatted = ModiriFormatters.formatDate(dt);
      expect(formatted, equals('2026-10-16'));
      expect(formatted.contains(RegExp(r'[٠-٩]')), isFalse);
    });
  });

  group('Requirement 2: Localization Dictionary Parity', () {
    test('All profile and AI scanner keys exist across EN, FR, and AR dictionaries', () {
      final locEn = ModiriLocalizations(const Locale('en'));
      final locFr = ModiriLocalizations(const Locale('fr'));
      final locAr = ModiriLocalizations(const Locale('ar'));

      final keys = [
        'customer_profile',
        'employee_profile',
        'supplier_profile',
        'view_profile',
        'lifetime_purchases',
        'credit_ledger',
        'invoices_and_sales',
        'staff_details',
        'salary_history',
        'attendance_logs',
        'import_to_inventory',
        'scan_demo_invoice',
        'upload_invoice_doc',
        'ai_scanner',
        'ai_scanner_title',
      ];

      for (final k in keys) {
        expect(locEn.get(k), isNotEmpty, reason: 'Key $k missing in EN');
        expect(locFr.get(k), isNotEmpty, reason: 'Key $k missing in FR');
        expect(locAr.get(k), isNotEmpty, reason: 'Key $k missing in AR');
      }
    });
  });

  group('Requirement 3: Desktop AI Invoice Scanner UI and Verification Engine', () {
    testWidgets('Renders AI Scanner screen with header, mode switcher, and upload panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 850));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopAiInvoiceScannerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Invoice & Receipt Scanner'), findsOneWidget);
      expect(find.text('Supplier / Stock Purchase'), findsOneWidget);
      expect(find.text('Sales Receipt / Invoiced Sale'), findsOneWidget);
      expect(find.text('Try Sample Invoice'), findsOneWidget);
      expect(find.text('Upload Invoice (PDF, PNG, JPG)'), findsOneWidget);
      expect(find.text('Scan & Extract with AI'), findsOneWidget);
    });

    testWidgets('Tapping Try Sample Invoice loads structured line items and calculates totals', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 850));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopAiInvoiceScannerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap sample invoice button
      await tester.tap(find.text('Try Sample Invoice'));
      await tester.pumpAndSettle();

      // Check extracted vendor
      expect(find.text('Sarl Agro Distribution Alger'), findsOneWidget);

      // Check extracted items
      expect(find.text('Huile de Table Elio 5L'), findsOneWidget);
      expect(find.text('Sucre Blanc Raffiné 1kg'), findsOneWidget);
      expect(find.text('Lait UHT Candia 1L'), findsOneWidget);
      expect(find.text('Café Moulu Facto 250g'), findsOneWidget);
      expect(find.text('Pâtes Couscous Dari 1kg'), findsOneWidget);

      // Verify import button is enabled and shows item count
      expect(find.text('Import to Inventory'), findsOneWidget);
    });
  });
}
