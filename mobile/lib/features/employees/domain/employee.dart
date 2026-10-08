/// Employee models  -  mirror `employees` table + the composed
/// GET /employees/:id response shape (employee row + attendance summary
/// + salary summary), verified against Phase 5 employees.service.js.
class Employee {
  Employee({
    required this.id,
    required this.name,
    required this.position,
    required this.baseSalary,
    this.phone,
  });

  final String id;
  final String name;
  final String position;
  final double baseSalary;
  final String? phone;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        name: json['name'] as String,
        position: (json['position'] as String?) ?? 'Staff',
        baseSalary: double.parse(json['base_salary'].toString()),
        phone: json['phone'] as String?,
      );
}

class AttendanceSummary {
  AttendanceSummary({required this.present, required this.absent, required this.late});
  final int present;
  final int absent;
  final int late;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) => AttendanceSummary(
        present: (json['present'] as num?)?.toInt() ?? 0,
        absent: (json['absent'] as num?)?.toInt() ?? 0,
        late: (json['late'] as num?)?.toInt() ?? 0,
      );
}

class SalarySummary {
  SalarySummary({required this.base, required this.bonuses, required this.deductions, required this.net});
  final double base;
  final double bonuses;
  final double deductions;
  final double net;

  factory SalarySummary.fromJson(Map<String, dynamic> json) => SalarySummary(
        base: (json['base'] as num).toDouble(),
        bonuses: (json['bonuses'] as num).toDouble(),
        deductions: (json['deductions'] as num).toDouble(),
        net: (json['net'] as num).toDouble(),
      );
}

class SalaryPayment {
  SalaryPayment({
    required this.id,
    required this.amount,
    required this.expenseDate,
    this.salaryPeriod,
    this.duration,
    this.description,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String expenseDate;
  final String? salaryPeriod;
  final String? duration;
  final String? description;
  final String? createdAt;

  factory SalaryPayment.fromJson(Map<String, dynamic> json) => SalaryPayment(
        id: json['id'] as String,
        amount: double.parse(json['amount'].toString()),
        expenseDate: (json['expenseDate'] ?? json['expense_date'])?.toString() ?? '',
        salaryPeriod: (json['salaryPeriod'] ?? json['salary_period']) as String?,
        duration: json['duration'] as String?,
        description: json['description'] as String?,
        createdAt: (json['createdAt'] ?? json['created_at']) as String?,
      );
}

class EmployeeDetails {
  EmployeeDetails({
    required this.employee,
    required this.attendance,
    this.salary,
    this.salaryPayments = const [],
  });
  final Employee employee;
  final AttendanceSummary attendance;
  final SalarySummary? salary;
  final List<SalaryPayment> salaryPayments;

  factory EmployeeDetails.fromJson(Map<String, dynamic> json) => EmployeeDetails(
        employee: Employee.fromJson(json),
        attendance: AttendanceSummary.fromJson(json['attendance'] as Map<String, dynamic>),
        salary: json['salary'] != null
            ? SalarySummary.fromJson(json['salary'] as Map<String, dynamic>)
            : null,
        salaryPayments: (json['salaryPayments'] as List?)
                ?.map((item) => SalaryPayment.fromJson(item as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
