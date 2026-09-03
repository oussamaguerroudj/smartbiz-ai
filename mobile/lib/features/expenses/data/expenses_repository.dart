import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/expense.dart';

class ExpensesRepository extends StateNotifier<List<Expense>> {
  ExpensesRepository()
      : super([
          Expense(
            id: 'e1',
            category: 'Electricity',
            amount: 12000,
            date: DateTime.now().subtract(const Duration(days: 2)),
          ),
          Expense(
            id: 'e2',
            category: 'Rent',
            amount: 60000,
            date: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ]);

  int _nextId = 3;

  void addExpense({
    required String category,
    required double amount,
    required DateTime date,
    String? description,
  }) {
    state = [
      Expense(
        id: 'e${_nextId++}',
        category: category,
        amount: amount,
        date: date,
        description: description,
      ),
      ...state,
    ];
  }

  double get thisMonthTotal {
    final now = DateTime.now();
    return state
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0, (sum, e) => sum + e.amount);
  }
}

final expensesRepositoryProvider =
    StateNotifierProvider<ExpensesRepository, List<Expense>>(
  (ref) => ExpensesRepository(),
);
