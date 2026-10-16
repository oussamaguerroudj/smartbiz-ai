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

class DesktopEmployeesScreen extends ConsumerStatefulWidget {
  const DesktopEmployeesScreen({super.key});

  @override
  ConsumerState<DesktopEmployeesScreen> createState() => _DesktopEmployeesScreenState();
}

class _DesktopEmployeesScreenState extends ConsumerState<DesktopEmployeesScreen> {
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
  List<Map<String, dynamic>> _employees = [];
  String? _error;
  final _searchController = TextEditingController();

  ModiriLocalizations get _loc => ModiriLocalizations(ref.read(desktopLocaleProvider));

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      var localRows = await db.query(
        'employees',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      if (localRows.isEmpty) {
        localRows = await db.query('employees', orderBy: 'name ASC');
      }

      if (mounted && localRows.isNotEmpty) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(localRows);
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Fetch from backend API while preserving pending local sync changes
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/employees');
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      final db = await ModiriDesktopDatabase.instance.database;
      final pendingRows = await db.query(
        'sync_queue',
        columns: ['entity_id'],
        where: "company_id = ? AND entity_type = 'employee' AND status = 'pending'",
        whereArgs: [companyId],
      );
      final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

      final batch = db.batch();

      for (final item in list) {
        final emp = Map<String, dynamic>.from(item as Map);
        final id = emp['id']?.toString() ?? const Uuid().v4();
        if (pendingIds.contains(id)) continue;

        final name = emp['name']?.toString() ?? 'Unnamed';
        final pos = emp['position']?.toString() ?? emp['role']?.toString() ?? 'Staff';
        final salary = ((emp['base_salary'] ?? emp['baseSalary'] ?? emp['salary'] ?? 0.0) as num).toDouble();
        final phone = emp['phone']?.toString();

        batch.insert(
          'employees',
          {
            'id': id,
            'company_id': companyId,
            'name': name,
            'position': pos,
            'base_salary': salary,
            'phone': phone,
            'created_at': emp['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);

      var freshRows = await db.query(
        'employees',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      if (freshRows.isEmpty) {
        freshRows = await db.query('employees', orderBy: 'name ASC');
      }

      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(freshRows);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _employees.isEmpty) {
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

  void _showAddEmployeeDialog() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Staff');
    final salaryCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.get('add_staff_member'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('customer_name'), prefixIcon: const Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('position_role_input'), prefixIcon: const Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salaryCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('monthly_base_salary'), prefixIcon: const Icon(Icons.payments_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('phone_number_label'), prefixIcon: const Icon(Icons.phone_outlined)),
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
              final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
              Navigator.of(ctx).pop();

              final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
              final newId = const Uuid().v4();
              final pos = roleCtrl.text.trim();
              final phone = phoneCtrl.text.trim();

              try {
                final db = await ModiriDesktopDatabase.instance.database;
                await db.insert('employees', {
                  'id': newId,
                  'company_id': companyId,
                  'name': name,
                  'position': pos,
                  'base_salary': salary,
                  'phone': phone.isEmpty ? null : phone,
                  'created_at': DateTime.now().toIso8601String(),
                });

                await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                  id: const Uuid().v4(),
                  clientTransactionId: const Uuid().v4(),
                  entityType: 'employee',
                  entityId: newId,
                  operationType: 'CREATE',
                  payload: {
                    'name': name,
                    'position': pos,
                    'baseSalary': salary,
                    if (phone.isNotEmpty) 'phone': phone,
                  },
                );

                await _loadEmployees();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.get('employee_registered_success')), backgroundColor: ModiriColors.brandTeal),
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
            child: Text(loc.get('save_employee')),
          ),
        ],
      ),
    );
  }

