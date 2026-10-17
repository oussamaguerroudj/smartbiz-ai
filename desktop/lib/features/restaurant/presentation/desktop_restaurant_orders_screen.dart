import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../../core/utils/receipt_printer.dart';
import '../../ai/presentation/desktop_ai_invoice_scanner_screen.dart';

class DesktopRestaurantOrdersScreen extends ConsumerStatefulWidget {
  const DesktopRestaurantOrdersScreen({super.key});

  @override
  ConsumerState<DesktopRestaurantOrdersScreen> createState() => _DesktopRestaurantOrdersScreenState();
}

class _DesktopRestaurantOrdersScreenState extends ConsumerState<DesktopRestaurantOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  late final TabController _tabController;
  ModiriLocalizations get _loc => ModiriLocalizations(ref.read(desktopLocaleProvider));

  bool _isLoading = true;
  List<dynamic> _orders = [];
  List<dynamic> _tables = [];
  List<dynamic> _menuItems = [];
  List<dynamic> _reservations = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRestaurantData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch tables, orders, and reservations from local SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final localTables = await db.query(
        'restaurant_tables',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      final localOrders = await db.query(
        'restaurant_orders',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'created_at DESC',
      );
      final localReservations = await db.query(
        'restaurant_reservations',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'reserved_at ASC',
      );
      if (mounted && (localTables.isNotEmpty || localOrders.isNotEmpty || localReservations.isNotEmpty)) {
        setState(() {
          if (localTables.isNotEmpty) {
            _tables = localTables.map((t) => {
              'id': t['id'],
              'name': t['name'],
              'seats': t['seats'],
              'status': t['status'],
            }).toList();
          }
          if (localOrders.isNotEmpty) {
            _orders = localOrders.map((o) {
              final total = (o['total'] as num?)?.toDouble() ?? 0.0;
              final amountPaid = (o['amount_paid'] as num?)?.toDouble() ?? 0.0;
              final paymentStatus = o['payment_status']?.toString() ??
                  (amountPaid >= total && total > 0 ? 'paid' : amountPaid > 0 ? 'partially_paid' : 'unpaid');
              return {
                'id': o['id'],
                'tableName': o['table_name'],
                'table_label': o['table_name'],
                'status': o['status'],
                'total': total,
                'amount_paid': amountPaid,
                'payment_status': paymentStatus,
                'customer_name': o['customer_name'],
                'customer_phone': o['customer_phone'],
                'order_type': o['order_type'],
                'notes': o['notes'],
                'items': jsonDecode(o['items_json'] as String? ?? '[]'),
                'created_at': o['created_at'],
              };
            }).toList();
          }
          if (localReservations.isNotEmpty) {
            _reservations = List<dynamic>.from(localReservations);
          }
          _isLoading = false;
        });
      }
    } catch (_) {}

    try {
      final client = ref.read(apiClientProvider);
      final res = await Future.wait([
        client.get('/restaurant/orders').catchError((_) => []),
        client.get('/restaurant/tables').catchError((_) => []),
        client.get('/restaurant/menu-items').catchError((_) => []),
        client.get('/restaurant/reservations').catchError((_) => []),
      ]);

      final oList = res[0] is List ? res[0] : (res[0] is Map ? (res[0]['data'] ?? []) : []);
      final tList = res[1] is List ? res[1] : (res[1] is Map ? (res[1]['data'] ?? []) : []);
      var mList = res[2] is List ? res[2] : (res[2] is Map ? (res[2]['data'] ?? []) : []);
      final rList = res[3] is List ? res[3] : (res[3] is Map ? (res[3]['data'] ?? []) : []);

      // Cache tables, orders, and reservations to local SQLite while preserving pending sync operations
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        final pendingOps = await db.query(
          'sync_queue',
          where: "entity_type IN ('restaurant_table', 'restaurant_order', 'restaurant_reservation') AND status = 'pending'",
        );
        final pendingIds = pendingOps.map((r) => r['entity_id']?.toString()).whereType<String>().toSet();

        final batch = db.batch();
        for (final item in tList) {
          final t = Map<String, dynamic>.from(item as Map);
          final id = t['id']?.toString() ?? const Uuid().v4();
          if (pendingIds.contains(id)) continue;
          batch.insert(
            'restaurant_tables',
            {
              'id': id,
              'company_id': companyId,
              'name': t['name'] ?? t['label'] ?? 'Table',
              'seats': (t['seats'] as num?)?.toInt() ?? 4,
              'status': t['status'] ?? 'available',
              'created_at': DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final item in oList) {
          final o = Map<String, dynamic>.from(item as Map);
          final id = o['id']?.toString() ?? const Uuid().v4();
          if (pendingIds.contains(id)) continue;
          final total = (o['total'] as num?)?.toDouble() ?? (o['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final amountPaid = (o['amount_paid'] as num?)?.toDouble() ?? (o['amountPaid'] as num?)?.toDouble() ?? 0.0;
          final paymentStatus = o['payment_status'] ?? o['paymentStatus'] ??
              (amountPaid >= total && total > 0 ? 'paid' : amountPaid > 0 ? 'partially_paid' : 'unpaid');
          batch.insert(
            'restaurant_orders',
            {
              'id': id,
              'company_id': companyId,
              'table_name': o['tableName'] ?? o['table_label'] ?? 'Takeaway',
              'items_json': jsonEncode(o['items'] ?? []),
              'status': o['status'] ?? 'preparing',
              'total': total,
              'amount_paid': amountPaid,
              'payment_status': paymentStatus,
              'customer_name': o['customerName'] ?? o['customer_name'],
              'customer_phone': o['customerPhone'] ?? o['customer_phone'],
              'order_type': o['orderType'] ?? o['order_type'] ?? 'dine_in',
              'notes': o['notes'] ?? '',
              'created_at': o['createdAt'] ?? o['created_at'] ?? DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final item in rList) {
          final r = Map<String, dynamic>.from(item as Map);
          final id = r['id']?.toString() ?? const Uuid().v4();
          if (pendingIds.contains(id)) continue;
          batch.insert(
            'restaurant_reservations',
            {
              'id': id,
              'company_id': companyId,
              'customer_name': r['customerName'] ?? r['customer_name'] ?? 'Guest',
              'phone': r['phone'] ?? r['customerPhone'],
              'party_size': ((r['partySize'] ?? r['party_size'] ?? 2) as num).toInt(),
              'table_id': r['tableId'] ?? r['table_id'],
              'table_name': r['tableName'] ?? r['table_name'],
              'reserved_at': r['reservedAt'] ?? r['reserved_at'] ?? DateTime.now().toIso8601String(),
              'status': r['status'] ?? 'pending',
              'notes': r['notes'] ?? '',
              'created_at': r['createdAt'] ?? r['created_at'] ?? DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);

        final freshTables = await db.query(
          'restaurant_tables',
          where: 'company_id = ?',
          whereArgs: [companyId],
          orderBy: 'name ASC',
        );
        final freshOrders = await db.query(
          'restaurant_orders',
          where: 'company_id = ?',
          whereArgs: [companyId],
          orderBy: 'created_at DESC',
        );
        final freshReservations = await db.query(
          'restaurant_reservations',
          where: 'company_id = ?',
          whereArgs: [companyId],
          orderBy: 'reserved_at ASC',
        );
        if (freshTables.isNotEmpty) {
          tList.clear();
          tList.addAll(freshTables.map((t) => {
            'id': t['id'],
            'name': t['name'],
            'seats': t['seats'],
            'status': t['status'],
          }));
        }
        if (freshOrders.isNotEmpty) {
          oList.clear();
          oList.addAll(freshOrders.map((o) {
            final total = (o['total'] as num?)?.toDouble() ?? 0.0;
            final amountPaid = (o['amount_paid'] as num?)?.toDouble() ?? 0.0;
            final paymentStatus = o['payment_status']?.toString() ??
                (amountPaid >= total && total > 0 ? 'paid' : amountPaid > 0 ? 'partially_paid' : 'unpaid');
            return {
              'id': o['id'],
              'tableName': o['table_name'],
              'table_label': o['table_name'],
              'status': o['status'],
              'total': total,
              'amount_paid': amountPaid,
              'payment_status': paymentStatus,
              'customer_name': o['customer_name'],
              'customer_phone': o['customer_phone'],
              'order_type': o['order_type'],
              'notes': o['notes'],
              'items': jsonDecode(o['items_json'] as String? ?? '[]'),
              'created_at': o['created_at'],
            };
          }));
        }
        if (freshReservations.isNotEmpty) {
          rList.clear();
          rList.addAll(freshReservations);
        }
      } catch (_) {}

      // If menu items from backend are empty, fall back to SQLite products (matching Mobile RestaurantRepository)
      if (mList.isEmpty) {
        try {
          final db = await ModiriDesktopDatabase.instance.database;
          final localProducts = await db.query(
            'products',
            where: 'company_id = ?',
            whereArgs: [companyId],
            orderBy: 'name ASC',
          );
          mList = localProducts.map((p) => {
            'id': p['id'],
            'name': p['name'],
            'category': p['category'] ?? 'Menu Item',
            'price': p['price'] ?? 0.0,
            'prep_time': '10m',
          }).toList();
        } catch (_) {}
      }

      setState(() {
        _orders = List<dynamic>.from(oList is List ? oList : []);
        _tables = List<dynamic>.from(tList is List ? tList : []);
        _menuItems = List<dynamic>.from(mList is List ? mList : []);
        _reservations = List<dynamic>.from(rList is List ? rList : []);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted && _orders.isEmpty && _tables.isEmpty) {
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

  Future<void> _updateOrderStatus(String id, String status) async {
    try {
      final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
      final db = await ModiriDesktopDatabase.instance.database;
      final existingRows = await db.query('restaurant_orders', where: 'id = ?', whereArgs: [id], limit: 1);
      if (existingRows.isEmpty) return;

      final orderRow = existingRows.first;
      final total = (orderRow['total'] as num?)?.toDouble() ?? 0.0;
      final amountPaid = (orderRow['amount_paid'] as num?)?.toDouble() ?? 0.0;
      final paymentStatus = (orderRow['payment_status'] ?? '').toString();
      final remaining = (total - amountPaid).clamp(0.0, double.infinity);

      // Phase 3 Guard: Order cannot be completed if there is an outstanding balance remaining
      if (status == 'completed' && paymentStatus != 'paid' && remaining > 0.01) {
        if (mounted) {
          _showUnpaidCompletionGuard(orderRow);
        }
        return;
      }

      await db.update('restaurant_orders', {'status': status, 'synced': 0}, where: 'id = ?', whereArgs: [id]);

      // Free dining table when order is completed or cancelled
      if (status == 'completed' || status == 'cancelled') {
        final tableLabel = orderRow['table_name']?.toString();
        if (tableLabel != null && !tableLabel.toLowerCase().contains('takeaway')) {
          await db.update(
            'restaurant_tables',
            {'status': 'available', 'synced': 0},
            where: 'name = ? AND company_id = ?',
            whereArgs: [tableLabel, companyId],
          );
        }
      }

      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: const Uuid().v4(),
        entityType: 'restaurant_order',
        entityId: id,
        operationType: 'UPDATE',
        payload: {'status': status},
      );
      _loadRestaurantData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_loc.get('restaurant_status_update_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  void _showUnpaidCompletionGuard(Map<String, dynamic> orderRow) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = (orderRow['total'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (orderRow['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = (total - amountPaid).clamp(0.0, double.infinity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ModiriColors.border(isDark)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ModiriColors.brandAmber, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(loc.get('cannot_complete_unpaid'),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.get('order_not_paid_warning'),
                style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
            const SizedBox(height: 12),
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
                  Text(loc.get('remaining_balance'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    _formatCurrency(remaining),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ModiriColors.brandRose, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.get('cancel')),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
            icon: const Icon(Icons.payments_outlined, size: 16),
            label: Text(loc.get('record_payment')),
            onPressed: () {
              Navigator.of(ctx).pop();
              _showPaymentModal(orderRow);
            },
          ),
        ],
      ),
    );
  }

  void _showAddDishesModal(Map<String, dynamic> order) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final messenger = ScaffoldMessenger.of(context);
    final orderId = order['id']?.toString() ?? '';
    final tableName = order['tableName'] ?? order['table_label'] ?? 'Table';
    final existingItems = List<Map<String, dynamic>>.from(
      (order['items'] as List? ?? []).map((it) => Map<String, dynamic>.from(it as Map)),
    );
    final existingTotal = (order['total'] as num?)?.toDouble() ?? 0.0;
    final amountPaid = (order['amount_paid'] as num?)?.toDouble() ?? 0.0;

    final Map<String, Map<String, dynamic>> additionalCart = {};
    final customPriceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            double calculateAdditionalTotal() {
              double sum = 0.0;
              for (final entry in additionalCart.values) {
                final item = entry['item'] as Map<String, dynamic>;
                final qty = (entry['quantity'] as num).toInt();
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                sum += price * qty;
              }
              final custom = double.tryParse(customPriceCtrl.text.trim()) ?? 0.0;
              return sum + custom;
            }

            final additionalTotal = calculateAdditionalTotal();
            final newTotal = existingTotal + additionalTotal;

            return AlertDialog(
              backgroundColor: ModiriColors.surface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ModiriColors.border(isDark)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.restaurant_menu, color: ModiriColors.brandAmber, size: 22),
                  const SizedBox(width: 8),
                  Text('${loc.get("add_dishes")} · $tableName',
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Order Items
                      Text('${loc.get("selected_order_items")} (${existingItems.length})',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.textPrimary(isDark))),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ModiriColors.card(isDark),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ModiriColors.border(isDark)),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: existingItems.length,
                          itemBuilder: (ctx, idx) {
                            final it = existingItems[idx];
                            final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                            final price = (it['unitPrice'] as num?)?.toDouble() ?? (it['price'] as num?)?.toDouble() ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${qty}x ${it['name']}', style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark))),
                                  Text(_formatCurrency(price * qty), style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dish Picker Section
                      Text(loc.get('pick_dishes_menu'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.textPrimary(isDark))),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        decoration: BoxDecoration(
                          color: ModiriColors.card(isDark),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ModiriColors.border(isDark)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _menuItems.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: ModiriColors.border(isDark)),
                          itemBuilder: (context, i) {
                            final dish = Map<String, dynamic>.from(_menuItems[i] as Map);
                            final dishName = (dish['name'] ?? 'Dish').toString();
                            final dishPrice = (dish['price'] as num?)?.toDouble() ?? 0.0;
                            final key = dish['id']?.toString() ?? dishName;
                            final currentQty = (additionalCart[key]?['quantity'] as num?)?.toInt() ?? 0;

                            return ListTile(
                              dense: true,
                              title: Text(dishName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ModiriColors.textPrimary(isDark))),
                              subtitle: Text('${_formatCurrency(dishPrice)} • ${dish['category'] ?? 'Menu'}',
                                  style: TextStyle(fontSize: 11, color: ModiriColors.textSecondary(isDark))),
                              trailing: currentQty == 0
                                  ? OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                      icon: const Icon(Icons.add, size: 14),
                                      label: Text(loc.get('add'), style: const TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        setModalState(() {
                                          additionalCart[key] = {'item': dish, 'quantity': 1};
                                        });
                                      },
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 18, color: ModiriColors.brandRose),
                                          onPressed: () {
                                            setModalState(() {
                                              if (currentQty <= 1) {
                                                additionalCart.remove(key);
                                              } else {
                                                additionalCart[key]!['quantity'] = currentQty - 1;
                                              }
                                            });
                                          },
                                        ),
                                        Text('$currentQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 18, color: ModiriColors.brandTeal),
                                          onPressed: () {
                                            setModalState(() {
                                              additionalCart[key]!['quantity'] = currentQty + 1;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: customPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('custom_order_amount')),
                      ),
                      const SizedBox(height: 16),

                      // Grand total display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${loc.get("grand_total")}: ${_formatCurrency(newTotal)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('+ ${_formatCurrency(additionalTotal)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ModiriColors.brandAmber, fontFamily: 'monospace')),
                          ],
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
                  onPressed: additionalTotal <= 0
                      ? null
                      : () async {
                          try {
                            final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                            final updatedItems = List<Map<String, dynamic>>.from(existingItems);

                            for (final entry in additionalCart.values) {
                              final it = entry['item'] as Map<String, dynamic>;
                              final qty = entry['quantity'] as int;
                              final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                              updatedItems.add({
                                'id': it['id'],
                                'name': it['name'] ?? 'Dish',
                                'unitPrice': price,
                                'quantity': qty,
                              });
                            }

                            final custom = double.tryParse(customPriceCtrl.text.trim()) ?? 0.0;
                            if (custom > 0) {
                              updatedItems.add({
                                'name': 'Additional Dishes / Extras',
                                'unitPrice': custom,
                                'quantity': 1,
                              });
                            }

                            final newPaymentStatus = amountPaid >= (newTotal - 0.001)
                                ? 'paid'
                                : (amountPaid > 0 ? 'partially_paid' : 'unpaid');

                            final db = await ModiriDesktopDatabase.instance.database;
                            await db.update(
                              'restaurant_orders',
                              {
                                'items_json': jsonEncode(updatedItems),
                                'total': newTotal,
                                'payment_status': newPaymentStatus,
                                'synced': 0,
                              },
                              where: 'id = ? AND company_id = ?',
                              whereArgs: [orderId, companyId],
                            );

                            await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                              id: const Uuid().v4(),
                              clientTransactionId: const Uuid().v4(),
                              entityType: 'restaurant_order',
                              entityId: orderId,
                              operationType: 'UPDATE',
                              payload: {
                                'items': updatedItems,
                                'total': newTotal,
                              },
                            );

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _loadRestaurantData();

                            messenger.showSnackBar(
                              SnackBar(content: Text(loc.get('dishes_added_success')), backgroundColor: ModiriColors.brandTeal),
                            );
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('${loc.get('restaurant_dish_add_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                              );
                            }
                          }
                        },
                  child: Text(loc.get('add_dishes')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPaymentModal(Map<String, dynamic> order) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final messenger = ScaffoldMessenger.of(context);
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final orderId = order['id']?.toString() ?? '';
    final tableName = order['tableName'] ?? order['table_label'] ?? 'Table';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;

    // Fetch live order and payment history from SQLite
    final db = await ModiriDesktopDatabase.instance.database;
    final orderQuery = await db.query('restaurant_orders', where: 'id = ?', whereArgs: [orderId], limit: 1);
    final freshOrder = orderQuery.isNotEmpty ? orderQuery.first : order;
    final currentPaid = (freshOrder['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = (total - currentPaid).clamp(0.0, double.infinity);

    final paymentRows = await db.query(
      'restaurant_payments',
      where: 'order_id = ? AND company_id = ?',
      whereArgs: [orderId, companyId],
      orderBy: 'paid_at DESC',
    );

    final amountCtrl = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(2) : '0.00');
    final noteCtrl = TextEditingController();
    String selectedMethod = 'cash';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final toPay = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
            return AlertDialog(
              backgroundColor: ModiriColors.surface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ModiriColors.border(isDark)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: ModiriColors.brandTeal, size: 22),
                  const SizedBox(width: 8),
                  Text('${loc.get("split_check")} · $tableName',
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Summary Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ModiriColors.card(isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ModiriColors.border(isDark)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(loc.get('grand_total'), style: TextStyle(fontSize: 11, color: ModiriColors.textSecondary(isDark))),
                                const SizedBox(height: 4),
                                Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                              ],
                            ),
                            Container(width: 1, height: 32, color: ModiriColors.border(isDark)),
                            Column(
                              children: [
                                Text(loc.get('total_paid'), style: TextStyle(fontSize: 11, color: ModiriColors.textSecondary(isDark))),
                                const SizedBox(height: 4),
                                Text(_formatCurrency(currentPaid), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ModiriColors.brandTeal, fontFamily: 'monospace')),
                              ],
                            ),
                            Container(width: 1, height: 32, color: ModiriColors.border(isDark)),
                            Column(
                              children: [
                                Text(loc.get('remaining_balance'), style: TextStyle(fontSize: 11, color: ModiriColors.textSecondary(isDark))),
                                const SizedBox(height: 4),
                                Text(_formatCurrency(remaining), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: remaining > 0 ? ModiriColors.brandRose : ModiriColors.brandTeal, fontFamily: 'monospace')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (remaining > 0) ...[
                        // Quick split presets
                        Text(loc.get('split_check'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ModiriColors.textPrimary(isDark))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: Text(loc.get('pay_full')),
                              onPressed: () {
                                setModalState(() {
                                  amountCtrl.text = remaining.toStringAsFixed(2);
                                });
                              },
                            ),
                            ActionChip(
                              label: Text(loc.get('split_2_ways')),
                              onPressed: () {
                                setModalState(() {
                                  amountCtrl.text = (remaining / 2).toStringAsFixed(2);
                                });
                              },
                            ),
                            ActionChip(
                              label: Text(loc.get('split_3_ways')),
                              onPressed: () {
                                setModalState(() {
                                  amountCtrl.text = (remaining / 3).toStringAsFixed(2);
                                });
                              },
                            ),
                            ActionChip(
                              label: Text(loc.get('split_4_ways')),
                              onPressed: () {
                                setModalState(() {
                                  amountCtrl.text = (remaining / 4).toStringAsFixed(2);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Amount to Pay input
                        TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setModalState(() {}),
                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 14, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: loc.get('amount_to_pay'),
                            prefixText: 'DZD ',
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Payment Method Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedMethod,
                          decoration: InputDecoration(labelText: loc.get('payment_method')),
                          items: [
                            DropdownMenuItem(value: 'cash', child: Text(loc.get('cash'))),
                            DropdownMenuItem(value: 'card', child: Text(loc.get('card'))),
                            DropdownMenuItem(value: 'transfer', child: Text(loc.get('bank_transfer_check'))),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedMethod = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: noteCtrl,
                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                          decoration: InputDecoration(labelText: '${loc.get("notes")} (e.g. Split Guest #1)'),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Payment History Section
                      Text('${loc.get("payment_history")} (${paymentRows.length})',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.textPrimary(isDark))),
                      const SizedBox(height: 8),
                      if (paymentRows.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ModiriColors.card(isDark),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ModiriColors.border(isDark)),
                          ),
                          child: Text(loc.get('order_unpaid'), style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark))),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(
                            color: ModiriColors.card(isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ModiriColors.border(isDark)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: paymentRows.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: ModiriColors.border(isDark)),
                            itemBuilder: (ctx, idx) {
                              final pr = paymentRows[idx];
                              final pAmt = (pr['amount'] as num?)?.toDouble() ?? 0.0;
                              final pMethod = pr['method']?.toString() ?? 'cash';
                              final pDate = pr['paid_at']?.toString() ?? '';
                              final pNote = pr['note']?.toString() ?? '';
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle, size: 16, color: ModiriColors.brandTeal),
                                title: Text('${_formatCurrency(pAmt)} · ${pMethod.toUpperCase()}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ModiriColors.textPrimary(isDark), fontFamily: 'monospace')),
                                subtitle: Text('$pDate${pNote.isNotEmpty ? ' · $pNote' : ''}',
                                    style: TextStyle(fontSize: 10, color: ModiriColors.textSecondary(isDark))),
                              );
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
                if (remaining > 0)
                  ElevatedButton(
                    onPressed: toPay <= 0
                        ? null
                        : () async {
                            try {
                              final paymentId = const Uuid().v4();
                              final nowIso = DateTime.now().toIso8601String();
                              final note = noteCtrl.text.trim();

                              // 1. Insert into restaurant_payments
                              await db.insert('restaurant_payments', {
                                'id': paymentId,
                                'company_id': companyId,
                                'order_id': orderId,
                                'amount': toPay,
                                'method': selectedMethod,
                                'note': note,
                                'paid_at': nowIso,
                                'synced': 0,
                              });

                              // 2. Update restaurant_orders
                              final newPaid = currentPaid + toPay;
                              final newStatus = newPaid >= (total - 0.001)
                                  ? 'paid'
                                  : (newPaid > 0 ? 'partially_paid' : 'unpaid');

                              await db.update(
                                'restaurant_orders',
                                {
                                  'amount_paid': newPaid,
                                  'payment_status': newStatus,
                                  'synced': 0,
                                },
                                where: 'id = ? AND company_id = ?',
                                whereArgs: [orderId, companyId],
                              );

                              // 3. If paid in full, register dining revenue sale row for financial reporting
                              if (newStatus == 'paid' && total > 0) {
                                final saleId = 'REST-$orderId';
                                await db.insert(
                                  'sales',
                                  {
                                    'id': saleId,
                                    'company_id': companyId,
                                    'customer_name': 'Dining ($tableName)',
                                    'payment_method': selectedMethod,
                                    'subtotal': total,
                                    'discount': 0.0,
                                    'total': total,
                                    'paid_amount': total,
                                    'remaining_amount': 0.0,
                                    'created_at': nowIso,
                                    'synced': 1,
                                  },
                                  conflictAlgorithm: ConflictAlgorithm.replace,
                                );
                              }

                              // 4. Enqueue sync
                              await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                                id: const Uuid().v4(),
                                clientTransactionId: const Uuid().v4(),
                                entityType: 'restaurant_payment',
                                entityId: paymentId,
                                operationType: 'CREATE',
                                payload: {
                                  'orderId': orderId,
                                  'amount': toPay,
                                  'method': selectedMethod,
                                  'note': note,
                                },
                              );

                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _loadRestaurantData();

                              messenger.showSnackBar(
                                SnackBar(content: Text(loc.get('payment_recorded_success')), backgroundColor: ModiriColors.brandTeal),
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('${loc.get('restaurant_payment_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                                );
                              }
                            }
                          },
                    child: Text(loc.get('record_payment')),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateTableStatus(String id, String status) async {
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      await db.update('restaurant_tables', {'status': status, 'synced': 0}, where: 'id = ?', whereArgs: [id]);
      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: const Uuid().v4(),
        entityType: 'restaurant_table',
        entityId: id,
        operationType: 'UPDATE',
        payload: {'status': status},
      );
      _loadRestaurantData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_loc.get('restaurant_table_update_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  void _showTableModal({Map<String, dynamic>? table}) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isEditing = table != null;
    final nameCtrl = TextEditingController(text: table?['name']?.toString() ?? 'Table ${_tables.length + 1}');
    final seatsCtrl = TextEditingController(text: table?['seats']?.toString() ?? '4');

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
              Icon(isEditing ? Icons.edit : Icons.table_restaurant, color: ModiriColors.brandTeal, size: 22),
              const SizedBox(width: 8),
              Text(
                isEditing ? loc.get('edit_dining_table') : loc.get('add_dining_table'),
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('table_name_input')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: seatsCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('table_seats_input')),
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
                final seats = int.tryParse(seatsCtrl.text.trim()) ?? 2;
                if (name.isEmpty) return;

                final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

                try {
                  final db = await ModiriDesktopDatabase.instance.database;

                  if (isEditing) {
                    final targetId = table['id'].toString();
                    await db.update(
                      'restaurant_tables',
                      {'name': name, 'seats': seats, 'synced': 0},
                      where: 'id = ?',
                      whereArgs: [targetId],
                    );

                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'restaurant_table',
                      entityId: targetId,
                      operationType: 'UPDATE',
                      payload: {'name': name, 'seats': seats},
                    );
                  } else {
                    final newId = const Uuid().v4();
                    await db.insert('restaurant_tables', {
                      'id': newId,
                      'company_id': companyId,
                      'name': name,
                      'seats': seats,
                      'status': 'available',
                      'created_at': DateTime.now().toIso8601String(),
                      'synced': 0,
                    });

                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'restaurant_table',
                      entityId: newId,
                      operationType: 'CREATE',
                      payload: {'name': name, 'seats': seats},
                    );
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadRestaurantData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('restaurant_table_save_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(isEditing ? loc.get('save_changes') : loc.get('add_table')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTable(String id, String name) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          title: Text(loc.get('delete_table_confirm'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${loc.get('confirm_remove_table')} "$name"?',
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
        await db.delete('restaurant_tables', where: 'id = ?', whereArgs: [id]);
        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'restaurant_table',
          entityId: id,
          operationType: 'DELETE',
          payload: {},
        );
        _loadRestaurantData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_table_error')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  Future<void> _updateReservationStatus(String id, String status) async {
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final existingRows = await db.query('restaurant_reservations', where: 'id = ?', whereArgs: [id], limit: 1);
      await db.update('restaurant_reservations', {'status': status, 'synced': 0}, where: 'id = ?', whereArgs: [id]);

      // If seated and has a table assigned, mark that table as occupied
      if (status == 'seated' && existingRows.isNotEmpty) {
        final r = existingRows.first;
        final tableId = r['table_id']?.toString();
        final tableName = r['table_name']?.toString();
        if (tableId != null && tableId.isNotEmpty) {
          await db.update('restaurant_tables', {'status': 'occupied', 'synced': 0}, where: 'id = ?', whereArgs: [tableId]);
        } else if (tableName != null && tableName.isNotEmpty) {
          await db.update('restaurant_tables', {'status': 'occupied', 'synced': 0}, where: 'name = ?', whereArgs: [tableName]);
        }
      }

      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: const Uuid().v4(),
        entityType: 'restaurant_reservation',
        entityId: id,
        operationType: 'UPDATE',
        payload: {'status': status},
      );
      _loadRestaurantData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_loc.get('restaurant_reservation_update_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  Future<void> _deleteReservation(String id, String customerName) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        title: Text(loc.get('delete_reservation'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
        content: Text('${loc.get('confirm_cancel_reservation')} ($customerName)', style: TextStyle(color: ModiriColors.textSecondary(isDark))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(loc.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.get('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.update('restaurant_reservations', {'status': 'cancelled', 'synced': 0}, where: 'id = ?', whereArgs: [id]);
        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'restaurant_reservation',
          entityId: id,
          operationType: 'DELETE',
          payload: {'status': 'cancelled'},
        );
        _loadRestaurantData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('restaurant_reservation_cancel_failed')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  void _showReservationModal({Map<String, dynamic>? reservation}) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isEditing = reservation != null;

    final nameCtrl = TextEditingController(text: reservation?['customer_name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: reservation?['phone']?.toString() ?? '');
    final partyCtrl = TextEditingController(text: (reservation?['party_size'] ?? 2).toString());
    final notesCtrl = TextEditingController(text: reservation?['notes']?.toString() ?? '');
    String? selectedTableId = reservation?['table_id']?.toString();
    if (selectedTableId == null && reservation?['table_name'] != null) {
      final found = _tables.where((t) => (t['name'] ?? t['label']) == reservation!['table_name']);
      if (found.isNotEmpty) {
        selectedTableId = found.first['id']?.toString();
      }
    }

    DateTime reservedAt = DateTime.tryParse(reservation?['reserved_at']?.toString() ?? '') ??
        DateTime.now().add(const Duration(hours: 1));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: ModiriColors.surface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ModiriColors.border(isDark)),
              ),
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.event_seat, color: ModiriColors.brandAmber, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? loc.get('edit_reservation') : loc.get('add_reservation'),
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: '${loc.get('guest_name')} *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('guest_phone')),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: partyCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                              decoration: InputDecoration(labelText: loc.get('party_size_label')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: selectedTableId,
                              decoration: InputDecoration(labelText: loc.get('assigned_table')),
                              items: [
                                DropdownMenuItem(value: null, child: Text(loc.get('unassigned_table'))),
                                ..._tables.map((t) {
                                  final id = t['id']?.toString() ?? '';
                                  final name = (t['name'] ?? t['label'] ?? 'Table').toString();
                                  final seats = t['seats'] ?? 2;
                                  return DropdownMenuItem(value: id, child: Text('$name ($seats seats)'));
                                }),
                              ],
                              onChanged: (val) => setModalState(() => selectedTableId = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: reservedAt,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(reservedAt),
                          );
                          if (time == null) return;
                          setModalState(() {
                            reservedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: ModiriColors.card(isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ModiriColors.border(isDark)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.get('reservation_time_label'),
                                      style: TextStyle(fontSize: 11, color: ModiriColors.textSecondary(isDark))),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('yyyy-MM-dd HH:mm').format(reservedAt),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                                  ),
                                ],
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: ModiriColors.brandAmber),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('special_requests')),
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
                    final customerName = nameCtrl.text.trim();
                    if (customerName.isEmpty) return;
                    final phone = phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null;
                    final partySize = int.tryParse(partyCtrl.text.trim()) ?? 2;
                    final notes = notesCtrl.text.trim();

                    String? assignedTableName;
                    if (selectedTableId != null) {
                      final found = _tables.where((t) => t['id']?.toString() == selectedTableId);
                      if (found.isNotEmpty) {
                        assignedTableName = (found.first['name'] ?? found.first['label'])?.toString();
                      }
                    }

                    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                    final db = await ModiriDesktopDatabase.instance.database;

                    try {
                      if (isEditing) {
                        final targetId = reservation['id'].toString();
                        await db.update(
                          'restaurant_reservations',
                          {
                            'customer_name': customerName,
                            'phone': phone,
                            'party_size': partySize,
                            'table_id': selectedTableId,
                            'table_name': assignedTableName,
                            'reserved_at': reservedAt.toIso8601String(),
                            'notes': notes,
                            'synced': 0,
                          },
                          where: 'id = ?',
                          whereArgs: [targetId],
                        );

                        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                          id: const Uuid().v4(),
                          clientTransactionId: const Uuid().v4(),
                          entityType: 'restaurant_reservation',
                          entityId: targetId,
                          operationType: 'UPDATE',
                          payload: {
                            'customerName': customerName,
                            'phone': phone,
                            'partySize': partySize,
                            'tableId': selectedTableId,
                            'reservedAt': reservedAt.toIso8601String(),
                            'notes': notes,
                          },
                        );
                      } else {
                        final newId = const Uuid().v4();
                        final nowIso = DateTime.now().toIso8601String();
                        await db.insert('restaurant_reservations', {
                          'id': newId,
                          'company_id': companyId,
                          'customer_name': customerName,
                          'phone': phone,
                          'party_size': partySize,
                          'table_id': selectedTableId,
                          'table_name': assignedTableName,
                          'reserved_at': reservedAt.toIso8601String(),
                          'status': 'pending',
                          'notes': notes,
                          'created_at': nowIso,
                          'synced': 0,
                        });

                        // Optionally set table to reserved if assigned
                        if (selectedTableId != null) {
                          await db.update(
                            'restaurant_tables',
                            {'status': 'reserved', 'synced': 0},
                            where: 'id = ?',
                            whereArgs: [selectedTableId],
                          );
                        }

                        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                          id: const Uuid().v4(),
                          clientTransactionId: const Uuid().v4(),
                          entityType: 'restaurant_reservation',
                          entityId: newId,
                          operationType: 'CREATE',
                          payload: {
                            'customerName': customerName,
                            'phone': phone,
                            'partySize': partySize,
                            'tableId': selectedTableId,
                            'reservedAt': reservedAt.toIso8601String(),
                            'notes': notes,
                          },
                        );
                      }

                      if (ctx.mounted) Navigator.of(ctx).pop();
                      _loadRestaurantData();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('${loc.get('restaurant_reservation_save_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                        );
                      }
                    }
                  },
                  child: Text(loc.get('save_changes')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNewOrderModal() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    String selectedTable = _tables.isNotEmpty
        ? (_tables.first['name'] ?? _tables.first['label'] ?? 'Table 1').toString()
        : 'Takeaway';
    final notesCtrl = TextEditingController();
    final customPriceCtrl = TextEditingController();

    // Map of dish item key -> { 'item': Map, 'quantity': int }
    final Map<String, Map<String, dynamic>> orderCart = {};

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            double calculateCartTotal() {
              double sum = 0.0;
              for (final entry in orderCart.values) {
                final item = entry['item'] as Map<String, dynamic>;
                final qty = (entry['quantity'] as num).toInt();
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                sum += price * qty;
              }
              final custom = double.tryParse(customPriceCtrl.text.trim()) ?? 0.0;
              return sum + custom;
            }

            final cartTotal = calculateCartTotal();

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
                      const Icon(Icons.restaurant_menu, color: ModiriColors.brandAmber, size: 22),
                      const SizedBox(width: 8),
                      Text(loc.get('create_kitchen_order'),
                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModiriColors.brandAmber.withOpacity(0.15),
                      foregroundColor: ModiriColors.brandAmber,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.document_scanner_outlined, size: 16),
                    label: Text(loc.get('scan_order_receipt'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _showScanBillModalForCart(orderCart, setModalState),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table Selector
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _tables.any((t) => (t['name'] ?? t['label']) == selectedTable)
                                  ? selectedTable
                                  : null,
                              decoration: InputDecoration(labelText: loc.get('dining_location')),
                              items: [
                                DropdownMenuItem(value: 'Takeaway', child: Text(loc.get('takeaway_counter'))),
                                ..._tables.map((t) {
                                  final tName = (t['name'] ?? t['label'] ?? 'Table').toString();
                                  final seats = t['seats'] ?? 2;
                                  return DropdownMenuItem(value: tName, child: Text('$tName ($seats seats)'));
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedTable = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dish Picker Section
                      Text(loc.get('pick_dishes_menu'),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.textPrimary(isDark))),
                      const SizedBox(height: 8),

                      if (_menuItems.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ModiriColors.card(isDark),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ModiriColors.border(isDark)),
                          ),
                          child: Text(loc.get('no_menu_items_configured'),
                              style: TextStyle(fontSize: 12)),
                        ),
                      ] else ...[
                        Container(
                          constraints: const BoxConstraints(maxHeight: 140),
                          decoration: BoxDecoration(
                            color: ModiriColors.card(isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ModiriColors.border(isDark)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _menuItems.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: ModiriColors.border(isDark)),
                            itemBuilder: (context, i) {
                              final dish = Map<String, dynamic>.from(_menuItems[i] as Map);
                              final dishName = (dish['name'] ?? 'Dish').toString();
                              final dishPrice = (dish['price'] as num?)?.toDouble() ?? 0.0;
                              final key = dish['id']?.toString() ?? dishName;
                              final currentQty = (orderCart[key]?['quantity'] as num?)?.toInt() ?? 0;

                              return ListTile(
                                dense: true,
                                title: Text(dishName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ModiriColors.textPrimary(isDark))),
                                subtitle: Text('${_formatCurrency(dishPrice)} • ${dish['category'] ?? 'Menu'}',
                                    style: TextStyle(fontSize: 11, color: ModiriColors.textSecondary(isDark))),
                                trailing: currentQty == 0
                                    ? OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: Text(loc.get('add'), style: const TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setModalState(() {
                                            orderCart[key] = {'item': dish, 'quantity': 1};
                                          });
                                        },
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: ModiriColors.brandRose),
                                            onPressed: () {
                                              setModalState(() {
                                                if (currentQty <= 1) {
                                                  orderCart.remove(key);
                                                } else {
                                                  orderCart[key]!['quantity'] = currentQty - 1;
                                                }
                                              });
                                            },
                                          ),
                                          Text('$currentQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 18, color: ModiriColors.brandTeal),
                                            onPressed: () {
                                              setModalState(() {
                                                orderCart[key]!['quantity'] = currentQty + 1;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Order Summary list
                      if (orderCart.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('${loc.get("selected_order_items")} (${orderCart.length})',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.textPrimary(isDark))),
                        const SizedBox(height: 6),
                        ...orderCart.entries.map((entry) {
                          final it = entry.value['item'] as Map<String, dynamic>;
                          final qty = entry.value['quantity'] as int;
                          final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${qty}x ${it['name']}', style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark))),
                                Text(_formatCurrency(price * qty),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 12),
                      TextField(
                        controller: customPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('custom_order_amount')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('chef_instructions')),
                      ),
                      const SizedBox(height: 16),

                      // Grand total display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(loc.get('estimated_order_total'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(_formatCurrency(cartTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: ModiriColors.brandAmber,
                                  fontFamily: 'monospace',
                                )),
                          ],
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
                    try {
                      final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                      final newId = const Uuid().v4();
                      final total = cartTotal;
                      final tableLabel = selectedTable;
                      final notes = notesCtrl.text.trim();

                      final items = <Map<String, dynamic>>[];
                      for (final entry in orderCart.values) {
                        final it = entry['item'] as Map<String, dynamic>;
                        final qty = entry['quantity'] as int;
                        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                        items.add({
                          'id': it['id'],
                          'name': it['name'] ?? 'Dish',
                          'unitPrice': price,
                          'quantity': qty,
                        });
                      }
                      if (items.isEmpty) {
                        items.add({
                          'name': notes.isNotEmpty ? notes : 'Dining Order ($tableLabel)',
                          'unitPrice': total > 0 ? total : 0.0,
                          'quantity': 1,
                        });
                      }

                      final nowIso = DateTime.now().toIso8601String();
                      final db = await ModiriDesktopDatabase.instance.database;

                      // 1. Insert into restaurant_orders
                      await db.insert('restaurant_orders', {
                        'id': newId,
                        'company_id': companyId,
                        'table_name': tableLabel,
                        'items_json': jsonEncode(items),
                        'status': 'preparing',
                        'total': total,
                        'notes': notes,
                        'created_at': nowIso,
                        'synced': 0,
                      });

                      // 2. Mark table as occupied in restaurant_tables if it's a specific table
                      if (!tableLabel.toLowerCase().contains('takeaway')) {
                        await db.update(
                          'restaurant_tables',
                          {'status': 'occupied', 'synced': 0},
                          where: 'name = ? AND company_id = ?',
                          whereArgs: [tableLabel, companyId],
                        );
                      }

                      // 3. Enqueue order creation
                      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                        id: const Uuid().v4(),
                        clientTransactionId: const Uuid().v4(),
                        entityType: 'restaurant_order',
                        entityId: newId,
                        operationType: 'CREATE',
                        payload: {
                          'tableName': tableLabel,
                          'table_label': tableLabel,
                          'items': items,
                          'notes': notes,
                          'orderType': tableLabel.toLowerCase().contains('takeaway') ? 'takeaway' : 'dine_in',
                          'status': 'preparing',
                          'total': total,
                        },
                      );

                      if (ctx.mounted) Navigator.of(ctx).pop();
                      _loadRestaurantData();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('${loc.get('create_order_error')} $e'), backgroundColor: ModiriColors.brandRose),
                        );
                      }
                    }
                  },
                  child: Text(loc.get('send_to_kitchen')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showScanBillModal() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
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
            body: DesktopAiInvoiceScannerScreen(
              initialMode: InvoiceScanMode.sales,
              onImportToCart: (scannedItems, customerName) async {
                await _importScannedItemsToRestaurantOrder(scannedItems, customerName);
              },
            ),
          ),
        ),
      ),
    ).then((_) {
      _loadRestaurantData();
    });
  }

  Future<void> _importScannedItemsToRestaurantOrder(List<ScannedLineItem> scannedItems, String? customerName) async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));

    final parsedOrderItems = scannedItems.map((it) {
      final pName = it.nameController.text.trim();
      final qty = it.quantity;
      final price = it.sellingPrice > 0 ? it.sellingPrice : (it.purchasePrice * 1.25);
      return {
        'name': pName.isNotEmpty ? pName : 'Menu Item',
        'quantity': qty,
        'price': price,
        'total': qty * price,
      };
    }).toList();

    if (parsedOrderItems.isEmpty) return;

    final grandTotal = parsedOrderItems.fold<double>(0.0, (s, i) => s + (i['total'] as num).toDouble());
    final orderId = const Uuid().v4();
    final clientTxId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final cust = (customerName != null && customerName.isNotEmpty) ? customerName : 'Walk-in Guest';

    try {
      final db = await ModiriDesktopDatabase.instance.database;
      await db.insert(
        'restaurant_orders',
        {
          'id': orderId,
          'company_id': companyId,
          'table_name': 'Takeaway',
          'items_json': jsonEncode(parsedOrderItems),
          'status': 'preparing',
          'total': grandTotal,
          'amount_paid': 0.0,
          'payment_status': 'unpaid',
          'customer_name': cust,
          'notes': 'Imported from AI Invoice Scanner',
          'created_at': nowIso,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: clientTxId,
        entityType: 'restaurant_order',
        entityId: orderId,
        operationType: 'CREATE',
        payload: {
          'id': orderId,
          'tableName': 'Takeaway',
          'total': grandTotal,
          'status': 'preparing',
          'items': parsedOrderItems,
          'customerName': cust,
        },
      );

      await _loadRestaurantData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${parsedOrderItems.length} ${loc.get('items_imported_to_cart')} (#Takeaway)'),
            backgroundColor: ModiriColors.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import order: $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  void _showScanBillModalForCart(Map<String, Map<String, dynamic>> orderCart, void Function(void Function()) setModalState) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    showDialog(
      context: context,
      builder: (sCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Scaffold(
            appBar: AppBar(
              title: Text(loc.get('scan_order_receipt')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(sCtx).pop(),
              ),
            ),
            body: DesktopAiInvoiceScannerScreen(
              initialMode: InvoiceScanMode.sales,
              onImportToCart: (scannedItems, _) {
                for (final it in scannedItems) {
                  final pName = it.nameController.text.trim();
                  if (pName.isEmpty) continue;
                  final qty = it.quantity;
                  final price = it.sellingPrice > 0 ? it.sellingPrice : (it.purchasePrice * 1.25);

                  final existingDish = _menuItems.firstWhere(
                    (m) => (m['name']?.toString() ?? '').toLowerCase() == pName.toLowerCase(),
                    orElse: () => null,
                  );

                  final dishItem = existingDish != null
                      ? Map<String, dynamic>.from(existingDish as Map)
                      : {'id': 'scan_${const Uuid().v4().substring(0, 8)}', 'name': pName, 'price': price};

                  final key = (dishItem['id'] ?? pName).toString();
                  if (orderCart.containsKey(key)) {
                    orderCart[key]!['quantity'] = (orderCart[key]!['quantity'] as int) + qty;
                  } else {
                    orderCart[key] = {'item': dishItem, 'quantity': qty};
                  }
                }
                setModalState(() {});
              },
            ),
          ),
        ),
      ),
    );
  }

  void _scanInvoiceToMenu() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    showDialog(
      context: context,
      builder: (sCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Scaffold(
            appBar: AppBar(
              title: Text(loc.get('scan_menu_invoice')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(sCtx).pop(),
              ),
            ),
            body: DesktopAiInvoiceScannerScreen(
              initialMode: InvoiceScanMode.purchase,
              onImportToCart: (scannedItems, _) async {
                await _importScannedItemsToMenu(scannedItems);
              },
            ),
          ),
        ),
      ),
    ).then((_) => _loadRestaurantData());
  }

  Future<void> _importScannedItemsToMenu(List<ScannedLineItem> scannedItems) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    int imported = 0;
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      for (final it in scannedItems) {
        final pName = it.nameController.text.trim();
        if (pName.isEmpty) continue;
        final sellPrice = it.sellingPrice > 0 ? it.sellingPrice : (it.purchasePrice * 1.3);
        final newId = const Uuid().v4();
        await db.insert(
          'products',
          {
            'id': newId,
            'company_id': companyId,
            'name': pName,
            'barcode': 'DISH${DateTime.now().millisecondsSinceEpoch % 1000000}',
            'price': sellPrice,
            'cost_price': it.purchasePrice,
            'stock_quantity': 100,
            'category': 'Main Course',
            'created_at': DateTime.now().toIso8601String(),
            'synced': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'product',
          entityId: newId,
          operationType: 'CREATE',
          payload: {
            'id': newId,
            'name': pName,
            'price': sellPrice,
            'category': 'Main Course',
            'companyId': companyId,
          },
        );
        imported++;
      }
      await _loadRestaurantData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$imported ${loc.get('dishes_added_to_menu')}'),
            backgroundColor: ModiriColors.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import menu: $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
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
          // Header: Title & Subtitle on start, Quick actions on end
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant, color: ModiriColors.brandAmber, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          loc.get('restaurant_management_title'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ModiriColors.textPrimary(isDark),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.get('restaurant_management_subtitle'),
                      style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.document_scanner_outlined, size: 16, color: ModiriColors.brandAmber),
                    label: Text(loc.get('scan_order_receipt')),
                    onPressed: _showScanBillModal,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(loc.get('new_order')),
                    onPressed: _showNewOrderModal,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dedicated TabBar Row
          Container(
            decoration: BoxDecoration(
              color: ModiriColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ModiriColors.border(isDark)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: ModiriColors.brandAmber,
              labelColor: ModiriColors.textPrimary(isDark),
              unselectedLabelColor: ModiriColors.textSecondary(isDark),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(icon: const Icon(Icons.kitchen, size: 16), text: loc.get('kitchen_tickets')),
                Tab(icon: const Icon(Icons.table_restaurant, size: 16), text: loc.get('floor_tables')),
                Tab(icon: const Icon(Icons.menu_book, size: 16), text: loc.get('menu_recipes')),
                Tab(icon: const Icon(Icons.event_seat, size: 16), text: loc.get('reservations')),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: KITCHEN DISPATCH ORDERS
                      _orders.isEmpty
                          ? Center(
                              child: ModiriPanel(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.kitchen, color: ModiriColors.brandAmber, size: 48),
                                    const SizedBox(height: 12),
                                    Text(loc.get('no_kitchen_orders'),
                                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(loc.get('all_orders_dispatched'),
                                        style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _showNewOrderModal,
                                      child: Text(loc.get('create_dining_order')),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final o = _orders[i];
                                final id = o['id']?.toString() ?? '#';
                                final table = o['table_label'] ?? o['table_id'] ?? 'Takeaway';
                                final status = (o['status'] ?? 'pending').toString().toLowerCase();
                                final total = (o['total'] as num?)?.toDouble() ?? 0.0;
                                final amountPaid = (o['amount_paid'] as num?)?.toDouble() ?? 0.0;
                                final paymentStatus = (o['payment_status'] ??
                                    (amountPaid >= total && total > 0 ? 'paid' : amountPaid > 0 ? 'partially_paid' : 'unpaid')).toString().toLowerCase();
                                final remaining = (total - amountPaid).clamp(0.0, double.infinity);
                                final notes = o['notes'] ?? 'No special instructions';
                                final items = (o['items'] as List?) ?? [];

                                Color badgeColor = ModiriColors.brandAmber;
                                if (status == 'ready') badgeColor = ModiriColors.brandTeal;
                                if (status == 'served' || status == 'completed') badgeColor = ModiriColors.brandBlue;

                                Color payBadgeColor = ModiriColors.brandRose;
                                String payBadgeText = '${loc.get("order_unpaid")} (${_formatCurrency(total)})';
                                if (paymentStatus == 'paid' || remaining <= 0.01) {
                                  payBadgeColor = ModiriColors.brandTeal;
                                  payBadgeText = loc.get('order_paid_full');
                                } else if (paymentStatus == 'partially_paid' || amountPaid > 0) {
                                  payBadgeColor = ModiriColors.brandAmber;
                                  payBadgeText = '${loc.get("order_partially_paid")} (${_formatCurrency(remaining)} due)';
                                }

                                return ModiriPanel(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(Icons.restaurant, color: badgeColor, size: 20),
                                          ),
                                          const SizedBox(width: 16),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text('${loc.get('order_colon')}$id · $table',
                                                      style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 16)),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: badgeColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: badgeColor.withOpacity(0.3)),
                                                    ),
                                                    child: Text(status.toUpperCase(),
                                                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: payBadgeColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: payBadgeColor.withOpacity(0.3)),
                                                    ),
                                                    child: Text(payBadgeText,
                                                        style: TextStyle(color: payBadgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${items.length} ${loc.get("selected_order_items")} · $notes',
                                                style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(_formatCurrency(total),
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ModiriColors.textPrimary(isDark), fontFamily: 'monospace')),
                                          const SizedBox(width: 16),
                                          if (status != 'cancelled' && status != 'completed') ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                              icon: const Icon(Icons.restaurant_menu, size: 14),
                                              label: Text(loc.get('add_dishes'), style: const TextStyle(fontSize: 12)),
                                              onPressed: () => _showAddDishesModal(o),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                foregroundColor: ModiriColors.brandTeal,
                                              ),
                                              icon: const Icon(Icons.payments_outlined, size: 14),
                                              label: Text(loc.get('split_check'), style: const TextStyle(fontSize: 12)),
                                              onPressed: () => _showPaymentModal(o),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                foregroundColor: ModiriColors.brandAmber,
                                              ),
                                              icon: const Icon(Icons.receipt_long_outlined, size: 14),
                                              label: Text(loc.get('print_kitchen_ticket'), style: const TextStyle(fontSize: 12)),
                                              onPressed: () {
                                                final companyName = ref.read(sessionProvider).companyName ?? 'Modiri Restaurant';
                                                final parsedItems = items.map((it) {
                                                  if (it is Map) {
                                                    return {
                                                      'name': it['name'] ?? 'Item',
                                                      'quantity': it['quantity'] ?? 1,
                                                      'notes': it['notes']?.toString(),
                                                    };
                                                  }
                                                  return {'name': it.toString(), 'quantity': 1};
                                                }).toList();
                                                ReceiptPrinter.printKitchenTicket(
                                                  companyName: companyName,
                                                  orderNumber: id,
                                                  date: DateTime.now(),
                                                  items: parsedItems,
                                                  tableName: table.toString(),
                                                  notes: notes != 'No special instructions' ? notes.toString() : null,
                                                  loc: loc,
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (status == 'preparing')
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                                              onPressed: () => _updateOrderStatus(id, 'ready'),
                                              child: Text(loc.get('mark_ready')),
                                            )
                                          else if (status == 'ready')
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandBlue),
                                              onPressed: () => _updateOrderStatus(id, 'served'),
                                              child: Text(loc.get('mark_served')),
                                            )
                                          else if (status == 'served')
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                                              onPressed: () => _updateOrderStatus(id, 'completed'),
                                              child: Text(loc.get('complete_sale')),
                                            )
                                          else if (status == 'completed')
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_circle, size: 18, color: ModiriColors.brandTeal),
                                                const SizedBox(width: 4),
                                                Text(loc.get('order_paid_full'), style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ],
                                            ),
                                          if (status != 'cancelled' && status != 'served' && status != 'completed') ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, size: 18, color: ModiriColors.brandRose),
                                              tooltip: loc.get('cancel_order'),
                                              onPressed: () => _updateOrderStatus(id, 'cancelled'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      // TAB 2: FLOOR TABLES
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_tables.length} ${loc.get('active_tables_in_layout')}',
                                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13, fontWeight: FontWeight.bold)),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ModiriColors.brandBlue.withOpacity(0.15),
                                  foregroundColor: ModiriColors.brandBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(loc.get('add_table')),
                                onPressed: () => _showTableModal(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _tables.isEmpty
                                ? Center(
                                    child: ModiriPanel(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.table_restaurant, color: ModiriColors.brandTeal, size: 48),
                                          const SizedBox(height: 12),
                                          Text(loc.get('no_tables_configured'),
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(loc.get('add_dining_tables_hint'),
                                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () => _showTableModal(),
                                            child: Text(loc.get('add_table')),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1.4,
                                    ),
                                    itemCount: _tables.length,
                                    itemBuilder: (ctx, i) {
                                      final t = _tables[i];
                                      final id = t['id']?.toString() ?? '$i';
                                      final label = t['name'] ?? t['label'] ?? 'Table ${i + 1}';
                                      final seats = t['seats'] ?? t['capacity'] ?? 2;
                                      final status = (t['status'] ?? 'available').toString().toLowerCase();
                                      final isOccupied = status == 'occupied';
                                      final isReserved = status == 'reserved';
                                      Color tone = ModiriColors.brandTeal;
                                      if (isOccupied) tone = ModiriColors.brandAmber;
                                      if (isReserved) tone = ModiriColors.brandBlue;

                                      return ModiriPanel(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 16)),
                                                PopupMenuButton<String>(
                                                  initialValue: status,
                                                  onSelected: (newStatus) => _updateTableStatus(id, newStatus),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: tone.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: tone.withOpacity(0.3)),
                                                    ),
                                                    child: Text(loc.get(status).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tone)),
                                                  ),
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(value: 'available', child: Text(loc.get('available'))),
                                                    PopupMenuItem(value: 'occupied', child: Text(loc.get('occupied'))),
                                                    PopupMenuItem(value: 'reserved', child: Text(loc.get('reserved'))),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.people, size: 16, color: ModiriColors.brandBlue),
                                                const SizedBox(width: 4),
                                                Text('$seats ${loc.get("seats")}', style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                              ],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  isOccupied ? loc.get('guest_seated') : (isReserved ? loc.get('table_reserved') : loc.get('ready_for_seating')),
                                                  style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 16, color: ModiriColors.brandBlue),
                                                      tooltip: loc.get('edit_table'),
                                                      onPressed: () => _showTableModal(table: Map<String, dynamic>.from(t as Map)),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: ModiriColors.brandRose),
                                                      tooltip: loc.get('delete_table'),
                                                      onPressed: () => _deleteTable(id, label),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),

                      // TAB 3: MENU & RECIPES
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_menuItems.length} ${loc.get('culinary_dishes_menu')}',
                                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ModiriColors.brandAmber,
                                      side: BorderSide(color: ModiriColors.brandAmber.withOpacity(0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.document_scanner_outlined, size: 16),
                                    label: Text(loc.get('scan_menu_invoice')),
                                    onPressed: _scanInvoiceToMenu,
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ModiriColors.brandAmber.withOpacity(0.15),
                                      foregroundColor: ModiriColors.brandAmber,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text(loc.get('add_menu_dish')),
                                    onPressed: () => _showMenuItemModal(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _menuItems.isEmpty
                                ? Center(
                                    child: ModiriPanel(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.restaurant_menu, color: ModiriColors.brandAmber, size: 48),
                                          const SizedBox(height: 12),
                                          Text(loc.get('no_menu_items_found'),
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(loc.get('menu_items_sync_hint'),
                                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: _scanInvoiceToMenu,
                                                icon: const Icon(Icons.document_scanner_outlined, size: 16),
                                                label: Text(loc.get('scan_menu_invoice')),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: ModiriColors.brandAmber,
                                                  side: BorderSide(color: ModiriColors.brandAmber.withOpacity(0.5)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => _showMenuItemModal(),
                                                child: Text(loc.get('add_menu_dish')),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ModiriPanel(
                                    padding: EdgeInsets.zero,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SingleChildScrollView(
                                        child: DataTable(
                                          headingRowColor: WidgetStateProperty.all(ModiriColors.tableHeader(isDark)),
                                          columns: [
                                            DataColumn(label: Text(loc.get('dish_name_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('category'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('prep_time_column'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('selling_price'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            DataColumn(label: Text(loc.get('action'), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                          rows: _menuItems.map((m) {
                                            final mMap = Map<String, dynamic>.from(m as Map);
                                            final itemId = mMap['id']?.toString() ?? '';
                                            final name = mMap['name'] ?? 'Dish';
                                            final cat = mMap['category'] ?? 'Main Course';
                                            final prep = mMap['prep_time'] ?? '10m';
                                            final price = (mMap['price'] as num?)?.toDouble() ?? 0.0;

                                            return DataRow(
                                              cells: [
                                                DataCell(Text(name, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold))),
                                                DataCell(Text(cat, style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
                                                DataCell(Text(prep, style: TextStyle(color: ModiriColors.textMuted(isDark)))),
                                                DataCell(Text(_formatCurrency(price), style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandTeal, fontFamily: 'monospace'))),
                                                DataCell(
                                                  Row(
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, size: 18, color: ModiriColors.brandBlue),
                                                        tooltip: loc.get('edit_dish'),
                                                        onPressed: () => _showMenuItemModal(item: mMap),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline, size: 18, color: ModiriColors.brandRose),
                                                        tooltip: loc.get('remove_dish'),
                                                        onPressed: itemId.isNotEmpty ? () => _deleteMenuItem(itemId, name) : null,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      // TAB 4: RESERVATIONS
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_reservations.length} ${loc.get("active_reservations_label")}',
                                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13, fontWeight: FontWeight.bold)),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ModiriColors.brandAmber.withOpacity(0.15),
                                  foregroundColor: ModiriColors.brandAmber,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(loc.get('add_reservation')),
                                onPressed: () => _showReservationModal(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _reservations.isEmpty
                                ? Center(
                                    child: ModiriPanel(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.event_seat, color: ModiriColors.brandAmber, size: 48),
                                          const SizedBox(height: 12),
                                          Text(loc.get('no_reservations_found'),
                                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(loc.get('reservations_empty_hint'),
                                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () => _showReservationModal(),
                                            child: Text(loc.get('add_reservation')),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _reservations.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (ctx, i) {
                                      final r = Map<String, dynamic>.from(_reservations[i] as Map);
                                      final id = r['id']?.toString() ?? '';
                                      final customerName = (r['customer_name'] ?? r['customerName'] ?? 'Guest').toString();
                                      final phone = r['phone']?.toString();
                                      final partySize = r['party_size'] ?? r['partySize'] ?? 2;
                                      final tableName = (r['table_name'] ?? r['tableName'] ?? loc.get('unassigned_table')).toString();
                                      final status = (r['status'] ?? 'pending').toString().toLowerCase();
                                      final notes = r['notes']?.toString();
                                      final reservedAtStr = r['reserved_at']?.toString() ?? r['reservedAt']?.toString() ?? '';
                                      final reservedAt = DateTime.tryParse(reservedAtStr);
                                      final formattedTime = reservedAt != null
                                          ? DateFormat('yyyy-MM-dd HH:mm').format(reservedAt)
                                          : reservedAtStr;

                                      Color tone = ModiriColors.brandAmber;
                                      if (status == 'confirmed') tone = ModiriColors.brandBlue;
                                      if (status == 'seated') tone = ModiriColors.brandTeal;
                                      if (status == 'cancelled' || status == 'no_show') tone = ModiriColors.brandRose;

                                      return ModiriPanel(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: tone.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Icon(Icons.event_seat, color: tone, size: 20),
                                                ),
                                                const SizedBox(width: 16),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(customerName,
                                                            style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 16)),
                                                        const SizedBox(width: 10),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: tone.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: tone.withOpacity(0.3)),
                                                          ),
                                                          child: Text(loc.get(status).toUpperCase(),
                                                              style: TextStyle(color: tone, fontSize: 10, fontWeight: FontWeight.bold)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.people, size: 14, color: ModiriColors.brandBlue),
                                                        const SizedBox(width: 4),
                                                        Text('$partySize ${loc.get("seats")} · $tableName',
                                                            style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                                        const SizedBox(width: 12),
                                                        const Icon(Icons.access_time, size: 14, color: ModiriColors.brandAmber),
                                                        const SizedBox(width: 4),
                                                        Text(formattedTime,
                                                            style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                                        if (phone != null && phone.isNotEmpty) ...[
                                                          const SizedBox(width: 12),
                                                          const Icon(Icons.phone, size: 14, color: ModiriColors.brandTeal),
                                                          const SizedBox(width: 4),
                                                          Text(phone,
                                                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                                        ],
                                                      ],
                                                    ),
                                                    if (notes != null && notes.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(notes, style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                if (status == 'pending') ...[
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandBlue, visualDensity: VisualDensity.compact),
                                                    onPressed: () => _updateReservationStatus(id, 'confirmed'),
                                                    child: Text(loc.get('mark_confirmed')),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (status == 'confirmed' || status == 'pending') ...[
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal, visualDensity: VisualDensity.compact),
                                                    onPressed: () => _updateReservationStatus(id, 'seated'),
                                                    child: Text(loc.get('seat_guests')),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (status != 'cancelled' && status != 'no_show' && status != 'seated') ...[
                                                  OutlinedButton(
                                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                                    onPressed: () => _updateReservationStatus(id, 'no_show'),
                                                    child: Text(loc.get('mark_no_show')),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 18, color: ModiriColors.brandBlue),
                                                  tooltip: loc.get('edit_reservation'),
                                                  onPressed: () => _showReservationModal(reservation: r),
                                                ),
                                                if (status != 'cancelled')
                                                  IconButton(
                                                    icon: const Icon(Icons.cancel_outlined, size: 18, color: ModiriColors.brandRose),
                                                    tooltip: loc.get('delete_reservation'),
                                                    onPressed: () => _deleteReservation(id, customerName),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showMenuItemModal({Map<String, dynamic>? item}) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isEditing = item != null;
    final nameCtrl = TextEditingController(text: item?['name']?.toString() ?? '');
    final catCtrl = TextEditingController(text: item?['category']?.toString() ?? 'Main Course');
    final priceCtrl = TextEditingController(text: item != null ? (item['price']?.toString() ?? '0') : '850.00');

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
              Icon(isEditing ? Icons.edit : Icons.menu_book, color: ModiriColors.brandAmber, size: 22),
              const SizedBox(width: 8),
              Text(
                isEditing ? loc.get('edit_dish') : loc.get('add_menu_dish'),
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('dish_name_input')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('menu_category_input')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('selling_price_input')),
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
                final cat = catCtrl.text.trim().isNotEmpty ? catCtrl.text.trim() : 'Main Course';
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                if (name.isEmpty) return;

                final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

                try {
                  final db = await ModiriDesktopDatabase.instance.database;

                  if (isEditing) {
                    final targetId = item['id'].toString();
                    await db.update(
                      'products',
                      {
                        'name': name,
                        'category': cat,
                        'price': price,
                        'synced': 0,
                      },
                      where: 'id = ?',
                      whereArgs: [targetId],
                    );

                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'restaurant_menu_item',
                      entityId: targetId,
                      operationType: 'UPDATE',
                      payload: {
                        'name': name,
                        'category': cat,
                        'price': price,
                      },
                    );
                  } else {
                    final newId = const Uuid().v4();
                    await db.insert(
                      'products',
                      {
                        'id': newId,
                        'company_id': companyId,
                        'name': name,
                        'category': cat,
                        'price': price,
                        'cost_price': price * 0.4,
                        'stock_quantity': 999,
                        'minimum_stock': 5,
                        'created_at': DateTime.now().toIso8601String(),
                        'synced': 0,
                      },
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );

                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'restaurant_menu_item',
                      entityId: newId,
                      operationType: 'CREATE',
                      payload: {
                        'name': name,
                        'category': cat,
                        'price': price,
                      },
                    );
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadRestaurantData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.get('restaurant_dish_save_failed')} $e'), backgroundColor: ModiriColors.brandRose),
                    );
                  }
                }
              },
              child: Text(isEditing ? loc.get('save_changes') : loc.get('save_changes')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMenuItem(String id, String name) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          title: Text(loc.get('remove_menu_dish'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${loc.get('confirm_remove_dish')} ($name)',
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
        await db.delete('products', where: 'id = ?', whereArgs: [id]);
        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'restaurant_menu_item',
          entityId: id,
          operationType: 'DELETE',
          payload: {},
        );
        _loadRestaurantData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('restaurant_dish_remove_failed')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }
}
