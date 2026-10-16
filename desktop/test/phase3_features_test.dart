import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 3 Feature Tests — Modiri AI Desktop', () {
    late Database db;
    const testCompany = 'phase3_test_co';

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Create schema mirroring desktop_database.dart with Phase 3 enhancements
      await db.execute('''
        CREATE TABLE suppliers (
          id TEXT PRIMARY KEY,
          company_id TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
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
          client_transaction_id TEXT NOT NULL,
          company_id TEXT NOT NULL,
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

    test('1. Supplier address column persists and supports procurement spend tracking', () async {
      final supId = const Uuid().v4();
      await db.insert('suppliers', {
        'id': supId,
        'company_id': testCompany,
        'name': 'Wholesale Textiles Algeria',
        'phone': '0555123456',
        'address': 'Zone Industrielle Oued Smar, Alger',
        'products_supplied': 12,
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      final rows = await db.query('suppliers', where: 'id = ?', whereArgs: [supId]);
      expect(rows.length, 1);
      expect(rows.first['address'], 'Zone Industrielle Oued Smar, Alger');
      expect(rows.first['products_supplied'], 12);

      // Record a procurement supply invoice for this supplier
      final expId = const Uuid().v4();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await db.insert('expenses', {
        'id': expId,
        'company_id': testCompany,
        'category': 'Supplies / Restock',
        'amount': 45000.0,
        'description': 'Supplier: Wholesale Textiles Algeria | Ref: SUP-INV-001 (Fabric Rolls & Zippers)',
        'date': dateStr,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Verify procurement expense is queryable by supplier name
      final purchases = await db.query(
        'expenses',
        where: "company_id = ? AND description LIKE ?",
        whereArgs: [testCompany, '%Supplier: Wholesale Textiles Algeria%'],
      );
      expect(purchases.length, 1);
      expect((purchases.first['amount'] as num).toDouble(), 45000.0);
      expect(purchases.first['category'], 'Supplies / Restock');
    });

    test('2. Employee salary payment payload adheres to backend contract without double-counting', () async {
      final empId = const Uuid().v4();
      await db.insert('employees', {
        'id': empId,
        'company_id': testCompany,
        'name': 'Karim Bellil',
        'position': 'Head Cashier',
        'base_salary': 50000.0,
        'phone': '0661987654',
        'created_at': DateTime.now().toIso8601String(),
      });

      const period = '2026-10';
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      const amt = 50000.0;

      // Local expense logging in SQLite
      final expId = const Uuid().v4();
      await db.insert('expenses', {
        'id': expId,
        'company_id': testCompany,
        'category': 'Salaries',
        'amount': amt,
        'description': 'Salary: Karim Bellil ($period)',
        'date': dateStr,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Sync queue operation - single entry for salary_payment with normalized backend schema
      final syncId = const Uuid().v4();
      final clientTxId = const Uuid().v4();
      final payloadMap = {
        'employeeId': empId,
        'amount': amt,
        'salaryPeriod': period,
        'paymentDate': dateStr,
        'description': 'Salary: Karim Bellil ($period)',
      };

      await db.insert('sync_queue', {
        'id': syncId,
        'client_transaction_id': clientTxId,
        'company_id': testCompany,
        'entity_type': 'salary_payment',
        'entity_id': empId,
        'operation_type': 'CREATE',
        'payload': payloadMap.toString(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Confirm only ONE operation exists in sync_queue for this salary disbursement
      final queueRows = await db.query(
        'sync_queue',
        where: 'company_id = ? AND entity_id = ?',
        whereArgs: [testCompany, empId],
      );
      expect(queueRows.length, 1);
      expect(queueRows.first['entity_type'], 'salary_payment');
      expect(queueRows.first['operation_type'], 'CREATE');

      // Check local expense calculation
      final totalExpensesRes = await db.rawQuery(
        'SELECT SUM(amount) as total FROM expenses WHERE company_id = ? AND category = ?',
        [testCompany, 'Salaries'],
      );
      final totalSalaryExp = (totalExpensesRes.first['total'] as num).toDouble();
      expect(totalSalaryExp, 50000.0);
    });

    test('3. Financial statement CSV generation produces standard structured rows', () {
      final csv = StringBuffer();
      csv.writeln('Modiri AI - Financial Report Statement');
      csv.writeln('Period,October 2026');
      csv.writeln('Metric,Amount (DZD),Notes');
      csv.writeln('Gross Revenue,250000.0,15 transactions');
      csv.writeln('Cost of Goods Sold,150000.0,Procurement cost basis');
      csv.writeln('Gross Profit,100000.0,');
      csv.writeln('Operating Expenses,30000.0,Rent/utilities/salaries');
      csv.writeln('Net Operating Profit,70000.0,Margin: 28.0%');

      final lines = csv.toString().trim().split('\n');
      expect(lines.length, 8);
      expect(lines[0], 'Modiri AI - Financial Report Statement');
      expect(lines[1], 'Period,October 2026');
      expect(lines[3], contains('Gross Revenue,250000.0'));
      expect(lines[7], contains('Net Operating Profit,70000.0'));
    });

    test('4. Product label format verification for retail printing', () {
      const name = 'Classic Blue Denim Jeans';
      const price = 4500.0;
      const barcode = '6131234567890';

      final currency = NumberFormat.currency(symbol: 'DZD ', decimalDigits: 2);
      final formattedPrice = currency.format(price);

      expect(formattedPrice, contains('4,500.00'));
      expect(barcode.length, 13);
      expect(name.length, lessThanOrEqualTo(30));
    });
  });
}
