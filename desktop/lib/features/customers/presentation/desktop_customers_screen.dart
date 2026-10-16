import 'dart:async';
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
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopCustomersScreen extends ConsumerStatefulWidget {
  const DesktopCustomersScreen({super.key});

  @override
  ConsumerState<DesktopCustomersScreen> createState() => _DesktopCustomersScreenState();
}

class _DesktopCustomersScreenState extends ConsumerState<DesktopCustomersScreen> {
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
  List<Map<String, dynamic>> _customers = [];
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from local SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      var localRows = await db.query(
        'customers',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      if (localRows.isEmpty) {
        localRows = await db.query('customers', orderBy: 'name ASC');
      }

      if (mounted && localRows.isNotEmpty) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(localRows);
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch from backend API while preserving pending local sync changes
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/customers');
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      final db = await ModiriDesktopDatabase.instance.database;
      final pendingRows = await db.query(
        'sync_queue',
        columns: ['entity_id'],
        where: "company_id = ? AND entity_type IN ('customer', 'credit_payment', 'credit_purchase') AND status = 'pending'",
        whereArgs: [companyId],
      );
      final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

      final batch = db.batch();

      for (final item in list) {
        final c = Map<String, dynamic>.from(item as Map);
        final id = c['id']?.toString() ?? const Uuid().v4();
        if (pendingIds.contains(id)) continue;

        final name = c['name']?.toString() ?? 'Unnamed';
        final phone = c['phone']?.toString();
        final balance = ((c['credit_balance'] ?? c['balanceDue'] ?? c['balance'] ?? 0.0) as num).toDouble();

        batch.insert(
          'customers',
          {
            'id': id,
            'company_id': companyId,
            'name': name,
            'phone': phone,
            'credit_balance': balance,
            'created_at': c['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);

      var freshRows = await db.query(
        'customers',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      if (freshRows.isEmpty) {
        freshRows = await db.query('customers', orderBy: 'name ASC');
      }

      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(freshRows);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _customers.isEmpty) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddCustomerDialog() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController();

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
          title: Text(loc.get('add_new_customer'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('customer_full_name'), prefixIcon: const Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('phone_number_label'), prefixIcon: const Icon(Icons.phone)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('credit_limit_optional'), prefixIcon: const Icon(Icons.credit_card)),
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
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();

                final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                final newId = const Uuid().v4();
                final phone = phoneCtrl.text.trim();

                try {
                  final db = await ModiriDesktopDatabase.instance.database;
                  await db.insert('customers', {
                    'id': newId,
                    'company_id': companyId,
                    'name': name,
                    'phone': phone.isEmpty ? null : phone,
                    'credit_balance': 0.0,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                    id: const Uuid().v4(),
                    clientTransactionId: const Uuid().v4(),
                    entityType: 'customer',
                    entityId: newId,
                    operationType: 'CREATE',
                    payload: {
                      'name': name,
                      if (phone.isNotEmpty) 'phone': phone,
                    },
                  );

                  await _loadCustomers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.get('customer_added_success')), backgroundColor: ModiriColors.brandTeal),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(loc.get('save_customer')),
            ),
          ],
        );
      },
    );
  }

