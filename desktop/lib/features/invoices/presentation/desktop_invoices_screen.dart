import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/database/payment_transaction_manager.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/receipt_printer.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../ai/presentation/desktop_ai_invoice_scanner_screen.dart';

class DesktopInvoicesScreen extends ConsumerStatefulWidget {
  const DesktopInvoicesScreen({super.key});

  @override
  ConsumerState<DesktopInvoicesScreen> createState() => _DesktopInvoicesScreenState();
}

class _DesktopInvoicesScreenState extends ConsumerState<DesktopInvoicesScreen> with SingleTickerProviderStateMixin {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<dynamic> _invoices = [];
  List<dynamic> _purchaseInvoices = [];
  String? _error;
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'PAID', 'PARTIAL', 'UNPAID'
  String _searchQuery = '';
  List<String> _customerNames = ['Walk-in Customer'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInvoices();
    _loadPurchaseInvoices();
    _loadCustomers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadInvoices(),
      _loadPurchaseInvoices(),
      _loadCustomers(),
    ]);
  }

  Future<void> _loadCustomers() async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final rows = await db.query(
        'customers',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      final names = ['Walk-in Customer', ...rows.map((r) => r['name'] as String).where((n) => n != 'Walk-in Customer')];
      if (mounted) {
        setState(() {
          _customerNames = names;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from local SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      var localRows = await db.query(
        'invoices',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'created_at DESC',
      );
      if (localRows.isEmpty) {
        localRows = await db.query(
          'invoices',
          orderBy: 'created_at DESC',
        );
      }
      if (mounted && localRows.isNotEmpty) {
        setState(() {
          _invoices = localRows;
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch from backend if online
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/invoices');
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      final db = await ModiriDesktopDatabase.instance.database;
      final pendingRows = await db.query(
        'sync_queue',
        columns: ['entity_id'],
        where: "company_id = ? AND entity_type = 'invoice' AND status = 'pending'",
        whereArgs: [companyId],
      );
      final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

      final batch = db.batch();
      for (final inv in list) {
        final id = inv['id']?.toString() ?? const Uuid().v4();
        if (pendingIds.contains(id)) continue;

        final invNum = inv['invoice_number'] ?? inv['invoiceNumber'] ?? 'INV-$id';
        final total = (inv['total'] ?? 0.0 as num).toDouble();
        final status = inv['status']?.toString() ?? 'paid';
        final soldAt = inv['sold_at'] ?? inv['created_at'] ?? DateTime.now().toIso8601String();
        final paidAmt = ((inv['paid_amount'] ?? inv['paidAmount'] ?? (status == 'paid' ? total : 0.0)) as num).toDouble();
        final remAmt = ((inv['remaining_amount'] ?? inv['remainingAmount'] ?? (status == 'unpaid' ? total : (status == 'partial' ? (total - paidAmt) : 0.0))) as num).toDouble();

        batch.insert(
          'invoices',
          {
            'id': id,
            'company_id': companyId,
            'sale_id': inv['sale_id'] ?? inv['saleId'],
            'invoice_number': invNum,
            'customer_name': inv['customer_name'] ?? inv['customerName'],
            'total': total,
            'paid_amount': paidAmt,
            'remaining_amount': remAmt,
            'status': status,
            'sold_at': soldAt,
            'created_at': soldAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      var fresh = await db.query(
        'invoices',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'created_at DESC',
      );
      if (fresh.isEmpty) {
        fresh = await db.query(
          'invoices',
          orderBy: 'created_at DESC',
        );
      }

      if (mounted) {
        setState(() {
          _invoices = fresh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_invoices.isEmpty) _error = e.toString();
        });
      }
    }
  }

  Future<void> _markPaid(String id) async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      var invRows = await db.query(
        'invoices',
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );
      if (invRows.isEmpty) {
        invRows = await db.query(
          'invoices',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      if (invRows.isEmpty) return;
      final inv = invRows.first;
      final total = (inv['total'] as num?)?.toDouble() ?? 0.0;
      final currentPaid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final remaining = (inv['remaining_amount'] as num?)?.toDouble() ?? (total - currentPaid).clamp(0.0, double.infinity);
      await _applyInvoicePayment(id, remaining > 0 ? remaining : total);
    } catch (_) {}
  }

  Future<void> _loadPurchaseInvoices() async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      var localPurchases = await db.rawQuery('''
        SELECT 
          p.*,
          COALESCE(s.name, 'Fournisseur') as supplier_name,
          COALESCE(s.phone, '') as supplier_phone
        FROM supplier_purchases p
        LEFT JOIN suppliers s ON s.id = p.supplier_id
        WHERE p.company_id = ?
        ORDER BY p.purchase_date DESC, p.created_at DESC
      ''', [companyId]);

      if (localPurchases.isEmpty) {
        localPurchases = await db.rawQuery('''
          SELECT 
            p.*,
            COALESCE(s.name, 'Fournisseur') as supplier_name,
            COALESCE(s.phone, '') as supplier_phone
          FROM supplier_purchases p
          LEFT JOIN suppliers s ON s.id = p.supplier_id
          ORDER BY p.purchase_date DESC, p.created_at DESC
        ''');
      }

      if (mounted) {
        setState(() {
          _purchaseInvoices = localPurchases;
        });
      }
    } catch (_) {}
  }

  Future<void> _applyPurchasePayment(String pId, double paymentAmount) async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final rows = await db.query(
        'supplier_purchases',
        where: 'id = ? AND company_id = ?',
        whereArgs: [pId, companyId],
      );
      if (rows.isEmpty) return;
      final p = rows.first;
      final total = (p['total_amount'] as num?)?.toDouble() ?? 0.0;
      final currentPaid = (p['amount_paid'] as num?)?.toDouble() ?? 0.0;
      final newPaid = currentPaid + paymentAmount;
      final newRem = (total - newPaid).clamp(0.0, double.infinity);
      final newStatus = newRem <= 0.001 ? 'PAID' : 'PARTIAL';

      await db.update(
        'supplier_purchases',
        {
          'amount_paid': newPaid,
          'outstanding_balance': newRem,
          'payment_status': newStatus,
          'synced': 0,
        },
        where: 'id = ? AND company_id = ?',
        whereArgs: [pId, companyId],
      );

      final supplierId = p['supplier_id']?.toString();
      if (supplierId != null && supplierId.isNotEmpty) {
        await db.rawUpdate('''
          UPDATE suppliers 
          SET credit_balance = MAX(0.0, credit_balance - ?)
          WHERE id = ? AND company_id = ?
        ''', [paymentAmount, supplierId, companyId]);
      }

      await _loadPurchaseInvoices();
      if (mounted) {
        final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.get("payment_recorded_success")}: ${_formatCurrency(paymentAmount)}'),
            backgroundColor: ModiriColors.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  void _showPurchasePaymentDialog(Map<String, dynamic> purchase) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final pId = purchase['id'].toString();
    final invNum = purchase['invoice_number']?.toString() ?? 'P-INV';
    final supplier = (purchase['supplier_name'] ?? 'Fournisseur').toString();
    final total = (purchase['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (purchase['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = (purchase['outstanding_balance'] as num?)?.toDouble() ?? (total - paidAmount).clamp(0.0, double.infinity);

    final payCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(2) : total.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Text('${loc.get("record_supplier_payment")}: $invNum', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loc.get("supplier_label")}: $supplier', style: TextStyle(color: ModiriColors.textSecondary(isDark))),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModiriColors.card(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ModiriColors.border(isDark)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('invoice_total_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          Text(_formatCurrency(total), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('already_paid_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          Text(_formatCurrency(paidAmount), style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Divider(color: ModiriColors.border(isDark), height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('remaining_balance_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          Text(_formatCurrency(remaining), style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: payCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: loc.get('payment_amount_input'),
                    helperText: '${loc.get('invoice_max_payable_helper')} ${_formatCurrency(remaining)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
              onPressed: () async {
                final amt = double.tryParse(payCtrl.text.trim());
                if (amt == null || amt <= 0.001 || amt > remaining + 0.001) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${loc.get('invoice_invalid_amount_error')} (${_formatCurrency(remaining)})'),
                      backgroundColor: ModiriColors.brandRose,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await _applyPurchasePayment(pId, amt);
              },
              child: Text(loc.get('record_payment')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPurchaseInvoiceDetailsModal(Map<String, dynamic> purchase) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final pId = purchase['id']?.toString() ?? '';
    final invNum = purchase['invoice_number']?.toString() ?? 'P-INV';
    final supplierName = purchase['supplier_name']?.toString() ?? 'Fournisseur';
    final supplierPhone = purchase['supplier_phone']?.toString() ?? '';
    final rawDate = purchase['purchase_date'] ?? purchase['created_at'];
    final dateStr = rawDate != null ? rawDate.toString().replaceAll('T', ' ').substring(0, 10) : '—';
    final total = (purchase['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (purchase['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = (purchase['outstanding_balance'] as num?)?.toDouble() ?? (total - paidAmount).clamp(0.0, double.infinity);
    final statusStr = (purchase['payment_status'] ?? 'paid').toString().toLowerCase();
    final isFullyPaid = statusStr == 'paid' || remaining <= 0.001;

    List<Map<String, dynamic>> items = [];
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      items = await db.query(
        'supplier_purchase_items',
        where: 'purchase_id = ?',
        whereArgs: [pId],
      );
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: ModiriColors.brandAmber, size: 26),
                  const SizedBox(width: 10),
                  Text('${loc.get("supplier_invoice_number")} $invNum', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: ModiriColors.textMuted(isDark)),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModiriColors.card(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('supplier_label'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(supplierName, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
                            if (supplierPhone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(supplierPhone, style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                            ],
                            const SizedBox(height: 2),
                            Text('${loc.get('purchase_date_label')}: $dateStr', style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(loc.get('payment_status_header'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isFullyPaid ? ModiriColors.brandTeal : ModiriColors.brandAmber).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: (isFullyPaid ? ModiriColors.brandTeal : ModiriColors.brandAmber).withOpacity(0.3)),
                              ),
                              child: Text(
                                isFullyPaid ? loc.get('paid') : (paidAmount > 0 ? loc.get('partial') : loc.get('unpaid')),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isFullyPaid ? ModiriColors.brandTeal : ModiriColors.brandAmber),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(loc.get('purchase_items_label'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: ModiriColors.border(isDark)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: ModiriColors.tableHeader(isDark),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(loc.get('item_description'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                              SizedBox(width: 40, child: Text(loc.get('quantity_header'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                              SizedBox(width: 80, child: Text(loc.get('price_header'), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                              SizedBox(width: 90, child: Text(loc.get('total_header'), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                            ],
                          ),
                        ),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(loc.get('no_records_found'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12)),
                          )
                        else
                          ...items.map((it) {
                            final iName = it['product_name'] ?? loc.get('product_item');
                            final iQty = (it['quantity'] as num?)?.toInt() ?? 1;
                            final iCost = (it['unit_cost'] as num?)?.toDouble() ?? 0.0;
                            final iTotal = (it['line_total'] as num?)?.toDouble() ?? (iQty * iCost);

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text(iName.toString(), style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.w500))),
                                  SizedBox(width: 40, child: Text('$iQty', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark)))),
                                  SizedBox(width: 80, child: Text(_formatCurrency(iCost), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark), fontFamily: 'monospace'))),
                                  SizedBox(width: 90, child: Text(_formatCurrency(iTotal), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.get('grand_total'), style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 16)),
                      Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w800, color: ModiriColors.brandAmber, fontSize: 22, fontFamily: 'monospace')),
                    ],
                  ),
                  if (!isFullyPaid) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.get('already_paid_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                        Text(_formatCurrency(paidAmount), style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.get('remaining_balance_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                        Text(_formatCurrency(remaining), style: const TextStyle(color: ModiriColors.brandRose, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: Text(loc.get('print_save_pdf')),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final company = ref.read(sessionProvider).companyName ?? 'Modiri Business';
                try {
                  await ReceiptPrinter.printReceipt(
                    companyName: '$company - Bon d\'Achat',
                    invoiceNumber: invNum.toString(),
                    date: DateTime.now(),
                    items: items.map((it) {
                      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                      final cost = (it['unit_cost'] as num?)?.toDouble() ?? 0.0;
                      final lTotal = (it['line_total'] as num?)?.toDouble() ?? (qty * cost);
                      return {
                        'name': (it['product_name'] ?? loc.get('product_item')).toString(),
                        'quantity': qty,
                        'price': cost,
                        'lineTotal': lTotal,
                      };
                    }).toList(),
                    total: total,
                    subtotal: total,
                    discount: 0.0,
                    paymentMethod: isFullyPaid ? loc.get('paid') : loc.get('partial'),
                    customerName: 'Fournisseur: $supplierName',
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('print_preview_error')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
            ),
            if (!isFullyPaid)
              ElevatedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text(loc.get('record_supplier_payment')),
                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandAmber),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showPurchasePaymentDialog(purchase);
                },
              ),
          ],
        );
      },
    );
  }

  void _showPaymentDialog(Map<String, dynamic> inv) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final id = inv['id'].toString();
    final invNum = inv['invoice_number'] ?? inv['invoiceNumber'] ?? 'INV-$id';
    final customer = (inv['customer_name'] ?? inv['customerName'] ?? 'Walk-in Customer').toString();
    final total = (inv['total'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (inv['remaining_amount'] as num?)?.toDouble() ?? (total - paidAmount).clamp(0.0, double.infinity);

    final payCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(2) : total.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Text('${loc.get("record_payment")}: $invNum', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loc.get("customer_label")}: $customer', style: TextStyle(color: ModiriColors.textSecondary(isDark))),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModiriColors.card(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ModiriColors.border(isDark)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('invoice_total_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          Text(_formatCurrency(total), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('already_paid_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          Text(_formatCurrency(paidAmount), style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Divider(color: ModiriColors.border(isDark), height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('remaining_balance_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          Text(_formatCurrency(remaining), style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: payCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: loc.get('payment_amount_input'),
                    helperText: '${loc.get('invoice_max_payable_helper')} ${_formatCurrency(remaining)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
              onPressed: () async {
                final amt = double.tryParse(payCtrl.text.trim());
                if (amt == null || amt <= 0.001 || amt > remaining + 0.001) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${loc.get('invoice_invalid_amount_error')} (${_formatCurrency(remaining)})'),
                      backgroundColor: ModiriColors.brandRose,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                await _applyInvoicePayment(id, amt);
              },
              child: Text(loc.get('confirm_payment')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyInvoicePayment(String id, double paymentAmount) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final result = await PaymentTransactionManager.recordInvoicePayment(
        db: db,
        companyId: companyId,
        invoiceId: id,
        paymentAmount: paymentAmount,
      );

      ref.read(desktopSyncServiceProvider.notifier).refreshQueueCounts();
      unawaited(ref.read(desktopSyncServiceProvider.notifier).syncPending());

      if (result.newStatus == 'paid') {
        try {
          final client = ref.read(apiClientProvider);
          await client.put('/invoices/$id/mark-paid');
        } catch (_) {}
      }

      await _loadInvoices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.duplicateIgnored
                  ? (result.message ?? 'Duplicate payment replay safely ignored.')
                  : result.newStatus == 'paid'
                      ? loc.get('invoice_settled_success')
                      : '${loc.get('invoice_payment_recorded_success')} (${_formatCurrency(paymentAmount)}, ${loc.get('remaining_debt_to_pay')}: ${_formatCurrency(result.newRemaining)})',
            ),
            backgroundColor: ModiriColors.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.get('invoice_failed_save')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }
  void _showCreateInvoiceModal() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final formKey = GlobalKey<FormState>();
    String selectedCustomer = _customerNames.first;
    final descriptionCtrl = TextEditingController(text: loc.get('goods_purchased'));
    final totalCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');
    String status = 'unpaid'; // 'unpaid', 'partial', 'paid'
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: ModiriColors.surface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ModiriColors.border(isDark)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.note_add_outlined, color: ModiriColors.brandBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(loc.get('create_manual_invoice'),
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ModiriColors.brandBlue.withOpacity(0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: ModiriColors.brandBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.get('manual_invoice_local_notice'),
                                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          value: selectedCustomer,
                          dropdownColor: ModiriColors.card(isDark),
                          decoration: InputDecoration(labelText: '${loc.get("customer_label")} *', prefixIcon: const Icon(Icons.person_outline, size: 18)),
                          items: _customerNames.map((c) => DropdownMenuItem(value: c, child: Text(c == 'Walk-in Customer' ? loc.get('walk_in_customer') : c))).toList(),
                          onChanged: (v) => setDialogState(() => selectedCustomer = v ?? 'Walk-in Customer'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descriptionCtrl,
                          decoration: InputDecoration(labelText: loc.get('item_description_input'), prefixIcon: const Icon(Icons.description_outlined, size: 18)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? loc.get('invoice_desc_required_error') : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: totalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: '${loc.get("total_amount")} (${loc.get("currency_symbol")}) *', prefixIcon: const Icon(Icons.attach_money, size: 18)),
                          validator: (v) {
                            final val = double.tryParse(v?.trim() ?? '');
                            if (val == null || val <= 0) return loc.get('invoice_valid_amount_error');
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          dropdownColor: ModiriColors.card(isDark),
                          decoration: InputDecoration(labelText: loc.get('initial_payment_status'), prefixIcon: const Icon(Icons.payments_outlined, size: 18)),
                          items: [
                            DropdownMenuItem(value: 'unpaid', child: Text(loc.get('unpaid_full_debt'))),
                            DropdownMenuItem(value: 'partial', child: Text(loc.get('order_partially_paid'))),
                            DropdownMenuItem(value: 'paid', child: Text(loc.get('order_paid_full'))),
                          ],
                          onChanged: (v) {
                            setDialogState(() {
                              status = v ?? 'unpaid';
                              if (status == 'paid') {
                                paidCtrl.text = totalCtrl.text;
                              } else if (status == 'unpaid') {
                                paidCtrl.text = '0';
                              }
                            });
                          },
                        ),
                        if (status == 'partial') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: paidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: loc.get('amount_paid'), prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 18)),
                            validator: (v) {
                              final p = double.tryParse(v?.trim() ?? '');
                              final t = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
                              if (p == null || p < 0 || p >= t) return loc.get('invoice_partial_range_error');
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${loc.get("due_date_label")}: ${DateFormat('yyyy-MM-dd').format(dueDate)}',
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today, size: 18, color: ModiriColors.brandBlue),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: dialogCtx,
                                initialDate: dueDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setDialogState(() => dueDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final total = double.parse(totalCtrl.text.trim());
                    final paid = status == 'paid'
                        ? total
                        : status == 'unpaid'
                            ? 0.0
                            : (double.tryParse(paidCtrl.text.trim()) ?? 0.0);
                    final remaining = (total - paid).clamp(0.0, total);
                    final nowIso = DateTime.now().toIso8601String();
                    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                    final invId = const Uuid().v4();
                    final desc = descriptionCtrl.text.trim();

                    try {
                      final db = await ModiriDesktopDatabase.instance.database;

                      await db.transaction((txn) async {
                        // Monotonic seq number
                        final maxRes = await txn.rawQuery(
                          "SELECT COALESCE(MAX(CAST(SUBSTR(invoice_number, 5) AS INTEGER)), 1000) AS max_seq FROM invoices WHERE company_id = ? AND invoice_number LIKE 'INV-%'",
                          [companyId],
                        );
                        final nextSeq = ((maxRes.first['max_seq'] as num?)?.toInt() ?? 1000) + 1;
                        final invNum = 'INV-$nextSeq';

                        String? customerId;
                        if (selectedCustomer != 'Walk-in Customer') {
                          final custRows = await txn.query(
                            'customers',
                            where: 'name = ? AND company_id = ?',
                            whereArgs: [selectedCustomer, companyId],
                          );
                          if (custRows.isNotEmpty) {
                            customerId = custRows.first['id']?.toString();
                          }
                        }

                        // Insert invoice
                        await txn.insert('invoices', {
                          'id': invId,
                          'company_id': companyId,
                          'customer_id': customerId,
                          'invoice_number': invNum,
                          'customer_name': selectedCustomer,
                          'total': total,
                          'paid_amount': paid,
                          'remaining_amount': remaining,
                          'status': status,
                          'due_date': dueDate.toIso8601String(),
                          'notes': desc,
                          'sold_at': nowIso,
                          'created_at': nowIso,
                        });

                        // If customer has credit debt
                        if (remaining > 0 && customerId != null) {
                          final custRows = await txn.query('customers', where: 'id = ?', whereArgs: [customerId]);
                          if (custRows.isNotEmpty) {
                            final oldBal = (custRows.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
                            final newBal = oldBal + remaining;
                            await txn.update('customers', {'credit_balance': newBal}, where: 'id = ?', whereArgs: [customerId]);
                            await txn.insert('customer_transactions', {
                              'id': const Uuid().v4(),
                              'company_id': companyId,
                              'customer_id': customerId,
                              'type': 'purchase',
                              'amount': remaining,
                              'balance_after': newBal,
                              'description': 'Manual Invoice $invNum: $desc',
                              'created_at': nowIso,
                            });
                          }
                        }

                        // Standalone manual billing invoice is saved authoritatively in local SQLite.
                      });

                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                      ref.read(desktopSyncServiceProvider.notifier).refreshQueueCounts();
                      unawaited(ref.read(desktopSyncServiceProvider.notifier).syncPending());

                      await _loadInvoices();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.get('invoice_created_success')), backgroundColor: ModiriColors.brandTeal),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${loc.get('create_invoice_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                        );
                      }
                    }
                  },
                  child: Text(loc.get('create_invoice')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showInvoiceDetailsModal(dynamic inv) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final invId = inv['id']?.toString() ?? '';
    final saleId = inv['sale_id']?.toString() ?? inv['saleId']?.toString() ?? '';
    final invNum = inv['invoice_number'] ?? inv['invoiceNumber'] ?? 'INV-${invId.padLeft(6, '0')}';
    final customer = inv['customer_name'] ?? inv['customerName'] ?? 'Walk-in Customer';
    final rawDate = inv['created_at'] ?? inv['createdAt'];
    final dateStr = rawDate != null ? rawDate.toString().replaceAll('T', ' ').substring(0, 16) : loc.get('recent');
    final rawStatus = (inv['status'] ?? 'paid').toString().toLowerCase();
    final isPaid = rawStatus == 'paid';
    final isPartial = rawStatus == 'partial';
    final total = (inv['total'] ?? inv['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (inv['paid_amount'] as num?)?.toDouble() ?? (isPaid ? total : 0.0);
    final remainingAmount = (inv['remaining_amount'] as num?)?.toDouble() ?? (total - paidAmount).clamp(0.0, double.infinity);

    List<dynamic> items = (inv['items'] as List?) ?? [];
    if (items.isEmpty) {
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        if (saleId.isNotEmpty) {
          final rows = await db.query(
            'sale_items',
            where: 'sale_id = ? AND company_id = ?',
            whereArgs: [saleId, companyId],
          );
          if (rows.isNotEmpty) {
            items = rows;
          }
        }
        if (items.isEmpty) {
          final saleRows = await db.query(
            'sales',
            where: 'invoice_number = ? AND company_id = ?',
            whereArgs: [invNum, companyId],
          );
          if (saleRows.isNotEmpty) {
            final resolvedSaleId = saleRows.first['id']?.toString() ?? '';
            final rows = await db.query(
              'sale_items',
              where: 'sale_id = ? AND company_id = ?',
              whereArgs: [resolvedSaleId, companyId],
            );
            if (rows.isNotEmpty) items = rows;
          }
        }
      } catch (_) {}
    }

    if (items.isEmpty && invId.isNotEmpty) {
      try {
        final res = await ref.read(apiClientProvider).get('/invoices/$invId');
        final data = res is Map ? (res['data'] ?? res) : null;
        if (data is Map && data['items'] is List && (data['items'] as List).isNotEmpty) {
          items = data['items'] as List;
        }
      } catch (_) {}
    }

    if (items.isEmpty) {
      items = [
        {'name': '${loc.get("invoice")} #$invNum', 'quantity': 1, 'unit_price': total, 'total': total}
      ];
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final statusColor = isPaid
            ? ModiriColors.brandTeal
            : isPartial
                ? ModiriColors.brandAmber
                : ModiriColors.brandRose;
        final statusLabel = isPaid ? loc.get('paid') : (isPartial ? loc.get('partial') : loc.get('unpaid'));

        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/images/logo.png', width: 28, height: 28, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.receipt, color: ModiriColors.brandBlue)),
                  ),
                  const SizedBox(width: 10),
                  Text('${loc.get("invoice")} #$invNum', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: ModiriColors.textMuted(isDark)),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModiriColors.card(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('billed_to'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(customer == 'Walk-in Customer' ? loc.get('walk_in_customer') : customer, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(dateStr, style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(loc.get('payment_status_header'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(statusLabel,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(loc.get('invoice_items_header'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: ModiriColors.border(isDark)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: ModiriColors.tableHeader(isDark),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(loc.get('item_description'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                              SizedBox(width: 40, child: Text(loc.get('quantity_header'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                              SizedBox(width: 80, child: Text(loc.get('price_header'), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                              SizedBox(width: 90, child: Text(loc.get('total_header'), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark)))),
                            ],
                          ),
                        ),
                        ...items.map((it) {
                          final iName = it['name'] ?? it['product_name'] ?? loc.get('product_item');
                          final iQty = (it['quantity'] as num?)?.toInt() ?? 1;
                          final iPrice = (it['unit_price'] ?? it['price'] as num?)?.toDouble() ?? 0.0;
                          final iTotal = (it['total'] ?? it['line_total'] as num?)?.toDouble() ?? (iQty * iPrice);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(child: Text(iName.toString(), style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.w500))),
                                SizedBox(width: 40, child: Text('$iQty', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark)))),
                                SizedBox(width: 80, child: Text(_formatCurrency(iPrice), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark), fontFamily: 'monospace'))),
                                SizedBox(width: 90, child: Text(_formatCurrency(iTotal), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.get('grand_total'), style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 16)),
                      Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w800, color: ModiriColors.brandTeal, fontSize: 22, fontFamily: 'monospace')),
                    ],
                  ),
                  if (!isPaid) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.get('paid_amount_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                        Text(_formatCurrency(paidAmount), style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.get('remaining_due_label'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                        Text(_formatCurrency(remainingAmount), style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: Text(loc.get('print_save_pdf')),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final company = ref.read(sessionProvider).companyName ?? 'Modiri Business';
                try {
                  await ReceiptPrinter.printReceipt(
                    companyName: company,
                    invoiceNumber: invNum.toString(),
                    date: DateTime.now(),
                    items: items.map((it) {
                      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                      final price = (it['unit_price'] ?? it['price'] as num?)?.toDouble() ?? total;
                      final lTotal = (it['total'] ?? it['line_total'] as num?)?.toDouble() ?? (qty * price);
                      return {
                        'name': (it['name'] ?? it['product_name'] ?? loc.get('product_item')).toString(),
                        'quantity': qty,
                        'price': price,
                        'lineTotal': lTotal,
                      };
                    }).toList(),
                    total: total,
                    subtotal: total,
                    discount: 0.0,
                    paymentMethod: statusLabel,
                    customerName: customer.toString(),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('print_preview_error')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
            ),
            if (!isPaid)
              ElevatedButton.icon(
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text(loc.get('record_payment')),
                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandAmber),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showPaymentDialog(Map<String, dynamic>.from(inv));
                },
              ),
            if (!isPaid)
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: Text(loc.get('mark_as_paid')),
                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _markPaid(inv['id'].toString());
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: ModiriColors.brandBlue, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        loc.get('invoices_title'),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('invoices_subtitle'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: ModiriColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicator: BoxDecoration(
                        color: ModiriColors.brandBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: ModiriColors.textSecondary(isDark),
                      tabs: [
                        Tab(icon: const Icon(Icons.arrow_upward, size: 15), text: loc.get('tab_sales_invoices')),
                        Tab(icon: const Icon(Icons.arrow_downward, size: 15), text: loc.get('tab_purchase_invoices')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.document_scanner_outlined, size: 16, color: ModiriColors.brandBlue),
                    label: Text(loc.get('ai_scanner')),
                    onPressed: () {
                      final scanMode = _tabController.index == 1 ? InvoiceScanMode.purchase : InvoiceScanMode.sales;
                      showDialog(
                        context: context,
                        builder: (sCtx) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Scaffold(
                              appBar: AppBar(
                                title: Text(loc.get('ai_scanner_title')),
                                leading: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(sCtx).pop(),
                                ),
                              ),
                              body: DesktopAiInvoiceScannerScreen(initialMode: scanMode),
                            ),
                          ),
                        ),
                      ).then((_) => _refreshAll());
                    },
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _refreshAll,
                  ),
                  if (_tabController.index == 0) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(loc.get('create_invoice')),
                      style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                      onPressed: _showCreateInvoiceModal,
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Filters & Search Row
          Row(
            children: [
              Wrap(
                spacing: 8,
                children: ['ALL', 'PAID', 'PARTIAL', 'UNPAID'].map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  final labelText = status == 'ALL'
                      ? loc.get('all')
                      : status == 'PAID'
                          ? loc.get('paid')
                          : status == 'PARTIAL'
                              ? loc.get('partial')
                              : loc.get('unpaid');
                  return ChoiceChip(
                    label: Text(labelText),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatusFilter = status);
                    },
                    selectedColor: ModiriColors.brandBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : ModiriColors.textPrimary(isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: loc.get('search_invoices_hint'),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModiriColors.brandRose.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: ModiriColors.brandRose, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: ModiriColors.brandRose, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: ModiriColors.brandBlue))
                : _tabController.index == 0
                    ? _buildSalesInvoicesTable(isDark, loc)
                    : _buildPurchaseInvoicesTable(isDark, loc),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesInvoicesTable(bool isDark, ModiriLocalizations loc) {
    final displayedInvoices = _invoices.where((inv) {
      final status = (inv['status'] ?? 'paid').toString().toUpperCase();
      if (_selectedStatusFilter != 'ALL' && status != _selectedStatusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final invNum = (inv['invoice_number'] ?? inv['invoiceNumber'] ?? '').toString().toLowerCase();
        final cust = (inv['customer_name'] ?? inv['customerName'] ?? '').toString().toLowerCase();
        if (!invNum.contains(_searchQuery) && !cust.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();

    if (displayedInvoices.isEmpty) {
      return Center(
        child: ModiriPanel(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt, color: ModiriColors.brandBlue, size: 48),
              const SizedBox(height: 12),
              Text(loc.get('no_invoices_found'),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(loc.get('no_invoices_found_desc'),
                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ModiriPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(ModiriColors.tableHeader(isDark)),
            columns: [
              DataColumn(label: Text(loc.get('invoice_number_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('customer_label'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('date_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('total'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('status_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('action'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: displayedInvoices.map((inv) {
              final id = inv['id'] ?? '1';
              final invNum = inv['invoice_number'] ?? inv['invoiceNumber'] ?? 'INV-${id.toString().padLeft(6, '0')}';
              final customer = inv['customer_name'] ?? inv['customerName'] ?? 'Walk-in Customer';
              final rawDate = inv['created_at'] ?? inv['createdAt'];
              final dateStr = rawDate != null ? rawDate.toString().replaceAll('T', ' ').substring(0, 10) : '—';
              final total = (inv['total'] ?? inv['total_amount'] as num?)?.toDouble() ?? 0.0;

              return DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () => _showInvoiceDetailsModal(inv),
                      child: Row(
                        children: [
                          Text(invNum, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontFamily: 'monospace')),
                          if (inv['sale_id'] == null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: ModiriColors.brandBlue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: ModiriColors.brandBlue.withOpacity(0.25)),
                              ),
                              child: Text(
                                loc.get('local_billing_badge'),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ModiriColors.brandBlue),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  DataCell(Text(customer == 'Walk-in Customer' ? loc.get('walk_in_customer') : customer, style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
                  DataCell(Text(dateStr, style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12))),
                  DataCell(Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandTeal, fontFamily: 'monospace'))),
                  DataCell(
                    Builder(
                      builder: (context) {
                        final statusStr = (inv['status'] ?? 'paid').toString().toLowerCase();
                        final isFullyPaid = statusStr == 'paid';
                        final isPartial = statusStr == 'partial';
                        final remaining = (inv['remaining_amount'] as num?)?.toDouble() ?? (total - ((inv['paid_amount'] as num?)?.toDouble() ?? 0.0));

                        final badgeColor = isFullyPaid
                            ? ModiriColors.brandTeal
                            : isPartial
                                ? ModiriColors.brandBlue
                                : ModiriColors.brandAmber;

                        final badgeText = isFullyPaid
                            ? loc.get('paid')
                            : isPartial
                                ? '${loc.get('partial')}: ${_formatCurrency(remaining)}'
                                : loc.get('unpaid');

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: badgeColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  DataCell(
                    Builder(
                      builder: (context) {
                        final statusStr = (inv['status'] ?? 'paid').toString().toLowerCase();
                        final isFullyPaid = statusStr == 'paid';

                        return Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              color: ModiriColors.brandBlue,
                              tooltip: loc.get('view_invoice'),
                              onPressed: () => _showInvoiceDetailsModal(inv),
                            ),
                            if (!isFullyPaid) ...[
                              IconButton(
                                icon: const Icon(Icons.payments_outlined, size: 18),
                                color: ModiriColors.brandTeal,
                                tooltip: loc.get('record_payment_tooltip'),
                                onPressed: () => _showPaymentDialog(inv),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                color: ModiriColors.brandTeal,
                                tooltip: loc.get('quick_pay_tooltip'),
                                onPressed: () => _markPaid(id.toString()),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseInvoicesTable(bool isDark, ModiriLocalizations loc) {
    final displayedPurchases = _purchaseInvoices.where((p) {
      final status = (p['payment_status'] ?? 'PAID').toString().toUpperCase();
      if (_selectedStatusFilter != 'ALL') {
        if (_selectedStatusFilter == 'PAID' && status != 'PAID') return false;
        if (_selectedStatusFilter == 'PARTIAL' && status != 'PARTIAL') return false;
        if (_selectedStatusFilter == 'UNPAID' && status != 'UNPAID') return false;
      }
      if (_searchQuery.isNotEmpty) {
        final invNum = (p['invoice_number'] ?? '').toString().toLowerCase();
        final sup = (p['supplier_name'] ?? '').toString().toLowerCase();
        if (!invNum.contains(_searchQuery) && !sup.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();

    if (displayedPurchases.isEmpty) {
      return Center(
        child: ModiriPanel(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_bag_outlined, color: ModiriColors.brandAmber, size: 48),
              const SizedBox(height: 12),
              Text(loc.get('no_purchase_invoices_found'),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(loc.get('no_purchase_invoices_found_desc'),
                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ModiriPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(ModiriColors.tableHeader(isDark)),
            columns: [
              DataColumn(label: Text(loc.get('supplier_invoice_number'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('supplier_label'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('date_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('total'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('status_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(loc.get('action'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: displayedPurchases.map((p) {
              final invNum = p['invoice_number']?.toString() ?? 'P-INV';
              final supplierName = p['supplier_name']?.toString() ?? 'Fournisseur';
              final rawDate = p['purchase_date'] ?? p['created_at'];
              final dateStr = rawDate != null ? rawDate.toString().replaceAll('T', ' ').substring(0, 10) : '—';
              final total = (p['total_amount'] as num?)?.toDouble() ?? 0.0;
              final paidAmount = (p['amount_paid'] as num?)?.toDouble() ?? 0.0;
              final remaining = (p['outstanding_balance'] as num?)?.toDouble() ?? (total - paidAmount).clamp(0.0, double.infinity);
              final statusStr = (p['payment_status'] ?? 'paid').toString().toLowerCase();
              final isFullyPaid = statusStr == 'paid' || remaining <= 0.001;

              final badgeColor = isFullyPaid
                  ? ModiriColors.brandTeal
                  : (paidAmount > 0 ? ModiriColors.brandBlue : ModiriColors.brandRose);
              final badgeText = isFullyPaid
                  ? loc.get('paid')
                  : (paidAmount > 0 ? '${loc.get('partial')}: ${_formatCurrency(remaining)}' : loc.get('unpaid'));

              return DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () => _showPurchaseInvoiceDetailsModal(p),
                      child: Text(invNum, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandAmber, fontFamily: 'monospace')),
                    ),
                  ),
                  DataCell(Text(supplierName, style: TextStyle(color: ModiriColors.textSecondary(isDark), fontWeight: FontWeight.w500))),
                  DataCell(Text(dateStr, style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12))),
                  DataCell(Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandAmber, fontFamily: 'monospace'))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          color: ModiriColors.brandBlue,
                          tooltip: loc.get('view_purchase_invoice'),
                          onPressed: () => _showPurchaseInvoiceDetailsModal(p),
                        ),
                        if (!isFullyPaid) ...[
                          IconButton(
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            color: ModiriColors.brandAmber,
                            tooltip: loc.get('record_supplier_payment'),
                            onPressed: () => _showPurchasePaymentDialog(p),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
