import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Credit Sale system (Ch. 5-14/17) — a customer buys now and pays part
/// (or none) of the total immediately; the rest becomes debt tracked on
/// their balance, repayable later. Deliberately its own repository/
/// models, mirroring the backend's own separate credit_purchases /
/// credit_payments / customer_transactions tables rather than reusing
/// the regular Sales models.
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

  bool get isPurchase => type == 'credit_purchase';

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

class CreditRepository {
  CreditRepository(this._ref);
  final Ref _ref;

  Future<CreditPurchase> createPurchase({
    required String customerId,
    required List<CreditItemInput> items,
    required double amountPaidNow,
    String? note,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/credit/purchases', body: {
      'customerId': customerId,
      'items': items
          .map((i) => {'productId': i.productId, 'quantity': i.quantity})
          .toList(),
      'amountPaidNow': amountPaidNow,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final data = response['data'] as Map<String, dynamic>;
    return CreditPurchase.fromJson(data['purchase'] as Map<String, dynamic>);
  }

  Future<List<CreditPurchase>> listPurchases() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/credit/purchases');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(CreditPurchase.fromJson).toList();
  }

  Future<void> recordPayment({
    required String customerId,
    required double amount,
    String? note,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/credit/payments', body: {
      'customerId': customerId,
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<List<CustomerTransaction>> customerTransactions(String customerId) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/credit/customers/$customerId/transactions');
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(CustomerTransaction.fromJson).toList();
  }

  Future<CreditSummary> summary() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/credit/summary');
    return CreditSummary.fromJson(response['data'] as Map<String, dynamic>);
  }
}

final creditRepositoryProvider = Provider<CreditRepository>((ref) => CreditRepository(ref));
