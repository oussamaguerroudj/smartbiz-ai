import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../ai/presentation/desktop_ai_invoice_scanner_screen.dart';

class DesktopSuppliersScreen extends ConsumerStatefulWidget {
  const DesktopSuppliersScreen({super.key});

  @override
  ConsumerState<DesktopSuppliersScreen> createState() => _DesktopSuppliersScreenState();
}

class _DesktopSuppliersScreenState extends ConsumerState<DesktopSuppliersScreen> {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  bool _isLoading = true;
  List<Map<String, dynamic>> _suppliers = [];
  String? _error;
  final _searchController = TextEditingController();

  ModiriLocalizations get _loc => ModiriLocalizations(ref.read(desktopLocaleProvider));

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from local SQLite first with purchase and debt aggregations
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      var localRows = await db.rawQuery('''
        SELECT 
          s.*,
          COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
          COALESCE(SUM(p.amount_paid), 0) as total_purchases_paid,
          COALESCE(SUM(p.outstanding_balance), 0) as outstanding_balance
        FROM suppliers s
        LEFT JOIN supplier_purchases p ON p.supplier_id = s.id
        WHERE s.company_id = ?
        GROUP BY s.id
        ORDER BY s.name ASC
      ''', [companyId]);

      if (localRows.isEmpty) {
        localRows = await db.rawQuery('''
          SELECT 
            s.*,
            COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
            COALESCE(SUM(p.amount_paid), 0) as total_purchases_paid,
            COALESCE(SUM(p.outstanding_balance), 0) as outstanding_balance
          FROM suppliers s
          LEFT JOIN supplier_purchases p ON p.supplier_id = s.id
          GROUP BY s.id
          ORDER BY s.name ASC
        ''');
      }

