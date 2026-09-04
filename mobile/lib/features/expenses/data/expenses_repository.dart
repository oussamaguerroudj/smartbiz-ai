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
    String? description,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/expenses', body: {
      'category': category,
      'amount': amount,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    await load();
    await _ref.read(dashboardRepositoryProvider.notifier).load(); // today's expenses KPI changed
  }
}

final expensesRepositoryProvider =
    StateNotifierProvider<ExpensesRepository, AsyncValue<ExpensesState>>(
  (ref) => ExpensesRepository(ref),
);
