import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/features/employees/domain/employee.dart';

void main() {
  group('Employee Domain & Salary Payment Tests', () {
    test('Correctly parses EmployeeDetails with actual salary payments', () {
      final json = {
        'id': 'emp-101',
        'name': 'Ahmed Benali',
        'position': 'Head Chef',
        'base_salary': '45000.00',
        'phone': '0555123456',
        'attendance': {
          'present': 22,
          'absent': 1,
          'late': 0,
        },
        'salary': {
          'base': 45000.0,
          'bonuses': 5000.0,
          'deductions': 1000.0,
          'net': 49000.0,
        },
        'salaryPayments': [
          {
            'id': 'exp-sal-1',
            'amount': 45000.0,
            'expenseDate': '2026-09-30',
            'salaryPeriod': '2026-09',
            'duration': '1 month',
            'description': 'September 2026 Salary',
            'createdAt': '2026-09-30T10:00:00.000Z',
          },
          {
            'id': 'exp-sal-2',
            'amount': 45000.0,
            'expense_date': '2026-08-31',
            'salary_period': '2026-08',
            'duration': '1 month',
            'description': 'August 2026 Salary',
            'created_at': '2026-08-31T10:00:00.000Z',
          },
        ],
      };

      final details = EmployeeDetails.fromJson(json);

      expect(details.employee.id, 'emp-101');
      expect(details.employee.name, 'Ahmed Benali');
      expect(details.employee.baseSalary, 45000.0);
      expect(details.attendance.present, 22);
      expect(details.salary?.net, 49000.0);

      expect(details.salaryPayments.length, 2);
      expect(details.salaryPayments[0].id, 'exp-sal-1');
      expect(details.salaryPayments[0].amount, 45000.0);
      expect(details.salaryPayments[0].expenseDate, '2026-09-30');
      expect(details.salaryPayments[0].salaryPeriod, '2026-09');
      expect(details.salaryPayments[0].duration, '1 month');

      // Verify snake_case fallback compatibility
      expect(details.salaryPayments[1].expenseDate, '2026-08-31');
      expect(details.salaryPayments[1].salaryPeriod, '2026-08');
    });

    test('Correctly handles EmployeeDetails with empty salary payments', () {
      final json = {
        'id': 'emp-102',
        'name': 'Sara Mansouri',
        'position': 'Barista',
        'base_salary': '30000',
        'attendance': {
          'present': 0,
          'absent': 0,
          'late': 0,
        },
      };

      final details = EmployeeDetails.fromJson(json);

      expect(details.employee.name, 'Sara Mansouri');
      expect(details.employee.baseSalary, 30000.0);
      expect(details.salary, isNull);
      expect(details.salaryPayments, isEmpty);
    });
  });
}
