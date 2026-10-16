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

IconData _getExpenseCategoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('electric') || c.contains('power')) return Icons.lightbulb_outline;
  if (c.contains('transport') || c.contains('fuel') || c.contains('gas')) return Icons.local_shipping_outlined;
  if (c.contains('rent') || c.contains('lease')) return Icons.storefront_outlined;
  if (c.contains('water')) return Icons.water_drop_outlined;
  if (c.contains('salary') || c.contains('wage') || c.contains('payroll')) return Icons.badge_outlined;
  if (c.contains('internet') || c.contains('phone')) return Icons.wifi;
  if (c.contains('repair') || c.contains('maint')) return Icons.build_outlined;
  return Icons.receipt_long_outlined;
}

class DesktopExpensesScreen extends ConsumerStatefulWidget {
  const DesktopExpensesScreen({super.key});

  @override
  ConsumerState<DesktopExpensesScreen> createState() => _DesktopExpensesScreenState();
}

class _DesktopExpensesScreenState extends ConsumerState<DesktopExpensesScreen> {
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
  List<Map<String, dynamic>> _expenses = [];
  String? _error;
  String _selectedCategoryFilter = 'All';

  final List<String> _categories = [
    'All',
    'Utilities',
    'Electricity',
    'Rent',
    'Salaries',
    'Supplies',
    'Transport',
    'Maintenance',
    'Other',
  ];

  ModiriLocalizations get _loc => ModiriLocalizations(ref.read(desktopLocaleProvider));

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final localRows = await db.query(
        'expenses',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'date DESC, created_at DESC',
      );

