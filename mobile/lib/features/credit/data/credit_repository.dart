import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../../customers/presentation/screens/customers_screen.dart'
    show Customer, customersRepositoryProvider;
import '../../dashboard/data/dashboard_repository.dart';
import '../../products/data/products_repository.dart';
import '../../reports/data/reports_repository.dart' show invalidateAllReports;

/// Credit Sale system — a customer buys now and pays part
/// (or none) of the total immediately; the rest becomes debt tracked on
/// their balance, repayable later.
/// Completely offline-first with local SQLite persistence and sync queueing.
class CreditItemInput {
  CreditItemInput({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  double get lineTotal => unitPrice * quantity;
}

class CreditPurchase {
  CreditPurchase({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.subtotal,
    required this.amountPaidNow,
    required this.remainingCredit,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final double subtotal;
  final double amountPaidNow;
  final double remainingCredit;
  final String status; // 'paid' | 'partial' | 'unpaid'
  final DateTime createdAt;

  factory CreditPurchase.fromJson(Map<String, dynamic> json) => CreditPurchase(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        customerName: json['customer_name'] as String? ?? '',
        subtotal: double.parse(json['subtotal'].toString()),
        amountPaidNow: double.parse(json['amount_paid_now'].toString()),
        remainingCredit: double.parse(json['remaining_credit'].toString()),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CustomerTransaction {
  CustomerTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String type; // 'credit_purchase' | 'payment'
  final double amount; // signed — positive = new debt, negative = paid down
  final double balanceAfter;
  final String? description;
  final DateTime createdAt;

  bool get isPurchase => type == 'credit_purchase' || type == 'credit_sale';

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) => CustomerTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: double.parse(json['amount'].toString()),
        balanceAfter: double.parse(json['balance_after'].toString()),
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CreditSummary {
  CreditSummary({
    required this.totalOutstanding,
    required this.totalCredit,
    required this.totalPaid,
  });

  final double totalOutstanding;
  final double totalCredit;
  final double totalPaid;

  factory CreditSummary.fromJson(Map<String, dynamic> json) => CreditSummary(
        totalOutstanding: double.parse(json['totalOutstanding'].toString()),
        totalCredit: double.parse(json['totalCredit'].toString()),
        totalPaid: double.parse(json['totalPaid'].toString()),
      );
}

class CustomerInvoiceItem {
  CustomerInvoiceItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
}

class CustomerInvoiceDetail {
  CustomerInvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.total,
    required this.amountPaid,
    required this.remainingBalance,
    required this.status,
    required this.items,
  });

  final String id;
  final String invoiceNumber;
  final DateTime date;
  final double total;
  final double amountPaid;
  final double remainingBalance;
  final String status;
  final List<CustomerInvoiceItem> items;
}

class CustomerCreditProfile {
  CustomerCreditProfile({
    required this.customer,
    required this.totalCreditSales,
    required this.totalRepayments,
    required this.remainingBalance,
    required this.unpaidInvoiceCount,
    required this.oldestDebtDate,
    required this.transactions,
    required this.unpaidInvoices,
    required this.allInvoices,
  });

  final Customer customer;
  final double totalCreditSales;
  final double totalRepayments;
  final double remainingBalance;
  final int unpaidInvoiceCount;
  final DateTime? oldestDebtDate;
  final List<CustomerTransaction> transactions;
  final List<CustomerInvoiceDetail> unpaidInvoices;
  final List<CustomerInvoiceDetail> allInvoices;
}

class CreditRepository {
  CreditRepository(this._ref);
  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<CreditPurchase> createPurchase({
    required String customerId,
    required List<CreditItemInput> items,
    required double amountPaidNow,
    String? note,
  }) async {
    final companyId = _companyId;
    if (companyId == null) throw Exception('Not authenticated');

    final db = await AppDatabase.instance.database;

    // 1. Get customer — scoped to this company
    final custRows = await db.query(
      'customers',
      where: 'id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      limit: 1,
    );
    final customerName = custRows.isNotEmpty ? (custRows.first['name'] as String? ?? 'Customer') : 'Customer';
    final currentBalance = custRows.isNotEmpty ? ((custRows.first['balance_due'] as num?)?.toDouble() ?? 0.0) : 0.0;

    // 2. Calculate totals
    double subtotal = 0.0;
    for (final item in items) {
      subtotal += item.unitPrice * item.quantity;
    }
    final remainingCredit = (subtotal - amountPaidNow).clamp(0.0, double.infinity);
    final status = remainingCredit == 0 ? 'paid' : (amountPaidNow == 0 ? 'unpaid' : 'partial');

    final purchaseId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();

    // 3. Atomically perform local persistence
    await db.transaction((txn) async {
      // Decrement stock for all items — scoped by company
      for (final item in items) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ? AND company_id = ?',
          [item.quantity, item.productId, companyId],
        );
      }

      // Insert credit purchase — tagged with company_id
      await txn.insert('credit_purchases', {
        'id': purchaseId,
        'client_id': purchaseId,
        'company_id': companyId,
        'customer_id': customerId,
        'customer_name': customerName,
        'subtotal': subtotal,
        'amount_paid_now': amountPaidNow,
        'remaining_credit': remainingCredit,
        'status': status,
        'note': note,
        'created_at': nowIso,
        'synced': 0,
      });

      // Insert credit items
      for (final item in items) {
        await txn.insert('credit_items', {
          'id': const Uuid().v4(),
          'credit_purchase_id': purchaseId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'cost_price': 0.0,
          'total': item.lineTotal,
        });
      }

      // Ledger entry 1: Debt added
      var runningBalance = currentBalance + subtotal;
      await txn.update(
        'customers',
        {'balance_due': runningBalance},
        where: 'id = ? AND company_id = ?',
        whereArgs: [customerId, companyId],
      );

      await txn.insert('customer_transactions', {
        'id': const Uuid().v4(),
        'customer_id': customerId,
        'type': 'credit_purchase',
        'amount': subtotal,
        'balance_after': runningBalance,
        'description': note ?? 'Credit purchase (${items.length} item(s))',
        'created_at': nowIso,
      });

      // Ledger entry 2: If paid now, debt reduced
      if (amountPaidNow > 0) {
        final paymentId = const Uuid().v4();
        await txn.insert('credit_payments', {
          'id': paymentId,
          'client_id': paymentId,
          'company_id': companyId,
          'customer_id': customerId,
          'amount': amountPaidNow,
          'note': 'Paid at time of purchase',
          'created_at': nowIso,
          'synced': 0,
        });

        runningBalance = runningBalance - amountPaidNow;
        await txn.update(
          'customers',
          {'balance_due': runningBalance},
          where: 'id = ? AND company_id = ?',
          whereArgs: [customerId, companyId],
        );

        await txn.insert('customer_transactions', {
          'id': const Uuid().v4(),
          'customer_id': customerId,
          'type': 'payment',
          'amount': -amountPaidNow,
          'balance_after': runningBalance,
          'description': 'Amount paid now',
          'created_at': nowIso,
        });
      }
    });

    // 4. Enqueue in sync queue
    final payload = {
      'customerId': customerId,
      'items': items.map((i) => {'productId': i.productId, 'quantity': i.quantity}).toList(),
      'amountPaidNow': amountPaidNow,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: purchaseId,
          entityType: 'credit_purchase',
          entityId: purchaseId,
          operationType: 'CREATE',
          payload: payload,
        );

    // 5. Refresh related providers
    await _ref.read(productsRepositoryProvider.notifier).load();
    await _ref.read(customersRepositoryProvider.notifier).load();
    await _ref.read(dashboardRepositoryProvider.notifier).load();
    invalidateAllReports(_ref);

    // 6. Trigger sync if online
    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());

    return CreditPurchase(
      id: purchaseId,
      customerId: customerId,
      customerName: customerName,
      subtotal: subtotal,
      amountPaidNow: amountPaidNow,
      remainingCredit: remainingCredit,
      status: status,
      createdAt: DateTime.parse(nowIso),
    );
  }

  Future<void> recordPayment({
    required String customerId,
    required double amount,
    String? note,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    if (amount <= 0) {
      throw ApiException(statusCode: 400, message: 'Amount must be greater than zero', code: 'INVALID_AMOUNT');
    }

    final db = await AppDatabase.instance.database;

    // Scoped to this company's customers
    final custRows = await db.query(
      'customers',
      where: 'id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      limit: 1,
    );
    final currentBalance = custRows.isNotEmpty ? ((custRows.first['balance_due'] as num?)?.toDouble() ?? 0.0) : 0.0;

    if (amount > currentBalance + 0.01) {
      throw ApiException(
        statusCode: 400,
        message: 'Repayment amount cannot exceed total outstanding balance',
        code: 'OVERPAYMENT',
      );
    }

    final newBalance = (currentBalance - amount).clamp(0.0, double.infinity);
    final paymentId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('credit_payments', {
        'id': paymentId,
        'client_id': paymentId,
        'company_id': companyId,
        'customer_id': customerId,
        'amount': amount,
        'note': note,
        'created_at': nowIso,
        'synced': 0,
      });

      await txn.update(
        'customers',
        {'balance_due': newBalance},
        where: 'id = ? AND company_id = ?',
        whereArgs: [customerId, companyId],
      );

      await txn.insert('customer_transactions', {
        'id': const Uuid().v4(),
        'customer_id': customerId,
        'type': 'payment',
        'amount': -amount,
        'balance_after': newBalance,
        'description': note ?? 'Debt Repayment',
        'created_at': nowIso,
      });

      // FIFO settlement for credit sales
      if (newBalance <= 0.005) {
        // All customer debts are completely settled
        await txn.update(
          'sales',
          {'payment_status': 'paid'},
          where: 'customer_id = ? AND company_id = ? AND payment_status != ?',
          whereArgs: [customerId, companyId, 'paid'],
        );
      } else {
        final allCreditSales = await txn.query(
          'sales',
          where: 'customer_id = ? AND company_id = ? AND payment_status != ?',
          whereArgs: [customerId, companyId, 'paid'],
          orderBy: 'sold_at ASC',
        );
        final totalDebtOfSales = allCreditSales.fold<double>(
          0.0,
          (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0.0),
        );
        double paidAmountToDistribute = (totalDebtOfSales - newBalance).clamp(0.0, double.infinity);

        for (final s in allCreditSales) {
          final sTotal = ((s['total'] as num?)?.toDouble() ?? 0.0);
          if (paidAmountToDistribute >= sTotal - 0.005) {
            await txn.update('sales', {'payment_status': 'paid'}, where: 'id = ?', whereArgs: [s['id']]);
            paidAmountToDistribute -= sTotal;
          } else if (paidAmountToDistribute > 0.005) {
            await txn.update('sales', {'payment_status': 'partial'}, where: 'id = ?', whereArgs: [s['id']]);
            paidAmountToDistribute = 0;
          } else {
            await txn.update('sales', {'payment_status': 'unpaid'}, where: 'id = ?', whereArgs: [s['id']]);
          }
        }
      }
    });

    final payload = {
      'customerId': customerId,
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: paymentId,
          entityType: 'payment',
          entityId: paymentId,
          operationType: 'CREATE',
          payload: payload,
        );

    await _ref.read(customersRepositoryProvider.notifier).load();
    await _ref.read(dashboardRepositoryProvider.notifier).load();
    invalidateAllReports(_ref);

    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
  }

