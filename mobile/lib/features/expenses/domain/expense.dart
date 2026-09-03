/// Expense model — mirrors `expenses` table (Phase 3 migration 009).
class Expense {
  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
  });

  final String id;
  final String
      category; // Electricity, Transport, Internet, Rent, Supplies, Other
  final double amount;
  final DateTime date;
  final String? description;
}