  void _showEditEmployeeDialog(Map<String, dynamic> emp) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final nameCtrl = TextEditingController(text: emp['name']?.toString() ?? '');
    final roleCtrl = TextEditingController(text: emp['position']?.toString() ?? '');
    final salaryCtrl = TextEditingController(text: (emp['base_salary']?.toString() ?? ''));
    final phoneCtrl = TextEditingController(text: emp['phone']?.toString() ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.get('edit_staff_member'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('employee_name'), prefixIcon: const Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('position'), prefixIcon: const Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salaryCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('base_salary'), prefixIcon: const Icon(Icons.payments_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('phone'), prefixIcon: const Icon(Icons.phone_outlined)),
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
              final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
              Navigator.of(ctx).pop();

              final id = emp['id']?.toString() ?? '';
              final pos = roleCtrl.text.trim();
              final phone = phoneCtrl.text.trim();

              try {
                final db = await ModiriDesktopDatabase.instance.database;
                await db.update(
                  'employees',
                  {
                    'name': name,
                    'position': pos,
                    'base_salary': salary,
                    'phone': phone.isEmpty ? null : phone,
                  },
                  where: 'id = ?',
                  whereArgs: [id],
                );

                await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                  id: const Uuid().v4(),
                  clientTransactionId: const Uuid().v4(),
                  entityType: 'employee',
                  entityId: id,
                  operationType: 'UPDATE',
                  payload: {
                    'name': name,
                    'position': pos,
                    'baseSalary': salary,
                    'phone': phone,
                  },
                );

                await _loadEmployees();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.get('employee_updated_success')), backgroundColor: ModiriColors.brandTeal),
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
            child: Text(loc.get('update_employee')),
          ),
        ],
      ),
    );
  }

  void _showPaySalaryDialog(Map<String, dynamic> emp) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final empId = emp['id']?.toString() ?? '';
    final name = emp['name']?.toString() ?? 'Staff';
    final salary = ((emp['base_salary'] ?? 0.0) as num).toDouble();
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final amtCtrl = TextEditingController(text: salary.toStringAsFixed(0));
    final periodCtrl = TextEditingController(text: currentMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${loc.get("salary_payment")}: $name', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: periodCtrl,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('salary_period_input'), prefixIcon: const Icon(Icons.calendar_month)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: InputDecoration(labelText: loc.get('salary_amount_input'), prefixIcon: const Icon(Icons.payments_outlined)),
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
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              Navigator.of(ctx).pop();

              final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
              final period = periodCtrl.text.trim();
              final newId = const Uuid().v4();
              final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

              try {
                final db = await ModiriDesktopDatabase.instance.database;

                // Log salary as expense
                await db.insert('expenses', {
                  'id': newId,
                  'company_id': companyId,
                  'category': 'Salaries',
                  'amount': amt,
                  'description': 'Salary: $name ($period)',
                  'date': dateStr,
                  'created_at': DateTime.now().toIso8601String(),
                });

                await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                  id: const Uuid().v4(),
                  clientTransactionId: const Uuid().v4(),
                  entityType: 'salary_payment',
                  entityId: empId,
                  operationType: 'CREATE',
                  payload: {
                    'employeeId': empId,
                    'amount': amt,
                    'salaryPeriod': period,
                    'paymentDate': dateStr,
                    'description': 'Salary: $name ($period)',
                  },
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${loc.get('salary_logged_for')} $name: ${_formatCurrency(amt)} ($period)'),
                      backgroundColor: ModiriColors.brandTeal,
                    ),
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
            child: Text(loc.get('disburse_salary')),
          ),
        ],
      ),
    );
  }

  void _showEmployeeAttendanceModal(Map<String, dynamic> emp) {
    _showEmployeeProfileDialog(emp, initialTab: 1);
  }

  void _showEmployeeProfileDialog(Map<String, dynamic> emp, {int initialTab = 0}) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final empId = emp['id']?.toString() ?? '';
    final name = emp['name']?.toString() ?? 'Staff';
    final position = emp['position']?.toString() ?? loc.get('employee');
    final phone = emp['phone']?.toString() ?? loc.get('no_phone_listed');
    final createdAt = emp['created_at']?.toString() ?? '';
    final baseSalary = ((emp['base_salary'] ?? 0.0) as num).toDouble();
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final db = await ModiriDesktopDatabase.instance.database;

    final salaryHistory = await db.query(
      'expenses',
      where: "company_id = ? AND category = 'Salaries' AND description LIKE ?",
      whereArgs: [companyId, '%$name%'],
      orderBy: 'date DESC',
    );

    if (!mounted) return;

    String selectedStatus = 'present';
    final noteCtrl = TextEditingController();
    final todayStr = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final double totalPaid = salaryHistory.fold<double>(
            0.0,
            (sum, row) => sum + (((row['amount'] ?? 0.0) as num).toDouble()),
          );
          final lastPayment = salaryHistory.isNotEmpty ? salaryHistory.first['date']?.toString() : loc.get('pending');

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
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'E',
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
                                  color: ModiriColors.brandBlue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  position.toUpperCase(),
                                  style: const TextStyle(
                                    color: ModiriColors.brandBlue,
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ModiriColors.brandTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: Text(loc.get('pay_salary'), style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showPaySalaryDialog(emp);
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
                    // Top KPI Metrics Row
                    Row(
                      children: [
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
                                Text(loc.get('base_salary_label'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(baseSalary),
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
                              color: ModiriColors.brandTeal.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.get('total_paid'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCurrency(totalPaid),
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
                                Text(loc.get('salary_history'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  ModiriFormatters.formatNumber(salaryHistory.length),
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
                                Text(loc.get('last_payment'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  lastPayment != null ? ModiriFormatters.toLatinDigits(lastPayment) : '—',
                                  style: TextStyle(
                                    color: ModiriColors.textPrimary(isDark),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tabs Header
                    TabBar(
                      labelColor: ModiriColors.brandBlue,
                      unselectedLabelColor: ModiriColors.textSecondary(isDark),
                      indicatorColor: ModiriColors.brandBlue,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          text: loc.get('salary_history'),
                        ),
                        Tab(
                          icon: const Icon(Icons.fact_check_outlined, size: 16),
                          text: loc.get('attendance_logs'),
                        ),
                        Tab(
                          icon: const Icon(Icons.badge_outlined, size: 16),
                          text: loc.get('staff_details'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tab Contents
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Salary History
                          salaryHistory.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.payments_outlined, size: 40, color: ModiriColors.textMuted(isDark)),
                                      const SizedBox(height: 8),
                                      Text(loc.get('no_salary_disbursements_yet'),
                                          style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 13)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: salaryHistory.length,
                                  separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 1),
                                  itemBuilder: (_, idx) {
                                    final row = salaryHistory[idx];
                                    final amt = ((row['amount'] ?? 0.0) as num).toDouble();
                                    final desc = row['description']?.toString() ?? 'Salary Payment';
                                    final date = row['date']?.toString() ?? '';

                                    return ListTile(
                                      dense: true,
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: ModiriColors.brandTeal.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.payments_outlined, color: ModiriColors.brandTeal, size: 18),
                                      ),
                                      title: Text(desc,
                                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text(ModiriFormatters.toLatinDigits(date), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                      trailing: Text(
                                        _formatCurrency(amt),
                                        style: const TextStyle(
                                          color: ModiriColors.brandTeal,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    );
                                  },
                                ),

                          // Tab 2: Attendance Logger & Records
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
                                Text('${loc.get('log_today_attendance')} (${ModiriFormatters.toLatinDigits(todayStr)})',
                                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    for (final st in ['present', 'late', 'absent']) ...[
                                      ChoiceChip(
                                        label: Text(st.toUpperCase()),
                                        selected: selectedStatus == st,
                                        selectedColor: st == 'present'
                                            ? ModiriColors.brandTeal
                                            : (st == 'late' ? ModiriColors.brandAmber : ModiriColors.brandRose),
                                        labelStyle: TextStyle(
                                          color: selectedStatus == st ? Colors.white : ModiriColors.textPrimary(isDark),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                        onSelected: (_) => setDialogState(() => selectedStatus = st),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: noteCtrl,
                                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                                        decoration: InputDecoration(
                                          labelText: loc.get('attendance_note_optional'),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 16),
                                      label: Text(loc.get('save_attendance')),
                                      onPressed: () async {
                                        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
                                          id: const Uuid().v4(),
                                          clientTransactionId: const Uuid().v4(),
                                          entityType: 'employee_attendance',
                                          entityId: empId,
                                          operationType: 'CREATE',
                                          payload: {
                                            'employeeId': empId,
                                            'status': selectedStatus,
                                            'date': todayStr,
                                            if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
                                          },
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${loc.get('attendance_logged_for')} $name ($selectedStatus).'),
                                              backgroundColor: ModiriColors.brandTeal,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Tab 3: Detailed Staff Information
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
                                    Text(loc.get('staff_details'),
                                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: Text(loc.get('edit_staff'), style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _showEditEmployeeDialog(emp);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _EmployeeInfoRow(label: loc.get('name'), value: name, isDark: isDark),
                                const SizedBox(height: 10),
                                _EmployeeInfoRow(label: loc.get('position'), value: position, isDark: isDark),
                                const SizedBox(height: 10),
                                _EmployeeInfoRow(label: loc.get('base_salary_label'), value: _formatCurrency(baseSalary), isDark: isDark),
                                const SizedBox(height: 10),
                                _EmployeeInfoRow(label: loc.get('phone'), value: ModiriFormatters.toLatinDigits(phone), isDark: isDark),
                                const SizedBox(height: 10),
                                _EmployeeInfoRow(label: loc.get('hire_date'), value: ModiriFormatters.toLatinDigits(createdAt.split('T')[0]), isDark: isDark),
                                const SizedBox(height: 10),
                                _EmployeeInfoRow(label: loc.get('id'), value: ModiriFormatters.toLatinDigits(empId), isDark: isDark),
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
      ),
    );
  }

  Future<void> _confirmDeleteEmployee(Map<String, dynamic> emp) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final name = emp['name']?.toString() ?? 'Staff';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.get('delete_employee'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
        content: Text('${loc.get('confirm_delete_employee')} "$name"',
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
      ),
    );

    if (confirmed == true) {
      final id = emp['id']?.toString() ?? '';
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('employees', where: 'id = ?', whereArgs: [id]);

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'employee',
          entityId: id,
          operationType: 'DELETE',
          payload: {'id': id},
        );

        await _loadEmployees();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('removed_prefix')} "$name".'), backgroundColor: ModiriColors.brandTeal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('operation_failed')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final filtered = _employees.where((e) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (e['name'] ?? '').toString().toLowerCase();
      final pos = (e['position'] ?? '').toString().toLowerCase();
      return name.contains(q) || pos.contains(q);
    }).toList();

    final totalStaff = _employees.length;
    final totalMonthlyPayroll = _employees.fold(
      0.0,
      (acc, e) => acc + ((e['base_salary'] ?? 0.0 as num).toDouble()),
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
                    loc.get('employees_title'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.get('employees_subtitle'),
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(loc.get('refresh')),
                    onPressed: _loadEmployees,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: Text(loc.get('add_staff_member')),
                    onPressed: _showAddEmployeeDialog,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards
          Row(
            children: [
              Expanded(
                child: _EmployeeKpiCard(
                  title: loc.get('active_employees'),
                  value: totalStaff.toString(),
                  icon: Icons.badge_outlined,
                  color: ModiriColors.brandBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _EmployeeKpiCard(
                  title: loc.get('monthly_payroll_liability'),
                  value: _formatCurrency(totalMonthlyPayroll),
                  icon: Icons.payments_outlined,
                  color: ModiriColors.brandTeal,
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
              hintText: loc.get('search_staff_hint'),
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
                          child: Text(loc.get('no_employees_registered'),
                              style: TextStyle(color: ModiriColors.textMuted(isDark))),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: ModiriColors.border(isDark), height: 1),
                          itemBuilder: (ctx, i) {
                            final emp = filtered[i];
                            final name = emp['name']?.toString() ?? 'Staff';
                            final position = emp['position']?.toString() ?? 'Team Member';
                            final salary = ((emp['base_salary'] ?? 0.0) as num).toDouble();
                            final phone = emp['phone']?.toString();

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showEmployeeProfileDialog(emp),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: ModiriColors.brandIndigo.withOpacity(0.18),
                                      foregroundColor: ModiriColors.brandIndigo,
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
                                          Text('$position ${phone != null ? "· ${ModiriFormatters.toLatinDigits(phone)}" : ""}',
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
                                          Text(loc.get('base_salary_label'),
                                              style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10)),
                                          Text(
                                            _formatCurrency(salary),
                                            style: const TextStyle(
                                              color: ModiriColors.brandTeal,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    IconButton(
                                      icon: const Icon(Icons.person_outline, size: 19, color: ModiriColors.brandBlue),
                                      tooltip: loc.get('employee_profile'),
                                      onPressed: () => _showEmployeeProfileDialog(emp),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.fact_check_outlined, size: 14, color: ModiriColors.brandBlue),
                                      label: Text(loc.get('attendance'), style: const TextStyle(fontSize: 12)),
                                      onPressed: () => _showEmployeeAttendanceModal(emp),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? ModiriColors.ink850 : Colors.white,
                                        side: const BorderSide(color: ModiriColors.brandTeal),
                                      ),
                                      icon: const Icon(Icons.payments_outlined, size: 14, color: ModiriColors.brandTeal),
                                      label: Text(loc.get('pay_salary'), style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 12)),
                                      onPressed: () => _showPaySalaryDialog(emp),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, size: 19, color: ModiriColors.textSecondary(isDark)),
                                      tooltip: loc.get('edit_staff'),
                                      onPressed: () => _showEditEmployeeDialog(emp),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 19, color: ModiriColors.brandRose),
                                      tooltip: loc.get('delete_staff'),
                                      onPressed: () => _confirmDeleteEmployee(emp),
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

class _EmployeeKpiCard extends StatelessWidget {
  const _EmployeeKpiCard({
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

class _EmployeeInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _EmployeeInfoRow({required this.label, required this.value, required this.isDark});

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
