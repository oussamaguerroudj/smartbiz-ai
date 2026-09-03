// Employee models — mirror `employees`, `attendance_records`,
// `salary_adjustments` tables (Phase 3 migration 003).

enum AttendanceStatus { present, absent, late }

enum SalaryAdjustmentType { bonus, deduction }

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
}

class AttendanceRecord {
  AttendanceRecord({
    required this.employeeId,
    required this.date,
    required this.status,
  });

  final String employeeId;
  final DateTime date;
  final AttendanceStatus status;
}

class SalaryAdjustment {
  SalaryAdjustment({
    required this.employeeId,
    required this.type,
    required this.amount,
    required this.note,
  });

  final String employeeId;
  final SalaryAdjustmentType type;
  final double amount;
  final String note;
}
