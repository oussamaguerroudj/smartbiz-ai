import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'modiri_offline_v1.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        company_id TEXT,
        name TEXT NOT NULL,
        category TEXT,
        barcode TEXT,
        purchase_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        minimum_stock INTEGER NOT NULL DEFAULT 5,
        expiration_date TEXT,
        size TEXT,
        color TEXT,
        brand TEXT,
        image_url TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX ix_products_barcode ON products (barcode)');
    await db.execute('CREATE INDEX ix_products_name ON products (name)');
    await db.execute('CREATE INDEX ix_products_company ON products (company_id)');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        client_transaction_id TEXT UNIQUE,
        company_id TEXT,
        customer_id TEXT,
        customer_name TEXT,
        employee_id TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        payment_status TEXT NOT NULL DEFAULT 'paid',
        sold_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX ix_sales_sold_at ON sales (sold_at)');
    await db.execute('CREATE INDEX ix_sales_client_tx ON sales (client_transaction_id)');
    await db.execute('CREATE INDEX ix_sales_company ON sales (company_id)');

    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        company_id TEXT,
        product_id TEXT NOT NULL,
        product_name TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost REAL NOT NULL,
        line_total REAL NOT NULL,
        line_profit REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX ix_sale_items_sale_id ON sale_items (sale_id)');
    await db.execute('CREATE INDEX ix_sale_items_product_id ON sale_items (product_id)');
    await db.execute('CREATE INDEX ix_sale_items_company ON sale_items (company_id)');

    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL UNIQUE,
        company_id TEXT,
        invoice_number TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'paid',
        customer_name TEXT,
        total REAL NOT NULL DEFAULT 0,
        sold_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX ix_invoices_number ON invoices (invoice_number)');
    await db.execute('CREATE INDEX ix_invoices_company ON invoices (company_id)');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        company_id TEXT,
        category TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL DEFAULT 0,
        expense_date TEXT NOT NULL,
        period_type TEXT DEFAULT 'one_time',
        employee_id TEXT,
        salary_period TEXT,
        duration TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX ix_expenses_date ON expenses (expense_date)');
    await db.execute('CREATE INDEX ix_expenses_client_id ON expenses (client_id)');
    await db.execute('CREATE INDEX ix_expenses_company ON expenses (company_id)');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        company_id TEXT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        balance_due REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX ix_customers_name ON customers (name)');
    await db.execute('CREATE INDEX ix_customers_company ON customers (company_id)');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        company_id TEXT,
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
    await db.execute('CREATE INDEX ix_sync_queue_status ON sync_queue (status, created_at)');
    await db.execute('CREATE INDEX ix_sync_queue_company ON sync_queue (company_id, status)');

    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createV2Tables(db);
    await _createV4Tables(db);
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        company_id TEXT,
        name TEXT NOT NULL,
        position TEXT,
        phone TEXT,
        base_salary REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_employees_name ON employees (name)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_employees_client_id ON employees (client_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS salary_payments (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        employee_id TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        payment_date TEXT NOT NULL,
        salary_period TEXT NOT NULL,
        duration TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_salary_payments_emp ON salary_payments (employee_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_salary_payments_date ON salary_payments (payment_date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        company_id TEXT,
        customer_id TEXT,
        customer_name TEXT,
        title TEXT,
        notes TEXT,
        scheduled_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'scheduled',
        reminder_enabled INTEGER NOT NULL DEFAULT 1,
        table_id TEXT,
        table_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_appointments_scheduled_at ON appointments (scheduled_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_appointments_status ON appointments (status)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_appointments_table ON appointments (table_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_purchases (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        company_id TEXT,
        customer_id TEXT NOT NULL,
        customer_name TEXT,
        subtotal REAL NOT NULL DEFAULT 0,
        amount_paid_now REAL NOT NULL DEFAULT 0,
        remaining_credit REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'unpaid',
        note TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_credit_purchases_cust ON credit_purchases (customer_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (purchase_id) REFERENCES credit_purchases (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_credit_items_purchase ON credit_items (purchase_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_payments (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        company_id TEXT,
        customer_id TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_credit_payments_cust ON credit_payments (customer_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_transactions (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        customer_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        balance_after REAL NOT NULL DEFAULT 0,
        description TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_cust_tx_cust ON customer_transactions (customer_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        client_id TEXT UNIQUE,
        company_id TEXT,
        name TEXT NOT NULL,
        phone TEXT,
        products_supplied INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_suppliers_name ON suppliers (name)');
  }

  Future<void> _createV4Tables(Database db) async {
    // 1. Supermarket / Retail Multi-cart Sessions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_sessions (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        discount REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_cart_sessions_company ON cart_sessions (company_id, status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_session_items (
        id TEXT PRIMARY KEY,
        cart_session_id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        unit_cost REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (cart_session_id) REFERENCES cart_sessions (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_cart_session_items_cart ON cart_session_items (cart_session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_cart_session_items_company ON cart_session_items (company_id)');

    // 2. Restaurant Orders & Tables (Offline-First)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_orders (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        table_id TEXT,
        table_name TEXT,
        order_number INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        total_amount REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        notes TEXT,
        customer_name TEXT,
        customer_id TEXT,
        order_type TEXT NOT NULL DEFAULT 'dine_in',
        customer_phone TEXT,
        delivery_address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_orders_company_status ON restaurant_orders (company_id, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_orders_created ON restaurant_orders (company_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_orders_phone ON restaurant_orders (company_id, customer_phone)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        company_id TEXT NOT NULL,
        menu_item_id TEXT,
        item_name TEXT NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 1,
        subtotal REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES restaurant_orders (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_order_items_order ON restaurant_order_items (order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_order_items_company ON restaurant_order_items (company_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_tables (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        seats INTEGER NOT NULL DEFAULT 2,
        status TEXT NOT NULL DEFAULT 'available',
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_tables_company ON restaurant_tables (company_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_payments (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        order_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT,
        note TEXT,
        paid_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES restaurant_orders (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_payments_order ON restaurant_payments (order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_payments_company ON restaurant_payments (company_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE invoices ADD COLUMN company_id TEXT'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_invoices_company ON invoices (company_id)'); } catch (_) {}

      try { await db.execute('ALTER TABLE sale_items ADD COLUMN company_id TEXT'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_sale_items_company ON sale_items (company_id)'); } catch (_) {}

      try { await db.execute('ALTER TABLE sync_queue ADD COLUMN company_id TEXT'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_sync_queue_company ON sync_queue (company_id, status)'); } catch (_) {}

      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_products_company ON products (company_id)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_sales_company ON sales (company_id)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_expenses_company ON expenses (company_id)'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_customers_company ON customers (company_id)'); } catch (_) {}
    }
    if (oldVersion < 4) {
      await _createV4Tables(db);
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE restaurant_orders ADD COLUMN customer_phone TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE restaurant_orders ADD COLUMN delivery_address TEXT'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_rest_orders_phone ON restaurant_orders (company_id, customer_phone)'); } catch (_) {}
      try { await db.execute('ALTER TABLE appointments ADD COLUMN table_id TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE appointments ADD COLUMN table_name TEXT'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS ix_appointments_table ON appointments (table_id)'); } catch (_) {}
    }
  }

  /// Deletes all rows from all local business tables in a single transaction.
  /// Use ONLY for explicit destructive actions (factory reset, dev tools).
  /// Do NOT call from logout or login  -  use company_id-scoped queries instead.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sync_queue');
      await txn.delete('sale_items');
      await txn.delete('invoices');
      await txn.delete('sales');
      await txn.delete('expenses');
      await txn.delete('customers');
      await txn.delete('products');
      await txn.delete('sync_metadata');
      await txn.delete('employees');
      await txn.delete('salary_payments');
      await txn.delete('appointments');
      await txn.delete('credit_purchases');
      await txn.delete('credit_items');
      await txn.delete('credit_payments');
      await txn.delete('customer_transactions');
      await txn.delete('suppliers');
      await txn.delete('cart_session_items');
      await txn.delete('cart_sessions');
      await txn.delete('restaurant_order_items');
      await txn.delete('restaurant_orders');
      await txn.delete('restaurant_tables');
      await txn.delete('restaurant_payments');
    });
  }
}