      if (mounted && localRows.isNotEmpty) {
        setState(() {
          _expenses = List<Map<String, dynamic>>.from(localRows);
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch from backend API while preserving pending local sync changes
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/expenses');
      final list = res is Map ? (res['data'] as List? ?? res['expenses'] as List? ?? []) : (res as List? ?? []);

      final db = await ModiriDesktopDatabase.instance.database;
      final pendingRows = await db.query(
        'sync_queue',
        columns: ['entity_id'],
        where: "company_id = ? AND entity_type = 'expense' AND status = 'pending'",
        whereArgs: [companyId],
      );
      final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

      final batch = db.batch();

      for (final item in list) {
        final exp = Map<String, dynamic>.from(item as Map);
        final id = exp['id']?.toString() ?? const Uuid().v4();
        if (pendingIds.contains(id)) continue;

        final cat = exp['category']?.toString() ?? 'General';
        final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
        final desc = exp['description']?.toString();
        final date = exp['date']?.toString().split('T')[0] ?? DateTime.now().toIso8601String().split('T')[0];

        batch.insert(
          'expenses',
          {
            'id': id,
            'company_id': companyId,
            'category': cat,
            'amount': amt,
            'description': desc,
            'date': date,
            'created_at': exp['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);

      final freshRows = await db.query(
        'expenses',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'date DESC, created_at DESC',
      );

      if (mounted) {
        setState(() {
          _expenses = List<Map<String, dynamic>>.from(freshRows);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _expenses.isEmpty) {
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

  void _showAddExpenseDialog() {
    final catController = TextEditingController(text: 'Utilities');
    final descController = TextEditingController();
    final amtController = TextEditingController();
    DateTime chosenDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Text(_loc.get('add_operating_expense'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: ['Utilities', 'Electricity', 'Rent', 'Salaries', 'Supplies', 'Transport', 'Maintenance', 'Other']
                            .contains(catController.text)
                        ? catController.text
                        : 'Utilities',
                    dropdownColor: ModiriColors.card(isDark),
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: _loc.get('expense_category_req'), prefixIcon: const Icon(Icons.category_outlined)),
                    items: ['Utilities', 'Electricity', 'Rent', 'Salaries', 'Supplies', 'Transport', 'Maintenance', 'Other']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => catController.text = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amtController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: _loc.get('amount_dzd_req'), prefixIcon: const Icon(Icons.attach_money)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: _loc.get('description_payee_note'), prefixIcon: const Icon(Icons.notes)),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogCtx,
                        initialDate: chosenDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => chosenDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: ModiriColors.card(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ModiriColors.border(isDark)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 16, color: ModiriColors.brandBlue),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('yyyy-MM-dd').format(chosenDate),
                                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                              ),
                            ],
                          ),
                          Text(_loc.get('change_date'), style: TextStyle(color: ModiriColors.brandBlue, fontSize: 12)),
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
                child: Text(_loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
                  if (amt <= 0) return;
                  Navigator.of(ctx).pop();

                  final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
                  final newId = const Uuid().v4();
                  final cat = catController.text.trim();
                  final desc = descController.text.trim();
                  final dateStr = DateFormat('yyyy-MM-dd').format(chosenDate);

                  try {
                    final db = await ModiriDesktopDatabase.instance.database;
                    await db.insert('expenses', {
                      'id': newId,
                      'company_id': companyId,
                      'category': cat,
                      'amount': amt,
                      'description': desc.isEmpty ? null : desc,
                      'date': dateStr,
                      'created_at': DateTime.now().toIso8601String(),
                    });

                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'expense',
                      entityId: newId,
                      operationType: 'CREATE',
                      payload: {
                        'category': cat,
                        'amount': amt,
                        'description': desc,
                        'date': dateStr,
                      },
                    );

                    await _loadExpenses();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_loc.get('expense_logged_success')), backgroundColor: ModiriColors.brandTeal),
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
                child: Text(_loc.get('save_expense')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditExpenseDialog(Map<String, dynamic> exp) {
    final allowedCats = ['Utilities', 'Electricity', 'Rent', 'Salaries', 'Supplies', 'Transport', 'Maintenance', 'Other'];
    final initCat = exp['category']?.toString() ?? 'Utilities';
    final catController = TextEditingController(text: allowedCats.contains(initCat) ? initCat : 'Other');
    final descController = TextEditingController(text: exp['description']?.toString() ?? '');
    final amtController = TextEditingController(text: (exp['amount']?.toString() ?? ''));
    final rawDate = exp['date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0];
    DateTime chosenDate = DateTime.tryParse(rawDate) ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Text(_loc.get('edit_operating_expense'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: allowedCats.contains(catController.text) ? catController.text : 'Other',
                    dropdownColor: ModiriColors.card(isDark),
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: _loc.get('expense_category_req'), prefixIcon: const Icon(Icons.category_outlined)),
                    items: allowedCats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => catController.text = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amtController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: _loc.get('amount_dzd_req'), prefixIcon: const Icon(Icons.attach_money)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Description / Notes', prefixIcon: Icon(Icons.notes)),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogCtx,
                        initialDate: chosenDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => chosenDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: ModiriColors.card(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ModiriColors.border(isDark)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 16, color: ModiriColors.brandBlue),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('yyyy-MM-dd').format(chosenDate),
                                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                              ),
                            ],
                          ),
                          Text(_loc.get('change_date'), style: TextStyle(color: ModiriColors.brandBlue, fontSize: 12)),
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
                child: Text(_loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
                  if (amt <= 0) return;
                  Navigator.of(ctx).pop();

                  final id = exp['id']?.toString() ?? '';
                  final cat = catController.text.trim();
                  final desc = descController.text.trim();
                  final dateStr = DateFormat('yyyy-MM-dd').format(chosenDate);

                  try {
                    final db = await ModiriDesktopDatabase.instance.database;
                    await db.update(
                      'expenses',
                      {'category': cat, 'amount': amt, 'description': desc.isEmpty ? null : desc, 'date': dateStr},
                      where: 'id = ?',
                      whereArgs: [id],
                    );

                    await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                      id: const Uuid().v4(),
                      clientTransactionId: const Uuid().v4(),
                      entityType: 'expense',
                      entityId: id,
                      operationType: 'UPDATE',
                      payload: {'category': cat, 'amount': amt, 'description': desc, 'date': dateStr},
                    );

                    await _loadExpenses();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_loc.get('expense_logged_success')), backgroundColor: ModiriColors.brandTeal),
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
                child: Text(_loc.get('update_expense')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Map<String, dynamic> exp) async {
    final cat = exp['category']?.toString() ?? 'Expense';
    final amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;

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
          title: Text(_loc.get('delete_expense'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: Text('${_loc.get('confirm_delete_expense')} ($cat - ${_formatCurrency(amt)})',
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
      final id = exp['id']?.toString() ?? '';
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('expenses', where: 'id = ?', whereArgs: [id]);

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'expense',
          entityId: id,
          operationType: 'DELETE',
          payload: {'id': id},
        );

        await _loadExpenses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_loc.get('expense_deleted')), backgroundColor: ModiriColors.brandTeal),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filtered = _expenses.where((e) {
      if (_selectedCategoryFilter == 'All') return true;
      final cat = (e['category'] ?? '').toString().toLowerCase();
      return cat.contains(_selectedCategoryFilter.toLowerCase());
    }).toList();

    final totalExpenses = _expenses.fold(
      0.0,
      (acc, item) => acc + ((item['amount'] ?? 0.0 as num).toDouble()),
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
                    loc.get('expenses_header_title'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('expenses_header_desc'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadExpenses,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(loc.get('add_expense')),
                    onPressed: _showAddExpenseDialog,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Total Outflow Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ModiriColors.brandRose.withOpacity(0.18),
                  ModiriColors.brandIndigo.withOpacity(0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ModiriColors.brandRose.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: ModiriColors.brandRose, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.get('total_outflows_recorded'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(totalExpenses), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${_expenses.length} ${loc.get('records_logged')}',
                  style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((c) {
                final isSelected = _selectedCategoryFilter == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(c),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategoryFilter = c),
                    backgroundColor: ModiriColors.card(isDark),
                    selectedColor: ModiriColors.brandBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : ModiriColors.textSecondary(isDark),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? ModiriColors.brandBlue : ModiriColors.border(isDark),
                    ),
                  ),
                );
              }).toList(),
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
                          child: Text(_loc.get('no_expenses_category'),
                              style: TextStyle(color: ModiriColors.textMuted(isDark))),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: ModiriColors.border(isDark), height: 1),
                          itemBuilder: (ctx, i) {
                            final exp = filtered[i];
                            final cat = exp['category']?.toString() ?? 'General';
                            final desc = exp['description']?.toString() ?? '';
                            final amt = (exp['amount'] ?? 0.0 as num).toDouble();
                            final date = exp['date'] ?? exp['created_at'] ?? '';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: ModiriColors.card(isDark),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(_getExpenseCategoryIcon(cat),
                                        color: ModiriColors.brandRose, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(cat,
                                            style: TextStyle(
                                                color: ModiriColors.textPrimary(isDark),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                        if (desc.isNotEmpty)
                                          Text(desc,
                                              style: TextStyle(
                                                  color: ModiriColors.textSecondary(isDark), fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      date.toString().split('T')[0],
                                      style: TextStyle(
                                          color: ModiriColors.textMuted(isDark), fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      _formatCurrency(amt),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          color: ModiriColors.brandRose,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, size: 19, color: ModiriColors.textSecondary(isDark)),
                                        tooltip: _loc.get('edit_expense'),
                                        onPressed: () => _showEditExpenseDialog(exp),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 19, color: ModiriColors.brandRose),
                                        tooltip: _loc.get('delete_expense'),
                                        onPressed: () => _confirmDeleteExpense(exp),
                                      ),
                                    ],
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
