import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_ai/core/database/local_financial_calculator.dart';
import 'package:modiri_ai/features/invoices/domain/invoice.dart';
import 'package:modiri_ai/features/sales/domain/sale.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Offline Financial Calculator & Arabic Invoices Tests', () {
    late Database db;
    const testCompanyId = 'company_test_arabic_finance_123';

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Create necessary schema
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
          company_id TEXT NOT NULL,
          employee_id TEXT,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          expense_date TEXT NOT NULL,
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
        CREATE TABLE credit_purchases (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          sale_id TEXT NOT NULL,
          amount REAL NOT NULL,
          amount_paid REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE appointments (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          scheduled_at TEXT NOT NULL,
          status TEXT NOT NULL,
          consultation_price REAL NOT NULL DEFAULT 0,
          amount_paid REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          balance_due REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE suppliers (
          id TEXT PRIMARY KEY,
          company_id TEXT,
          name TEXT NOT NULL,
          phone TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('LocalFinancialCalculator computes Revenue = sum(total), GrossProfit = sum(line_profit), NetProfit = GP - Exp', () async {
      final now = DateTime.now();
      final todayIso = now.toIso8601String();

      // Product with Arabic name: زيت زيتون
      await db.insert('products', {
        'id': 'prod_oil',
        'company_id': testCompanyId,
        'name': 'زيت زيتون بكر',
        'category': 'Alimentation',
        'purchase_price': 600.0,
        'selling_price': 900.0,
        'quantity': 50,
      });

      // Product with Arabic name: حليب
      await db.insert('products', {
        'id': 'prod_milk',
        'company_id': testCompanyId,
        'name': 'حليب طازج',
        'category': 'Alimentation',
        'purchase_price': 70.0,
        'selling_price': 100.0,
        'quantity': 100,
      });

      // Sale 1: 2x oil (subtotal 1800, total 1800, cost 1200, profit 600)
      await db.insert('sales', {
        'id': 'sale_1',
        'client_transaction_id': 'tx_1',
        'company_id': testCompanyId,
        'subtotal': 1800.0,
        'discount': 0.0,
        'total': 1800.0,
        'payment_status': 'paid',
        'sold_at': todayIso,
        'created_at': todayIso,
        'synced': 0,
      });

      await db.insert('sale_items', {
        'id': 'si_1',
        'sale_id': 'sale_1',
        'company_id': testCompanyId,
        'product_id': 'prod_oil',
        'product_name': 'زيت زيتون بكر',
        'quantity': 2,
        'unit_price': 900.0,
        'unit_cost': 600.0,
        'line_total': 1800.0,
        'line_profit': 600.0,
      });

      // Sale 2: 3x milk (subtotal 300, total 300, cost 210, profit 90)
      await db.insert('sales', {
        'id': 'sale_2',
        'client_transaction_id': 'tx_2',
        'company_id': testCompanyId,
        'subtotal': 300.0,
        'discount': 0.0,
        'total': 300.0,
        'payment_status': 'paid',
        'sold_at': todayIso,
        'created_at': todayIso,
        'synced': 0,
      });

      await db.insert('sale_items', {
        'id': 'si_2',
        'sale_id': 'sale_2',
        'company_id': testCompanyId,
        'product_id': 'prod_milk',
        'product_name': 'حليب طازج',
        'quantity': 3,
        'unit_price': 100.0,
        'unit_cost': 70.0,
        'line_total': 300.0,
        'line_profit': 90.0,
      });

      // Expense: 200 DZD
      await db.insert('expenses', {
        'id': 'exp_1',
        'company_id': testCompanyId,
        'category': 'Utilities',
        'amount': 200.0,
        'description': 'Electricity bill',
        'expense_date': todayIso,
        'created_at': todayIso,
        'synced': 0,
      });

      // Verify Superette Dashboard math
      final superetteStats = await LocalFinancialCalculator.calculateSuperetteDashboard(db: db, companyId: testCompanyId);
      // Revenue = 1800 + 300 = 2100
      expect(superetteStats.todayRevenue, equals(2100.0));
      // Gross Profit = 600 + 90 = 690
      expect(superetteStats.todayGrossProfit, equals(690.0));
      // Net Profit = GP (690) - Expenses (200) = 490
      expect(superetteStats.todayNetProfit, equals(490.0));
      expect(superetteStats.transactionsToday, equals(2));

      // Verify Generic Dashboard math
      final dashStats = await LocalFinancialCalculator.calculateDashboard(db: db, companyId: testCompanyId);
      expect(dashStats.todayRevenue, equals(2100.0));
      expect(dashStats.todayGrossProfit, equals(690.0));
      expect(dashStats.todayProfit, equals(490.0));

      // Verify Clothing Dashboard math
      final clothingStats = await LocalFinancialCalculator.calculateClothingDashboard(db: db, companyId: testCompanyId);
      expect(clothingStats.todayRevenue, equals(2100.0));
      expect(clothingStats.todayGrossProfit, equals(690.0));
      expect(clothingStats.todayNetProfit, equals(490.0));

      // Verify Pharmacy Dashboard math
      final pharmacyStats = await LocalFinancialCalculator.calculatePharmacyDashboard(db: db, companyId: testCompanyId);
      expect(pharmacyStats.todayRevenue, equals(2100.0));
      expect(pharmacyStats.todayGrossProfit, equals(690.0));
      expect(pharmacyStats.todayNetProfit, equals(490.0));
    });

    test('Invoice lookup resolves Arabic product name from products table when sale_items product_name is empty', () async {
      // Product in products table with Arabic name
      await db.insert('products', {
        'id': 'prod_bimo',
        'company_id': testCompanyId,
        'name': 'بيمو شوكولا',
        'category': 'Biscuits',
        'purchase_price': 50.0,
        'selling_price': 70.0,
        'quantity': 20,
      });

      // Sale
      await db.insert('sales', {
        'id': 'sale_bimo',
        'company_id': testCompanyId,
        'subtotal': 140.0,
        'discount': 0.0,
        'total': 140.0,
        'payment_status': 'paid',
        'sold_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      // sale_item where product_name was null/empty (e.g. from server sync)
      await db.insert('sale_items', {
        'id': 'si_bimo',
        'sale_id': 'sale_bimo',
        'company_id': testCompanyId,
        'product_id': 'prod_bimo',
        'product_name': '',
        'quantity': 2,
        'unit_price': 70.0,
        'unit_cost': 50.0,
        'line_total': 140.0,
        'line_profit': 40.0,
      });

      // Invoice linked to sale_bimo
      await db.insert('invoices', {
        'id': 'inv_server_uuid_99',
        'sale_id': 'sale_bimo',
        'company_id': testCompanyId,
        'invoice_number': 'INV-10',
        'status': 'paid',
        'customer_name': 'محمد الأمين',
        'total': 140.0,
        'sold_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Execute query used in InvoicesRepository.fetchDetails
      final invRows = await db.query('invoices', where: 'id = ? AND company_id = ?', whereArgs: ['inv_server_uuid_99', testCompanyId]);
      expect(invRows.isNotEmpty, isTrue);

      final inv = invRows.first;
      final saleId = (inv['sale_id'] as String?) ?? 'inv_server_uuid_99';
      final itemRows = await db.rawQuery('''
        SELECT si.*,
               COALESCE(NULLIF(si.product_name, ''), p.name, 'Product') AS resolved_product_name
        FROM sale_items si
        LEFT JOIN products p ON p.id = si.product_id AND p.company_id = si.company_id
        WHERE (si.sale_id = ? OR si.sale_id = ?) AND si.company_id = ?
      ''', [saleId, 'inv_server_uuid_99', testCompanyId]);

      expect(itemRows.length, equals(1));
      expect(itemRows.first['resolved_product_name'], equals('بيمو شوكولا'));
    });

    test('Offline PDF generation with Arabic text and Cairo font produces valid binary document', () async {
      final fontDataRegular = File('assets/fonts/Cairo-Regular.ttf').readAsBytesSync();
      final fontDataBold = File('assets/fonts/Cairo-Bold.ttf').readAsBytesSync();
      final cairoRegular = pw.Font.ttf(fontDataRegular.buffer.asByteData());
      final cairoBold = pw.Font.ttf(fontDataBold.buffer.asByteData());
      final theme = pw.ThemeData.withFont(
        base: cairoRegular,
        bold: cairoBold,
      );

      final invoice = Invoice(
        id: 'inv_123',
        saleId: 'sale_123',
        invoiceNumber: 'INV-101',
        status: PaymentStatus.paid,
        total: 240.0,
        soldAt: DateTime.now(),
        customerName: 'أحمد بن علي',
        items: [
          InvoiceLineItem(productName: 'فرانة غاز', quantity: 1, lineTotal: 180.0),
          InvoiceLineItem(productName: 'حليب مبستر', quantity: 2, lineTotal: 60.0),
        ],
      );

      bool hasArabic(String text) =>
          RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);

      pw.Widget pdfText(String text, {pw.TextStyle? style, pw.TextAlign textAlign = pw.TextAlign.left}) {
        final isRtl = hasArabic(text);
        return pw.Text(
          text,
          style: style,
          textAlign: isRtl ? (textAlign == pw.TextAlign.left ? pw.TextAlign.right : textAlign) : textAlign,
          textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        );
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('INVOICE / FACTURE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('Invoice #: ${invoice.invoiceNumber}'),
                if (invoice.customerName != null) pdfText('Customer: ${invoice.customerName}'),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item / Article')),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    ...invoice.items.map((i) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pdfText(i.productName)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.quantity.toString(), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i.lineTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right)),
                      ],
                    )),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
      // First 4 bytes of valid PDF: %PDF
      expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), equals('%PDF'));
    });
  });
}
