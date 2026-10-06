import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_ai/core/connectivity/connectivity_service.dart';
import 'package:modiri_ai/core/database/app_database.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/sync/sync_service.dart';
import 'package:modiri_ai/features/appointments/data/appointments_repository.dart';
import 'package:modiri_ai/features/customers/data/customers_repository.dart';
import 'package:modiri_ai/features/employees/data/employees_repository.dart';
import 'package:modiri_ai/features/expenses/data/expenses_repository.dart';
import 'package:modiri_ai/features/expenses/domain/expense.dart';
import 'package:modiri_ai/features/invoices/data/invoices_repository.dart';
import 'package:modiri_ai/features/products/data/products_repository.dart';
import 'package:modiri_ai/features/sales/data/sales_repository.dart';
import 'package:modiri_ai/features/sales/domain/sale.dart';
import 'package:modiri_ai/features/suppliers/presentation/screens/suppliers_screen.dart';

class _TestSessionNotifier extends SessionNotifier {
  _TestSessionNotifier(Session initial) {
    state = initial;
  }

  void setSessionForTest(Session next) {
    state = next;
  }
}

class _OfflineConnectivityNotifier extends ConnectivityNotifier {
  _OfflineConnectivityNotifier() {
    state = ConnectionStatus.offline;
  }

