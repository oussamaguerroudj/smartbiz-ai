import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopNotificationsScreen extends ConsumerStatefulWidget {
  const DesktopNotificationsScreen({super.key});

  @override
  ConsumerState<DesktopNotificationsScreen> createState() => _DesktopNotificationsScreenState();
}

class _DesktopNotificationsScreenState extends ConsumerState<DesktopNotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  final Set<String> _locallyReadKeys = {};
  String _selectedFilter = 'all';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  String _notificationKey(Map<String, dynamic> item) {
    return (item['id'] ?? item['referenceId'] ?? '${item['type']}_${item['title']}').toString();
  }

  bool _isItemRead(Map<String, dynamic> item) {
    final key = _notificationKey(item);
    if (_locallyReadKeys.contains(key)) return true;
    return item['read'] == true ||
        item['is_read'] == true ||
        item['isRead'] == true ||
        item['read_at'] != null ||
        item['readAt'] != null;
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/notifications');
      final rawList = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
      final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Local SQLite fallback: dynamically generate offline operational alerts
      try {
        final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
        final db = await ModiriDesktopDatabase.instance.database;

        final lowStock = await db.rawQuery(
          'SELECT id, name, stock_quantity, minimum_stock FROM products WHERE company_id = ? AND stock_quantity <= minimum_stock LIMIT 15',
          [companyId],
        );

        final pendingSync = await db.rawQuery(
          "SELECT COUNT(*) as count FROM sync_queue WHERE company_id = ? AND status = 'pending'",
          [companyId],
        );

        final debtors = await db.rawQuery(
          'SELECT COUNT(*) as count, SUM(credit_balance) as total FROM customers WHERE company_id = ? AND credit_balance > 0',
          [companyId],
        );

        final unpaidInvoices = await db.rawQuery(
          "SELECT id, invoice_number, total_amount FROM invoices WHERE company_id = ? AND status != 'paid' ORDER BY created_at DESC LIMIT 10",
          [companyId],
        );

        final offlineAlerts = <Map<String, dynamic>>[];

        final pendingCount = (pendingSync.first['count'] as num?)?.toInt() ?? 0;
        if (pendingCount > 0) {
          offlineAlerts.add({
            'id': 'offline_sync_alert',
            'title': 'Offline Queue Pending',
            'message': '$pendingCount offline operations waiting to be synced with the cloud.',
            'type': 'sync',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        for (final p in lowStock) {
          offlineAlerts.add({
            'id': 'low_stock_${p['id'] ?? p['name']}',
            'title': 'Low Inventory Warning: ${p['name']}',
            'message': '${p['name']} is running low (${p['stock_quantity']} remaining, min ${p['minimum_stock']}).',
            'type': 'low_stock',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        for (final inv in unpaidInvoices) {
          offlineAlerts.add({
            'id': 'unpaid_inv_${inv['id']}',
            'title': 'Invoice ${inv['invoice_number']} still unpaid',
            'message': 'Outstanding amount: ${((inv['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DZD',
            'type': 'unpaid_invoice',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        final debtTotal = (debtors.first['total'] as num?)?.toDouble() ?? 0.0;
        final debtorCount = (debtors.first['count'] as num?)?.toInt() ?? 0;
        if (debtorCount > 0) {
          offlineAlerts.add({
            'id': 'debt_summary_alert',
            'title': 'Outstanding Customer Credit',
            'message': '$debtorCount customer(s) have unpaid balances totaling ${debtTotal.toStringAsFixed(2)} DZD.',
            'type': 'finance',
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        if (mounted) {
          setState(() {
            _notifications = offlineAlerts;
            _isLoading = false;
          });
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _error = err.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _markSingleRead(Map<String, dynamic> item) async {
    final key = _notificationKey(item);
    setState(() {
      _locallyReadKeys.add(key);
      item['is_read'] = true;
      item['read'] = true;
      item['read_at'] = DateTime.now().toIso8601String();
    });

    final id = item['id']?.toString();
    if (id != null &&
        id.isNotEmpty &&
        !id.startsWith('low_stock_') &&
        !id.startsWith('unpaid_inv_') &&
        id != 'offline_sync_alert' &&
        id != 'debt_summary_alert') {
      try {
        final client = ref.read(apiClientProvider);
        await client.put('/notifications/$id/read', body: {});
      } catch (_) {
        // Derived or offline notification — local read state already updated
      }
    }
  }

  Future<void> _markAllRead() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final unreadItems = _notifications.where((item) => !_isItemRead(item)).toList();
    if (unreadItems.isEmpty) return;

    setState(() {
      for (final item in _notifications) {
        _locallyReadKeys.add(_notificationKey(item));
        item['is_read'] = true;
        item['read'] = true;
        item['read_at'] = DateTime.now().toIso8601String();
      }
    });

    final client = ref.read(apiClientProvider);
    for (final item in unreadItems) {
      final id = item['id']?.toString();
      if (id != null &&
          id.isNotEmpty &&
          !id.startsWith('low_stock_') &&
          !id.startsWith('unpaid_inv_') &&
          id != 'offline_sync_alert' &&
          id != 'debt_summary_alert') {
        try {
          await client.put('/notifications/$id/read', body: {});
        } catch (_) {}
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('notifications_marked_read')),
          backgroundColor: ModiriColors.brandTeal,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    return _notifications.where((item) {
      if (_selectedFilter == 'unread') return !_isItemRead(item);
      if (_selectedFilter == 'inventory') {
        final t = (item['type'] ?? '').toString().toLowerCase();
        return t.contains('stock') || t.contains('inventory');
      }
      if (_selectedFilter == 'finance') {
        final t = (item['type'] ?? '').toString().toLowerCase();
        return t.contains('invoice') || t.contains('finance') || t.contains('credit');
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filtered = _filteredNotifications;
    final unreadCount = _notifications.where((n) => !_isItemRead(n)).length;

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
                      Text(
                        loc.get('notifications_title'),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount ${loc.get('unread')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ModiriColors.brandBlue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('notifications_subtitle'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadNotifications,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text(loc.get('mark_all_read')),
                    onPressed: unreadCount > 0 ? _markAllRead : null,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Filter Chips
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('all', '${loc.get('all')} (${_notifications.length})', isDark),
              _buildFilterChip('unread', '${loc.get('unread')} ($unreadCount)', isDark),
              _buildFilterChip('inventory', loc.get('inventory'), isDark),
              _buildFilterChip('finance', loc.get('credit'), isDark),
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
                : filtered.isEmpty
                    ? Center(
                        child: ModiriPanel(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.notifications_none, color: ModiriColors.brandBlue, size: 48),
                              const SizedBox(height: 12),
                              Text(loc.get('no_notifications'),
                                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(loc.get('all_up_to_date'),
                                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          final title = (item['title'] ?? 'Notification').toString();
                          final message = (item['message'] ?? item['body'] ?? '').toString();
                          final isRead = _isItemRead(item);
                          final rawDate = item['created_at'] ?? item['createdAt'];
                          final dateStr = rawDate != null && rawDate.toString().length >= 16
                              ? rawDate.toString().replaceAll('T', ' ').substring(0, 16)
                              : '';

                          return ModiriPanel(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isRead
                                        ? (isDark ? ModiriColors.ink950 : ModiriColors.lightInk850)
                                        : ModiriColors.brandBlue.withOpacity(isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isRead ? Icons.notifications_none : Icons.notifications_active,
                                    color: isRead ? ModiriColors.textMuted(isDark) : ModiriColors.brandBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isRead ? ModiriColors.textSecondary(isDark) : ModiriColors.textPrimary(isDark),
                                              ),
                                            ),
                                          ),
                                          if (dateStr.isNotEmpty)
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: ModiriColors.textMuted(isDark),
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message,
                                        style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead) ...[
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: () => _markSingleRead(item),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: Text(loc.get('mark_read')),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final selected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: ModiriColors.brandBlue.withOpacity(0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? ModiriColors.brandBlue : ModiriColors.textSecondary(isDark),
      ),
    );
  }
}
