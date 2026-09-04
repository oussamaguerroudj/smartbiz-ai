import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/employee.dart';

class EmployeesRepository extends StateNotifier<AsyncValue<List<Employee>>> {
  EmployeesRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/employees');
      final employees = (response['data'] as List)
          .map((json) => Employee.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(employees);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addEmployee({required String name, required String position, required double baseSalary}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/employees', body: {'name': name, 'position': position, 'baseSalary': baseSalary});
    await load();
  }

  Future<EmployeeDetails> fetchDetails(String id) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/employees/$id');
    return EmployeeDetails.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> markAttendance(String employeeId, String status) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/employees/$employeeId/attendance', body: {'status': status});
  }

  Future<void> addSalaryAdjustment(String employeeId, {required String type, required double amount, String? note}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/employees/$employeeId/salary-adjustments', body: {
      'type': type,
      'amount': amount,
      if (note != null) 'note': note,
    });
  }
}

final employeesRepositoryProvider =
    StateNotifierProvider<EmployeesRepository, AsyncValue<List<Employee>>>(
  (ref) => EmployeesRepository(ref),
);

/// autoDispose: re-fetches fresh attendance/salary numbers every time
/// the Employee Details screen is opened (important — those numbers
/// change from actions taken ON this screen, like "Mark Present").
final employeeDetailsProvider =
    FutureProvider.autoDispose.family<EmployeeDetails, String>((ref, id) {
  return ref.read(employeesRepositoryProvider.notifier).fetchDetails(id);
});
