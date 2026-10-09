import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/expense.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../superette/presentation/screens/superette_main_dashboard_screen.dart' show superetteDashboardProvider;
import '../../clothing/presentation/screens/clothing_main_dashboard_screen.dart' show clothingDashboardProvider;
import '../../pharmacy/presentation/screens/pharmacy_main_dashboard_screen.dart' show pharmacyDashboardProvider;
import '../../restaurant/data/restaurant_repository.dart' show restaurantDashboardProvider;
import '../../clinic/presentation/screens/clinic_dashboard_screen.dart' show clinicDashboardProvider;

class ExpensesState {
  ExpensesState({required this.expenses, required this.thisMonthTotal});
  final List<Expense> expenses;
  final double thisMonthTotal;
}

class ExpensesRepository extends StateNotifier<AsyncValue<ExpensesState>> {
  ExpensesRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  Future<void> load() async {
    // 1. Read from local SQLite first
    try {
      final local = await _fetchFromLocal();
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {}

    // 2. Fetch from backend in the background if online
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/expenses');
      final expenses = (response['data'] as List)
          .map((json) => Expense.fromJson(json as Map<String, dynamic>))
          .toList();

      await _upsertToLocal(expenses);
      final fresh = await _fetchFromLocal();
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current != null) {
        return; // Keep offline expenses
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<ExpensesState> _fetchFromLocal() async {
    final companyId = _companyId;
    // TENANT ISOLATION: return empty state when no account is active.
    if (companyId == null) return ExpensesState(expenses: [], thisMonthTotal: 0);

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'expenses',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'expense_date DESC, created_at DESC',
    );

    final now = DateTime.now();
    final mStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final mEnd = '${now.year}-${now.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final totalRes = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE company_id = ? AND date(expense_date) BETWEEN date(?) AND date(?)',
      [companyId, mStart, mEnd],
    );

    final thisMonthTotal = (totalRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final expenses = rows.map((r) => Expense.fromJson(r)).toList();

    return ExpensesState(expenses: expenses, thisMonthTotal: thisMonthTotal);
  }

  Future<void> _upsertToLocal(List<Expense> expenses) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final exp in expenses) {
      batch.insert(
        'expenses',
        {
          'id': exp.id,
          'company_id': companyId,
          'category': exp.category,
          'description': exp.description,
          'amount': exp.amount,
          'expense_date': exp.date.toIso8601String().substring(0, 10),
          'period_type': periodTypeToApi(exp.periodType),
          'employee_id': exp.employeeId,
          'salary_period': exp.salaryPeriod,
          'duration': exp.duration,
          'created_at': exp.date.toIso8601String(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> addExpense({
    required String category,
    required double amount,
    required ExpensePeriodType periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
    String? description,
    String? employeeId,
    String? salaryPeriod,
    String? duration,
    bool confirmedDuplicate = false,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final expenseId = const Uuid().v4();
    final clientId = const Uuid().v4();
    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final dateStr = periodStart.toIso8601String().substring(0, 10);

    // Save locally in SQLite immediately — tagged with current company
    await db.insert('expenses', {
      'id': expenseId,
      'client_id': clientId,
      'company_id': companyId,
      'category': category,
      'description': description,
      'amount': amount,
      'expense_date': dateStr,
      'period_type': periodTypeToApi(periodType),
      'employee_id': employeeId,
      'salary_period': salaryPeriod,
      'duration': duration,
      'created_at': nowIso,
      'synced': 0,
    });

    // Enqueue in sync queue (tagged with company_id)
    final payload = {
      'category': category,
      'amount': amount,
      'periodType': periodTypeToApi(periodType),
      'periodStart': dateStr,
      if (periodType == ExpensePeriodType.custom && periodEnd != null)
        'periodEnd': periodEnd.toIso8601String().substring(0, 10),
      if (description != null && description.isNotEmpty) 'description': description,
      if (employeeId != null) 'employeeId': employeeId,
      if (salaryPeriod != null) 'salaryPeriod': salaryPeriod,
      if (duration != null) 'duration': duration,
      if (confirmedDuplicate) 'confirmedDuplicate': true,
    };

    await db.insert('sync_queue', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'client_transaction_id': clientId,
      'entity_type': 'expense',
      'entity_id': expenseId,
      'operation_type': 'CREATE',
      'payload': jsonEncode(payload),
      'status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    // Refresh memory & dashboard immediately
    final fresh = await _fetchFromLocal();
    if (!mounted) return;
    state = AsyncValue.data(fresh);
    _invalidateAllDashboards();
    await _ref.read(syncServiceProvider.notifier).refreshQueueCounts();

    // Trigger sync in background if online
    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
  }

  Future<void> updateExpense({
    required String id,
    String? category,
    double? amount,
    ExpensePeriodType? periodType,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? description,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final Map<String, dynamic> updates = {};
    if (category != null) updates['category'] = category;
    if (amount != null) updates['amount'] = amount;
    if (periodType != null) updates['period_type'] = periodTypeToApi(periodType);
    if (periodStart != null) updates['expense_date'] = periodStart.toIso8601String().substring(0, 10);
    if (description != null) updates['description'] = description;

    if (updates.isNotEmpty) {
      // Scoped by company_id — cannot update another company's expense
      await db.update(
        'expenses',
        updates,
        where: 'id = ? AND company_id = ?',
        whereArgs: [id, companyId],
      );
      final fresh = await _fetchFromLocal();
      if (!mounted) return;
      state = AsyncValue.data(fresh);
      _invalidateAllDashboards();
    }

    try {
      final client = _ref.read(apiClientProvider);
      await client.put('/expenses/$id', body: {
        if (category != null) 'category': category,
        if (amount != null) 'amount': amount,
        if (periodType != null) 'periodType': periodTypeToApi(periodType),
        if (periodStart != null)
          'periodStart': periodStart.toIso8601String().substring(0, 10),
        if (periodType == ExpensePeriodType.custom && periodEnd != null)
          'periodEnd': periodEnd.toIso8601String().substring(0, 10),
        if (description != null) 'description': description,
      });
    } catch (_) {}
  }

  Future<void> deleteExpense(String id) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    // Scoped by company_id — cannot delete another company's expense
    await db.delete(
      'expenses',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
    final fresh = await _fetchFromLocal();
    if (!mounted) return;
    state = AsyncValue.data(fresh);
    _invalidateAllDashboards();

    try {
      final client = _ref.read(apiClientProvider);
      await client.delete('/expenses/$id');
    } catch (_) {}
  }

  void _invalidateAllDashboards() {
    _ref.read(dashboardRepositoryProvider.notifier).load();
    _ref.invalidate(superetteDashboardProvider);
    _ref.invalidate(clothingDashboardProvider);
    _ref.invalidate(pharmacyDashboardProvider);
    _ref.invalidate(restaurantDashboardProvider);
    _ref.invalidate(clinicDashboardProvider);
  }
}

final expensesRepositoryProvider =
    StateNotifierProvider.autoDispose<ExpensesRepository, AsyncValue<ExpensesState>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return ExpensesRepository(ref);
  },
);
