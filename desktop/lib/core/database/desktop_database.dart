import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ModiriDesktopDatabase {
  static final ModiriDesktopDatabase instance = ModiriDesktopDatabase._init();
  static Database? _database;

  ModiriDesktopDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('modiri_desktop.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;

    Directory appDocDir;
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      appDocDir = Directory(p.join(localAppData, 'ModiriAI'));
    } else {
      try {
        final supportDir = await getApplicationSupportDirectory();
        appDocDir = Directory(p.join(supportDir.path, 'ModiriAI'));
      } catch (_) {
        final appData = Platform.environment['APPDATA'] ?? '.';
        appDocDir = Directory(p.join(appData, 'ModiriAI'));
      }
    }

    if (!await appDocDir.exists()) {
      await appDocDir.create(recursive: true);
    }

    final targetDbFile = File(p.join(appDocDir.path, filePath));

    // Safe migration from legacy locations if target does not exist yet
    if (!await targetDbFile.exists()) {
      final legacyCandidates = <String>[];
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        legacyCandidates.add(p.join(appData, 'Modiri AI', 'Modiri AI', 'modiri_desktop_v2.db'));
        legacyCandidates.add(p.join(appData, 'Modiri AI', 'Modiri AI', 'modiri_desktop.db'));
        legacyCandidates.add(p.join(appData, 'Modiri AI', 'modiri_desktop_v2.db'));
        legacyCandidates.add(p.join(appData, 'Modiri AI', 'modiri_desktop.db'));
      }
      try {
        final supportDir = await getApplicationSupportDirectory();
        legacyCandidates.add(p.join(supportDir.path, 'modiri_desktop_v2.db'));
        legacyCandidates.add(p.join(supportDir.path, 'modiri_desktop.db'));
      } catch (_) {}

      File? bestCandidate;
      int bestSize = 0;
      for (final candidatePath in legacyCandidates) {
        final candidateFile = File(candidatePath);
        if (await candidateFile.exists()) {
          final size = await candidateFile.length();
          if (size > bestSize) {
            bestSize = size;
            bestCandidate = candidateFile;
          }
        }
      }

      if (bestCandidate != null && bestSize > 0) {
        try {
          await bestCandidate.copy(targetDbFile.path);
        } catch (e) {
          stderr.writeln('Warning: Failed to copy legacy database from ${bestCandidate.path}: $e');
        }
      }
    }

    try {
      return await dbFactory.openDatabase(
        targetDbFile.path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _createDB,
          onOpen: (db) async => _createDB(db, 2),
        ),
      );
    } catch (e) {
      throw StateError(
        'CRITICAL: Failed to safely open Modiri Desktop database at ${targetDbFile.path}: $e. '
        'Refusing to overwrite or reset user database.',
      );
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0.0,
        purchase_price REAL NOT NULL DEFAULT 0.0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        minimum_stock INTEGER NOT NULL DEFAULT 5,
        barcode TEXT,
        category TEXT,
        expiration_date TEXT,
        size TEXT,
        color TEXT,
        brand TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await migrateLegacyDatabase(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        invoice_number TEXT,
        total REAL NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0.0,
        payment_status TEXT NOT NULL DEFAULT 'paid',
        payment_method TEXT NOT NULL DEFAULT 'cash',
        sold_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        line_total REAL NOT NULL,
        line_profit REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        sale_id TEXT,
        invoice_number TEXT NOT NULL,
        customer_name TEXT,
        total REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        remaining_amount REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'paid',
        sold_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        credit_balance REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
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
      CREATE TABLE IF NOT EXISTS employees (
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
      CREATE TABLE IF NOT EXISTS customer_transactions (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        type TEXT NOT NULL, -- 'purchase' or 'payment'
        amount REAL NOT NULL,
        balance_after REAL NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
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
      CREATE TABLE IF NOT EXISTS sync_queue (
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        service_type TEXT NOT NULL,
        appointment_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'confirmed',
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_tables (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        seats INTEGER NOT NULL DEFAULT 4,
        status TEXT NOT NULL DEFAULT 'available',
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_orders (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        items_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'preparing',
        total REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS enterprise_projects (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        client_name TEXT NOT NULL,
        budget REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'in_progress',
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pharmacy_batches (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        product_id TEXT,
        batch_number TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        expiration_date TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_purchases (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        invoice_number TEXT,
        purchase_date TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0.0,
        amount_paid REAL NOT NULL DEFAULT 0.0,
        outstanding_balance REAL NOT NULL DEFAULT 0.0,
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        notes TEXT,
        client_transaction_id TEXT UNIQUE,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_purchase_items (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        purchase_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        line_total REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        supplier_id TEXT NOT NULL,
        purchase_id TEXT,
        amount REAL NOT NULL DEFAULT 0.0,
        payment_date TEXT NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        reference TEXT,
        notes TEXT,
        client_id TEXT UNIQUE,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_reservations (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        phone TEXT,
        party_size INTEGER NOT NULL DEFAULT 2,
        table_id TEXT,
        table_name TEXT,
        reserved_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_sessions (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        discount REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_session_items (
        id TEXT PRIMARY KEY,
        cart_session_id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0.0,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (cart_session_id) REFERENCES cart_sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_inventory_items (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT NOT NULL DEFAULT 'unit',
        quantity REAL NOT NULL DEFAULT 0.0,
        minimum_stock REAL NOT NULL DEFAULT 0.0,
        purchase_price REAL NOT NULL DEFAULT 0.0,
        selling_price REAL,
        supplier TEXT,
        expiration_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_payments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        order_id TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        method TEXT NOT NULL DEFAULT 'cash',
        note TEXT,
        paid_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES restaurant_orders (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Safely migrates legacy databases without overwriting verified balances or duplicating payment history.
  ///
  /// Safe to run repeatedly or after interrupted migrations (idempotent).
  static Future<MigrationReport> migrateLegacyDatabase(DatabaseExecutor db) async {
    for (final col in [
      'ALTER TABLE products ADD COLUMN minimum_stock INTEGER NOT NULL DEFAULT 5',
      'ALTER TABLE products ADD COLUMN expiration_date TEXT',
      'ALTER TABLE products ADD COLUMN size TEXT',
      'ALTER TABLE products ADD COLUMN color TEXT',
      'ALTER TABLE products ADD COLUMN brand TEXT',
      'ALTER TABLE products ADD COLUMN supplier_id TEXT',
      'ALTER TABLE products ADD COLUMN supplier_name TEXT',
      'ALTER TABLE products ADD COLUMN purchase_price REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE products ADD COLUMN cost_price REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE invoices ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE invoices ADD COLUMN remaining_amount REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE customers ADD COLUMN notes TEXT',
      'ALTER TABLE suppliers ADD COLUMN address TEXT',
      'ALTER TABLE restaurant_orders ADD COLUMN amount_paid REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE restaurant_orders ADD COLUMN payment_status TEXT NOT NULL DEFAULT \'unpaid\'',
      'ALTER TABLE restaurant_orders ADD COLUMN customer_name TEXT',
      'ALTER TABLE restaurant_orders ADD COLUMN customer_phone TEXT',
      'ALTER TABLE restaurant_orders ADD COLUMN order_type TEXT DEFAULT \'dine_in\'',
    ]) {
      try {
        await db.execute(col);
      } catch (_) {}
    }

    for (final createTbl in [
      '''CREATE TABLE IF NOT EXISTS cart_sessions (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        discount REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''',
      '''CREATE TABLE IF NOT EXISTS cart_session_items (
        id TEXT PRIMARY KEY,
        cart_session_id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0.0,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY (cart_session_id) REFERENCES cart_sessions (id) ON DELETE CASCADE
      )''',
      '''CREATE TABLE IF NOT EXISTS restaurant_inventory_items (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT NOT NULL DEFAULT 'unit',
        quantity REAL NOT NULL DEFAULT 0.0,
        minimum_stock REAL NOT NULL DEFAULT 0.0,
        purchase_price REAL NOT NULL DEFAULT 0.0,
        selling_price REAL,
        supplier TEXT,
        expiration_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE IF NOT EXISTS restaurant_payments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        order_id TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        method TEXT NOT NULL DEFAULT 'cash',
        note TEXT,
        paid_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES restaurant_orders (id) ON DELETE CASCADE
      )''',
    ]) {
      try {
        await db.execute(createTbl);
      } catch (_) {}
    }

    int fullyPaidCount = 0;
    int unpaidCount = 0;
    int historyReconstructed = 0;
    final ambiguousInvoices = <String>[];

    List<Map<String, dynamic>> unmigratedInvoices = [];
    try {
      unmigratedInvoices = await db.rawQuery('''
        SELECT id, company_id, invoice_number, total, status
        FROM invoices
        WHERE total > 0.0 AND (paid_amount = 0.0 AND remaining_amount = 0.0)
      ''');
    } catch (_) {}

    for (final inv in unmigratedInvoices) {
      final id = inv['id'] as String;
      final companyId = inv['company_id'] as String;
      final invNum = inv['invoice_number'] as String? ?? id;
      final total = (inv['total'] as num?)?.toDouble() ?? 0.0;
      final status = (inv['status'] as String? ?? 'paid').toLowerCase();

      // Check customer_transactions for historical payment records
      List<Map<String, dynamic>> txRows = [];
      try {
        txRows = await db.query(
          'customer_transactions',
          where: "company_id = ? AND type = 'payment' AND (description LIKE ? OR description LIKE ?)",
          whereArgs: [companyId, '%$invNum%', '%$id%'],
        );
      } catch (_) {}

      if (txRows.isNotEmpty) {
        final paidSum = txRows.fold<double>(
          0.0,
          (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0.0),
        );
        final safePaid = paidSum.clamp(0.0, total);
        final safeRemaining = (total - safePaid).clamp(0.0, total);
        final resolvedStatus = safeRemaining <= 0.001 ? 'paid' : (safePaid > 0 ? 'partial' : 'unpaid');

        await db.update(
          'invoices',
          {
            'paid_amount': safePaid,
            'remaining_amount': safeRemaining,
            'status': resolvedStatus,
          },
          where: 'id = ? AND company_id = ?',
          whereArgs: [id, companyId],
        );
        historyReconstructed++;
      } else if (status == 'paid') {
        await db.update(
          'invoices',
          {
            'paid_amount': total,
            'remaining_amount': 0.0,
          },
          where: 'id = ? AND company_id = ?',
          whereArgs: [id, companyId],
        );
        fullyPaidCount++;
      } else if (status == 'unpaid') {
        await db.update(
          'invoices',
          {
            'paid_amount': 0.0,
            'remaining_amount': total,
          },
          where: 'id = ? AND company_id = ?',
          whereArgs: [id, companyId],
        );
        unpaidCount++;
      } else if (status == 'partial') {
        // Ambiguous partial with no historical transaction records found
        ambiguousInvoices.add(id);
        await db.update(
          'invoices',
          {
            'paid_amount': 0.0,
            'remaining_amount': total,
          },
          where: 'id = ? AND company_id = ?',
          whereArgs: [id, companyId],
        );
      }
    }

    return MigrationReport(
      totalInspected: unmigratedInvoices.length,
      fullyPaidBackfilled: fullyPaidCount,
      unpaidBackfilled: unpaidCount,
      historyReconstructed: historyReconstructed,
      ambiguousInvoices: ambiguousInvoices,
    );
  }

  /// Safely deletes business records strictly scoped to [companyId] within an atomic transaction.
  /// Clears queued operations for [companyId] so stale operations cannot recreate deleted records.
  /// Preserves other companies' records and does not truncate tables or reset schema.
  Future<void> clearCompanyBusinessData(String companyId) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Clear sync queue scoped to this company so stale requests cannot replay
      await txn.delete('sync_queue', where: 'company_id = ?', whereArgs: [companyId]);

      // 2. Clear invoices, sale items, sales
      await txn.delete('invoices', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('sale_items', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('sales', where: 'company_id = ?', whereArgs: [companyId]);

      // 3. Clear credit transactions and customers
      await txn.delete('customer_transactions', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('customers', where: 'company_id = ?', whereArgs: [companyId]);

      // 4. Clear expenses, employees, suppliers, products
      await txn.delete('expenses', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('employees', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('supplier_payments', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.rawDelete('''
        DELETE FROM supplier_purchase_items
        WHERE purchase_id IN (SELECT id FROM supplier_purchases WHERE company_id = ?)
      ''', [companyId]);
      await txn.delete('supplier_purchases', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('suppliers', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('products', where: 'company_id = ?', whereArgs: [companyId]);

      // 5. Clear specialized business tables
      await txn.delete('appointments', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('restaurant_tables', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('restaurant_orders', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('restaurant_payments', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('restaurant_inventory_items', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('enterprise_projects', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('pharmacy_batches', where: 'company_id = ?', whereArgs: [companyId]);
      await txn.delete('restaurant_reservations', where: 'company_id = ?', whereArgs: [companyId]);
    });
  }
}

class MigrationReport {
  final int totalInspected;
  final int fullyPaidBackfilled;
  final int unpaidBackfilled;
  final int historyReconstructed;
  final List<String> ambiguousInvoices;

  const MigrationReport({
    this.totalInspected = 0,
    this.fullyPaidBackfilled = 0,
    this.unpaidBackfilled = 0,
    this.historyReconstructed = 0,
    this.ambiguousInvoices = const [],
  });
}
