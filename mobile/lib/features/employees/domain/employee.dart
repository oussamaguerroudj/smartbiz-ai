/// Employee models — mirror `employees` table + the composed
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

class EmployeeDetails {
  EmployeeDetails({required this.employee, required this.attendance, this.salary});
  final Employee employee;
  final AttendanceSummary attendance;
  final SalarySummary? salary;

  factory EmployeeDetails.fromJson(Map<String, dynamic> json) => EmployeeDetails(
        employee: Employee.fromJson(json),
        attendance: AttendanceSummary.fromJson(json['attendance'] as Map<String, dynamic>),
        salary: json['salary'] != null
            ? SalarySummary.fromJson(json['salary'] as Map<String, dynamic>)
            : null,
      );
}
