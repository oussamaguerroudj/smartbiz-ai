import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class PaymentResult {
  final bool success;
  final bool duplicateIgnored;
  final double paymentAmount;
  final double newPaid;
  final double newRemaining;
  final String newStatus;
  final double? newCustomerDebt;
  final String? message;

  const PaymentResult({
    required this.success,
    this.duplicateIgnored = false,
    required this.paymentAmount,
    this.newPaid = 0.0,
    this.newRemaining = 0.0,
    this.newStatus = 'paid',
    this.newCustomerDebt,
    this.message,
  });
}

class PaymentTransactionManager {
  static const _uuid = Uuid();

  /// Records an invoice payment within an atomic transaction with strict validation guards.
  ///
  /// Rejects zero, negative, excessive, and duplicate payments before any database mutation.
  /// Customer debt cannot be silently clamped to zero when payment exceeds the valid debt.
  static Future<PaymentResult> recordInvoicePayment({
    required Database db,
    required String companyId,
    required String invoiceId,
    required double paymentAmount,
    String? paymentId,
    String? nowIso,
  }) async {
    final stablePaymentId = paymentId ?? _uuid.v4();
    final timestamp = nowIso ?? DateTime.now().toIso8601String();

    // 1. Guard against non-positive payment amounts
    if (paymentAmount <= 0.001) {
      throw ArgumentError('Payment amount must be greater than zero. Received: $paymentAmount');
    }

    return await db.transaction<PaymentResult>((txn) async {
      // 2. Idempotency guard: If this paymentId was already processed, ignore duplicate replay
      final existingTx = await txn.query(
        'customer_transactions',
        where: 'id = ? AND company_id = ?',
        whereArgs: [stablePaymentId, companyId],
      );
      if (existingTx.isNotEmpty) {
        return PaymentResult(
          success: true,
          duplicateIgnored: true,
          paymentAmount: paymentAmount,
          message: 'Payment $stablePaymentId was already recorded. Replay ignored safely.',
        );
      }

      // 3. Query current invoice state within transaction
      final invRows = await txn.query(
        'invoices',
        where: 'id = ? AND company_id = ?',
        whereArgs: [invoiceId, companyId],
      );
      if (invRows.isEmpty) {
        throw StateError('Invoice $invoiceId not found in company $companyId');
      }

      final inv = invRows.first;
      final saleId = inv['sale_id'] as String?;
      final invNum = inv['invoice_number'] as String? ?? invoiceId;
      final customerName = inv['customer_name'] as String?;
      final total = (inv['total'] as num?)?.toDouble() ?? 0.0;
      final currentPaid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final currentRemaining = (inv['remaining_amount'] as num?)?.toDouble() ??
          (total - currentPaid).clamp(0.0, double.infinity);

      // 4. Guard against excessive payment on invoice
      if (paymentAmount > currentRemaining + 0.001) {
        throw ArgumentError(
          'Payment amount ($paymentAmount DZD) exceeds invoice remaining balance ($currentRemaining DZD)',
        );
      }

      // 5. Customer debt validation (if credit customer)
      String? customerId;
      double? currentDebt;
      if (customerName != null && customerName != 'Walk-in Customer') {
        final custRows = await txn.query(
          'customers',
          where: 'name = ? AND company_id = ?',
          whereArgs: [customerName, companyId],
        );
        if (custRows.isNotEmpty) {
          customerId = custRows.first['id'] as String;
          currentDebt = (custRows.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
          if (paymentAmount > currentDebt + 0.001) {
            throw ArgumentError(
              'Payment amount ($paymentAmount DZD) exceeds customer outstanding debt balance ($currentDebt DZD)',
            );
          }
        }
      }

      // 6. Calculate consistent updated states
      final newPaid = currentPaid + paymentAmount;
      final newRemaining = (currentRemaining - paymentAmount).clamp(0.0, double.infinity);
      final isFullyPaid = newRemaining <= 0.001;
      final newStatus = isFullyPaid ? 'paid' : 'partial';

      // 7. Atomic Write: Update invoice
      await txn.update(
        'invoices',
        {
          'paid_amount': newPaid,
          'remaining_amount': newRemaining,
          'status': newStatus,
        },
        where: 'id = ? AND company_id = ?',
        whereArgs: [invoiceId, companyId],
      );

      // 8. Atomic Write: Update matching sale
      if (saleId != null && saleId.isNotEmpty) {
        await txn.update(
          'sales',
          {'payment_status': newStatus},
          where: 'id = ? AND company_id = ?',
          whereArgs: [saleId, companyId],
        );
      }

      // 9. Atomic Write: Update customer credit balance & transaction ledger
      double? newCustomerDebt;
      if (customerId != null && currentDebt != null) {
        newCustomerDebt = currentDebt - paymentAmount; // Strictly positive or zero due to validation guard
        await txn.update(
          'customers',
          {'credit_balance': newCustomerDebt},
          where: 'id = ? AND company_id = ?',
          whereArgs: [customerId, companyId],
        );

        await txn.insert('customer_transactions', {
          'id': stablePaymentId,
          'company_id': companyId,
          'customer_id': customerId,
          'type': 'payment',
          'amount': paymentAmount,
          'balance_after': newCustomerDebt,
          'description': isFullyPaid
              ? 'Full invoice settlement ($invNum)'
              : 'Partial payment on invoice ($invNum)',
          'created_at': timestamp,
        });
      }

      // 10. Atomic Write: Enqueue sync operation with stable transaction ID
      await txn.insert('sync_queue', {
        'id': _uuid.v4(),
        'company_id': companyId,
        'client_transaction_id': stablePaymentId,
        'entity_type': 'invoice',
        'entity_id': invoiceId,
        'operation_type': 'UPDATE',
        'payload': jsonEncode({
          'status': newStatus,
          'paid_amount': newPaid,
          'remaining_amount': newRemaining,
          'payment_amount': paymentAmount,
          'sale_id': saleId,
        }),
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      return PaymentResult(
        success: true,
        paymentAmount: paymentAmount,
        newPaid: newPaid,
        newRemaining: newRemaining,
        newStatus: newStatus,
        newCustomerDebt: newCustomerDebt,
      );
    });
  }

  /// Records customer credit repayment with FIFO invoice allocation within an atomic transaction.
  ///
  /// Rejects zero, negative, excessive, and duplicate payments before any database mutation.
  /// Customer debt cannot be silently clamped to zero when payment exceeds current debt.
  static Future<PaymentResult> recordCreditRepayment({
    required Database db,
    required String companyId,
    required String customerId,
    required double paymentAmount,
    String? paymentId,
    String? nowIso,
  }) async {
    final stablePaymentId = paymentId ?? _uuid.v4();
    final timestamp = nowIso ?? DateTime.now().toIso8601String();

    // 1. Guard against non-positive payment amounts
    if (paymentAmount <= 0.001) {
      throw ArgumentError('Payment amount must be greater than zero. Received: $paymentAmount');
    }

    return await db.transaction<PaymentResult>((txn) async {
      // 2. Idempotency guard: If this paymentId was already processed, ignore duplicate replay
      final existingTx = await txn.query(
        'customer_transactions',
        where: 'id = ? AND company_id = ?',
        whereArgs: [stablePaymentId, companyId],
      );
      if (existingTx.isNotEmpty) {
        return PaymentResult(
          success: true,
          duplicateIgnored: true,
          paymentAmount: paymentAmount,
          message: 'Repayment $stablePaymentId was already recorded. Replay ignored safely.',
        );
      }

      // 3. Query current customer state within transaction
      final custRows = await txn.query(
        'customers',
        where: 'id = ? AND company_id = ?',
        whereArgs: [customerId, companyId],
      );
      if (custRows.isEmpty) {
        throw StateError('Customer $customerId not found in company $companyId');
      }

      final cust = custRows.first;
      final customerName = cust['name'] as String;
      final currentDebt = (cust['credit_balance'] as num?)?.toDouble() ?? 0.0;

      // 4. Guard against excessive payment on customer debt
      if (paymentAmount > currentDebt + 0.001) {
        throw ArgumentError(
          'Payment amount ($paymentAmount DZD) exceeds current customer debt balance ($currentDebt DZD)',
        );
      }

      // 5. Calculate new balance: strictly positive or zero, no silent clamping
      final newBalance = currentDebt - paymentAmount;

      // 6. Atomic Write: Insert customer transaction ledger record
      await txn.insert('customer_transactions', {
        'id': stablePaymentId,
        'company_id': companyId,
        'customer_id': customerId,
        'type': 'payment',
        'amount': paymentAmount,
        'balance_after': newBalance,
        'description': 'Credit repayment at register',
        'created_at': timestamp,
      });

      // 7. Atomic Write: Update customer credit balance
      await txn.update(
        'customers',
        {'credit_balance': newBalance},
        where: 'id = ? AND company_id = ?',
        whereArgs: [customerId, companyId],
      );

      // 8. Atomic Write: FIFO invoice debt allocation
      // Query customer unpaid/partial invoices strictly in chronological order
      final unpaidInvoices = await txn.query(
        'invoices',
        where: "company_id = ? AND customer_name = ? AND status IN ('unpaid', 'partial')",
        whereArgs: [companyId, customerName],
        orderBy: 'created_at ASC',
      );

      double remainingToAllocate = paymentAmount;
      for (final inv in unpaidInvoices) {
        if (remainingToAllocate <= 0.001) break;

        final invId = inv['id'] as String;
        final invTotal = (inv['total'] as num?)?.toDouble() ?? 0.0;
        final curPaid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final curRemaining = (inv['remaining_amount'] as num?)?.toDouble() ??
            (invTotal - curPaid).clamp(0.0, double.infinity);

        if (curRemaining <= 0) continue;

        // Allocation bounded strictly by remainingToAllocate and invoice balance
        final alloc = remainingToAllocate > curRemaining ? curRemaining : remainingToAllocate;
        final invNewPaid = curPaid + alloc;
        final invNewRemaining = (curRemaining - alloc).clamp(0.0, double.infinity);
        final invNewStatus = invNewRemaining <= 0.001 ? 'paid' : 'partial';

        await txn.update(
          'invoices',
          {
            'paid_amount': invNewPaid,
            'remaining_amount': invNewRemaining,
            'status': invNewStatus,
          },
          where: 'id = ? AND company_id = ?',
          whereArgs: [invId, companyId],
        );

        final saleId = inv['sale_id'] as String?;
        if (saleId != null && saleId.isNotEmpty) {
          await txn.update(
            'sales',
            {'payment_status': invNewStatus},
            where: 'id = ? AND company_id = ?',
            whereArgs: [saleId, companyId],
          );
        }

        remainingToAllocate -= alloc;
      }

      // 9. Atomic Write: Enqueue sync operation with stable transaction ID
      await txn.insert('sync_queue', {
        'id': _uuid.v4(),
        'company_id': companyId,
        'client_transaction_id': stablePaymentId,
        'entity_type': 'credit_payment',
        'entity_id': customerId,
        'operation_type': 'CREATE',
        'payload': jsonEncode({
          'customerId': customerId,
          'amount': paymentAmount,
          'note': 'Desktop Credit Register repayment',
        }),
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      return PaymentResult(
        success: true,
        paymentAmount: paymentAmount,
        newCustomerDebt: newBalance,
      );
    });
  }
}