  Future<CustomerCreditProfile> getCustomerCreditProfile(String customerId) async {
    final companyId = _companyId;
    if (companyId == null) throw Exception('Not authenticated');

    final db = await AppDatabase.instance.database;

    // 1. Fetch customer details
    final custRows = await db.query(
      'customers',
      where: 'id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      limit: 1,
    );
    if (custRows.isEmpty) throw Exception('Customer not found');
    final customer = Customer.fromJson(custRows.first);

    // 2. Fetch all chronological transactions
    final transactions = await customerTransactions(customerId);

    // 3. Fetch sales & invoices
    final salesRows = await db.rawQuery('''
      SELECT s.id, s.total, s.discount, s.payment_status, s.sold_at, s.created_at, inv.invoice_number
      FROM sales s
      LEFT JOIN invoices inv ON inv.sale_id = s.id
      WHERE s.customer_id = ? AND s.company_id = ?
      ORDER BY s.sold_at DESC
    ''', [customerId, companyId]);

    final List<CustomerInvoiceDetail> invoicesList = [];

    for (final s in salesRows) {
      final saleId = s['id'] as String;
      final total = (s['total'] as num?)?.toDouble() ?? 0.0;
      final rawStatus = (s['payment_status'] as String? ?? 'paid').toLowerCase();
      final dateStr = (s['sold_at'] ?? s['created_at']) as String;
      final invNumber = s['invoice_number'] as String? ?? 'INV-${saleId.substring(0, 6).toUpperCase()}';

      final itemsRows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      final items = itemsRows.map((it) => CustomerInvoiceItem(
        productName: it['product_name'] as String? ?? 'Product',
        quantity: (it['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0.0,
        lineTotal: (it['line_total'] as num?)?.toDouble() ?? 0.0,
      )).toList();

      double amountPaid = 0.0;
      double remaining = total;
      if (rawStatus == 'paid') {
        amountPaid = total;
        remaining = 0.0;
      } else if (rawStatus == 'unpaid') {
        amountPaid = 0.0;
        remaining = total;
      } else {
        amountPaid = 0.0;
        remaining = total;
      }

      invoicesList.add(CustomerInvoiceDetail(
        id: saleId,
        invoiceNumber: invNumber,
        date: DateTime.tryParse(dateStr) ?? DateTime.now(),
        total: total,
        amountPaid: amountPaid,
        remainingBalance: remaining,
        status: rawStatus,
        items: items,
      ));
    }

    // 4. Fetch legacy credit_purchases
    final cpRows = await db.query(
      'credit_purchases',
      where: 'customer_id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      orderBy: 'created_at DESC',
    );

    for (final cp in cpRows) {
      final cpId = cp['id'] as String;
      final subtotal = (cp['subtotal'] as num?)?.toDouble() ?? 0.0;
      final paidNow = (cp['amount_paid_now'] as num?)?.toDouble() ?? 0.0;
      final remaining = (cp['remaining_credit'] as num?)?.toDouble() ?? 0.0;
      final status = cp['status'] as String? ?? 'unpaid';
      final dateStr = cp['created_at'] as String;

      final itemsRows = await db.query(
        'credit_items',
        where: 'purchase_id = ?',
        whereArgs: [cpId],
      );

      final items = itemsRows.map((it) => CustomerInvoiceItem(
        productName: it['product_name'] as String? ?? 'Product',
        quantity: (it['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0.0,
        lineTotal: (it['line_total'] as num?)?.toDouble() ?? 0.0,
      )).toList();

      invoicesList.add(CustomerInvoiceDetail(
        id: cpId,
        invoiceNumber: 'CR-${cpId.substring(0, 6).toUpperCase()}',
        date: DateTime.tryParse(dateStr) ?? DateTime.now(),
        total: subtotal,
        amountPaid: paidNow,
        remainingBalance: remaining,
        status: status,
        items: items,
      ));
    }

    invoicesList.sort((a, b) => b.date.compareTo(a.date));

    // Filter unpaid invoices: if status is unpaid or partial or remainingBalance > 0
    final unpaidInvoices = invoicesList
        .where((inv) => inv.remainingBalance > 0.005 || inv.status == 'unpaid' || inv.status == 'partial' || inv.status == 'partially_paid')
        .toList();

    DateTime? oldestDebt;
    if (unpaidInvoices.isNotEmpty) {
      oldestDebt = unpaidInvoices.map((i) => i.date).reduce((a, b) => a.isBefore(b) ? a : b);
    }

    // Calculate total credit sales and total repayments from transactions
    double totalCredit = 0.0;
    double totalRepayments = 0.0;

    for (final tx in transactions) {
      if (tx.amount > 0) {
        totalCredit += tx.amount;
      } else {
        totalRepayments += tx.amount.abs();
      }
    }

    if (totalCredit == 0 && invoicesList.isNotEmpty) {
      totalCredit = invoicesList.fold(0.0, (acc, i) => acc + i.total);
    }

    return CustomerCreditProfile(
      customer: customer,
      totalCreditSales: totalCredit,
      totalRepayments: totalRepayments,
      remainingBalance: customer.balanceDue,
      unpaidInvoiceCount: unpaidInvoices.length,
      oldestDebtDate: oldestDebt,
      transactions: transactions,
      unpaidInvoices: unpaidInvoices,
      allInvoices: invoicesList,
    );
  }

  Future<CreditSummary> summary() async {
    final companyId = _companyId;
    if (companyId == null) {
      return CreditSummary(totalOutstanding: 0, totalCredit: 0, totalPaid: 0);
    }

    final db = await AppDatabase.instance.database;
    // All queries scoped to this company
    final totalOutstandingRes = await db.rawQuery(
      'SELECT COALESCE(SUM(balance_due), 0) AS total FROM customers WHERE company_id = ? AND deleted_at IS NULL',
      [companyId],
    );
    final totalCreditRes = await db.rawQuery(
      'SELECT COALESCE(SUM(subtotal), 0) AS total FROM credit_purchases WHERE company_id = ?',
      [companyId],
    );
    final totalPaidRes = await db.rawQuery(
      '''
      SELECT (
        COALESCE((SELECT SUM(amount) FROM credit_payments WHERE company_id = ?), 0) +
        COALESCE((SELECT SUM(amount_paid_now) FROM credit_purchases WHERE company_id = ?), 0)
      ) AS total
      ''',
      [companyId, companyId],
    );

    final totalOutstanding = (totalOutstandingRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalCredit = (totalCreditRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (totalPaidRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final localSummary = CreditSummary(
      totalOutstanding: totalOutstanding,
      totalCredit: totalCredit,
      totalPaid: totalPaid,
    );

    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (!isOnline) return localSummary;

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/credit/summary');
      return CreditSummary.fromJson(response['data'] as Map<String, dynamic>);
    } catch (_) {
      return localSummary;
    }
  }

  Future<List<CustomerTransaction>> customerTransactions(String customerId) async {
    final companyId = _companyId;
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;

    // customer_transactions are scoped transitively through customers.company_id
    // We verify the customer belongs to this company before fetching transactions
    final custCheck = await db.query(
      'customers',
      where: 'id = ? AND company_id = ?',
      whereArgs: [customerId, companyId],
      limit: 1,
    );
    if (custCheck.isEmpty) return []; // Customer doesn't belong to this company

    final rows = await db.query(
      'customer_transactions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    final local = rows
        .map((r) => CustomerTransaction(
              id: r['id'] as String,
              type: r['type'] as String,
              amount: (r['amount'] as num).toDouble(),
              balanceAfter: (r['balance_after'] as num).toDouble(),
              description: r['description'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();

    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (!isOnline) return local;

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/credit/customers/$customerId/transactions');
      final remoteRows = (response['data'] as List).cast<Map<String, dynamic>>();
      final remoteTx = remoteRows.map(CustomerTransaction.fromJson).toList();

      final batch = db.batch();
      for (final tx in remoteTx) {
        batch.insert(
          'customer_transactions',
          {
            'id': tx.id,
            'customer_id': customerId,
            'type': tx.type,
            'amount': tx.amount,
            'balance_after': tx.balanceAfter,
            'description': tx.description,
            'created_at': tx.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      return remoteTx;
    } catch (_) {
      return local;
    }
  }

  Future<List<CreditPurchase>> listPurchases() async {
    final companyId = _companyId;
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    // Scoped to this company's credit purchases
    final rows = await db.query(
      'credit_purchases',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'created_at DESC',
    );

    final local = rows
        .map((r) => CreditPurchase(
              id: r['id'] as String,
              customerId: r['customer_id'] as String,
              customerName: (r['customer_name'] ?? '') as String,
              subtotal: (r['subtotal'] as num).toDouble(),
              amountPaidNow: (r['amount_paid_now'] as num).toDouble(),
              remainingCredit: (r['remaining_credit'] as num).toDouble(),
              status: r['status'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();

    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (!isOnline) return local;

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/credit/purchases');
      final remoteRows = (response['data'] as List).cast<Map<String, dynamic>>();
      final remotePurchases = remoteRows.map(CreditPurchase.fromJson).toList();

      final batch = db.batch();
      for (final p in remotePurchases) {
        batch.insert(
          'credit_purchases',
          {
            'id': p.id,
            'client_id': p.id,
            'company_id': companyId, // Tag server data with the active company
            'customer_id': p.customerId,
            'customer_name': p.customerName,
            'subtotal': p.subtotal,
            'amount_paid_now': p.amountPaidNow,
            'remaining_credit': p.remainingCredit,
            'status': p.status,
            'created_at': p.createdAt.toIso8601String(),
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      return remotePurchases;
    } catch (_) {
      return local;
    }
  }
}

final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  ref.watch(sessionProvider.select((s) => s.companyId));
  return CreditRepository(ref);
});