  void _showEditCustomerDialog(Map<String, dynamic> customer) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final nameCtrl = TextEditingController(text: customer['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: customer['phone']?.toString() ?? '');

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
          title: Text(loc.get('edit_customer'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('customer_name'), prefixIcon: const Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('phone'), prefixIcon: const Icon(Icons.phone)),
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
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();

                final id = customer['id']?.toString() ?? '';
                final phone = phoneCtrl.text.trim();

                try {
                  final db = await ModiriDesktopDatabase.instance.database;
                  await db.update(
                    'customers',
                    {'name': name, 'phone': phone.isEmpty ? null : phone},
                    where: 'id = ?',
                    whereArgs: [id],
                  );

                  await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                    id: const Uuid().v4(),
                    clientTransactionId: const Uuid().v4(),
                    entityType: 'customer',
                    entityId: id,
                    operationType: 'UPDATE',
                    payload: {'name': name, 'phone': phone},
                  );

                  await _loadCustomers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.get('customer_updated_success')), backgroundColor: ModiriColors.brandTeal),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(loc.get('update_customer')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteCustomer(Map<String, dynamic> customer) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final balance = ((customer['credit_balance'] ?? 0.0) as num).toDouble();
    final name = customer['name']?.toString() ?? 'Customer';

    if (balance > 0) {
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
              children: [
                const Icon(Icons.warning_amber_rounded, color: ModiriColors.brandAmber),
                const SizedBox(width: 8),
                Text(loc.get('cannot_delete_customer'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
              ],
            ),
            content: Text(
              '$name has an unpaid debt balance of ${_formatCurrency(balance)}. Settle the outstanding balance before deleting this account.',
              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.get('close')),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Text(loc.get('confirm_deletion'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${loc.get('confirm_delete_customer')} "$name"?',
              style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.get('delete')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final id = customer['id']?.toString() ?? '';
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('customers', where: 'id = ?', whereArgs: [id]);

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'customer',
          entityId: id,
          operationType: 'DELETE',
          payload: {'id': id},
        );

        await _loadCustomers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('removed_prefix')} "$name".'), backgroundColor: ModiriColors.brandTeal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_failed_prefix')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  void _showCustomerCreditHistoryDialog(Map<String, dynamic> customer) {
    _showCustomerProfileDialog(customer, initialTab: 1);
  }

  void _showCustomerProfileDialog(Map<String, dynamic> customer, {int initialTab = 0}) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final customerId = customer['id']?.toString() ?? '';
    final name = customer['name']?.toString() ?? 'Customer';
    final phone = customer['phone']?.toString() ?? loc.get('no_phone_listed');
    final notes = customer['notes']?.toString() ?? '';
    final createdAt = customer['created_at']?.toString() ?? '';
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    final db = await ModiriDesktopDatabase.instance.database;

    // Load customer transactions
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

    // Load invoices associated with customer
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
        double currentBalance = ((customer['credit_balance'] ?? 0.0) as num).toDouble();

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
                          backgroundColor: ModiriColors.brandBlue.withOpacity(0.15),
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                            style: const TextStyle(color: ModiriColors.brandBlue, fontWeight: FontWeight.bold, fontSize: 18),
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

                                await _loadCustomers();
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
                                  Text(loc.get('invoices'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    ModiriFormatters.formatNumber(invoices.length),
                                    style: const TextStyle(
                                      color: ModiriColors.brandViolet,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
                                color: ModiriColors.brandGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ModiriColors.brandGreen.withOpacity(0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('total_paid'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrency(totalSettled),
                                    style: const TextStyle(
                                      color: ModiriColors.brandGreen,
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
                      const SizedBox(height: 14),

                      // Profile Navigation Tabs
                      TabBar(
                        labelColor: ModiriColors.brandBlue,
                        unselectedLabelColor: ModiriColors.textSecondary(isDark),
                        indicatorColor: ModiriColors.brandBlue,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.receipt_long_outlined, size: 16),
                            text: loc.get('invoices_and_sales'),
                          ),
                          Tab(
                            icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                            text: loc.get('credit_ledger'),
                          ),
                          Tab(
                            icon: const Icon(Icons.person_outline, size: 16),
                            text: loc.get('customer_profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: Invoices and Sales
                            invoices.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.receipt_outlined, size: 40, color: ModiriColors.textMuted(isDark)),
                                        const SizedBox(height: 8),
                                        Text(loc.get('no_invoices_found'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 13)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: invoices.length,
                                    separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                                    itemBuilder: (_, idx) {
                                      final inv = invoices[idx];
                                      final invNo = inv['invoice_number']?.toString() ?? 'INV-${inv['id']}';
                                      final date = inv['created_at']?.toString().split('T')[0] ?? '';
                                      final total = ((inv['total'] ?? 0.0) as num).toDouble();
                                      final paid = ((inv['paid_amount'] ?? 0.0) as num).toDouble();
                                      final rem = ((inv['remaining_amount'] ?? 0.0) as num).toDouble();
                                      final status = inv['status']?.toString() ?? 'paid';

                                      return ListTile(
                                        dense: true,
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: ModiriColors.brandBlue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.receipt_long, color: ModiriColors.brandBlue, size: 18),
                                        ),
                                        title: Row(
                                          children: [
                                            Text(ModiriFormatters.toLatinDigits(invNo), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: status == 'paid'
                                                    ? ModiriColors.brandTeal.withOpacity(0.12)
                                                    : ModiriColors.brandAmber.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  color: status == 'paid' ? ModiriColors.brandTeal : ModiriColors.brandAmber,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          '${ModiriFormatters.toLatinDigits(date)} · ${loc.get('paid_label')}: ${_formatCurrency(paid)} · ${loc.get('remaining')}: ${_formatCurrency(rem)}',
                                          style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11),
                                        ),
                                        trailing: Text(
                                          _formatCurrency(total),
                                          style: const TextStyle(
                                            color: ModiriColors.brandBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                            // Tab 2: Credit Ledger & Transactions
                            transactions.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.history_outlined, size: 40, color: ModiriColors.textMuted(isDark)),
                                        const SizedBox(height: 8),
                                        Text(loc.get('no_credit_transactions_yet'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 13)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: transactions.length,
                                    separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                                    itemBuilder: (_, i) {
                                      final t = transactions[i];
                                      final isPayment = t['type'] == 'payment';
                                      final amt = ((t['amount'] ?? 0.0) as num).toDouble();
                                      final bAfter = ((t['balance_after'] ?? 0.0) as num).toDouble();
                                      final date = t['created_at']?.toString().split('T')[0] ?? '';

                                      return ListTile(
                                        dense: true,
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: (isPayment ? ModiriColors.brandTeal : ModiriColors.brandAmber).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isPayment ? Icons.payments_outlined : Icons.shopping_bag_outlined,
                                            color: isPayment ? ModiriColors.brandTeal : ModiriColors.brandAmber,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          isPayment ? loc.get('record_repayment') : loc.get('new_credit_sale'),
                                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        subtitle: Text(
                                          '${loc.get('owed_balance')}: ${_formatCurrency(bAfter)} · ${ModiriFormatters.toLatinDigits(date)}',
                                          style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11),
                                        ),
                                        trailing: Text(
                                          '${isPayment ? '-' : '+'}${_formatCurrency(amt)}',
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

                            // Tab 3: Detailed Profile Information
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ModiriColors.border(isDark)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(loc.get('staff_details'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit_outlined, size: 14),
                                        label: Text(loc.get('edit_customer'), style: const TextStyle(fontSize: 12)),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          _showEditCustomerDialog(customer);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _ProfileInfoRow(label: loc.get('name'), value: name, isDark: isDark),
                                  const SizedBox(height: 10),
                                  _ProfileInfoRow(label: loc.get('phone'), value: ModiriFormatters.toLatinDigits(phone), isDark: isDark),
                                  const SizedBox(height: 10),
                                  _ProfileInfoRow(label: loc.get('notes'), value: notes.isNotEmpty ? notes : loc.get('no_address_provided'), isDark: isDark),
                                  const SizedBox(height: 10),
                                  _ProfileInfoRow(label: loc.get('date_registered'), value: ModiriFormatters.toLatinDigits(createdAt.split('T')[0]), isDark: isDark),
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
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(loc.get('close'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filtered = _customers.where((c) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    final totalCustomers = _customers.length;
    final debtors = _customers.where((c) => ((c['credit_balance'] ?? 0.0) as num).toDouble() > 0).toList();
    final totalOutstanding = debtors.fold(
      0.0,
      (acc, c) => acc + ((c['credit_balance'] ?? 0.0) as num).toDouble(),
    );

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
                    loc.get('customers_title'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('customers_subtitle'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadCustomers,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add, size: 16),
                    label: Text(loc.get('add_customer')),
                    onPressed: _showAddCustomerDialog,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // KPI Stats Cards matching website style
          Row(
            children: [
              Expanded(
                child: _KpiStatCard(
                  title: loc.get('total_customers'),
                  value: totalCustomers.toString(),
                  icon: Icons.people_outline,
                  color: ModiriColors.brandBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiStatCard(
                  title: loc.get('debtor_accounts'),
                  value: debtors.length.toString(),
                  icon: Icons.account_balance_wallet_outlined,
                  color: ModiriColors.brandAmber,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiStatCard(
                  title: loc.get('total_credit_due'),
                  value: _formatCurrency(totalOutstanding),
                  icon: Icons.credit_score_outlined,
                  color: totalOutstanding > 0 ? ModiriColors.brandRose : ModiriColors.brandTeal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
            decoration: InputDecoration(
              hintText: loc.get('search_customers_hint'),
              prefixIcon: const Icon(Icons.search, color: ModiriColors.brandBlue, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: ModiriColors.textSecondary(isDark), size: 18),
                      onPressed: () => setState(() => _searchController.clear()),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModiriColors.brandRose.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: ModiriColors.brandRose, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: ModiriPanel(
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: ModiriColors.brandBlue))
                  : filtered.isEmpty
                      ? Center(
                          child: Text(loc.get('no_customers_found'),
                              style: TextStyle(color: ModiriColors.textMuted(isDark))),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: ModiriColors.border(isDark), height: 1),
                          itemBuilder: (ctx, i) {
                            final cust = filtered[i];
                            final name = cust['name']?.toString() ?? 'Client';
                            final phone = cust['phone']?.toString() ?? loc.get('no_phone_listed');
                            final balance = ((cust['credit_balance'] ?? 0.0) as num).toDouble();

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showCustomerProfileDialog(cust),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: ModiriColors.brandBlue.withOpacity(0.15),
                                      foregroundColor: ModiriColors.brandBlue,
                                      radius: 18,
                                      child: Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
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
                                          Text(loc.get('balance_due'),
                                              style: TextStyle(
                                                  color: ModiriColors.textMuted(isDark), fontSize: 10)),
                                          Text(
                                            _formatCurrency(balance),
                                            style: TextStyle(
                                              color: balance > 0
                                                  ? ModiriColors.brandAmber
                                                  : ModiriColors.brandTeal,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.person_outline, size: 19, color: ModiriColors.brandBlue),
                                          tooltip: loc.get('customer_profile'),
                                          onPressed: () => _showCustomerProfileDialog(cust),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.history_rounded, size: 19, color: ModiriColors.textSecondary(isDark)),
                                          tooltip: loc.get('transaction_ledger_credit'),
                                          onPressed: () => _showCustomerCreditHistoryDialog(cust),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, size: 19, color: ModiriColors.textSecondary(isDark)),
                                          tooltip: loc.get('edit_customer'),
                                          onPressed: () => _showEditCustomerDialog(cust),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 19, color: ModiriColors.brandRose),
                                          tooltip: loc.get('delete_customer'),
                                          onPressed: () => _confirmDeleteCustomer(cust),
                                        ),
                                      ],
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

class _KpiStatCard extends StatelessWidget {
  const _KpiStatCard({
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
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16),
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
