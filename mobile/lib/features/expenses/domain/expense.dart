/// Expense model — mirrors `expenses` table (Phase 3 migration 009)
/// and GET /expenses response shape, verified in Phase 5 testing.
class Expense {
  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
  });

  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String? description;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        category: json['category'] as String,
        amount: double.parse(json['amount'].toString()),
        date: DateTime.parse(json['expense_date'] as String),
        description: json['description'] as String?,
      );
}
