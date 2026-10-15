import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:modiri_ai/core/connectivity/connectivity_service.dart';
import 'package:modiri_ai/core/database/app_database.dart';
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
}
