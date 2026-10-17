import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:modiri_ai/core/connectivity/connectivity_service.dart';
import 'package:modiri_ai/core/database/app_database.dart';
import 'package:modiri_ai/core/database/local_financial_calculator.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/core/network/api_exception.dart';
import 'package:modiri_ai/features/credit/data/credit_repository.dart';
import 'package:modiri_ai/features/sales/data/sales_repository.dart';
import 'package:modiri_ai/features/sales/domain/sale.dart';

class SessionNotifierFake extends StateNotifier<Session> implements SessionNotifier {
  SessionNotifierFake(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete('customer_transactions');
    await db.delete('credit_payments');
    await db.delete('credit_items');
    await db.delete('credit_purchases');
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('invoices');
    await db.delete('supplier_payments');
    await db.delete('supplier_purchases');
    await db.delete('expenses');
    await db.delete('products');
    await db.delete('customers');
    await db.delete('sync_queue');
  });

  test('Sale payment invariants: Paid vs Unpaid strictly enforce debt math', () async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => SessionNotifierFake(
              const Session(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'comp_test',
                companyName: 'Test Company',
                businessType: 'retail',
              ),
            )),
        connectionStatusProvider.overrideWith((ref) => _OfflineConnectivityNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    // Insert customer
    final customerId = const Uuid().v4();
    await db.insert('customers', {
      'id': customerId,
      'company_id': 'comp_test',
      'name': 'Ahmed Credit Client',
      'balance_due': 0.0,
      'created_at': nowIso,
    });

    // Insert product
    final prodId = const Uuid().v4();
    await db.insert('products', {
      'id': prodId,
      'company_id': 'comp_test',
      'name': 'Test Item',
      'purchase_price': 500.0,
      'selling_price': 1000.0,
      'quantity': 50,
      'updated_at': nowIso,
    });

    final salesRepo = container.read(salesRepositoryProvider.notifier);

    // 1. Paid Sale: Full payment received, no debt added
    await salesRepo.createSale(
      items: [SaleItemInput(productId: prodId, productName: 'Test Item', quantity: 2)],
      discount: 0,
      paymentStatus: PaymentStatus.paid,
      customerId: customerId,
    );

    var cust = (await db.query('customers', where: 'id = ?', whereArgs: [customerId])).first;
    expect((cust['balance_due'] as num).toDouble(), 0.0);

    // 2. Unpaid Sale: Full amount (2 * 1000 = 2000 DZD) becomes customer debt
    await salesRepo.createSale(
      items: [SaleItemInput(productId: prodId, productName: 'Test Item', quantity: 2)],
      discount: 0,
      paymentStatus: PaymentStatus.unpaid,
      customerId: customerId,
    );

    cust = (await db.query('customers', where: 'id = ?', whereArgs: [customerId])).first;
    expect((cust['balance_due'] as num).toDouble(), 2000.0);

    // Check transactions
    final txs = await db.query('customer_transactions', where: 'customer_id = ?', whereArgs: [customerId]);
    expect(txs.length, 1);
    expect(txs.first['type'], 'credit_sale');
    expect((txs.first['amount'] as num).toDouble(), 2000.0);
    expect((txs.first['balance_after'] as num).toDouble(), 2000.0);
  });

  test('Customer Credit Profile & Overpayment-Protected Repayment Workflow', () async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => SessionNotifierFake(
              const Session(
                accessToken: 'test_token',
                userId: 'user_1',
                companyId: 'comp_test',
                companyName: 'Test Company',
                businessType: 'retail',
              ),
            )),
        connectionStatusProvider.overrideWith((ref) => _OfflineConnectivityNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final customerId = const Uuid().v4();
    await db.insert('customers', {
      'id': customerId,
      'company_id': 'comp_test',
      'name': 'Nadia Debt Profile',
      'balance_due': 5000.0,
      'created_at': nowIso,
    });

    final saleId = const Uuid().v4();
    await db.insert('sales', {
      'id': saleId,
      'company_id': 'comp_test',
      'customer_id': customerId,
      'customer_name': 'Nadia Debt Profile',
      'subtotal': 5000.0,
      'discount': 0.0,
      'total': 5000.0,
      'payment_status': 'unpaid',
      'sold_at': nowIso,
      'created_at': nowIso,
    });

    await db.insert('sale_items', {
      'id': const Uuid().v4(),
      'sale_id': saleId,
      'company_id': 'comp_test',
      'product_id': 'prod_1',
      'product_name': 'Electronics Box',
      'quantity': 1,
      'unit_price': 5000.0,
      'unit_cost': 3500.0,
      'line_total': 5000.0,
      'line_profit': 1500.0,
    });

    await db.insert('customer_transactions', {
      'id': const Uuid().v4(),
      'customer_id': customerId,
      'type': 'credit_sale',
      'amount': 5000.0,
      'balance_after': 5000.0,
      'description': 'Sale INV-1',
      'created_at': nowIso,
    });

    final creditRepo = container.read(creditRepositoryProvider);

    // 1. Fetch Profile
    final profile = await creditRepo.getCustomerCreditProfile(customerId);
    expect(profile.remainingBalance, 5000.0);
    expect(profile.totalCreditSales, 5000.0);
    expect(profile.unpaidInvoiceCount, 1);
    expect(profile.unpaidInvoices.first.items.first.productName, 'Electronics Box');
    expect(profile.oldestDebtDate, isNotNull);

    // 2. Overpayment Protection: amount > 5000 must throw OVERPAYMENT
    expect(
      () => creditRepo.recordPayment(customerId: customerId, amount: 6000.0),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'OVERPAYMENT')),
    );

    // 3. Negative / Zero Amount Protection: amount <= 0 must throw INVALID_AMOUNT
    expect(
      () => creditRepo.recordPayment(customerId: customerId, amount: -100.0),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_AMOUNT')),
    );

    // 4. Valid Partial Repayment: 2000 DZD
    await creditRepo.recordPayment(
      customerId: customerId,
      amount: 2000.0,
      note: 'Partial cash payment',
    );

    var updatedProfile = await creditRepo.getCustomerCreditProfile(customerId);
    expect(updatedProfile.remainingBalance, 3000.0);
    expect(updatedProfile.totalRepayments, 2000.0);

    // 5. Complete Remaining Repayment: 3000 DZD
    await creditRepo.recordPayment(
      customerId: customerId,
      amount: 3000.0,
      note: 'Final settlement',
    );

    updatedProfile = await creditRepo.getCustomerCreditProfile(customerId);
    expect(updatedProfile.remainingBalance, 0.0);
    expect(updatedProfile.totalRepayments, 5000.0);
    expect(updatedProfile.unpaidInvoiceCount, 0);
  });

  test('Partial-payment revenue reconciliation: Upfront payment + installments equals receipts exactly once', () async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    const companyId = 'comp_reconcile_test';

    // 1. Partial sale of 10,000 DZD (payment_status = 'partial')
    final saleId = const Uuid().v4();
    await db.insert('sales', {
      'id': saleId,
      'company_id': companyId,
      'customer_id': 'cust_1',
      'customer_name': 'Test Client',
      'subtotal': 10000.0,
      'discount': 0.0,
      'total': 10000.0,
      'payment_status': 'partial',
      'sold_at': nowIso,
      'created_at': nowIso,
    });

    // Upfront down-payment of 4,000 DZD in credit_payments
    await db.insert('credit_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'customer_id': 'cust_1',
      'amount': 4000.0,
      'note': 'cash',
      'created_at': nowIso,
      'synced': 0,
    });

    // Verify revenue with upfront payment only
    var report = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: nowIso.substring(0, 10),
    );
    expect(report.revenue, 4000.0);

    // 2. Installment 1 of 3,000 DZD
    await db.insert('credit_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'customer_id': 'cust_1',
      'amount': 3000.0,
      'note': 'cash',
      'created_at': nowIso,
      'synced': 0,
    });

    report = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: nowIso.substring(0, 10),
    );
    expect(report.revenue, 7000.0);

    // 3. Installment 2 of 3,000 DZD (completing the full 10,000 DZD)
    await db.insert('credit_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'customer_id': 'cust_1',
      'amount': 3000.0,
      'note': 'cash',
      'created_at': nowIso,
      'synced': 0,
    });

    report = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: nowIso.substring(0, 10),
    );
    expect(report.revenue, 10000.0);

    // 4. Fully paid sale of 5,000 DZD (payment_status = 'paid')
    final paidSaleId = const Uuid().v4();
    await db.insert('sales', {
      'id': paidSaleId,
      'company_id': companyId,
      'customer_id': 'cust_2',
      'customer_name': 'Cash Client',
      'subtotal': 5000.0,
      'discount': 0.0,
      'total': 5000.0,
      'payment_status': 'paid',
      'sold_at': nowIso,
      'created_at': nowIso,
    });

    report = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: nowIso.substring(0, 10),
    );
    // Total revenue = 10,000 (credit payments) + 5,000 (direct paid sale) = 15,000 DZD
    expect(report.revenue, 15000.0);
  });

  test('Financial Invariants: Cancelled sales and unpaid credit never inflate revenue', () async {
    final db = await AppDatabase.instance.database;
    const companyId = 'comp_cancelled_test';
    const dateStr = '2026-10-15';
    const dateIso = '${dateStr}T12:00:00.000Z';

    // 1. Paid sale: 5,000 DZD -> counts as revenue
    await db.insert('sales', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'total': 5000.0,
      'payment_status': 'paid',
      'sold_at': dateIso,
      'created_at': dateIso,
    });

    // 2. Cancelled sale: 8,000 DZD -> MUST NOT count as revenue
    await db.insert('sales', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'total': 8000.0,
      'payment_status': 'cancelled',
      'sold_at': dateIso,
      'created_at': dateIso,
    });

    // 3. Unpaid sale: 3,000 DZD -> MUST NOT count as revenue
    await db.insert('sales', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'total': 3000.0,
      'payment_status': 'unpaid',
      'sold_at': dateIso,
      'created_at': dateIso,
    });

    // 4. Partial sale: 6,000 DZD with 2,000 DZD actual upfront receipt in credit_payments
    await db.insert('sales', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'total': 6000.0,
      'payment_status': 'partial',
      'sold_at': dateIso,
      'created_at': dateIso,
    });
    await db.insert('credit_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'customer_id': 'cust_x',
      'amount': 2000.0,
      'created_at': dateIso,
      'synced': 1,
    });

    final report = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: dateStr,
    );

    // Revenue must equal exactly: 5,000 (paid sale) + 2,000 (credit payment) = 7,000 DZD
    // It must NOT include 8,000 (cancelled), 3,000 (unpaid), or the remaining 4,000 uncollected debt
    expect(report.revenue, 7000.0);
    expect(report.revenueBreakdown.sales, 5000.0);
    expect(report.revenueBreakdown.creditPayments, 2000.0);
  });

  test('Financial Invariants: Restaurant Gross Profit does NOT subtract ingredient purchase costs, Net Profit accounts for inventory and expenses', () async {
    final db = await AppDatabase.instance.database;
    const companyId = 'comp_restaurant_test';
    const dateStr = '2026-10-15';
    const dateIso = '${dateStr}T12:00:00.000Z';

    // 1. Restaurant Sale: 25,000 DZD with 10,000 DZD recorded line cost
    final saleId = const Uuid().v4();
    await db.insert('sales', {
      'id': saleId,
      'company_id': companyId,
      'total': 25000.0,
      'payment_status': 'paid',
      'sold_at': dateIso,
      'created_at': dateIso,
    });
    await db.insert('sale_items', {
      'id': const Uuid().v4(),
      'sale_id': saleId,
      'company_id': companyId,
      'product_id': 'prod_dish',
      'product_name': 'Plat Restaurant',
      'quantity': 10,
      'unit_price': 2500.0,
      'unit_cost': 1000.0,
      'line_total': 25000.0,
      'line_profit': 15000.0,
    });

    // 2. Product raw materials / inventory in stock: 5,000 DZD
    await db.insert('products', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'name': 'Meat & Vegetables Ingredient',
      'purchase_price': 500.0,
      'selling_price': 0.0,
      'quantity': 10, // 10 * 500 = 5,000 DZD inventory value
      'updated_at': dateIso,
    });

    // 3. Operating expenses: 4,000 DZD
    await db.insert('expenses', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'category': 'Rent & Utilities',
      'description': 'Monthly gas & electric',
      'amount': 4000.0,
      'expense_date': dateStr,
      'created_at': dateIso,
      'synced': 1,
    });

    // 4. Paid supplier payment for ingredients: 5,000 DZD
    await db.insert('supplier_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'supplier_id': 'supp_restaurant_meat',
      'amount': 5000.0,
      'payment_date': dateStr,
      'created_at': dateIso,
      'synced': 1,
    });

    // Test A: Calculate Report as Restaurant
    final restaurantReport = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: dateStr,
      businessType: 'restaurant',
    );

    // Rule: For restaurant, costOfGoodsSold must be 0.0
    expect(restaurantReport.costOfGoodsSold, 0.0);
    // Gross Profit equals entire turnover without subtracting ingredient purchases/cogs
    expect(restaurantReport.grossProfit, 25000.0);
    // Operating expenses
    expect(restaurantReport.operatingExpenses, 4000.0);
    // Net profit = turnover (25,000) - expenses (4,000) - supplier_payments (5,000) = 16,000 DZD
    expect(restaurantReport.netProfit, 16000.0);

    // Test B: Calculate Report as Retail for comparison
    final retailReport = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: dateStr,
      businessType: 'retail',
    );

    // Retail: costOfGoodsSold = 10,000 DZD
    expect(retailReport.costOfGoodsSold, 10000.0);
    // Gross Profit = 25,000 - 10,000 = 15,000 DZD
    expect(retailReport.grossProfit, 15000.0);
    // Net Cash Result under Cash-Based Accounting: turnover (25,000) - expenses (4,000) - supplier payment (5,000) = 16,000 DZD
    expect(retailReport.netProfit, 16000.0);
  });

  test('Financial Invariants: Multi-date installment collections count exactly once in their respective reporting periods', () async {
    final db = await AppDatabase.instance.database;
    const companyId = 'comp_periods_test';

    // Credit sale on 2026-10-01 (10,000 DZD total)
    await db.insert('sales', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'total': 10000.0,
      'payment_status': 'partial',
      'sold_at': '2026-10-01T10:00:00.000Z',
      'created_at': '2026-10-01T10:00:00.000Z',
    });

    // Receipt 1: Upfront 3,000 DZD on 2026-10-01
    await db.insert('credit_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'customer_id': 'cust_installment',
      'amount': 3000.0,
      'created_at': '2026-10-01T10:00:00.000Z',
      'synced': 1,
    });

    // Receipt 2: Installment 4,000 DZD on 2026-10-10
    await db.insert('credit_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'customer_id': 'cust_installment',
      'amount': 4000.0,
      'created_at': '2026-10-10T14:30:00.000Z',
      'synced': 1,
    });

    // Receipt 3: Final Installment 3,000 DZD on 2026-10-20
    await db.insert('credit_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'customer_id': 'cust_installment',
      'amount': 3000.0,
      'created_at': '2026-10-20T09:15:00.000Z',
      'synced': 1,
    });

    // Daily report for 2026-10-01 -> only 3,000 DZD recognized
    final repDay1 = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: '2026-10-01',
    );
    expect(repDay1.revenue, 3000.0);

    // Daily report for 2026-10-10 -> only 4,000 DZD recognized
    final repDay10 = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: '2026-10-10',
    );
    expect(repDay10.revenue, 4000.0);

    // Daily report for 2026-10-20 -> only 3,000 DZD recognized
    final repDay20 = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: '2026-10-20',
    );
    expect(repDay20.revenue, 3000.0);

    // Monthly report for October 2026 -> all 3 receipts combined = 10,000 DZD
    final repMonth = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'monthly',
      month: '2026-10',
    );
    expect(repMonth.revenue, 10000.0);
  });

  test('Sync Idempotency: Repeated synchronization of offline payment prevents duplicate records and double revenue', () async {
    final db = await AppDatabase.instance.database;
    const companyId = 'comp_sync_idempotent';
    const clientId = 'client_uuid_abc_123';
    const serverId = 'srv_uuid_xyz_789';
    const dateIso = '2026-10-15T12:00:00.000Z';

    // 1. Locally inserted offline payment (synced = 0)
    await db.insert('credit_payments', {
      'id': 'local_temp_id_001',
      'client_id': clientId,
      'company_id': companyId,
      'customer_id': 'cust_sync',
      'amount': 4500.0,
      'note': 'Installment offline',
      'created_at': dateIso,
      'synced': 0,
    });

    var rows = await db.query('credit_payments', where: 'company_id = ?', whereArgs: [companyId]);
    expect(rows.length, 1);

    // 2. Simulated Sync: Server returns confirmed record with serverId & matching clientId
    // Sync logic replaces / reconciles using client_id
    await db.delete(
      'credit_payments',
      where: 'company_id = ? AND client_id = ? AND id != ?',
      whereArgs: [companyId, clientId, serverId],
    );
    await db.insert(
      'credit_payments',
      {
        'id': serverId,
        'client_id': clientId,
        'company_id': companyId,
        'customer_id': 'cust_sync',
        'amount': 4500.0,
        'note': 'Installment offline',
        'created_at': dateIso,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 3. Repeated Sync: Server returns the same payment again on next polling loop
    await db.delete(
      'credit_payments',
      where: 'company_id = ? AND client_id = ? AND id != ?',
      whereArgs: [companyId, clientId, serverId],
    );
    await db.insert(
      'credit_payments',
      {
        'id': serverId,
        'client_id': clientId,
        'company_id': companyId,
        'customer_id': 'cust_sync',
        'amount': 4500.0,
        'note': 'Installment offline',
        'created_at': dateIso,
        'synced': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Check rows count
    rows = await db.query('credit_payments', where: 'company_id = ?', whereArgs: [companyId]);
    expect(rows.length, 1);
    expect(rows.first['id'], serverId);

    // Financial report must only count 4500.0 exactly once
    final report = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: '2026-10-15',
    );
    expect(report.revenue, 4500.0);
  });

  test('Financial Invariants: Restaurant Net Profit prevents double deduction and installment purchases deduct only when paid', () async {
    final db = await AppDatabase.instance.database;
    const companyId = 'comp_restaurant_installments_test';

    // 1. In stock: catalog products with total inventory value = 15,000 DZD
    await db.insert('products', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'name': 'Existing Meat Stock',
      'purchase_price': 1500.0,
      'selling_price': 0.0,
      'quantity': 10, // 10 * 1500 = 15,000 DZD inventory value
      'updated_at': '2026-10-01T08:00:00.000Z',
    });

    // Supplier invoice created on 2026-10-01: 10,000 DZD total, 6,000 DZD paid upfront, 4,000 DZD debt
    final purchaseId = const Uuid().v4();
    await db.insert('supplier_purchases', {
      'id': purchaseId,
      'company_id': companyId,
      'supplier_id': 'supp_agro',
      'invoice_number': 'INV-SUPP-001',
      'purchase_date': '2026-10-01T09:00:00.000Z',
      'total_amount': 10000.0,
      'amount_paid': 6000.0,
      'outstanding_balance': 4000.0,
      'payment_status': 'partial',
      'created_at': '2026-10-01T09:00:00.000Z',
      'synced': 1,
    });

    // Period 1 (2026-10-01):
    // Paid restaurant turnover: 20,000 DZD
    await db.insert('sales', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'total': 20000.0,
      'payment_status': 'paid',
      'sold_at': '2026-10-01T12:00:00.000Z',
      'created_at': '2026-10-01T12:00:00.000Z',
    });

    // Installment 1: 6,000 DZD paid on 2026-10-01
    await db.insert('supplier_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'supplier_id': 'supp_agro',
      'purchase_id': purchaseId,
      'amount': 6000.0,
      'payment_date': '2026-10-01T09:30:00.000Z',
      'created_at': '2026-10-01T09:30:00.000Z',
      'synced': 1,
    });

    // Operating expenses on 2026-10-01: 3,000 DZD
    await db.insert('expenses', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'category': 'Rent',
      'description': 'Daily shop portion',
      'amount': 3000.0,
      'expense_date': '2026-10-01',
      'created_at': '2026-10-01T08:00:00.000Z',
      'synced': 1,
    });

    // Verify Period 1 report
    final rep1 = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: '2026-10-01',
      businessType: 'restaurant',
    );

    // Rule: Gross Profit does NOT subtract ingredient purchase costs
    expect(rep1.costOfGoodsSold, 0.0);
    expect(rep1.grossProfit, 20000.0);
    expect(rep1.operatingExpenses, 3000.0);
    // Net profit = 20,000 - 3,000 (expenses) - 6,000 (actual paid supplier purchase) = 11,000 DZD
    // Invariant: Unpaid supplier debt (4,000 DZD) does NOT deduct in Period 1.
    // Invariant: Catalog stock inventory value (15,000 DZD) does NOT double-deduct against paid cash.
    expect(rep1.netProfit, 11000.0);

    // Period 2 (2026-10-15):
    // Paid restaurant turnover: 15,000 DZD
    await db.insert('sales', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'total': 15000.0,
      'payment_status': 'paid',
      'sold_at': '2026-10-15T12:00:00.000Z',
      'created_at': '2026-10-15T12:00:00.000Z',
    });

    // Installment 2: Remaining 4,000 DZD paid on 2026-10-15
    await db.insert('supplier_payments', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'supplier_id': 'supp_agro',
      'purchase_id': purchaseId,
      'amount': 4000.0,
      'payment_date': '2026-10-15T10:00:00.000Z',
      'created_at': '2026-10-15T10:00:00.000Z',
      'synced': 1,
    });

    // Operating expenses on 2026-10-15: 2,000 DZD
    await db.insert('expenses', {
      'id': const Uuid().v4(),
      'company_id': companyId,
      'category': 'Electricity',
      'description': 'Mid-month bill',
      'amount': 2000.0,
      'expense_date': '2026-10-15',
      'created_at': '2026-10-15T09:00:00.000Z',
      'synced': 1,
    });

    // Verify Period 2 report
    final rep2 = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'daily',
      date: '2026-10-15',
      businessType: 'restaurant',
    );

    expect(rep2.costOfGoodsSold, 0.0);
    expect(rep2.grossProfit, 15000.0);
    expect(rep2.operatingExpenses, 2000.0);
    // Net profit = 15,000 - 2,000 (expenses) - 4,000 (installment 2) = 9,000 DZD
    expect(rep2.netProfit, 9000.0);

    // Verify Monthly report for October 2026:
    final repMonthly = await LocalFinancialCalculator.calculateReport(
      companyId: companyId,
      period: 'monthly',
      month: '2026-10',
      businessType: 'restaurant',
    );

    // Total Turnover = 20,000 + 15,000 = 35,000 DZD
    expect(repMonthly.revenue, 35000.0);
    expect(repMonthly.costOfGoodsSold, 0.0);
    expect(repMonthly.grossProfit, 35000.0);
    // Total Expenses = 3,000 + 2,000 = 5,000 DZD
    expect(repMonthly.operatingExpenses, 5000.0);
    // Net Profit across entire month = 35,000 - 5,000 - 10,000 (total paid supplier purchases) = 20,000 DZD
    // Exactly matches rep1.netProfit (11,000) + rep2.netProfit (9,000) = 20,000 DZD
    expect(repMonthly.netProfit, 20000.0);
  });
}
