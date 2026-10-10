import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desktop_components.dart';
import '../../../core/widgets/glass_panel.dart';

class DesktopInvoicesScreen extends StatefulWidget {
  const DesktopInvoicesScreen({super.key});

  @override
  State<DesktopInvoicesScreen> createState() => _DesktopInvoicesScreenState();
}

class _DesktopInvoicesScreenState extends State<DesktopInvoicesScreen> {
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _invoices = [
    {
      'id': 'INV-2026-0042',
      'customer': 'Walk-in Customer',
      'date': '2026-10-09',
      'status': 'PAID',
      'total': 148.50,
      'items': [
        {'name': 'Premium Espresso Beans 1kg', 'qty': 2, 'price': 24.50},
        {'name': 'Artisan Sourdough Loaf', 'qty': 4, 'price': 6.50},
      ],
    },
    {
      'id': 'INV-2026-0041',
      'customer': 'Sarah Jenkins',
      'date': '2026-10-09',
      'status': 'PAID',
      'total': 320.00,
      'items': [
        {'name': 'Extra Virgin Olive Oil 750ml', 'qty': 10, 'price': 18.25},
      ],
    },
    {
      'id': 'INV-2026-0040',
      'customer': 'Apex Logistics Corp',
      'date': '2026-10-08',
      'status': 'PENDING',
      'total': 850.00,
      'items': [
        {'name': 'Premium Espresso Beans 1kg', 'qty': 20, 'price': 24.50},
        {'name': 'French Butter Croissant (x4)', 'qty': 40, 'price': 9.00},
      ],
    },
  ];

  Future<void> _printInvoice(Map<String, dynamic> invoice) async {
    final pdf = pw.Document();

    pw.Font? cairoRegular;
    pw.Font? cairoBold;
    try {
      final regData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      cairoRegular = pw.Font.ttf(regData);
      cairoBold = pw.Font.ttf(boldData);
    } catch (_) {}

    final theme = (cairoRegular != null && cairoBold != null)
        ? pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold)
        : pw.ThemeData.base();

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          final items = invoice['items'] as List<Map<String, dynamic>>;
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MODIRI AI ENTERPRISE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text('INVOICE / FACTURE', style: pw.TextStyle(fontSize: 18, color: PdfColors.blueGrey700)),
                  ],
                ),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 12),
                pw.Text('Invoice #: ${invoice['id']}'),
                pw.Text('Date: ${invoice['date']}'),
                pw.Text('Customer: ${invoice['customer']}'),
                pw.Text('Status: ${invoice['status']}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Item / Description', 'Qty', 'Unit Price', 'Line Total'],
                  data: items.map((it) {
                    final qty = it['qty'] as int;
                    final price = it['price'] as double;
                    return [it['name'], '$qty', '\$${price.toStringAsFixed(2)}', '\$${(qty * price).toStringAsFixed(2)}'];
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text('TOTAL DUE: \$${(invoice['total'] as double).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${invoice['id']}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _invoices.where((inv) {
      if (_selectedFilter == 'All') return true;
      return inv['status'] == _selectedFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopPageHeader(
            title: 'Billing & Invoices',
            subtitle: 'Issue, view, and print enterprise invoices with Cairo Arabic typography.',
            actions: [
              for (final f in ['All', 'PAID', 'PENDING'])
                Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _selectedFilter == f,
                    onSelected: (_) => setState(() => _selectedFilter = f),
                    backgroundColor: AppColors.surfaceElevatedDark,
                    selectedColor: AppColors.electricBlue.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _selectedFilter == f ? AppColors.electricBlue : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),

          Expanded(
            child: GlassPanel(
              padding: EdgeInsets.zero,
              child: DesktopDataTable(
                columns: const [
                  'Invoice #',
                  'Client / Recipient',
                  'Issue Date',
                  'Payment Status',
                  'Total Amount',
                  'Actions',
                ],
                rows: filtered.map((inv) {
                  final status = inv['status'] as String;
                  final isPaid = status == 'PAID';

                  return [
                    Text(inv['id'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(inv['customer'] as String, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    Text(inv['date'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    DesktopBadge(
                      label: status,
                      color: isPaid ? AppColors.neonEmerald : AppColors.neonAmber,
                    ),
                    Text(_currency.format(inv['total']), style: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 18, color: AppColors.electricBlue),
                          tooltip: 'Print PDF (Cairo TTF)',
                          onPressed: () => _printInvoice(inv),
                        ),
                      ],
                    ),
                  ];
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
