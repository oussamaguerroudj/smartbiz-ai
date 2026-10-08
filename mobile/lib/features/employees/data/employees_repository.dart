import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../expenses/data/expenses_repository.dart';
import '../domain/employee.dart';

class EmployeesRepository extends StateNotifier<AsyncValue<List<Employee>>> {
  EmployeesRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> load({String? query}) async {
    // 1. Read from local SQLite immediately
    try {
      final local = await _fetchFromLocal(query: query);
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {}

    // 2. Fetch from backend in the background if online
    final status = _ref.read(connectionStatusProvider);
    if (status != ConnectionStatus.online) {
      return;
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/employees');
      final employees = (response['data'] as List)
          .map((json) => Employee.fromJson(json as Map<String, dynamic>))
          .toList();

      await _upsertToLocal(employees);
      final fresh = await _fetchFromLocal(query: query);
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current != null) {
        return; // Keep offline data smoothly
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Employee>> _fetchFromLocal({String? query}) async {
    final companyId = _companyId;
    // TENANT ISOLATION: return nothing when no account is active.
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    List<Map<String, dynamic>> rows;
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      rows = await db.query(
        'employees',
        where: 'company_id = ? AND (name LIKE ? OR position LIKE ?) AND deleted_at IS NULL',
        whereArgs: [companyId, q, q],
        orderBy: 'name ASC',
      );
    } else {
      rows = await db.query(
        'employees',
        where: 'company_id = ? AND deleted_at IS NULL',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
    }

    return rows
        .map((r) => Employee(
              id: r['id'] as String,
              name: r['name'] as String,
              position: (r['position'] as String?) ?? 'Staff',
              baseSalary: (r['base_salary'] as num?)?.toDouble() ?? 0.0,
              phone: r['phone'] as String?,
            ))
        .toList();
  }

  Future<void> _upsertToLocal(List<Employee> employees) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final emp in employees) {
      // Preserve local un-synced changes
      final unSynced = await db.query(
        'employees',
        where: 'id = ? AND company_id = ? AND synced = 0',
        whereArgs: [emp.id, companyId],
      );
      if (unSynced.isNotEmpty) continue;

      batch.insert(
        'employees',
        {
          'id': emp.id,
          'company_id': companyId,
          'name': emp.name,
          'position': emp.position,
          'base_salary': emp.baseSalary,
          'phone': emp.phone,
          'created_at': DateTime.now().toIso8601String(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> addEmployee({
    required String name,
    required String position,
    required double baseSalary,
    String? phone,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final newId = const Uuid().v4();
    final clientId = const Uuid().v4();
    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.insert('employees', {
      'id': newId,
      'client_id': clientId,
      'company_id': companyId,
      'name': name,
      'position': position,
      'base_salary': baseSalary,
      'phone': phone,
      'created_at': nowIso,
      'synced': 0,
    });

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: clientId,
          entityType: 'employee',
          entityId: newId,
          operationType: 'CREATE',
          payload: {
            'name': name,
            'position': position,
            'baseSalary': baseSalary,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
          },
        );
  }

  Future<void> updateEmployee(
    String id, {
    required String name,
    required String position,
    required double baseSalary,
    String? phone,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    // Scoped by company_id  -  cannot update another company's employee
    await db.update(
      'employees',
      {
        'name': name,
        'position': position,
        'base_salary': baseSalary,
        'phone': phone,
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'employee',
          entityId: id,
          operationType: 'UPDATE',
          payload: {
            'name': name,
            'position': position,
            'baseSalary': baseSalary,
            if (phone != null) 'phone': phone,
          },
        );
  }

  Future<void> deleteEmployee(String id) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    // Scoped by company_id  -  cannot soft-delete another company's employee
    await db.update(
      'employees',
      {'deleted_at': nowIso, 'synced': 0},
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'employee',
          entityId: id,
          operationType: 'DELETE',
          payload: {'id': id},
        );
  }

  Future<EmployeeDetails> fetchDetails(String id) async {
    final companyId = _companyId;
    final db = await AppDatabase.instance.database;

    // 1. Fetch locally first (strictly scoped by company)
    Employee? localEmp;
    final empRows = companyId != null
        ? await db.query('employees', where: 'id = ? AND company_id = ?', whereArgs: [id, companyId])
        : <Map<String, dynamic>>[];

    if (empRows.isNotEmpty) {
      final r = empRows.first;
      localEmp = Employee(
        id: r['id'] as String,
        name: r['name'] as String,
        position: (r['position'] as String?) ?? 'Staff',
        baseSalary: (r['base_salary'] as num?)?.toDouble() ?? 0.0,
        phone: r['phone'] as String?,
      );
    }

    // Salary payments are linked by employee_id (FK to employees)
    // Since employees are already scoped by company, payments are transitively scoped.
    final payRows = await db.query(
      'salary_payments',
      where: 'employee_id = ?',
      whereArgs: [id],
      orderBy: 'payment_date DESC',
    );
    final localPayments = payRows.map((r) => SalaryPayment(
          id: r['id'] as String,
          amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
          expenseDate: (r['payment_date'] ?? '').toString(),
          salaryPeriod: r['salary_period'] as String?,
          duration: r['duration'] as String?,
          description: r['note'] as String?,
          createdAt: r['created_at'] as String?,
        )).toList();

    // 2. If online, fetch authoritative details from backend
    final status = _ref.read(connectionStatusProvider);
    if (status == ConnectionStatus.online) {
      try {
        final client = _ref.read(apiClientProvider);
        final response = await client.get('/employees/$id');
        final serverDetails = EmployeeDetails.fromJson(response['data'] as Map<String, dynamic>);

        // Cache payments locally
        final batch = db.batch();
        for (final p in serverDetails.salaryPayments) {
          batch.insert(
            'salary_payments',
            {
              'id': p.id,
              'employee_id': id,
              'amount': p.amount,
              'payment_date': p.expenseDate,
              'salary_period': p.salaryPeriod ?? '',
              'duration': p.duration,
              'note': p.description,
              'created_at': p.createdAt ?? DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);

        return serverDetails;
      } catch (_) {}
    }

    if (localEmp != null) {
      return EmployeeDetails(
        employee: localEmp,
        attendance: AttendanceSummary(present: 0, absent: 0, late: 0),
        salary: SalarySummary(
          base: localEmp.baseSalary,
          bonuses: 0,
          deductions: 0,
          net: localEmp.baseSalary,
        ),
        salaryPayments: localPayments,
      );
    }

    throw Exception('Employee not found locally');
  }

  Future<void> markAttendance(String employeeId, String status) async {
    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'employee',
          entityId: employeeId,
          operationType: 'MARK_ATTENDANCE',
          payload: {'status': status},
        );
  }

  Future<void> addSalaryAdjustment(
    String employeeId, {
    required String type,
    required double amount,
    String? note,
  }) async {
    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'employee',
          entityId: employeeId,
          operationType: 'SALARY_ADJUSTMENT',
          payload: {'type': type, 'amount': amount, if (note != null) 'note': note},
        );
  }

  Future<void> paySalary({
    required String employeeId,
    required double amount,
    required DateTime paymentDate,
    required String salaryPeriod,
    String duration = '1 month',
    String? note,
    bool confirmedDuplicate = false,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final paymentId = const Uuid().v4();
    final clientId = const Uuid().v4();
    final expenseId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final dateStr =
        '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';

    // 1. Fetch employee name for expense description (scoped by company)
    final empRows = await db.query(
      'employees',
      where: 'id = ? AND company_id = ?',
      whereArgs: [employeeId, companyId],
    );
    final empName = empRows.isNotEmpty ? (empRows.first['name'] as String?) : 'Employee';

    // 2. Insert salary payment locally
    await db.insert('salary_payments', {
      'id': paymentId,
      'client_id': clientId,
      'employee_id': employeeId,
      'amount': amount,
      'payment_date': dateStr,
      'salary_period': salaryPeriod,
      'duration': duration,
      'note': note,
      'created_at': nowIso,
      'synced': 0,
    });

    // 3. Insert expense locally (tagged with company_id so financial calculations update correctly)
    await db.insert('expenses', {
      'id': expenseId,
      'client_id': clientId,
      'company_id': companyId,
      'category': 'Salary',
      'description': 'Salary: $empName ($salaryPeriod)',
      'amount': amount,
      'expense_date': dateStr,
      'period_type': 'one_time',
      'employee_id': employeeId,
      'salary_period': salaryPeriod,
      'duration': duration,
      'created_at': nowIso,
      'synced': 0,
    });

    // 4. Enqueue in Sync Queue
    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: clientId,
          entityType: 'salary_payment',
          entityId: paymentId,
          operationType: 'CREATE',
          payload: {
            'employeeId': employeeId,
            'amount': amount,
            'paymentDate': dateStr,
            'salaryPeriod': salaryPeriod,
            'duration': duration,
            if (note != null && note.isNotEmpty) 'note': note,
            if (confirmedDuplicate) 'confirmedDuplicate': true,
          },
        );

    // 5. Instantly refresh affected repositories & Dashboard!
    await _ref.read(dashboardRepositoryProvider.notifier).load();
    await _ref.read(expensesRepositoryProvider.notifier).load();
  }
}

final employeesRepositoryProvider =
    StateNotifierProvider<EmployeesRepository, AsyncValue<List<Employee>>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return EmployeesRepository(ref);
  },
);

final employeeDetailsProvider =
    FutureProvider.autoDispose.family<EmployeeDetails, String>((ref, id) {
  return ref.read(employeesRepositoryProvider.notifier).fetchDetails(id);
});
