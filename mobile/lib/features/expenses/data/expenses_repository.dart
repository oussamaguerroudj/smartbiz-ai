import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/expense.dart';
import '../../dashboard/data/dashboard_repository.dart';

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

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/expenses');
      final expenses = (response['data'] as List)
          .map((json) => Expense.fromJson(json as Map<String, dynamic>))
          .toList();
      final total = (response['thisMonthTotal'] as num).toDouble();
      state = AsyncValue.data(ExpensesState(expenses: expenses, thisMonthTotal: total));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
    final client = _ref.read(apiClientProvider);
    await client.post('/expenses', body: {
      'category': category,
      'amount': amount,
      'periodType': periodTypeToApi(periodType),
      'periodStart': periodStart.toIso8601String().substring(0, 10),
      // Required by the backend only when periodType is custom — for
      // every other type the server computes the real period_end
      // itself (see expenses.service.js resolvePeriodEnd), so it's
      // safe to omit otherwise.
      if (periodType == ExpensePeriodType.custom && periodEnd != null)
        'periodEnd': periodEnd.toIso8601String().substring(0, 10),
      if (description != null && description.isNotEmpty) 'description': description,
      if (employeeId != null) 'employeeId': employeeId,
      if (salaryPeriod != null) 'salaryPeriod': salaryPeriod,
      if (duration != null) 'duration': duration,
      if (confirmedDuplicate) 'confirmedDuplicate': true,
    });
    await load();
    await _ref.read(dashboardRepositoryProvider.notifier).load(); // today's expenses KPI changed
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
    await load();
    await _ref.read(dashboardRepositoryProvider.notifier).load();
  }

  Future<void> deleteExpense(String id) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/expenses/$id');
    await load();
    await _ref.read(dashboardRepositoryProvider.notifier).load();
  }
}

final expensesRepositoryProvider =
    StateNotifierProvider.autoDispose<ExpensesRepository, AsyncValue<ExpensesState>>(
  (ref) => ExpensesRepository(ref),
);
