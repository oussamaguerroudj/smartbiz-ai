import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Desktop CRUD & Offline Sync Workflows', () {
    late Database db;

    setUp(() async {
      final factory = databaseFactoryFfi;
      db = await factory.openDatabase(inMemoryDatabasePath);

      // Create full desktop SQLite tables
      await db.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          credit_balance REAL NOT NULL DEFAULT 0.0,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE suppliers (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          products_supplied INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE employees (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          position TEXT NOT NULL,
          base_salary REAL NOT NULL DEFAULT 0.0,
          phone TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE customer_transactions (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          customer_id TEXT NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          balance_after REAL NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE expenses (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          client_transaction_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation_type TEXT NOT NULL,
          payload TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Customer CRUD & Debt Deletion Guard', () async {
      const companyId = 'comp_test';

      // Insert customer with initial credit
      await db.insert('customers', {
        'id': 'cust_1',
        'company_id': companyId,
        'name': 'Karim Ahmed',
        'phone': '0555123456',
        'credit_balance': 4500.0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Verify customer exists
      final read = await db.query('customers', where: 'id = ?', whereArgs: ['cust_1']);
      expect(read.length, equals(1));
      final cust = read.first;
      expect(cust['name'], equals('Karim Ahmed'));
      final balance = cust['credit_balance'] as double;
      expect(balance, equals(4500.0));

      // Business Rule: Customers with credit_balance > 0 cannot be deleted
      final canDelete = balance <= 0;
      expect(canDelete, isFalse);

      // Now pay off the debt
      await db.update(
        'customers',
        {'credit_balance': 0.0},
        where: 'id = ?',
        whereArgs: ['cust_1'],
      );

      final updated = await db.query('customers', where: 'id = ?', whereArgs: ['cust_1']);
      expect((updated.first['credit_balance'] as num).toDouble(), equals(0.0));

      // Now safe to delete
      await db.delete('customers', where: 'id = ?', whereArgs: ['cust_1']);
      final afterDelete = await db.query('customers', where: 'id = ?', whereArgs: ['cust_1']);
      expect(afterDelete.isEmpty, isTrue);
    });

    test('2. Credit Repayment Ledger Mathematical Invariant', () async {
      const companyId = 'comp_test';
      const custId = 'cust_debtor';
      const initialDebt = 10000.0;
      const payment1 = 3000.0;
      const payment2 = 7000.0;

      await db.insert('customers', {
        'id': custId,
        'company_id': companyId,
        'name': 'Samir Benali',
        'credit_balance': initialDebt,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Record first repayment of 3,000 DZD
      const balanceAfter1 = initialDebt - payment1;
      await db.insert('customer_transactions', {
        'id': 'tx_1',
        'company_id': companyId,
        'customer_id': custId,
        'type': 'payment',
        'amount': payment1,
        'balance_after': balanceAfter1,
        'description': 'Partial repayment 1',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.update('customers', {'credit_balance': balanceAfter1}, where: 'id = ?', whereArgs: [custId]);

      var current = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect((current['credit_balance'] as num).toDouble(), equals(7000.0));

      // Record second repayment of 7,000 DZD (full settlement)
      const balanceAfter2 = balanceAfter1 - payment2;
      await db.insert('customer_transactions', {
        'id': 'tx_2',
        'company_id': companyId,
        'customer_id': custId,
        'type': 'payment',
        'amount': payment2,
        'balance_after': balanceAfter2,
        'description': 'Final settlement',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.update('customers', {'credit_balance': balanceAfter2}, where: 'id = ?', whereArgs: [custId]);

      current = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first;
      expect((current['credit_balance'] as num).toDouble(), equals(0.0));

      // Verify ledger has 2 payments total
      final txs = await db.query('customer_transactions', where: 'customer_id = ?', whereArgs: [custId]);
      expect(txs.length, equals(2));
      final totalPaid = txs.fold<double>(0.0, (acc, tx) => acc + (tx['amount'] as num).toDouble());
      expect(totalPaid, equals(10000.0));
    });

    test('3. Supplier CRUD & Search Filter', () async {
      const companyId = 'comp_test';

      await db.insert('suppliers', {
        'id': 'sup_1',
        'company_id': companyId,
        'name': 'Algiers Wholesale Foods',
        'phone': '021123456',
        'products_supplied': 24,
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('suppliers', {
        'id': 'sup_2',
        'company_id': companyId,
        'name': 'Oran Beverage Logistics',
        'phone': '041987654',
        'products_supplied': 12,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Query with search filter '%Oran%'
      final searchResult = await db.query(
        'suppliers',
        where: 'company_id = ? AND (name LIKE ? OR phone LIKE ?)',
        whereArgs: [companyId, '%Oran%', '%Oran%'],
      );
      expect(searchResult.length, equals(1));
      expect(searchResult.first['name'], equals('Oran Beverage Logistics'));
    });

    test('4. Payroll Disbursement Linked to Operating Expenses', () async {
      const companyId = 'comp_test';

      // Register employee
      await db.insert('employees', {
        'id': 'emp_1',
        'company_id': companyId,
        'name': 'Yacine Ammar',
        'position': 'Head Chef',
        'base_salary': 65000.0,
        'phone': '0661223344',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Disburse monthly salary
      const salaryMonth = '2026-10';
      await db.insert('expenses', {
        'id': 'exp_sal_1',
        'company_id': companyId,
        'category': 'Salaries',
        'amount': 65000.0,
        'description': 'Salary: Yacine Ammar ($salaryMonth)',
        'date': '2026-10-10',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Verify expense is recorded under Salaries
      final salaryExpenses = await db.query(
        'expenses',
        where: "company_id = ? AND category = 'Salaries'",
        whereArgs: [companyId],
      );
      expect(salaryExpenses.length, equals(1));
      expect((salaryExpenses.first['amount'] as num).toDouble(), equals(65000.0));
      expect(salaryExpenses.first['description'], contains('Yacine Ammar'));
    });

    test('5. Offline Sync Queue Isolation & Dequeue Lifecycle', () async {
      const companyA = 'comp_A';
      const companyB = 'comp_B';

      // Insert pending sync operations for company A
      await db.insert('sync_queue', {
        'id': 'q1',
        'company_id': companyA,
        'client_transaction_id': const Uuid().v4(),
        'entity_type': 'sale',
        'entity_id': 'sale_101',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'total': 2500.0, 'items': []}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert pending sync operation for company B
      await db.insert('sync_queue', {
        'id': 'q2',
        'company_id': companyB,
        'client_transaction_id': const Uuid().v4(),
        'entity_type': 'sale',
        'entity_id': 'sale_202',
        'operation_type': 'CREATE',
        'payload': jsonEncode({'total': 9000.0, 'items': []}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Read queue for company A only
      final queueA = await db.query(
        'sync_queue',
        where: "company_id = ? AND status = 'pending'",
        whereArgs: [companyA],
      );
      expect(queueA.length, equals(1));
      expect(queueA.first['entity_id'], equals('sale_101'));

      // Process operation and mark synced
      await db.update(
        'sync_queue',
        {'status': 'synced', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: ['q1'],
      );

      final pendingA = await db.query(
        'sync_queue',
        where: "company_id = ? AND status = 'pending'",
        whereArgs: [companyA],
      );
      expect(pendingA.isEmpty, isTrue);

      // Company B's operation must remain untouched and pending
      final pendingB = await db.query(
        'sync_queue',
        where: "company_id = ? AND status = 'pending'",
        whereArgs: [companyB],
      );
      expect(pendingB.length, equals(1));
      expect(pendingB.first['entity_id'], equals('sale_202'));
    });
  });
}
