/// Expense model — mirrors `expenses` table (Phase 3 migration 009,
/// extended by migration 013 with period_type/period_start/period_end)
/// and GET /expenses response shape.
enum ExpensePeriodType { oneTime, daily, monthly, yearly, custom }

ExpensePeriodType _periodTypeFromJson(String? raw) {
  switch (raw) {
    case 'daily':
      return ExpensePeriodType.daily;
    case 'monthly':
      return ExpensePeriodType.monthly;
    case 'yearly':
      return ExpensePeriodType.yearly;
    case 'custom':
      return ExpensePeriodType.custom;
    case 'one_time':
    default:
      return ExpensePeriodType.oneTime;
  }
}

String periodTypeToApi(ExpensePeriodType type) {
  switch (type) {
    case ExpensePeriodType.daily:
      return 'daily';
    case ExpensePeriodType.monthly:
      return 'monthly';
    case ExpensePeriodType.yearly:
      return 'yearly';
    case ExpensePeriodType.custom:
      return 'custom';
    case ExpensePeriodType.oneTime:
      return 'one_time';
  }
}

class Expense {
  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    this.description,
    this.employeeId,
    this.salaryPeriod,
    this.duration,
  });

  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String? description;
  final String? employeeId;
  final String? salaryPeriod;
  final String? duration;

  /// FIX (reported bug): a single payment covering several months (e.g.
  /// a 3-month electricity bill) used to have no way to say so, and was
  /// treated as if the whole amount was spent on [date] alone. These
  /// three fields are what let Profit calculations spread the cost
  /// across the real period it covers instead (see backend migration
  /// 013 / expenses.repository.totalForRange).
  final ExpensePeriodType periodType;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Whole days covered by this expense — used client-side to show
  /// "covers 92 days" / a per-day cost hint next to the amount field.
  int get periodDays => periodEnd.difference(periodStart).inDays + 1;

  double get dailyCost => periodDays > 0 ? amount / periodDays : amount;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        category: json['category'] as String,
        amount: double.parse(json['amount'].toString()),
        date: DateTime.parse(json['expense_date'] as String),
        description: json['description'] as String?,
        employeeId: json['employee_id'] as String?,
        salaryPeriod: json['salary_period'] as String?,
        duration: json['duration'] as String?,
        periodType: _periodTypeFromJson(json['period_type'] as String?),
        periodStart: DateTime.parse(
          (json['period_start'] as String?) ?? json['expense_date'] as String,
        ),
        periodEnd: DateTime.parse(
          (json['period_end'] as String?) ?? json['expense_date'] as String,
        ),
      );
}
