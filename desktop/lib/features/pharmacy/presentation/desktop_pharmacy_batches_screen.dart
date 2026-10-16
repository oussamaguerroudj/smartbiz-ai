import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopPharmacyBatchesScreen extends ConsumerStatefulWidget {
  const DesktopPharmacyBatchesScreen({super.key});

  @override
  ConsumerState<DesktopPharmacyBatchesScreen> createState() => _DesktopPharmacyBatchesScreenState();
}

class _DesktopPharmacyBatchesScreenState extends ConsumerState<DesktopPharmacyBatchesScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  bool _isLoading = true;
  String? _error;
  int _selectedFilterDays = 30; // 30, 60, 90, 365
  String _searchQuery = '';

  List<Map<String, dynamic>> _batches = [];
  int _expiredCount = 0;
  int _expiringSoonCount = 0;
  int _totalBatchesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from SQLite pharmacy_batches and products with expiration_date
    try {
      final db = await ModiriDesktopDatabase.instance.database;

      final batchRows = await db.query(
        'pharmacy_batches',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'expiration_date ASC',
      );

      final productRows = await db.rawQuery(
        '''SELECT id, name, expiration_date, stock_quantity, barcode 
           FROM products 
           WHERE company_id = ? AND expiration_date IS NOT NULL AND expiration_date != '' 
           ORDER BY expiration_date ASC''',
        [companyId],
      );

      final combined = <Map<String, dynamic>>[];
      for (final b in batchRows) {
        combined.add({
          'id': b['id'],
          'medicine_name': b['medicine_name'],
          'batch_number': b['batch_number'],
          'expiration_date': b['expiration_date'],
          'quantity': b['quantity'],
          'is_batch_entry': true,
        });
      }

      for (final p in productRows) {
        combined.add({
          'id': p['id'],
          'medicine_name': p['name'],
          'batch_number': p['barcode'] ?? 'N/A',
          'expiration_date': p['expiration_date'],
          'quantity': p['stock_quantity'],
          'is_batch_entry': false,
        });
      }

      final now = DateTime.now();
      int expired = 0;
      int soon = 0;

      for (final item in combined) {
        final exp = DateTime.tryParse(item['expiration_date']?.toString() ?? '') ?? now;
        final diff = exp.difference(now).inDays;
        item['days_remaining'] = diff;
        if (diff < 0) {
          expired++;
        } else if (diff <= 30) {
          soon++;
        }
      }

      if (mounted) {
        setState(() {
          _batches = combined;
          _expiredCount = expired;
          _expiringSoonCount = soon;
          _totalBatchesCount = combined.length;
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch from backend if online
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/pharmacy/expiring-products', query: {'days': '$_selectedFilterDays'});
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      if (list.isNotEmpty && mounted) {
        final now = DateTime.now();
        final serverItems = list.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final expStr = m['expiration_date']?.toString() ?? m['expirationDate']?.toString() ?? '';
          final exp = DateTime.tryParse(expStr) ?? now;
          return {
            'id': m['id']?.toString() ?? const Uuid().v4(),
            'medicine_name': m['name'] ?? 'Medicine',
            'batch_number': m['batch_number'] ?? m['barcode'] ?? 'N/A',
            'expiration_date': expStr,
            'quantity': (m['quantity'] as num?)?.toInt() ?? 0,
            'days_remaining': exp.difference(now).inDays,
            'is_batch_entry': false,
          };
        }).toList();

        int expired = 0;
        int soon = 0;
        for (final item in serverItems) {
          final diff = item['days_remaining'] as int? ?? 0;
          if (diff < 0) {
            expired++;
          } else if (diff <= 30) {
            soon++;
          }
        }

        setState(() {
          _batches = serverItems;
          _expiredCount = expired;
          _expiringSoonCount = soon;
          _totalBatchesCount = serverItems.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBatchModal({Map<String, dynamic>? batch}) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isEditing = batch != null;
    final nameCtrl = TextEditingController(text: batch?['medicine_name']?.toString() ?? '');
    final batchNumCtrl = TextEditingController(
      text: batch?['batch_number']?.toString() ?? 'LOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final qtyCtrl = TextEditingController(text: batch?['quantity']?.toString() ?? '50');

    DateTime selectedExp;
    try {
      final expStr = batch?['expiration_date']?.toString();
      selectedExp = expStr != null ? DateTime.parse(expStr) : DateTime.now().add(const Duration(days: 180));
    } catch (_) {
      selectedExp = DateTime.now().add(const Duration(days: 180));
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Row(
              children: [
                Icon(isEditing ? Icons.edit : Icons.medication_outlined, color: ModiriColors.brandTeal, size: 22),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Medicine Batch' : 'Register Medicine Batch',
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('medicine_product_name_req')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: batchNumCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('lot_batch_number_req')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: loc.get('batch_qty_units_req')),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(loc.get('expiry_date'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                      subtitle: Text(
                        _dateFormat.format(selectedExp),
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      trailing: OutlinedButton(
                        child: Text(loc.get('pick_date')),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedExp,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedExp = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
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
                  final batchNum = batchNumCtrl.text.trim();
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  if (name.isEmpty || batchNum.isEmpty) return;

                  final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                  final expIso = _dateFormat.format(selectedExp);

                  try {
                    final db = await ModiriDesktopDatabase.instance.database;

                    if (isEditing) {
                      final targetId = batch['id'].toString();
                      await db.update(
                        'pharmacy_batches',
                        {
                          'medicine_name': name,
                          'batch_number': batchNum,
                          'expiration_date': expIso,
                          'quantity': qty,
                          'synced': 0,
                        },
                        where: 'id = ?',
                        whereArgs: [targetId],
                      );

                      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                        id: const Uuid().v4(),
                        clientTransactionId: const Uuid().v4(),
                        entityType: 'product',
                        entityId: targetId,
                        operationType: 'UPDATE',
                        payload: {
                          'name': name,
                          'barcode': batchNum,
                          'quantity': qty,
                          'expirationDate': expIso,
                        },
                      );
                    } else {
                      final newId = const Uuid().v4();
                      await db.insert('pharmacy_batches', {
                        'id': newId,
                        'company_id': companyId,
                        'batch_number': batchNum,
                        'medicine_name': name,
                        'expiration_date': expIso,
                        'quantity': qty,
                        'created_at': DateTime.now().toIso8601String(),
                        'synced': 0,
                      });

                      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                        id: const Uuid().v4(),
                        clientTransactionId: const Uuid().v4(),
                        entityType: 'product',
                        entityId: newId,
                        operationType: 'CREATE',
                        payload: {
                          'name': name,
                          'barcode': batchNum,
                          'quantity': qty,
                          'expirationDate': expIso,
                          'sellingPrice': 0.0,
                          'purchasePrice': 0.0,
                        },
                      );
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _loadBatches();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('${loc.get('save_batch_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                      );
                    }
                  }
                },
                child: Text(loc.get('save')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteBatch(String id, String medicineName) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          title: Text(loc.get('delete_medicine_batch'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${loc.get('confirm_delete_batch')} "$medicineName"?',
              style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(loc.get('cancel'))),
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
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('pharmacy_batches', where: 'id = ?', whereArgs: [id]);
        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'product',
          entityId: id,
          operationType: 'DELETE',
          payload: {},
        );
        _loadBatches();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_failed_prefix')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filteredBatches = _batches.where((b) {
      final name = (b['medicine_name'] ?? '').toString().toLowerCase();
      final lot = (b['batch_number'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty && !name.contains(q) && !lot.contains(q)) return false;

      final days = b['days_remaining'] as int? ?? 999;
      if (_selectedFilterDays == 30) return days <= 30;
      if (_selectedFilterDays == 60) return days <= 60;
      if (_selectedFilterDays == 90) return days <= 90;
      return true; // All
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.get('pharmacy_batches_header_title'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('pharmacy_batches_header_desc'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(loc.get('register_batch')),
                onPressed: () => _showBatchModal(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Cards
          Row(
            children: [
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandRose.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: ModiriColors.brandRose, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.get('expired_batches'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$_expiredCount',
                              style: const TextStyle(color: ModiriColors.brandRose, fontWeight: FontWeight.bold, fontSize: 20)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandAmber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.access_time_rounded, color: ModiriColors.brandAmber, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.get('expiring_in_30_days'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$_expiringSoonCount',
                              style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontSize: 20)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandTeal.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: ModiriColors.brandTeal, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.get('total_monitored_batches'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$_totalBatchesCount',
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 20)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters row
          Row(
            children: [
              Text(loc.get('filter_horizon'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
              const SizedBox(width: 8),
              ...[30, 60, 90, 365].map((days) {
                final isSel = _selectedFilterDays == days;
                final label = days == 365 ? 'All Batches' : '< $days Days';
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSel,
                    selectedColor: ModiriColors.brandTeal.withOpacity(0.2),
                    backgroundColor: ModiriColors.card(isDark),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSel ? ModiriColors.brandTeal : ModiriColors.textSecondary(isDark),
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSel ? ModiriColors.brandTeal : ModiriColors.border(isDark),
                    ),
                    onSelected: (_) => setState(() => _selectedFilterDays = days),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Search bar
          SizedBox(
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(fontSize: 13, color: ModiriColors.textPrimary(isDark)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: loc.get('search_batches_hint'),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Batch Table
          Expanded(
            child: ModiriPanel(
              padding: EdgeInsets.zero,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredBatches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_outlined, size: 48, color: ModiriColors.brandTeal),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilterDays == 30
                                    ? 'No medicines expiring within the next 30 days.'
                                    : 'No monitored batches found for this criteria.',
                                style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredBatches.length,
                          separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                          itemBuilder: (ctx, idx) {
                            final b = filteredBatches[idx];
                            final days = b['days_remaining'] as int? ?? 0;
                            final isExp = days < 0;
                            final isUrgent = days >= 0 && days <= 30;

                            final color = isExp
                                ? ModiriColors.brandRose
                                : (isUrgent ? ModiriColors.brandAmber : ModiriColors.brandTeal);

                            final statusText = isExp
                                ? 'EXPIRED (${-days}d ago)'
                                : (isUrgent ? 'URGENT ($days days left)' : 'OK ($days days left)');

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.medication, color: color, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    b['medicine_name'] ?? 'Medicine',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 14),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: color.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Lot: ${b['batch_number']} · Stock: ${b['quantity']} units · Expires: ${b['expiration_date']}',
                                  style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${b['quantity']} Units',
                                    style: TextStyle(
                                      color: ModiriColors.textPrimary(isDark),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: ModiriColors.brandTeal),
                                    tooltip: loc.get('edit_batch'),
                                    onPressed: () => _showBatchModal(batch: b),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: ModiriColors.brandRose),
                                    tooltip: loc.get('delete_batch'),
                                    onPressed: () => _deleteBatch(b['id'].toString(), b['medicine_name'] ?? 'Medicine'),
                                  ),
                                ],
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