  @override
  Future<void> checkNow() async {
    state = ConnectionStatus.offline;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const companyA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const companyB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  const sessionA = Session(
    accessToken: 'token-a',
    refreshToken: 'refresh-a',
    userId: 'user-a',
    companyId: companyA,
    userName: 'Owner A',
    email: 'owner-a@modiri.dz',
    role: 'owner',
  );

  const sessionB = Session(
    accessToken: 'token-b',
    refreshToken: 'refresh-b',
    userId: 'user-b',
    companyId: companyB,
    userName: 'Owner B',
    email: 'owner-b@modiri.dz',
    role: 'owner',
  );

  setUp(() async {
    final db = await AppDatabase.instance.database;
    for (final table in [
      'appointments',
      'products',
      'customers',
      'employees',
      'suppliers',
      'sales',
      'sale_items',
      'invoices',
      'expenses',
      'sync_queue',
    ]) {
      await db.delete(
        table,
        where: 'company_id IN (?, ?)',
        whereArgs: [companyA, companyB],
      );
    }
    await db.delete(
      'sync_metadata',
      where: 'key IN (?, ?)',
      whereArgs: ['company_info_$companyA', 'company_info_$companyB'],
    );
  });

  group('SEC-SQLITE-001 & SEC-SQLITE-002: Offline Multi-Tenant SQLite & Provider Isolation', () {
    test('Account A offline data (appointments, products, customers, employees, suppliers, expenses, sales, sync_queue) is completely invisible to Account B and unauthenticated state', () async {
      final sessionNotifier = _TestSessionNotifier(sessionA);
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => sessionNotifier),
          connectionStatusProvider.overrideWith((ref) => _OfflineConnectivityNotifier()),
        ],
      );
      addTearDown(container.dispose);

      // Keep autoDispose providers mounted just as active UI screens do
      container.listen(productsRepositoryProvider, (_, __) {});
      container.listen(customersRepositoryProvider, (_, __) {});
      container.listen(employeesRepositoryProvider, (_, __) {});
      container.listen(suppliersRepositoryProvider, (_, __) {});
      container.listen(appointmentsRepositoryProvider, (_, __) {});
      container.listen(expensesRepositoryProvider, (_, __) {});
      container.listen(salesRepositoryProvider, (_, __) {});
      container.listen(invoicesRepositoryProvider, (_, __) {});
      container.listen(syncServiceProvider, (_, __) {});

      // 1. Account A creates offline records across all modules
      await container.read(productsRepositoryProvider.notifier).addProduct(
            name: 'Tenant A Secret Product',
            category: 'Electronics',
            purchasePrice: 1000,
            sellingPrice: 1500,
            quantity: 20,
          );
      await container.read(customersRepositoryProvider.notifier).addCustomer(
            'Tenant A VIP Customer',
            '0550112233',
          );
      await container.read(employeesRepositoryProvider.notifier).addEmployee(
            name: 'Tenant A Employee',
            position: 'Manager',
            baseSalary: 60000,
          );
      await container.read(suppliersRepositoryProvider.notifier).addSupplier(
            'Tenant A Supplier',
            '0550998877',
          );
      await container.read(appointmentsRepositoryProvider.notifier).addAppointment(
            customerName: 'Tenant A Patient',
            scheduledAt: DateTime(2026, 10, 15, 14, 30),
            notes: 'Dental Checkup',
          );
      await container.read(expensesRepositoryProvider.notifier).addExpense(
            category: 'Rent',
            amount: 45000,
            periodType: ExpensePeriodType.monthly,
            periodStart: DateTime(2026, 10, 1),
            description: 'Tenant A Office Rent',
          );

      final productsA = container.read(productsRepositoryProvider).valueOrNull ?? [];
      expect(productsA.length, 1);
      expect(productsA.first.name, 'Tenant A Secret Product');

      // Create an offline POS sale for Account A
      await container.read(salesRepositoryProvider.notifier).createSale(
            items: [
              SaleItemInput(
                productId: productsA.first.id,
                productName: productsA.first.name,
                quantity: 2,
              ),
            ],
          );

      expect(container.read(customersRepositoryProvider).valueOrNull?.length, 1);
      expect(container.read(employeesRepositoryProvider).valueOrNull?.length, 1);
      expect(container.read(suppliersRepositoryProvider).valueOrNull?.length, 1);
      expect(container.read(appointmentsRepositoryProvider).valueOrNull?.length, 1);
      expect(container.read(expensesRepositoryProvider).valueOrNull?.expenses.length, 1);
      expect(container.read(salesRepositoryProvider).valueOrNull?.length, 1);
      expect(container.read(invoicesRepositoryProvider).valueOrNull?.length, 1);

      await container.read(syncServiceProvider.notifier).refreshQueueCounts();
      expect(container.read(syncServiceProvider).pendingCount, greaterThan(0));

      // 2. Account A logs out -> Session becomes empty
      sessionNotifier.setSessionForTest(Session.empty);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await container.read(productsRepositoryProvider.notifier).load();
      await container.read(customersRepositoryProvider.notifier).load();
      await container.read(employeesRepositoryProvider.notifier).load();
      await container.read(suppliersRepositoryProvider.notifier).load();
      await container.read(appointmentsRepositoryProvider.notifier).load();
      await container.read(expensesRepositoryProvider.notifier).load();
      await container.read(salesRepositoryProvider.notifier).load();
      await container.read(invoicesRepositoryProvider.notifier).load();
      await container.read(syncServiceProvider.notifier).refreshQueueCounts();

      expect(container.read(productsRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(customersRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(employeesRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(suppliersRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(appointmentsRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(expensesRepositoryProvider).valueOrNull?.expenses ?? [], isEmpty);
      expect(container.read(salesRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(invoicesRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(syncServiceProvider).pendingCount, 0);

      // 3. Account B logs in on the same device
      sessionNotifier.setSessionForTest(sessionB);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await container.read(productsRepositoryProvider.notifier).load();
      await container.read(customersRepositoryProvider.notifier).load();
      await container.read(employeesRepositoryProvider.notifier).load();
      await container.read(suppliersRepositoryProvider.notifier).load();
      await container.read(appointmentsRepositoryProvider.notifier).load();
      await container.read(expensesRepositoryProvider.notifier).load();
      await container.read(salesRepositoryProvider.notifier).load();
      await container.read(invoicesRepositoryProvider.notifier).load();
      await container.read(syncServiceProvider.notifier).refreshQueueCounts();

      // Account B MUST see zero rows from Account A
      expect(container.read(productsRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(customersRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(employeesRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(suppliersRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(appointmentsRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(expensesRepositoryProvider).valueOrNull?.expenses ?? [], isEmpty);
      expect(container.read(salesRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(invoicesRepositoryProvider).valueOrNull ?? [], isEmpty);
      expect(container.read(syncServiceProvider).pendingCount, 0);

      // 4. Account B attempts to modify/cancel Account A's appointment by ID
      final db = await AppDatabase.instance.database;
      final accountAAppointmentRows = await db.query(
        'appointments',
        where: 'company_id = ?',
        whereArgs: [companyA],
      );
      expect(accountAAppointmentRows.length, 1);
      final accountAAppointmentId = accountAAppointmentRows.first['id'] as String;

      await container.read(appointmentsRepositoryProvider.notifier).updateStatus(accountAAppointmentId, 'cancelled');
      await container.read(appointmentsRepositoryProvider.notifier).updateAppointment(
            id: accountAAppointmentId,
            customerName: 'Hijacked By Tenant B',
          );

      // Verify Account A's appointment was NOT modified or deleted by Account B
      final accountAAfterAttack = await db.query(
        'appointments',
        where: 'id = ? AND company_id = ?',
        whereArgs: [accountAAppointmentId, companyA],
      );
      expect(accountAAfterAttack.length, 1);
      expect(accountAAfterAttack.first['status'], 'scheduled');

      // 5. Switch back to Account A and verify all Account A offline data is still preserved
      sessionNotifier.setSessionForTest(sessionA);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await container.read(productsRepositoryProvider.notifier).load();
      await container.read(appointmentsRepositoryProvider.notifier).load();
      await container.read(syncServiceProvider.notifier).refreshQueueCounts();

      expect(container.read(productsRepositoryProvider).valueOrNull?.length, 1);
      expect(container.read(appointmentsRepositoryProvider).valueOrNull?.length, 1);
      expect(container.read(syncServiceProvider).pendingCount, greaterThan(0));
    });
  });
}