      if (mounted && localRows.isNotEmpty) {
        setState(() {
          _suppliers = List<Map<String, dynamic>>.from(localRows);
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch from backend API while preserving pending local sync changes
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/suppliers');
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      final db = await ModiriDesktopDatabase.instance.database;
      final pendingRows = await db.query(
        'sync_queue',
        columns: ['entity_id'],
        where: "company_id = ? AND entity_type = 'supplier' AND status = 'pending'",
        whereArgs: [companyId],
      );
      final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

      final batch = db.batch();

      for (final item in list) {
        final s = Map<String, dynamic>.from(item as Map);
        final id = s['id']?.toString() ?? const Uuid().v4();
        if (pendingIds.contains(id)) continue;

        final name = s['name']?.toString() ?? 'Unnamed';
        final phone = s['phone']?.toString();
        final address = s['address']?.toString();
        final supplied = _parseInt(s['products_supplied']);

        batch.insert(
          'suppliers',
          {
            'id': id,
            'company_id': companyId,
            'name': name,
            'phone': phone,
            'address': address,
            'products_supplied': supplied,
            'created_at': s['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);

      var freshRows = await db.rawQuery('''
        SELECT 
          s.*,
          COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
          COALESCE(SUM(p.amount_paid), 0) as total_purchases_paid,
          COALESCE(SUM(p.outstanding_balance), 0) as outstanding_balance
        FROM suppliers s
        LEFT JOIN supplier_purchases p ON p.supplier_id = s.id
        WHERE s.company_id = ?
        GROUP BY s.id
        ORDER BY s.name ASC
      ''', [companyId]);

      if (freshRows.isEmpty) {
        freshRows = await db.rawQuery('''
          SELECT 
            s.*,
            COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
            COALESCE(SUM(p.amount_paid), 0) as total_purchases_paid,
            COALESCE(SUM(p.outstanding_balance), 0) as outstanding_balance
          FROM suppliers s
          LEFT JOIN supplier_purchases p ON p.supplier_id = s.id
          GROUP BY s.id
          ORDER BY s.name ASC
        ''');
      }

      // If backend returned API aggregates, map them in case local purchase cache hasn't synced all purchases yet:
      final apiMap = <String, Map<String, dynamic>>{};
      for (final item in list) {
        if (item is Map && item['id'] != null) {
          apiMap[item['id'].toString()] = Map<String, dynamic>.from(item);
        }
      }

      final mergedRows = freshRows.map((r) {
        final m = Map<String, dynamic>.from(r);
        final apiItem = apiMap[m['id']?.toString()];
        if (apiItem != null) {
          final localPurchases = _parseDouble(m['total_purchases_amount']);
          if (localPurchases == 0 && apiItem['total_purchases_amount'] != null) {
            m['total_purchases_amount'] = _parseDouble(apiItem['total_purchases_amount']);
            m['total_purchases_paid'] = _parseDouble(apiItem['total_purchases_paid']);
            m['outstanding_balance'] = _parseDouble(apiItem['outstanding_balance']);
          }
        }
        return m;
      }).toList();

      if (mounted) {
        setState(() {
          _suppliers = mergedRows;
          _isLoading = false;
        });
      }
    } catch (_) {
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        var localRows = await db.rawQuery('''
          SELECT 
            s.*,
            COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
            COALESCE(SUM(p.amount_paid), 0) as total_purchases_paid,
            COALESCE(SUM(p.outstanding_balance), 0) as outstanding_balance
          FROM suppliers s
          LEFT JOIN supplier_purchases p ON p.supplier_id = s.id
          WHERE s.company_id = ?
          GROUP BY s.id
          ORDER BY s.name ASC
        ''', [companyId]);

        if (localRows.isEmpty) {
          localRows = await db.rawQuery('''
            SELECT 
              s.*,
              COALESCE(SUM(p.total_amount), 0) as total_purchases_amount,
              COALESCE(SUM(p.amount_paid), 0) as total_purchases_paid,
              COALESCE(SUM(p.outstanding_balance), 0) as outstanding_balance
            FROM suppliers s
            LEFT JOIN supplier_purchases p ON p.supplier_id = s.id
            GROUP BY s.id
            ORDER BY s.name ASC
          ''');
        }

        if (mounted) {
          setState(() {
            _suppliers = List<Map<String, dynamic>>.from(localRows);
            _isLoading = false;
            _error = null;
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
  }

  void _showAddSupplierDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

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
          title: Text(_loc.get('add_wholesale_supplier'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: _loc.get('supplier_name_input'), prefixIcon: const Icon(Icons.business_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: _loc.get('contact_phone_number'), prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: _loc.get('warehouse_address_input'), prefixIcon: const Icon(Icons.location_on_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();

                final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                final newId = const Uuid().v4();
                final phone = phoneCtrl.text.trim();
                final address = addressCtrl.text.trim();

                try {
                  final db = await ModiriDesktopDatabase.instance.database;
                  await db.insert('suppliers', {
                    'id': newId,
                    'company_id': companyId,
                    'name': name,
                    'phone': phone.isEmpty ? null : phone,
                    'address': address.isEmpty ? null : address,
                    'products_supplied': 0,
                    'created_at': DateTime.now().toIso8601String(),
                    'synced': 0,
                  });

                  await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                    id: const Uuid().v4(),
                    clientTransactionId: const Uuid().v4(),
                    entityType: 'supplier',
                    entityId: newId,
                    operationType: 'CREATE',
                    payload: {
                      'name': name,
                      if (phone.isNotEmpty) 'phone': phone,
                      if (address.isNotEmpty) 'address': address,
                    },
                  );

                  await _loadSuppliers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_loc.get('supplier_added_success')), backgroundColor: ModiriColors.brandTeal),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(_loc.get('save_supplier')),
            ),
          ],
        );
      },
    );
  }

  void _showEditSupplierDialog(Map<String, dynamic> supplier) {
    final nameCtrl = TextEditingController(text: supplier['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: supplier['phone']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: supplier['address']?.toString() ?? '');

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
          title: Text(_loc.get('edit_supplier_info'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: _loc.get('supplier_name_req'), prefixIcon: const Icon(Icons.business_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: _loc.get('contact_phone_number'), prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: _loc.get('warehouse_address_label'), prefixIcon: const Icon(Icons.location_on_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();

                final id = supplier['id']?.toString() ?? '';
                final phone = phoneCtrl.text.trim();
                final address = addressCtrl.text.trim();

                try {
                  final db = await ModiriDesktopDatabase.instance.database;
                  await db.update(
                    'suppliers',
                    {
                      'name': name,
                      'phone': phone.isEmpty ? null : phone,
                      'address': address.isEmpty ? null : address,
                    },
                    where: 'id = ?',
                    whereArgs: [id],
                  );

                  await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                    id: const Uuid().v4(),
                    clientTransactionId: const Uuid().v4(),
                    entityType: 'supplier',
                    entityId: id,
                    operationType: 'UPDATE',
                    payload: {
                      'name': name,
                      'phone': phone,
                      'address': address,
                    },
                  );

                  await _loadSuppliers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_loc.get('supplier_updated_success')), backgroundColor: ModiriColors.brandTeal),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(_loc.get('update_supplier')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSupplierDetailsDialog(Map<String, dynamic> supplier) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = supplier['name']?.toString() ?? _loc.get('supplier');
    final phone = supplier['phone']?.toString() ?? _loc.get('no_phone_listed');
    final address = supplier['address']?.toString() ?? _loc.get('no_address_provided');
    final suppliedCount = _parseInt(supplier['products_supplied']);
    final companyId = supplier['company_id']?.toString() ?? ref.read(sessionProvider).companyId ?? 'default_company';
    final supplierId = supplier['id']?.toString() ?? '';

    List<Map<String, dynamic>> purchases = [];
    List<Map<String, dynamic>> payments = [];
    double stockValuation = 0.0;

    // 1. Safely pre-load local records before opening dialog
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      var pRows = await db.query(
        'supplier_purchases',
        where: 'company_id = ? AND supplier_id = ?',
        whereArgs: [companyId, supplierId],
        orderBy: 'purchase_date DESC, created_at DESC',
      );
      if (pRows.isEmpty) {
        pRows = await db.query(
          'supplier_purchases',
          where: 'supplier_id = ?',
          whereArgs: [supplierId],
          orderBy: 'purchase_date DESC, created_at DESC',
        );
      }
      var payRows = await db.query(
        'supplier_payments',
        where: 'company_id = ? AND supplier_id = ?',
        whereArgs: [companyId, supplierId],
        orderBy: 'payment_date DESC, created_at DESC',
      );
      if (payRows.isEmpty) {
        payRows = await db.query(
          'supplier_payments',
          where: 'supplier_id = ?',
          whereArgs: [supplierId],
          orderBy: 'payment_date DESC, created_at DESC',
        );
      }

      final purchaseItemsVal = await db.rawQuery('''
        SELECT COALESCE(SUM(spi.quantity * spi.unit_cost), 0.0) as val
        FROM supplier_purchase_items spi
        JOIN supplier_purchases sp ON sp.id = spi.purchase_id
        WHERE sp.company_id = ? AND sp.supplier_id = ?
      ''', [companyId, supplierId]);

      double computedVal = _parseDouble(purchaseItemsVal.firstOrNull?['val']);
      if (computedVal <= 0.0) {
        final pTotal = await db.rawQuery('''
          SELECT COALESCE(SUM(total_amount), 0.0) as val
          FROM supplier_purchases
          WHERE company_id = ? AND supplier_id = ?
        ''', [companyId, supplierId]);
        computedVal = _parseDouble(pTotal.firstOrNull?['val']);
      }

      purchases = List<Map<String, dynamic>>.from(pRows);
      payments = List<Map<String, dynamic>>.from(payRows);
      stockValuation = computedVal;
    } catch (_) {}

    Future<void> reloadData(void Function(void Function()) setDialogState) async {
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        var pRows = await db.query(
          'supplier_purchases',
          where: 'company_id = ? AND supplier_id = ?',
          whereArgs: [companyId, supplierId],
          orderBy: 'purchase_date DESC, created_at DESC',
        );
        if (pRows.isEmpty) {
          pRows = await db.query(
            'supplier_purchases',
            where: 'supplier_id = ?',
            whereArgs: [supplierId],
            orderBy: 'purchase_date DESC, created_at DESC',
          );
        }
        var payRows = await db.query(
          'supplier_payments',
          where: 'company_id = ? AND supplier_id = ?',
          whereArgs: [companyId, supplierId],
          orderBy: 'payment_date DESC, created_at DESC',
        );
        if (payRows.isEmpty) {
          payRows = await db.query(
            'supplier_payments',
            where: 'supplier_id = ?',
            whereArgs: [supplierId],
            orderBy: 'payment_date DESC, created_at DESC',
          );
        }

        final purchaseItemsVal = await db.rawQuery('''
          SELECT COALESCE(SUM(spi.quantity * spi.unit_cost), 0.0) as val
          FROM supplier_purchase_items spi
          JOIN supplier_purchases sp ON sp.id = spi.purchase_id
          WHERE sp.company_id = ? AND sp.supplier_id = ?
        ''', [companyId, supplierId]);

        double computedVal = _parseDouble(purchaseItemsVal.firstOrNull?['val']);
        if (computedVal <= 0.0) {
          final pTotal = await db.rawQuery('''
            SELECT COALESCE(SUM(total_amount), 0.0) as val
            FROM supplier_purchases
            WHERE company_id = ? AND supplier_id = ?
          ''', [companyId, supplierId]);
          computedVal = _parseDouble(pTotal.firstOrNull?['val']);
        }

        setDialogState(() {
          purchases = List<Map<String, dynamic>>.from(pRows);
          payments = List<Map<String, dynamic>>.from(payRows);
          stockValuation = computedVal;
        });
      } catch (_) {}

      // Try fetching fresh data from API in background if online
      try {
        final client = ref.read(apiClientProvider);
        final pRes = await client.get('/suppliers/$supplierId/purchases');
        final payRes = await client.get('/suppliers/$supplierId/payments');

        final apiPurchases = pRes is Map ? (pRes['data'] as List? ?? []) : (pRes as List? ?? []);
        final apiPayments = payRes is Map ? (payRes['data'] as List? ?? []) : (payRes as List? ?? []);

        final db = await ModiriDesktopDatabase.instance.database;
        final batch = db.batch();

        for (final p in apiPurchases) {
          final pMap = Map<String, dynamic>.from(p as Map);
          batch.insert(
            'supplier_purchases',
            {
              'id': pMap['id']?.toString() ?? const Uuid().v4(),
              'company_id': companyId,
              'supplier_id': supplierId,
              'invoice_number': pMap['invoice_number']?.toString() ?? '',
              'purchase_date': pMap['purchase_date']?.toString() ?? DateTime.now().toIso8601String(),
              'total_amount': _parseDouble(pMap['total_amount']),
              'amount_paid': _parseDouble(pMap['amount_paid'] ?? pMap['paid_amount']),
              'outstanding_balance': _parseDouble(pMap['outstanding_balance'] ?? pMap['remaining_balance']),
              'payment_status': pMap['payment_status']?.toString() ?? 'unpaid',
              'notes': pMap['notes']?.toString(),
              'created_at': pMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final py in apiPayments) {
          final pyMap = Map<String, dynamic>.from(py as Map);
          batch.insert(
            'supplier_payments',
            {
              'id': pyMap['id']?.toString() ?? const Uuid().v4(),
              'company_id': companyId,
              'supplier_id': supplierId,
              'purchase_id': pyMap['purchase_id']?.toString(),
              'amount': _parseDouble(pyMap['amount']),
              'payment_date': pyMap['payment_date']?.toString() ?? DateTime.now().toIso8601String(),
              'payment_method': pyMap['payment_method']?.toString() ?? 'cash',
              'reference': pyMap['reference']?.toString(),
              'notes': pyMap['notes']?.toString(),
              'created_at': pyMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);

        final freshP = await db.query(
          'supplier_purchases',
          where: 'company_id = ? AND supplier_id = ?',
          whereArgs: [companyId, supplierId],
          orderBy: 'purchase_date DESC, created_at DESC',
        );
        final freshPay = await db.query(
          'supplier_payments',
          where: 'company_id = ? AND supplier_id = ?',
          whereArgs: [companyId, supplierId],
          orderBy: 'payment_date DESC, created_at DESC',
        );

        setDialogState(() {
          purchases = List<Map<String, dynamic>>.from(freshP);
          payments = List<Map<String, dynamic>>.from(freshPay);
        });
      } catch (_) {}
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) {

          final totalPurchases = purchases.fold<double>(
            0.0,
            (sum, p) => sum + _parseDouble(p['total_amount']),
          );
          final totalPaid = purchases.fold<double>(
            0.0,
            (sum, p) => sum + _parseDouble(p['amount_paid'] ?? p['paid_amount']),
          );
          final outstandingDebt = purchases.fold<double>(
            0.0,
            (sum, p) => sum + _parseDouble(p['outstanding_balance'] ?? p['remaining_balance']),
          );

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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ModiriColors.brandBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_outlined, color: ModiriColors.brandBlue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(_loc.get('supplier_file_ledger'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: ModiriColors.textMuted(isDark)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: 780,
              height: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact info bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 14, color: ModiriColors.textSecondary(isDark)),
                            const SizedBox(width: 4),
                            Text(ModiriFormatters.toLatinDigits(phone), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 16),
                            Icon(Icons.location_on_outlined, size: 14, color: ModiriColors.textSecondary(isDark)),
                            const SizedBox(width: 4),
                            Text(address, style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${ModiriFormatters.toLatinDigits('$suppliedCount')} ${_loc.get('products')}',
                            style: const TextStyle(color: ModiriColors.brandBlue, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Financial KPI Cards Row (Strict separation between inventory valuation and Accounts Payable)
                  Row(
                    children: [
                      // Stock asset valuation
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ModiriColors.brandBlue.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_loc.get('stock_value'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 10)),
                              const SizedBox(height: 3),
                              Text(
                                _formatCurrency(stockValuation),
                                style: const TextStyle(color: ModiriColors.brandBlue, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 2),
                              Text(_loc.get('shelf_assets'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Total Invoiced
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandTeal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_loc.get('total_invoiced'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 10)),
                              const SizedBox(height: 3),
                              Text(
                                _formatCurrency(totalPurchases),
                                style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 2),
                              Text('${ModiriFormatters.toLatinDigits('${purchases.length}')} ${_loc.get('invoices_count')}', style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Total Paid
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ModiriColors.brandGreen.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_loc.get('total_paid_supplier'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 10)),
                              const SizedBox(height: 3),
                              Text(
                                _formatCurrency(totalPaid),
                                style: const TextStyle(color: ModiriColors.brandGreen, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 2),
                              Text('${ModiriFormatters.toLatinDigits('${payments.length}')} ${_loc.get('payments_count')}', style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Outstanding Debt
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (outstandingDebt > 0 ? ModiriColors.brandRose : ModiriColors.brandGreen).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: (outstandingDebt > 0 ? ModiriColors.brandRose : ModiriColors.brandGreen).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_loc.get('supplier_debt'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text(
                                _formatCurrency(outstandingDebt),
                                style: TextStyle(
                                  color: outstandingDebt > 0 ? ModiriColors.brandRose : ModiriColors.brandGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                outstandingDebt > 0 ? _loc.get('remaining_debt_is') : _loc.get('paid'),
                                style: TextStyle(color: outstandingDebt > 0 ? ModiriColors.brandRose : ModiriColors.brandGreen, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_loc.get('purchases_payments_history'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.document_scanner_outlined, size: 16, color: ModiriColors.brandBlue),
                            label: Text(_loc.get('scan_purchase_invoice')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (sCtx) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(24),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Scaffold(
                                      appBar: AppBar(
                                        title: Text(_loc.get('scan_purchase_invoice')),
                                        leading: IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () => Navigator.of(sCtx).pop(),
                                        ),
                                      ),
                                      body: DesktopAiInvoiceScannerScreen(
                                        initialMode: InvoiceScanMode.purchase,
                                        onImportToCart: (scannedItems, _) {
                                          reloadData(setDialogState);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ).then((_) {
                                reloadData(setDialogState);
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.post_add, size: 16),
                            label: Text(_loc.get('new_purchase_invoice')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ModiriColors.brandTeal,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _showRecordSupplyPurchaseDialog(supplier, () {
                              reloadData(setDialogState);
                            }),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.payments_outlined, size: 16),
                            label: Text(_loc.get('record_payment')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: outstandingDebt > 0 ? ModiriColors.brandAmber : Colors.grey,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: outstandingDebt > 0
                                ? () => _showRecordSupplierPaymentDialog(supplier, outstandingDebt, () {
                                      reloadData(setDialogState);
                                    })
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tabbed Ledger View
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: ModiriColors.brandBlue,
                            unselectedLabelColor: ModiriColors.textMuted(isDark),
                            indicatorColor: ModiriColors.brandBlue,
                            tabs: [
                              Tab(text: '${_loc.get("purchase_history")} (${purchases.length})'),
                              Tab(text: '${_loc.get("payment_history")} (${payments.length})'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Tab 1: Purchases
                                purchases.isEmpty
                                    ? Center(
                                        child: Text(
                                          _loc.get('no_invoices_found'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: purchases.length,
                                        separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                                        itemBuilder: (_, idx) {
                                          final p = purchases[idx];
                                          final total = _parseDouble(p['total_amount']);
                                          final paid = _parseDouble(p['amount_paid'] ?? p['paid_amount']);
                                          final remaining = _parseDouble(p['outstanding_balance'] ?? p['remaining_balance']);
                                          final invNo = p['invoice_number']?.toString() ?? 'N/A';
                                          final dateStr = p['purchase_date']?.toString() ?? '';
                                          final status = p['payment_status']?.toString() ?? 'unpaid';

                                          Color statusColor = ModiriColors.brandRose;
                                          String statusLabel = _loc.get('unpaid');
                                          if (status == 'paid') {
                                            statusColor = ModiriColors.brandGreen;
                                            statusLabel = _loc.get('paid');
                                          } else if (status == 'partial') {
                                            statusColor = ModiriColors.brandAmber;
                                            statusLabel = _loc.get('partial');
                                          }

                                          return ListTile(
                                            dense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            leading: const Icon(Icons.receipt_long, color: ModiriColors.brandTeal, size: 20),
                                            title: Row(
                                              children: [
                                                Text(invNo, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12, fontWeight: FontWeight.bold)),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                            subtitle: Text(
                                              '${_loc.get("date")}: ${ModiriFormatters.toLatinDigits(dateStr)} • ${_loc.get("paid")}: ${_formatCurrency(paid)} ${p['notes'] != null && p['notes'].toString().isNotEmpty ? '• ${p['notes']}' : ''}',
                                              style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11),
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _formatCurrency(total),
                                                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                                                ),
                                                Text(
                                                  remaining > 0 ? '${_loc.get("balance")}: ${_formatCurrency(remaining)}' : _loc.get('paid'),
                                                  style: TextStyle(
                                                    color: remaining > 0 ? ModiriColors.brandRose : ModiriColors.brandGreen,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                // Tab 2: Payments
                                payments.isEmpty
                                    ? Center(
                                        child: Text(
                                          _loc.get('no_debtors'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: payments.length,
                                        separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                                        itemBuilder: (_, idx) {
                                          final pay = payments[idx];
                                          final amt = _parseDouble(pay['amount']);
                                          final dateStr = pay['payment_date']?.toString() ?? '';
                                          final method = pay['payment_method']?.toString() ?? 'cash';
                                          final refStr = pay['reference']?.toString();
                                          final notesStr = pay['notes']?.toString();

                                          String methodLabel = _loc.get('cash');
                                          if (method == 'bank_transfer') methodLabel = _loc.get('bank_transfer');
                                          if (method == 'check') methodLabel = _loc.get('check');

                                          return ListTile(
                                            dense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            leading: const Icon(Icons.check_circle_outline, color: ModiriColors.brandGreen, size: 20),
                                            title: Text(
                                              '${_loc.get("payment_method")}: $methodLabel',
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text(
                                              '${_loc.get("date")}: ${ModiriFormatters.toLatinDigits(dateStr)} ${refStr != null ? '• Réf: $refStr' : ''} ${notesStr != null ? '• $notesStr' : ''}',
                                              style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11),
                                            ),
                                            trailing: Text(
                                              _formatCurrency(amt),
                                              style: const TextStyle(color: ModiriColors.brandGreen, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                                            ),
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(_loc.get('close'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordSupplyPurchaseDialog(Map<String, dynamic> supplier, VoidCallback onAdded) {
    final refCtrl = TextEditingController(text: 'SUP-INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final amtCtrl = TextEditingController();
    final paidCtrl = TextEditingController(text: '0');
    final itemsCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String paymentMethod = 'cash';
    DateTime chosenDate = DateTime.now();

    showDialog(
      context: context,
      builder: (pCtx) {
        final isDark = Theme.of(pCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dCtx, setDialogState) => AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('${_loc.get('new_purchase_invoice_for')} ${supplier["name"]}',
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.document_scanner_outlined, size: 16, color: ModiriColors.brandBlue),
                  label: Text(_loc.get('scan_purchase_invoice'), style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (sCtx) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Scaffold(
                            appBar: AppBar(
                              title: Text(_loc.get('scan_purchase_invoice')),
                              leading: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(sCtx).pop(),
                              ),
                            ),
                            body: DesktopAiInvoiceScannerScreen(
                              initialMode: InvoiceScanMode.purchase,
                              onImportToCart: (scannedItems, vendorName) {
                                if (scannedItems.isNotEmpty) {
                                  double totalSum = 0.0;
                                  final itemNames = <String>[];
                                  for (final it in scannedItems) {
                                    totalSum += it.lineTotal;
                                    if (it.nameController.text.trim().isNotEmpty) {
                                      itemNames.add(it.nameController.text.trim());
                                    }
                                  }
                                  setDialogState(() {
                                    amtCtrl.text = totalSum.toStringAsFixed(2);
                                    paidCtrl.text = totalSum.toStringAsFixed(2);
                                    if (itemNames.isNotEmpty) {
                                      itemsCtrl.text = itemNames.join(', ');
                                      qtyCtrl.text = scannedItems.length.toString();
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: refCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('supplier_invoice_ref_label'), prefixIcon: const Icon(Icons.tag)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amtCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('supplier_invoice_total_label'), prefixIcon: const Icon(Icons.payments_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: paidCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('downpayment_immediate_label'), prefixIcon: const Icon(Icons.price_check_outlined)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: InputDecoration(labelText: _loc.get('downpayment_method_label'), prefixIcon: const Icon(Icons.credit_card)),
                      items: [
                        DropdownMenuItem(value: 'cash', child: Text(_loc.get('cash'))),
                        DropdownMenuItem(value: 'bank_transfer', child: Text(_loc.get('bank_transfer'))),
                        DropdownMenuItem(value: 'check', child: Text(_loc.get('check'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => paymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemsCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('goods_designation_label'), prefixIcon: const Icon(Icons.inventory_2_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('quantity'), prefixIcon: const Icon(Icons.numbers_outlined)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: pCtx,
                          initialDate: chosenDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => chosenDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: _loc.get('purchase_receipt_date_label'), prefixIcon: const Icon(Icons.calendar_today)),
                        child: Text(DateFormat('yyyy-MM-dd').format(chosenDate),
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(pCtx).pop(),
                child: Text(_loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                onPressed: () async {
                  final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                  final paid = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
                  final refNo = refCtrl.text.trim();
                  if (amt <= 0 || refNo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_loc.get('enter_valid_amount_invoice')), backgroundColor: ModiriColors.brandRose),
                    );
                    return;
                  }

                  if (paid < 0 || paid > amt) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_loc.get('downpayment_exceeds_total_error')), backgroundColor: ModiriColors.brandRose),
                    );
                    return;
                  }

                  Navigator.of(pCtx).pop();

                  final companyId = supplier['company_id']?.toString() ?? ref.read(sessionProvider).companyId ?? 'default_company';
                  final supplierId = supplier['id']?.toString() ?? '';
                  final itemsDesc = itemsCtrl.text.trim();
                  final dateStr = DateFormat('yyyy-MM-dd').format(chosenDate);
                  final purchaseId = const Uuid().v4();
                  final clientTxId = const Uuid().v4();
                  final remaining = amt - paid;
                  final paymentStatus = paid == 0 ? 'unpaid' : (paid >= amt ? 'paid' : 'partial');

                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                  final validQty = qty > 0 ? qty : 1.0;
                  final unitCost = amt / validQty;

                  try {
                    final db = await ModiriDesktopDatabase.instance.database;
                    // Insert purchase record into local SQLite
                    await db.insert('supplier_purchases', {
                      'id': purchaseId,
                      'company_id': companyId,
                      'supplier_id': supplierId,
                      'invoice_number': refNo,
                      'purchase_date': dateStr,
                      'total_amount': amt,
                      'amount_paid': paid,
                      'outstanding_balance': remaining,
                      'payment_status': paymentStatus,
                      'notes': itemsDesc.isNotEmpty ? itemsDesc : null,
                      'client_transaction_id': clientTxId,
                      'created_at': DateTime.now().toIso8601String(),
                      'synced': 0,
                    });

                    // Insert purchase item row with accurate quantity and calculated unit cost
                    await db.insert('supplier_purchase_items', {
                      'id': const Uuid().v4(),
                      'company_id': companyId,
                      'purchase_id': purchaseId,
                      'product_name': itemsDesc.isNotEmpty ? itemsDesc : _loc.get('goods_purchased'),
                      'quantity': validQty,
                      'unit_cost': unitCost,
                      'line_total': amt,
                      'created_at': DateTime.now().toIso8601String(),
                    });

                    // Auto-increment inventory stock if purchase description matches an existing catalog product or kitchen ingredient
                    if (itemsDesc.isNotEmpty) {
                      try {
                        final matchingProducts = await db.query(
                          'products',
                          where: 'company_id = ? AND LOWER(TRIM(name)) = ?',
                          whereArgs: [companyId, itemsDesc.toLowerCase()],
                          limit: 1,
                        );
                        if (matchingProducts.isNotEmpty) {
                          final prod = matchingProducts.first;
                          final curStock = _parseInt(prod['stock_quantity']);
                          await db.update(
                            'products',
                            {
                              'stock_quantity': curStock + validQty.toInt(),
                              'cost_price': unitCost > 0 ? unitCost : (prod['cost_price'] ?? 0.0),
                              'updated_at': DateTime.now().toIso8601String(),
                            },
                            where: 'id = ? AND company_id = ?',
                            whereArgs: [prod['id'], companyId],
                          );
                        }

                        final matchingIngredients = await db.query(
                          'restaurant_inventory_items',
                          where: 'company_id = ? AND LOWER(TRIM(name)) = ?',
                          whereArgs: [companyId, itemsDesc.toLowerCase()],
                          limit: 1,
                        );
                        if (matchingIngredients.isNotEmpty) {
                          final ing = matchingIngredients.first;
                          final curStock = _parseDouble(ing['current_stock']);
                          await db.update(
                            'restaurant_inventory_items',
                            {
                              'current_stock': curStock + validQty,
                              'cost_per_unit': unitCost > 0 ? unitCost : (ing['cost_per_unit'] ?? 0.0),
                              'updated_at': DateTime.now().toIso8601String(),
                            },
                            where: 'id = ? AND company_id = ?',
                            whereArgs: [ing['id'], companyId],
                          );
                        }
                      } catch (_) {}
                    }

                    // If downpayment was paid immediately, record initial payment locally
                    if (paid > 0) {
                      await db.insert('supplier_payments', {
                        'id': const Uuid().v4(),
                        'company_id': companyId,
                        'supplier_id': supplierId,
                        'purchase_id': purchaseId,
                        'amount': paid,
                        'payment_date': dateStr,
                        'payment_method': paymentMethod,
                        'reference': 'Acompte $refNo',
                        'notes': itemsDesc.isNotEmpty ? itemsDesc : null,
                        'created_at': DateTime.now().toIso8601String(),
                        'synced': 0,
                      });
                    }

                    // Enqueue offline sync operation
                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: clientTxId,
                      entityType: 'supplier_purchase',
                      entityId: purchaseId,
                      operationType: 'CREATE',
                      payload: {
                        'supplierId': supplierId,
                        'invoiceNumber': refNo,
                        'purchaseDate': dateStr,
                        'totalAmount': amt,
                        'amountPaidNow': paid,
                        'paymentMethod': paymentMethod,
                        'notes': itemsDesc,
                        'items': [
                          {
                            'productName': itemsDesc.isNotEmpty ? itemsDesc : 'Achat marchandises',
                            'quantity': validQty,
                            'unitCost': unitCost,
                          }
                        ],
                      },
                    );

                    onAdded();
                    await _loadSuppliers();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${_loc.get('purchase_invoice_recorded')} (${_formatCurrency(amt)}) !'),
                          backgroundColor: ModiriColors.brandTeal,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${_loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                      );
                    }
                  }
                },
                child: Text(_loc.get('save_purchase_invoice')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRecordSupplierPaymentDialog(Map<String, dynamic> supplier, double currentDebt, VoidCallback onAdded) {
    final amtCtrl = TextEditingController(text: currentDebt.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = 'cash';
    DateTime chosenDate = DateTime.now();

    showDialog(
      context: context,
      builder: (pCtx) {
        final isDark = Theme.of(pCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dCtx, setDialogState) => AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('${_loc.get('settle_supplier_debt_title')} ${supplier["name"]}',
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ModiriColors.brandRose.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_loc.get('remaining_debt_to_pay'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(
                            _formatCurrency(currentDebt),
                            style: const TextStyle(color: ModiriColors.brandRose, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amtCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('settlement_amount_label'), prefixIcon: const Icon(Icons.payments_outlined)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: InputDecoration(labelText: _loc.get('settlement_method_label'), prefixIcon: const Icon(Icons.credit_card)),
                      dropdownColor: ModiriColors.surface(isDark),
                      items: [
                        DropdownMenuItem(value: 'cash', child: Text(_loc.get('cash'))),
                        DropdownMenuItem(value: 'bank_transfer', child: Text(_loc.get('bank_transfer'))),
                        DropdownMenuItem(value: 'check', child: Text(_loc.get('check'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => paymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: refCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('settlement_ref_label'), prefixIcon: const Icon(Icons.receipt_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                      decoration: InputDecoration(labelText: _loc.get('optional_note_label'), prefixIcon: const Icon(Icons.notes_outlined)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: pCtx,
                          initialDate: chosenDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => chosenDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: _loc.get('settlement_date_label'), prefixIcon: const Icon(Icons.calendar_today)),
                        child: Text(DateFormat('yyyy-MM-dd').format(chosenDate),
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(pCtx).pop(),
                child: Text(_loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandGreen),
                onPressed: () async {
                  final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                  if (amt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_loc.get('enter_valid_payment_amount')), backgroundColor: ModiriColors.brandRose),
                    );
                    return;
                  }

                  if (amt > currentDebt + 0.001) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_loc.get('payment_cannot_exceed_debt')} (${_formatCurrency(currentDebt)}).'), backgroundColor: ModiriColors.brandRose),
                    );
                    return;
                  }

                  Navigator.of(pCtx).pop();

                  final companyId = supplier['company_id']?.toString() ?? ref.read(sessionProvider).companyId ?? 'default_company';
                  final supplierId = supplier['id']?.toString() ?? '';
                  final refStr = refCtrl.text.trim();
                  final notesStr = notesCtrl.text.trim();
                  final dateStr = DateFormat('yyyy-MM-dd').format(chosenDate);
                  final paymentId = const Uuid().v4();
                  final clientTxId = const Uuid().v4();

                  try {
                    final db = await ModiriDesktopDatabase.instance.database;

                    // Apply FIFO allocation to unpaid purchases in SQLite
                    final unpaidPurchases = await db.query(
                      'supplier_purchases',
                      where: 'company_id = ? AND supplier_id = ? AND outstanding_balance > 0',
                      whereArgs: [companyId, supplierId],
                      orderBy: 'purchase_date ASC, created_at ASC',
                    );

                    double remainingToAllocate = amt;
                    for (final p in unpaidPurchases) {
                      if (remainingToAllocate <= 0) break;
                      final pId = p['id']?.toString() ?? '';
                      final pPaid = _parseDouble(p['amount_paid'] ?? p['paid_amount']);
                      final pRemaining = _parseDouble(p['outstanding_balance'] ?? p['remaining_balance']);

                      final alloc = remainingToAllocate < pRemaining ? remainingToAllocate : pRemaining;
                      final newPaid = pPaid + alloc;
                      final newRemaining = pRemaining - alloc;
                      final newStatus = newRemaining <= 0.001 ? 'paid' : 'partial';

                      await db.update(
                        'supplier_purchases',
                        {
                          'amount_paid': newPaid,
                          'outstanding_balance': newRemaining < 0 ? 0 : newRemaining,
                          'payment_status': newStatus,
                        },
                        where: 'id = ?',
                        whereArgs: [pId],
                      );
                      remainingToAllocate -= alloc;
                    }

                    // Record payment row
                    await db.insert('supplier_payments', {
                      'id': paymentId,
                      'company_id': companyId,
                      'supplier_id': supplierId,
                      'purchase_id': null,
                      'amount': amt,
                      'payment_date': dateStr,
                      'payment_method': paymentMethod,
                      'reference': refStr.isNotEmpty ? refStr : null,
                      'notes': notesStr.isNotEmpty ? notesStr : null,
                      'client_id': clientTxId,
                      'created_at': DateTime.now().toIso8601String(),
                      'synced': 0,
                    });

                    // Enqueue offline sync operation
                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: clientTxId,
                      entityType: 'supplier_payment',
                      entityId: paymentId,
                      operationType: 'CREATE',
                      payload: {
                        'supplierId': supplierId,
                        'amount': amt,
                        'paymentDate': dateStr,
                        'paymentMethod': paymentMethod,
                        'reference': refStr,
                        'notes': notesStr,
                      },
                    );

                    onAdded();
                    await _loadSuppliers();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${_loc.get('payment_recorded_success')} (${_formatCurrency(amt)})'),
                          backgroundColor: ModiriColors.brandGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${_loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                      );
                    }
                  }
                },
                child: Text(_loc.get('confirm_settlement')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSupplier(Map<String, dynamic> supplier) async {
    final name = supplier['name']?.toString() ?? 'Supplier';
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
          title: Text(_loc.get('delete_supplier'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${_loc.get('confirm_remove_supplier')} "$name"?',
              style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(_loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(_loc.get('delete')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final id = supplier['id']?.toString() ?? '';
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'supplier',
          entityId: id,
          operationType: 'DELETE',
          payload: {'id': id},
        );

        await _loadSuppliers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_loc.get('removed_prefix')} "$name".'), backgroundColor: ModiriColors.brandTeal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _suppliers.where((s) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final phone = (s['phone'] ?? '').toString().toLowerCase();
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.get('suppliers_title'),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.get('suppliers_subtitle'),
                      style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.document_scanner_outlined, size: 16, color: ModiriColors.brandBlue),
                    label: Text(loc.get('ai_scanner')),
                    onPressed: () {
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
                              body: const DesktopAiInvoiceScannerScreen(initialMode: InvoiceScanMode.purchase),
                            ),
                          ),
                        ),
                      ).then((_) => _loadSuppliers());
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadSuppliers,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_business_outlined, size: 16),
                    label: Text(loc.get('add_supplier')),
                    onPressed: _showAddSupplierDialog,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
            decoration: InputDecoration(
              hintText: _loc.get('search_suppliers_hint'),
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
                          child: Text(loc.get('no_suppliers_listed'),
                              style: TextStyle(color: ModiriColors.textMuted(isDark))),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: ModiriColors.border(isDark), height: 1),
                          itemBuilder: (ctx, i) {
                            final s = filtered[i];
                            final name = s['name']?.toString() ?? loc.get('supplier');
                            final phone = s['phone']?.toString() ?? loc.get('no_phone_listed');

                            final address = s['address']?.toString();
                            final supplied = _parseInt(s['products_supplied']);
                            final debt = _parseDouble(s['outstanding_balance']);

                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _showSupplierDetailsDialog(s),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: ModiriColors.card(isDark),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.local_shipping_outlined,
                                          color: ModiriColors.brandBlue, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(name,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        color: ModiriColors.textPrimary(isDark),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600)),
                                              ),
                                              if (supplied > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ModiriColors.brandBlue.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text('${ModiriFormatters.toLatinDigits('$supplied')} ${loc.get("products")}',
                                                      style: const TextStyle(color: ModiriColors.brandBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                              if (debt > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ModiriColors.brandRose.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
                                                  ),
                                                  child: Text(
                                                    '${loc.get("debt")}: ${_formatCurrency(debt)}',
                                                    style: const TextStyle(color: ModiriColors.brandRose, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            ModiriFormatters.toLatinDigits(phone) + (address != null && address.isNotEmpty ? ' • $address' : ''),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.person_outline, size: 19, color: ModiriColors.brandBlue),
                                          tooltip: loc.get('supplier_profile'),
                                          onPressed: () => _showSupplierDetailsDialog(s),
                                        ),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.receipt_long_outlined, size: 15),
                                          label: Text(loc.get('purchases_and_debts')),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () => _showSupplierDetailsDialog(s),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, size: 19, color: ModiriColors.textSecondary(isDark)),
                                          tooltip: _loc.get('edit_supplier'),
                                          onPressed: () => _showEditSupplierDialog(s),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 19, color: ModiriColors.brandRose),
                                          tooltip: _loc.get('delete_supplier'),
                                          onPressed: () => _confirmDeleteSupplier(s),
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
