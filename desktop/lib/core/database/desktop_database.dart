import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DesktopDatabase {
  static final DesktopDatabase instance = DesktopDatabase._init();
  static Database? _database;

  DesktopDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('modiri_desktop.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Windows FFI initialization
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;

    Directory appDocDir;
    try {
      appDocDir = await getApplicationSupportDirectory();
    } catch (_) {
      final appData = Platform.environment['APPDATA'] ?? '.';
      appDocDir = Directory(p.join(appData, 'ModiriAI'));
    }

    if (!await appDocDir.exists()) {
      await appDocDir.create(recursive: true);
    }

    final dbPath = p.join(appDocDir.path, filePath);
    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0.0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        barcode TEXT,
        category TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        invoice_number TEXT,
        total REAL NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0.0,
        payment_status TEXT NOT NULL DEFAULT 'paid',
        payment_method TEXT NOT NULL DEFAULT 'cash',
        sold_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL DEFAULT 0.0,
        line_total REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        sale_id TEXT,
        invoice_number TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'paid',
        total REAL NOT NULL,
        customer_name TEXT,
        sold_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        expense_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_payments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        amount REAL NOT NULL,
        customer_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_orders (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        action TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
