import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../localization/desktop_localizations.dart';

class ReceiptPrinter {
  static Future<void> printReceipt({
    required String companyName,
    required String invoiceNumber,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double total,
    required double subtotal,
    required double discount,
    required String paymentMethod,
    String? customerName,
    ModiriLocalizations? loc,
  }) async {
    final l = loc ?? ModiriLocalizations(const Locale('en'));
    final currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'en_US');

    final doc = pw.Document();

    // 80mm roll standard width (approx 226 points)
    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                companyName.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(l.get('pos_receipt_title'), style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${l.get('receipt_invoice_prefix')} $invoiceNumber', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(dateFormat.format(date), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (customerName != null && customerName.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('${l.get('receipt_customer_prefix')} $customerName', style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              // Items header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 4, child: pw.Text(l.get('item_col_header'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 2, child: pw.Text(l.get('qty_col_header'), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 3, child: pw.Text(l.get('total_col_header'), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                ],
              ),
              pw.Divider(thickness: 0.5),
              ...items.map((item) {
                final name = item['name']?.toString() ?? 'Item';
                final qty = item['quantity'] ?? 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final lineTotal = (item['lineTotal'] as num?)?.toDouble() ?? (qty * price);

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(name, style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 2, child: pw.Text('$qty x ${price.toStringAsFixed(0)}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 3, child: pw.Text(lineTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(l.get('subtotal_colon'), style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(currency.format(subtotal), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(l.get('discount_colon'), style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('-${currency.format(discount)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(l.get('total_due_colon'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(currency.format(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(l.get('payment_method_colon'), style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(paymentMethod.toUpperCase(), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Text(l.get('receipt_thank_you'), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: invoiceNumber,
                width: 140,
                height: 28,
                drawText: false,
              ),
              pw.SizedBox(height: 4),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_$invoiceNumber',
    );
  }

  static Future<void> printFinancialReport({
    required String companyName,
    required String periodLabel,
    required double revenue,
    required double cogs,
    required double grossProfit,
    required double operatingExpenses,
    required double netProfit,
    required double profitMargin,
    required int salesCount,
    required List<dynamic> topProducts,
    required List<dynamic> expensesByCategory,
    ModiriLocalizations? loc,
  }) async {
    final l = loc ?? ModiriLocalizations(const Locale('en'));
    final currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(l.get('financial_perf_statement'),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('${l.get('period_prefix')} $periodLabel',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${l.get('generated_prefix')} ${DateFormat('yyyy-MM-dd HH:mm', 'en_US').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5, color: PdfColors.blueGrey800),
              pw.SizedBox(height: 12),
              pw.Text(l.get('exec_financial_summary'),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('financial_metric_header'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('amount_dzd_header'), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('notes_kpi_header'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('gross_sales_revenue'), style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(currency.format(revenue), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$salesCount transactions completed', style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('cogs_label'), style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(currency.format(cogs), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('cogs_desc'), style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('gross_profit_label'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(currency.format(grossProfit), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('gross_profit_formula'), style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('operating_expenses_label'), style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(currency.format(operatingExpenses), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('operating_expenses_desc'), style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(l.get('net_operating_profit'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(currency.format(netProfit), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Net Margin: ${profitMargin.toStringAsFixed(1)}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(l.get('top_performing_products'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        if (topProducts.isEmpty)
                          pw.Text(l.get('no_sales_period'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
                        else
                          ...topProducts.take(6).map((item) {
                            final name = item['name']?.toString() ?? 'Product';
                            final qty = item['unitsSold'] ?? item['quantity'] ?? item['count'] ?? 0;
                            final rev = ((item['revenue'] ?? item['total'] ?? 0.0) as num).toDouble();
                            return pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
                                  pw.Text('$qty sold • ${currency.format(rev)}', style: const pw.TextStyle(fontSize: 9)),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(l.get('expenses_by_category'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        if (expensesByCategory.isEmpty)
                          pw.Text(l.get('no_expenses_period'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
                        else
                          ...expensesByCategory.take(6).map((item) {
                            final cat = item['category']?.toString() ?? 'General';
                            final amt = ((item['total'] ?? item['amount'] ?? 0.0) as num).toDouble();
                            return pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(cat, style: const pw.TextStyle(fontSize: 9)),
                                  pw.Text(currency.format(amt), style: const pw.TextStyle(fontSize: 9)),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Modiri AI Enterprise Desktop Edition', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(l.get('official_ledger_statement'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Financial_Report_${periodLabel.replaceAll(' ', '_')}',
    );
  }

  static Future<void> printProductLabel({
    required String companyName,
    required String name,
    required double price,
    required String barcode,
  }) async {
    final currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
    final doc = pw.Document();

    const pageFormat = PdfPageFormat(
      50 * PdfPageFormat.mm,
      30 * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(companyName.toUpperCase(), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 1),
              pw.Text(
                name.length > 22 ? '${name.substring(0, 20)}...' : name,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                currency.format(price),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              if (barcode.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcode,
                  width: 100,
                  height: 18,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 6),
                ),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Label_${name.replaceAll(' ', '_')}',
    );
  }

  static Future<void> printKitchenTicket({
    required String companyName,
    required String orderNumber,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    String? tableName,
    String? serverName,
    String? notes,
    ModiriLocalizations? loc,
  }) async {
    final l = loc ?? ModiriLocalizations(const Locale('en'));
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'en_US');
    final doc = pw.Document();

    const pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                '*** KITCHEN ORDER TICKET (KOT) ***',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(companyName.toUpperCase(), style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ORDER: #$orderNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(dateFormat.format(date), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (tableName != null && tableName.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('TABLE: $tableName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ),
              ],
              if (serverName != null && serverName.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('SERVER: $serverName', style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 2, child: pw.Text(l.get('qty_col_header'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(flex: 6, child: pw.Text(l.get('item_col_header'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              pw.Divider(thickness: 0.5),
              ...items.map((item) {
                final name = item['name']?.toString() ?? 'Item';
                final qty = item['quantity'] ?? 1;
                final itemNote = item['notes']?.toString();

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(flex: 2, child: pw.Text('$qty x', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                          pw.Expanded(flex: 6, child: pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        ],
                      ),
                      if (itemNote != null && itemNote.isNotEmpty) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 20),
                          child: pw.Text('>> $itemNote', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              if (notes != null && notes.isNotEmpty) ...[
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('NOTE: $notes', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Text('--- END OF KITCHEN TICKET ---', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Kitchen_Ticket_$orderNumber',
    );
  }
}
