import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/database/payment_transaction_manager.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopCreditScreen extends ConsumerStatefulWidget {
  const DesktopCreditScreen({super.key});

  @override
  ConsumerState<DesktopCreditScreen> createState() => _DesktopCreditScreenState();
}

class _DesktopCreditScreenState extends ConsumerState<DesktopCreditScreen> {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  bool _isLoading = true;
  List<Map<String, dynamic>> _debtors = [];
  double _totalCreditExtended = 0.0;
  double _totalPaid = 0.0;
  double _totalOutstanding = 0.0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCreditData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCreditData() async {
    setState(() {
      _isLoading = true;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    try {
      final db = await ModiriDesktopDatabase.instance.database;

      // Fetch customers with credit balance > 0
      var rows = await db.query(
        'customers',
        where: 'company_id = ? AND credit_balance > 0',
        whereArgs: [companyId],
        orderBy: 'credit_balance DESC',
      );
      if (rows.isEmpty) {
        rows = await db.query(
          'customers',
          where: 'credit_balance > 0',
          orderBy: 'credit_balance DESC',
        );
      }

      // Fetch all customer transactions for metrics
      var txRows = await db.query(
        'customer_transactions',
        where: 'company_id = ?',
        whereArgs: [companyId],
      );
      if (txRows.isEmpty) {
        txRows = await db.query('customer_transactions');
      }

      double ext = 0.0;
      double paid = 0.0;
      for (final tx in txRows) {
        final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        if (tx['type'] == 'purchase') {
          ext += amt;
        } else if (tx['type'] == 'payment') {
          paid += amt;
        }
      }

      double out = 0.0;
      for (final r in rows) {
        out += (r['credit_balance'] as num?)?.toDouble() ?? 0.0;
      }

      // If no transactions logged yet, base metrics on customer balances
      if (ext == 0.0 && out > 0) {
        ext = out;
      }

      if (mounted) {
        setState(() {
          _debtors = List<Map<String, dynamic>>.from(rows);
          _totalCreditExtended = ext;
          _totalPaid = paid;
          _totalOutstanding = out;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showRepaymentDialog(Map<String, dynamic> debtor) {
    final customerId = debtor['id']?.toString() ?? '';
    final name = debtor['name']?.toString() ?? 'Customer';
    final currentBalance = ((debtor['credit_balance'] ?? 0.0) as num).toDouble();
    final payCtrl = TextEditingController();
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));

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
          title: Text('${loc.get('settle_debt')}: $name', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModiriColors.brandAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.get('total_debt_outstanding'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                      Text(_formatCurrency(currentBalance), style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: payCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark)),
                  decoration: InputDecoration(
                    labelText: loc.get('payment_amount'),
                    helperText: 'Max payable: ${_formatCurrency(currentBalance)}',
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
                final paid = double.tryParse(payCtrl.text.trim());
                if (paid == null || paid <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.get('payment_greater_zero_error')),
                      backgroundColor: ModiriColors.brandRose,
                    ),
                  );
                  return;
                }
                if (paid > currentBalance + 0.001) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${loc.get('payment_exceed_debt_error')} ${_formatCurrency(currentBalance)}'),
                      backgroundColor: ModiriColors.brandRose,
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop();

                final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

                try {
                  final db = await ModiriDesktopDatabase.instance.database;
                  final result = await PaymentTransactionManager.recordCreditRepayment(
                    db: db,
                    companyId: companyId,
                    customerId: customerId,
                    paymentAmount: paid,
                  );

                  ref.read(desktopSyncServiceProvider.notifier).refreshQueueCounts();
                  unawaited(ref.read(desktopSyncServiceProvider.notifier).syncPending());

                  await _loadCreditData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.duplicateIgnored
                              ? (result.message ?? loc.get('duplicate_repayment_ignored'))
                              : '${loc.get('repayment_recorded_for')} ${_formatCurrency(paid)} ($name) - ${loc.get('remaining_debt_is')} ${_formatCurrency(result.newCustomerDebt ?? 0.0)}',
                        ),
                        backgroundColor: ModiriColors.brandTeal,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('payment_failed_prefix')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(loc.get('confirm_payment')),
            ),
          ],
        );
      },
    );
  }

  void _showCustomerDebtProfileDialog(Map<String, dynamic> debtor, {int initialTab = 0}) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final customerId = debtor['id']?.toString() ?? '';
    final name = debtor['name']?.toString() ?? 'Customer';
    final phone = debtor['phone']?.toString() ?? loc.get('no_phone_listed');
    final notes = debtor['notes']?.toString() ?? '';
    final createdAt = debtor['created_at']?.toString() ?? '';
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    final db = await ModiriDesktopDatabase.instance.database;

    // Load customer credit transactions
    List<Map<String, dynamic>> transactions = await db.query(
      'customer_transactions',
      where: 'customer_id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      orderBy: 'created_at DESC',
    );
    if (transactions.isEmpty) {
      transactions = await db.query(
        'customer_transactions',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC',
      );
    }

    if (transactions.isEmpty && customerId.isNotEmpty) {
      try {
        final res = await ref.read(apiClientProvider).get('/credit/customers/$customerId/history');
        final data = res is Map ? (res['data'] ?? res) : null;
        final serverTx = data is Map ? (data['transactions'] as List? ?? []) : (res is List ? res : []);
        if (serverTx.isNotEmpty) {
          transactions = serverTx.map((t) {
            final m = Map<String, dynamic>.from(t as Map);
            return {
              'id': m['id']?.toString() ?? const Uuid().v4(),
              'type': (m['type'] ?? 'purchase').toString().toLowerCase(),
              'amount': ((m['amount'] ?? m['totalAmount'] ?? 0.0) as num).toDouble(),
              'balance_after': ((m['balance_after'] ?? m['balanceAfter'] ?? 0.0) as num).toDouble(),
              'description': m['description'] ?? m['note'] ?? '',
              'created_at': m['created_at'] ?? m['createdAt'] ?? DateTime.now().toIso8601String(),
            };
          }).toList();
        }
      } catch (_) {}
    }

    // Load customer invoices
    List<Map<String, dynamic>> invoices = await db.query(
      'invoices',
      where: 'company_id = ? AND (customer_name = ? OR customer_name LIKE ?)',
      whereArgs: [companyId, name, '%$name%'],
      orderBy: 'created_at DESC',
    );
    if (invoices.isEmpty) {
      invoices = await db.query(
        'invoices',
        where: 'customer_name = ? OR customer_name LIKE ?',
        whereArgs: [name, '%$name%'],
        orderBy: 'created_at DESC',
      );
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        double currentBalance = ((debtor['credit_balance'] ?? 0.0) as num).toDouble();

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final double totalInvoiced = invoices.fold<double>(
              0.0,
              (sum, inv) => sum + (((inv['total'] ?? 0.0) as num).toDouble()),
            );
            final double totalSettled = transactions
                .where((t) => t['type'] == 'payment')
                .fold<double>(0.0, (sum, t) => sum + (((t['amount'] ?? 0.0) as num).toDouble()));

            return DefaultTabController(
              length: 3,
              initialIndex: initialTab,
              child: AlertDialog(
                backgroundColor: ModiriColors.surface(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: ModiriColors.border(isDark)),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: ModiriColors.brandAmber.withOpacity(0.15),
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                            style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: ModiriColors.textPrimary(isDark),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: currentBalance > 0
                                        ? ModiriColors.brandAmber.withOpacity(0.12)
                                        : ModiriColors.brandTeal.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    currentBalance > 0 ? loc.get('credit') : loc.get('active'),
                                    style: TextStyle(
                                      color: currentBalance > 0 ? ModiriColors.brandAmber : ModiriColors.brandTeal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ModiriFormatters.toLatinDigits(phone),
                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (currentBalance > 0)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ModiriColors.brandTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.payments_outlined, size: 16),
                            label: Text(loc.get('record_repayment'), style: const TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final payCtrl = TextEditingController();
                              final paid = await showDialog<double>(
                                context: dialogCtx,
                                builder: (pCtx) {
                                  final pDark = Theme.of(pCtx).brightness == Brightness.dark;
                                  return AlertDialog(
                                    backgroundColor: ModiriColors.surface(pDark),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: ModiriColors.border(pDark)),
                                    ),
                                    title: Text(loc.get('record_debt_payment'),
                                        style: TextStyle(color: ModiriColors.textPrimary(pDark), fontWeight: FontWeight.bold)),
                                    content: TextField(
                                      controller: payCtrl,
                                      autofocus: true,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(color: ModiriColors.textPrimary(pDark)),
                                      decoration: InputDecoration(
                                        labelText: loc.get('payment_amount_optional'),
                                        helperText: '${loc.get('total_debt_outstanding')} ${_formatCurrency(currentBalance)}',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(pCtx).pop(),
                                        child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(pDark))),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final val = double.tryParse(payCtrl.text.trim());
                                          if (val != null && val > 0 && val <= currentBalance + 0.001) {
                                            Navigator.of(pCtx).pop(val);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${loc.get('valid_amount_up_to')} ${_formatCurrency(currentBalance)}'),
                                                backgroundColor: ModiriColors.brandRose,
                                              ),
                                            );
                                          }
                                        },
                                        child: Text(loc.get('confirm_payment')),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (paid != null && paid > 0) {
                                final result = await PaymentTransactionManager.recordCreditRepayment(
                                  db: db,
                                  companyId: companyId,
                                  customerId: customerId,
                                  paymentAmount: paid,
                                );

                                ref.read(desktopSyncServiceProvider.notifier).refreshQueueCounts();
                                unawaited(ref.read(desktopSyncServiceProvider.notifier).syncPending());

                                final updatedTx = await db.query(
                                  'customer_transactions',
                                  where: 'customer_id = ? AND company_id = ?',
                                  whereArgs: [customerId, companyId],
                                  orderBy: 'created_at DESC',
                                );

                                setDialogState(() {
                                  currentBalance = result.newCustomerDebt ?? (currentBalance - paid).clamp(0.0, double.infinity);
                                  transactions = updatedTx;
                                });

                                await _loadCreditData();
                              }
                            },
                          ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(Icons.close, color: ModiriColors.textMuted(isDark)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 820,
                  height: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Summary Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: currentBalance > 0
                                    ? ModiriColors.brandAmber.withOpacity(0.08)
                                    : ModiriColors.brandTeal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: currentBalance > 0
                                      ? ModiriColors.brandAmber.withOpacity(0.25)
                                      : ModiriColors.brandTeal.withOpacity(0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('balance_due'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrency(currentBalance),
                                    style: TextStyle(
                                      color: currentBalance > 0 ? ModiriColors.brandAmber : ModiriColors.brandTeal,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ModiriColors.brandBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ModiriColors.brandBlue.withOpacity(0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('lifetime_purchases'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrency(totalInvoiced),
                                    style: const TextStyle(
                                      color: ModiriColors.brandBlue,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ModiriColors.brandViolet.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ModiriColors.brandViolet.withOpacity(0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('invoices_count'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    ModiriFormatters.formatNumber(invoices.length),
                                    style: const TextStyle(
                                      color: ModiriColors.brandViolet,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ModiriColors.brandTeal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('total_settled'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrency(totalSettled),
                                    style: const TextStyle(
                                      color: ModiriColors.brandTeal,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tabs Navigation
                      Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: ModiriColors.border(isDark))),
                        ),
                        child: TabBar(
                          labelColor: ModiriColors.brandBlue,
                          unselectedLabelColor: ModiriColors.textSecondary(isDark),
                          indicatorColor: ModiriColors.brandBlue,
                          tabs: [
                            Tab(icon: const Icon(Icons.history_outlined, size: 16), text: loc.get('credit_history')),
                            Tab(icon: const Icon(Icons.receipt_long_outlined, size: 16), text: loc.get('invoices')),
                            Tab(icon: const Icon(Icons.badge_outlined, size: 16), text: loc.get('staff_details')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tabs Content
                      Expanded(
                        child: TabBarView(
                          children: [
                            // TAB 1: Credit Ledger & Transactions
                            transactions.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.history, size: 36, color: ModiriColors.textMuted(isDark)),
                                        const SizedBox(height: 8),
                                        Text(loc.get('no_credit_records'), style: TextStyle(color: ModiriColors.textMuted(isDark))),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: transactions.length,
                                    separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                                    itemBuilder: (tCtx, idx) {
                                      final t = transactions[idx];
                                      final isPayment = t['type'] == 'payment';
                                      final tAmt = (t['amount'] as num?)?.toDouble() ?? 0.0;
                                      final balAfter = (t['balance_after'] as num?)?.toDouble() ?? 0.0;
                                      final tDate = (t['created_at']?.toString() ?? '').split('T')[0];
                                      final desc = t['description']?.toString() ?? (isPayment ? loc.get('debt_settlement') : loc.get('credit_sale'));

                                      return ListTile(
                                        dense: true,
                                        leading: Icon(
                                          isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                          color: isPayment ? ModiriColors.brandTeal : ModiriColors.brandAmber,
                                          size: 18,
                                        ),
                                        title: Text(desc, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13, fontWeight: FontWeight.w600)),
                                        subtitle: Text('${ModiriFormatters.toLatinDigits(tDate)} • ${loc.get('balance_after')}: ${_formatCurrency(balAfter)}', style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                                        trailing: Text(
                                          '${isPayment ? "-" : "+"}${_formatCurrency(tAmt)}',
                                          style: TextStyle(
                                            color: isPayment ? ModiriColors.brandTeal : ModiriColors.brandAmber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                            // TAB 2: Invoices & Sales
                            invoices.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.receipt_outlined, size: 36, color: ModiriColors.textMuted(isDark)),
                                        const SizedBox(height: 8),
                                        Text(loc.get('no_invoices_found'), style: TextStyle(color: ModiriColors.textMuted(isDark))),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: invoices.length,
                                    separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                                    itemBuilder: (iCtx, idx) {
                                      final inv = invoices[idx];
                                      final invNum = inv['invoice_number'] ?? 'INV-${inv['id']}';
                                      final invTotal = (inv['total'] as num?)?.toDouble() ?? 0.0;
                                      final invStatus = (inv['status']?.toString() ?? 'paid').toLowerCase();
                                      final invDate = (inv['created_at']?.toString() ?? '').split('T')[0];

                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.receipt_long, color: ModiriColors.brandBlue, size: 18),
                                        title: Text(ModiriFormatters.toLatinDigits(invNum.toString()), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                        subtitle: Text(ModiriFormatters.toLatinDigits(invDate), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: invStatus == 'paid' ? ModiriColors.brandTeal.withOpacity(0.12) : ModiriColors.brandAmber.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                invStatus.toUpperCase(),
                                                style: TextStyle(
                                                  color: invStatus == 'paid' ? ModiriColors.brandTeal : ModiriColors.brandAmber,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _formatCurrency(invTotal),
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),

                            // TAB 3: Customer Information
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ModiriColors.border(isDark)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('customer_profile'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 16),
                                  _ProfileInfoRow(label: loc.get('name'), value: name, isDark: isDark),
                                  const SizedBox(height: 10),
                                  _ProfileInfoRow(label: loc.get('phone'), value: ModiriFormatters.toLatinDigits(phone), isDark: isDark),
                                  const SizedBox(height: 10),
                                  _ProfileInfoRow(label: loc.get('notes'), value: notes.isNotEmpty ? notes : loc.get('no_address_provided'), isDark: isDark),
                                  const SizedBox(height: 10),
                                  _ProfileInfoRow(label: loc.get('date_registered'), value: ModiriFormatters.toLatinDigits(createdAt.isNotEmpty ? createdAt.split('T')[0] : '—'), isDark: isDark),
                                  const SizedBox(height: 10),
                                  _ProfileInfoRow(label: loc.get('id'), value: ModiriFormatters.toLatinDigits(customerId), isDark: isDark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(loc.get('close')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showNewCreditSaleDialog() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final db = await ModiriDesktopDatabase.instance.database;
    final allCustomers = await db.query(
      'customers',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'name ASC',
    );
    if (!mounted) return;

    if (allCustomers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('no_customers_found')),
          backgroundColor: ModiriColors.brandAmber,
        ),
      );
      return;
    }

    String selectedCustomerId = allCustomers.first['id'].toString();
    final itemCtrl = TextEditingController(text: 'Credit Sale Order');
    final amountCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Text(loc.get('new_credit_sale'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCustomerId,
                    dropdownColor: ModiriColors.card(isDark),
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: loc.get('select_customer'), prefixIcon: const Icon(Icons.person)),
                    items: allCustomers
                        .map((c) => DropdownMenuItem(
                              value: c['id'].toString(),
                              child: Text('${c['name']} (Due: ${_formatCurrency(((c['credit_balance'] ?? 0.0) as num).toDouble())})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedCustomerId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: itemCtrl,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: loc.get('item_description'), prefixIcon: const Icon(Icons.description_outlined)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                          decoration: InputDecoration(labelText: loc.get('total')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: paidCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                          decoration: InputDecoration(labelText: loc.get('already_paid_label')),
                        ),
                      ),
                    ],
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
                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandAmber),
                onPressed: () async {
                  final totalAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  final paidAmt = (double.tryParse(paidCtrl.text.trim()) ?? 0.0).clamp(0.0, totalAmt);
                  final desc = itemCtrl.text.trim().isEmpty ? 'Credit Purchase' : itemCtrl.text.trim();
                  if (totalAmt <= 0 || totalAmt <= paidAmt) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.get('total_greater_downpayment')), backgroundColor: ModiriColors.brandRose),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();

                  final addedDebt = totalAmt - paidAmt;
                  final custRow = allCustomers.firstWhere((c) => c['id'].toString() == selectedCustomerId);
                  final custName = custRow['name']?.toString() ?? 'Customer';
                  final oldBal = ((custRow['credit_balance'] ?? 0.0) as num).toDouble();
                  final newBal = oldBal + addedDebt;
                  final nowIso = DateTime.now().toIso8601String();

                  await db.update(
                    'customers',
                    {'credit_balance': newBal},
                    where: 'id = ? AND company_id = ?',
                    whereArgs: [selectedCustomerId, companyId],
                  );
                  await db.insert('customer_transactions', {
                    'id': const Uuid().v4(),
                    'company_id': companyId,
                    'customer_id': selectedCustomerId,
                    'type': 'purchase',
                    'amount': addedDebt,
                    'balance_after': newBal,
                    'description': desc,
                    'created_at': nowIso,
                  });

                  await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                    id: const Uuid().v4(),
                    clientTransactionId: const Uuid().v4(),
                    entityType: 'credit_purchase',
                    entityId: selectedCustomerId,
                    operationType: 'CREATE',
                    payload: {
                      'customerId': selectedCustomerId,
                      'items': [
                        {'name': desc, 'quantity': 1, 'unitPrice': totalAmt}
                      ],
                      'paidAmount': paidAmt,
                      'note': desc,
                    },
                  );

                  await _loadCreditData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('credit_sale_recorded')} $custName (+${_formatCurrency(addedDebt)})'), backgroundColor: ModiriColors.brandTeal),
                    );
                  }
                },
                child: Text(loc.get('new_credit_sale')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filtered = _debtors.where((c) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

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
                  Text(
                    loc.get('credit_title'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('credit_subtitle'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_card, size: 16, color: ModiriColors.brandAmber),
                    label: Text(loc.get('new_credit_sale')),
                    onPressed: _showNewCreditSaleDialog,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadCreditData,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3 KPI Summary Cards matching mobile specification
          Row(
            children: [
              Expanded(
                child: _CreditMetricCard(
                  title: loc.get('total_credit_extended'),
                  value: _formatCurrency(_totalCreditExtended),
                  icon: Icons.credit_card,
                  color: ModiriColors.brandBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _CreditMetricCard(
                  title: loc.get('total_repaid_recovered'),
                  value: _formatCurrency(_totalPaid),
                  icon: Icons.task_alt,
                  color: ModiriColors.brandTeal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _CreditMetricCard(
                  title: loc.get('outstanding_debt_balance'),
                  value: _formatCurrency(_totalOutstanding),
                  icon: Icons.pending_actions,
                  color: ModiriColors.brandAmber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
            decoration: InputDecoration(
              hintText: loc.get('search_debtors_hint'),
              prefixIcon: const Icon(Icons.search, color: ModiriColors.brandAmber, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: ModiriColors.textSecondary(isDark), size: 18),
                      onPressed: () => setState(() => _searchController.clear()),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ModiriPanel(
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ModiriColors.brandAmber))
                  : filtered.isEmpty
                      ? Center(
                          child: Text(loc.get('no_credit_customers'),
                              style: TextStyle(color: ModiriColors.textMuted(isDark))),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: ModiriColors.border(isDark), height: 1),
                          itemBuilder: (ctx, i) {
                            final debtor = filtered[i];
                            final name = debtor['name']?.toString() ?? 'Customer';
                            final phone = debtor['phone']?.toString() ?? loc.get('no_phone_listed');
                            final balance = ((debtor['credit_balance'] ?? 0.0) as num).toDouble();

                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showCustomerDebtProfileDialog(debtor),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: ModiriColors.card(isDark),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.credit_card,
                                          color: ModiriColors.brandAmber, size: 18),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: TextStyle(
                                                  color: ModiriColors.textPrimary(isDark),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                          Text(ModiriFormatters.toLatinDigits(phone),
                                              style: TextStyle(
                                                  color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(loc.get('owed_balance'),
                                              style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10)),
                                          Text(
                                            _formatCurrency(balance),
                                            style: const TextStyle(
                                              color: ModiriColors.brandAmber,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.person_outline, size: 20),
                                      color: ModiriColors.brandBlue,
                                      tooltip: loc.get('customer_profile'),
                                      onPressed: () => _showCustomerDebtProfileDialog(debtor),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                                      icon: const Icon(Icons.payments_outlined, size: 15),
                                      label: Text(loc.get('record_repayment')),
                                      onPressed: () => _showRepaymentDialog(debtor),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditMetricCard extends StatelessWidget {
  const _CreditMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModiriColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ModiriColors.border(isDark)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _ProfileInfoRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
          ),
        ),
      ],
    );
  }
}
