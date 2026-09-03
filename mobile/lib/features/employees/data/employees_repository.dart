import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/employee.dart';

/// Net Salary formula (Spec Ch. 17.3): Base Salary + Bonuses − Deductions.
class EmployeesRepository extends StateNotifier<List<Employee>> {
  EmployeesRepository()
      : super([
          Employee(
              id: 'emp1',
              name: 'Sara Belkacem',
              position: 'Cashier',
              baseSalary: 35000),
          Employee(
              id: 'emp2',
              name: 'Yacine Hamdi',
              position: 'Stock Manager',
              baseSalary: 42000),
        ]);

  int _nextId = 3;

  void addEmployee(
      {required String name,
      required String position,
      required double baseSalary}) {
    state = [
      ...state,
      Employee(
          id: 'emp${_nextId++}',
          name: name,
          position: position,
          baseSalary: baseSalary)
    ];
  }
}

final employeesRepositoryProvider =
    StateNotifierProvider<EmployeesRepository, List<Employee>>(
        (ref) => EmployeesRepository());

class AttendanceRepository extends StateNotifier<List<AttendanceRecord>> {
  AttendanceRepository()
      : super([
          AttendanceRecord(
              employeeId: 'emp1',
              date: DateTime.now(),
              status: AttendanceStatus.present),
          AttendanceRecord(
              employeeId: 'emp2',
              date: DateTime.now(),
              status: AttendanceStatus.present),
        ]);

  void markAttendance(String employeeId, AttendanceStatus status) {
    state = [
      ...state,
      AttendanceRecord(
          employeeId: employeeId, date: DateTime.now(), status: status)
    ];
  }

  int countByStatus(String employeeId, AttendanceStatus status) => state
      .where((r) => r.employeeId == employeeId && r.status == status)
      .length;
}

final attendanceRepositoryProvider =
    StateNotifierProvider<AttendanceRepository, List<AttendanceRecord>>(
        (ref) => AttendanceRepository());

class SalaryAdjustmentsRepository
    extends StateNotifier<List<SalaryAdjustment>> {
  SalaryAdjustmentsRepository()
      : super([
          SalaryAdjustment(
              employeeId: 'emp1',
              type: SalaryAdjustmentType.bonus,
              amount: 2000,
              note: 'Performance'),
          SalaryAdjustment(
              employeeId: 'emp1',
              type: SalaryAdjustmentType.deduction,
              amount: 1000,
              note: 'Absence'),
        ]);

  double netSalaryFor(String employeeId, double baseSalary) {
    final bonuses = state
        .where((a) =>
            a.employeeId == employeeId && a.type == SalaryAdjustmentType.bonus)
        .fold<double>(0, (sum, a) => sum + a.amount);
    final deductions = state
        .where((a) =>
            a.employeeId == employeeId &&
            a.type == SalaryAdjustmentType.deduction)
        .fold<double>(0, (sum, a) => sum + a.amount);
    return baseSalary + bonuses - deductions;
  }
}

final salaryAdjustmentsRepositoryProvider =
    StateNotifierProvider<SalaryAdjustmentsRepository, List<SalaryAdjustment>>(
        (ref) => SalaryAdjustmentsRepository());
