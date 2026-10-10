import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../sales/domain/sale.dart';
import '../domain/invoice.dart';

class InvoicesRepository extends StateNotifier<AsyncValue<List<Invoice>>> {
  InvoicesRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> load() async {
    // 1. Read from local SQLite first
    try {
      final local = await _fetchFromLocal();
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {}

    // 2. Fetch from backend if online
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/invoices');
      final invoices = (response['data'] as List)
          .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
          .toList();

      await _upsertToLocal(invoices);
      final fresh = await _fetchFromLocal();
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (!mounted) return;
      if (state.hasValue) {
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Invoice>> _fetchFromLocal() async {
    final companyId = _companyId;
    // TENANT ISOLATION: return nothing when no account is active.
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'invoices',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'sold_at DESC',
    );
    return rows.map((r) => Invoice(
      id: r['id'] as String,
      invoiceNumber: r['invoice_number'] as String,
      status: paymentStatusFromApi(r['status'] as String),
      total: (r['total'] as num).toDouble(),
      soldAt: DateTime.parse(r['sold_at'] as String),
      customerName: r['customer_name'] as String?,
    )).toList();
  }

  Future<void> _upsertToLocal(List<Invoice> invoices) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final inv in invoices) {
      // Reconcile: delete any existing local placeholder that had the same invoice_number
      batch.delete(
        'invoices',
        where: 'company_id = ? AND invoice_number = ? AND id != ?',
        whereArgs: [companyId, inv.invoiceNumber, inv.id],
      );
      batch.insert(
        'invoices',
        {
          'id': inv.id,
          'sale_id': inv.saleId ?? inv.id,
          'company_id': companyId,
          'invoice_number': inv.invoiceNumber,
          'status': paymentStatusToApi(inv.status),
          'customer_name': inv.customerName,
          'total': inv.total,
          'sold_at': inv.soldAt.toIso8601String(),
          'created_at': inv.soldAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static pw.Font? _cairoRegular;
  static pw.Font? _cairoBold;

  Future<Invoice> fetchDetails(String id) async {
    final companyId = _companyId;

    // 1. Check local SQLite first (strictly scoped by company)
    try {
      if (companyId != null) {
        final db = await AppDatabase.instance.database;
        final invRows = await db.query('invoices', where: 'id = ? AND company_id = ?', whereArgs: [id, companyId]);

        if (invRows.isNotEmpty) {
          final inv = invRows.first;
          final saleId = (inv['sale_id'] as String?) ?? id;
          final itemRows = await db.rawQuery('''
            SELECT si.*,
                   COALESCE(NULLIF(si.product_name, ''), p.name, 'Product') AS resolved_product_name
            FROM sale_items si
            LEFT JOIN products p ON p.id = si.product_id AND (p.company_id = si.company_id OR p.company_id = ?)
            WHERE (si.sale_id = ? OR si.sale_id = ?) AND (si.company_id = ? OR si.company_id IS NULL)
          ''', [companyId, saleId, id, companyId]);

          final items = itemRows.map((ir) => InvoiceLineItem(
            productName: (ir['resolved_product_name'] ?? 'Product') as String,
            quantity: (ir['quantity'] as num).toInt(),
            lineTotal: (ir['line_total'] as num).toDouble(),
          )).toList();

          if (items.isNotEmpty) {
            return Invoice(
              id: inv['id'] as String,
              saleId: saleId,
              invoiceNumber: inv['invoice_number'] as String,
              status: paymentStatusFromApi(inv['status'] as String),
              total: (inv['total'] as num).toDouble(),
              soldAt: DateTime.parse(inv['sold_at'] as String),
              customerName: inv['customer_name'] as String?,
              items: items,
            );
          }
        }
      }
    } catch (_) {}

    // 2. Fetch from API if items were empty locally or local read failed
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/invoices/$id');
      return Invoice.fromJson(response['data'] as Map<String, dynamic>);
    } catch (_) {
      // If offline and we had an invoice header, return it with whatever items exist
      if (companyId != null) {
        final db = await AppDatabase.instance.database;
        final invRows = await db.query('invoices', where: 'id = ? AND company_id = ?', whereArgs: [id, companyId]);
        if (invRows.isNotEmpty) {
          final inv = invRows.first;
          return Invoice(
            id: inv['id'] as String,
            saleId: (inv['sale_id'] as String?) ?? id,
            invoiceNumber: inv['invoice_number'] as String,
            status: paymentStatusFromApi(inv['status'] as String),
            total: (inv['total'] as num).toDouble(),
            soldAt: DateTime.parse(inv['sold_at'] as String),
            customerName: inv['customer_name'] as String?,
            items: const [],
          );
        }
      }
      rethrow;
    }
  }

  Future<Uint8List> fetchInvoicePdf(String id) async {
    // Generate locally with bundled Cairo font to guarantee that Arabic product
    // and customer names are shaped and rendered with native TrueType fonts,
    // avoiding WinAnsi / Latin-1 masking corruption ('hdgjgj')
    try {
      return await _generateOfflinePdf(id);
    } catch (_) {
      try {
        final client = _ref.read(apiClientProvider);
        return await client.getBytes('/invoices/$id/pdf');
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<Uint8List> _generateOfflinePdf(String id) async {
    final invoice = await fetchDetails(id);
    final pdf = pw.Document();

    pw.ThemeData? theme;
    try {
      if (_cairoRegular == null || _cairoBold == null) {
        final fontDataRegular = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
        final fontDataBold = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
        _cairoRegular = pw.Font.ttf(fontDataRegular);
        _cairoBold = pw.Font.ttf(fontDataBold);
      }
      if (_cairoRegular != null && _cairoBold != null) {
        theme = pw.ThemeData.withFont(
          base: _cairoRegular!,
          bold: _cairoBold!,
        );
      }
    } catch (_) {
      // Fall back to default PDF fonts if assets are unavailable
    }

    bool hasArabic(String text) =>
        RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);

    pw.Widget pdfText(String text, {pw.TextStyle? style, pw.TextAlign textAlign = pw.TextAlign.left}) {
      final isRtl = hasArabic(text);
      final textStyle = (style ?? const pw.TextStyle()).copyWith(
        font: isRtl && _cairoRegular != null ? _cairoRegular : style?.font,
        fontBold: isRtl && _cairoBold != null ? _cairoBold : style?.fontBold,
      );
      return pw.Text(
        text,
        style: textStyle,
        textAlign: isRtl ? (textAlign == pw.TextAlign.left ? pw.TextAlign.right : textAlign) : textAlign,
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      );
    }

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('INVOICE / FACTURE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Invoice #: ${invoice.invoiceNumber}'),
              pw.Text('Date: ${invoice.soldAt.toIso8601String().substring(0, 10)}'),
              if (invoice.customerName != null) pdfText('Customer: ${invoice.customerName}'),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Item / Article', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Total (DZD)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...invoice.items.map((i) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pdfText(i.productName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(i.quantity.toString(), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(i.lineTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  )),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total: ${invoice.total.toStringAsFixed(2)} DZD',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }
}

final invoicesRepositoryProvider =
    StateNotifierProvider.autoDispose<InvoicesRepository, AsyncValue<List<Invoice>>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId ?? s.userId));
    return InvoicesRepository(ref);
  },
);

final invoiceDetailsProvider =
    FutureProvider.autoDispose.family<Invoice, String>((ref, id) {
  return ref.read(invoicesRepositoryProvider.notifier).fetchDetails(id);
});
