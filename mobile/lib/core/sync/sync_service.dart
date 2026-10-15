import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/session.dart';
import '../../features/reports/data/reports_repository.dart' show invalidateAllReports;
import '../../features/dashboard/data/dashboard_repository.dart' show dashboardRepositoryProvider;
import '../../features/expenses/data/expenses_repository.dart' show expensesRepositoryProvider;
import '../../features/sales/data/sales_repository.dart' show salesRepositoryProvider;

class SyncState {
  final int pendingCount;
  final int syncedCount;
  final int failedCount;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? lastError;

  const SyncState({
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
    this.lastSyncedAt,
    this.lastError,
  });

  SyncState copyWith({
    int? pendingCount,
    int? syncedCount,
    int? failedCount,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? lastError,
  }) {
    return SyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      failedCount: failedCount ?? this.failedCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError,
    );
  }
}

class SyncService extends StateNotifier<SyncState> {
  SyncService(this._ref) : super(const SyncState()) {
    _init();
  }

  /// Configurable flags for tests to avoid background timers and unawaited startup tasks
  static bool enablePeriodicTimer = true;
  static bool enableStartupSync = true;

  final Ref _ref;
  bool _isLocked = false;
  Timer? _pollingTimer;

  /// Active company from the current session. Null when not logged in.
  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  void _init() {
    if (enableStartupSync) {
      unawaited(reconcileLegacyClearDataOps());
      unawaited(refreshQueueCounts());

      // Listen to network changes: when back online, trigger auto-sync sequentially
      _ref.listen<ConnectionStatus>(connectionStatusProvider, (previous, current) async {
        if (current == ConnectionStatus.online && (previous != ConnectionStatus.online)) {
          await syncPending();
          await pullInitialData();
        }
      });

      // Also trigger on startup if online
      final initialStatus = _ref.read(connectionStatusProvider);
      if (initialStatus == ConnectionStatus.online) {
        Future.microtask(() async {
          if (!mounted) return;
          await syncPending();
        });
      }
    }

    // Periodic check every 45 seconds if online
    if (enablePeriodicTimer) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        final status = _ref.read(connectionStatusProvider);
        if (status == ConnectionStatus.online && state.pendingCount > 0) {
          syncPending();
        }
      });
    }
  }

  Future<void> refreshQueueCounts() async {
    final companyId = _companyId;
    if (!mounted) return;
    // When no account is active, show zero counts (not another account's queue).
    if (companyId == null) {
      state = state.copyWith(pendingCount: 0, syncedCount: 0, failedCount: 0);
      return;
    }

    final db = await AppDatabase.instance.database;
    final pendingRes = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_queue WHERE company_id = ? AND status = 'pending'",
      [companyId],
    );
    final syncedRes = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_queue WHERE company_id = ? AND status = 'synced'",
      [companyId],
    );
    final failedRes = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_queue WHERE company_id = ? AND status = 'failed'",
      [companyId],
    );

    if (!mounted) return;

    final pending = (pendingRes.first['count'] as num?)?.toInt() ?? 0;
    final synced = (syncedRes.first['count'] as num?)?.toInt() ?? 0;
    final failed = (failedRes.first['count'] as num?)?.toInt() ?? 0;

    state = state.copyWith(
      pendingCount: pending,
      syncedCount: synced,
      failedCount: failed,
    );
  }

  Future<void> enqueueOperation({
    required String id,
    required String clientTransactionId,
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.insert('sync_queue', {
      'id': id,
      'company_id': companyId, // Tag with active company — only this company will process it
      'client_transaction_id': clientTransactionId,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation_type': operationType,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
    });

    if (!mounted) return;
    await refreshQueueCounts();
    if (!mounted) return;

    // If online right now, trigger sync asynchronously
    final status = _ref.read(connectionStatusProvider);
    if (status == ConnectionStatus.online) {
      unawaited(syncPending());
    }
  }

  /// Safely resets retry metadata for an existing failed CLEAR_DATA operation for [companyId],
  /// allowing it to be immediately retried by the background sync worker.
  /// Explicit reconciliation: Cancels any legacy offline CLEAR_DATA queue entries
  /// so they cannot bypass the online-only rule or silently delete backend data.
  Future<int> reconcileLegacyClearDataOps({String? companyId}) async {
    final targetCompanyId = companyId ?? _companyId;
    if (targetCompanyId == null) return 0;

    final db = await AppDatabase.instance.database;
    final count = await db.update(
      'sync_queue',
      {
        'status': 'cancelled',
        'last_error': 'Legacy offline CLEAR_DATA cancelled: data reset requires direct online confirmation.',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: "company_id = ? AND entity_type = 'business_data' AND operation_type = 'CLEAR_DATA' AND status IN ('pending', 'failed')",
      whereArgs: [targetCompanyId],
    );

    if (count > 0 && mounted) {
      await refreshQueueCounts();
    }
    return count;
  }

  /// Cancels any legacy failed reset operations so they do not block queue processing.
  Future<bool> retryFailedReset({String? companyId}) async {
    final targetCompanyId = companyId ?? _companyId;
    if (targetCompanyId == null) return false;

    final count = await reconcileLegacyClearDataOps(companyId: targetCompanyId);
    if (count > 0) return true;

    final db = await AppDatabase.instance.database;
    final existing = await db.query(
      'sync_queue',
      where: "company_id = ? AND entity_type = 'business_data' AND operation_type = 'CLEAR_DATA'",
      whereArgs: [targetCompanyId],
      limit: 1,
    );
    return existing.isNotEmpty;
  }

  Future<void> syncPending() async {
    if (!mounted) return;
    final session = _ref.read(sessionProvider);
    if (!session.isLoggedIn || session.isSuspendedLocked || session.isTrialOrLicenseExpired) {
      return;
    }
    final companyId = _companyId;
    // TENANT ISOLATION: never process another account's queue.
    if (companyId == null) return;

    // Do not attempt network sync while offline
    final connStatus = _ref.read(connectionStatusProvider);
    if (connStatus != ConnectionStatus.online) return;

    if (_isLocked) return;
    _isLocked = true;
    state = state.copyWith(isSyncing: true);
    _ref.read(connectionStatusProvider.notifier).setSyncing(true);

    try {
      final db = await AppDatabase.instance.database;
      // Only fetch pending items that belong to the currently authenticated company
      final pendingOps = await db.query(
        'sync_queue',
        where: "company_id = ? AND (status = 'pending' OR (status = 'failed' AND retry_count < 5))",
        whereArgs: [companyId],
        orderBy: 'created_at ASC',
      );

      if (pendingOps.isEmpty) {
        if (mounted) {
          state = state.copyWith(isSyncing: false, lastSyncedAt: DateTime.now());
        }
        _ref.read(connectionStatusProvider.notifier).setSyncing(false);
        _isLocked = false;
        return;
      }

      final client = _ref.read(apiClientProvider);

      // If there is an uncompleted CLEAR_DATA for this company, do not process
      // any subsequent business mutations until the reset has completed successfully.
      final uncompletedClearOps = await db.query(
        'sync_queue',
        where: "company_id = ? AND entity_type = 'business_data' AND operation_type = 'CLEAR_DATA' AND status NOT IN ('synced', 'cancelled')",
        whereArgs: [companyId],
        limit: 1,
      );
      bool hasUncompletedClear = uncompletedClearOps.isNotEmpty;

      for (final op in pendingOps) {
        final opId = op['id'] as String;
        final clientTxId = op['client_transaction_id'] as String;
        final entityType = op['entity_type'] as String;
        final opType = op['operation_type'] as String;
        final currentRetry = (op['retry_count'] as num?)?.toInt() ?? 0;

        // Ensure post-reset mutations cannot reach the server before reset succeeds
        if (hasUncompletedClear && !(entityType == 'business_data' && opType == 'CLEAR_DATA')) {
          break;
        }

        try {
          Map<String, dynamic> payload;
          final rawPayload = op['payload'] as String? ?? '';
          try {
            payload = jsonDecode(rawPayload) as Map<String, dynamic>;
          } catch (decodeErr) {
            // Self-healing legacy payload recovery (e.g. unquoted Dart format from previous APK)
            if (entityType == 'sale' && opType == 'CREATE') {
              final saleRows = await db.query(
                'sales',
                where: 'id = ? AND company_id = ?',
                whereArgs: [op['entity_id'], companyId],
              );
              final itemRows = await db.query(
                'sale_items',
                where: 'sale_id = ? AND company_id = ?',
                whereArgs: [op['entity_id'], companyId],
              );

              if (saleRows.isNotEmpty && itemRows.isNotEmpty) {
                final saleRow = saleRows.first;
                final reconstructedItems = itemRows.map((ir) => {
                  'productId': ir['product_id'],
                  'quantity': (ir['quantity'] as num).toInt(),
                }).toList();

                payload = {
                  'items': reconstructedItems,
                  'discount': (saleRow['discount'] as num?)?.toDouble() ?? 0.0,
                  'paymentStatus': saleRow['payment_status']?.toString() ?? 'paid',
                  if (saleRow['sold_at'] != null) 'soldAt': saleRow['sold_at'].toString(),
                  if (saleRow['customer_id'] != null) 'customerId': saleRow['customer_id'].toString(),
                  if (saleRow['employee_id'] != null) 'employeeId': saleRow['employee_id'].toString(),
                };

                // Heal stored queue row with valid JSON once reconstruction succeeds
                await db.update(
                  'sync_queue',
                  {
                    'payload': jsonEncode(payload),
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ?',
                  whereArgs: [opId],
                );
              } else {
                throw FormatException('Malformed payload and local sale data missing for op $opId: $decodeErr');
              }
            } else {
              throw FormatException('Invalid JSON payload for op $opId ($entityType.$opType): $decodeErr');
            }
          }
          if (entityType == 'customer' && opType == 'CREATE') {
            await client.post('/customers', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('customers', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'customer' && opType == 'UPDATE') {
            await client.put('/customers/${op['entity_id']}', body: payload);
            await db.update('customers', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'customer' && opType == 'DELETE') {
            await client.delete('/customers/${op['entity_id']}');
          } else if (entityType == 'sale' && opType == 'CREATE') {
            final res = await client.post('/sales', body: {
              ...payload,
              'clientTransactionId': clientTxId,
            });
            String? serverSaleId;
            if (res is Map && res['data'] is Map && res['data']['sale'] is Map) {
              serverSaleId = res['data']['sale']['id']?.toString();
            } else if (res is Map && res['data'] is Map && res['data']['id'] != null) {
              serverSaleId = res['data']['id']?.toString();
            }

            if (serverSaleId != null && serverSaleId != op['entity_id']) {
              final existingServerRow = await db.query(
                'sales',
                columns: ['id'],
                where: 'id = ? AND company_id = ?',
                whereArgs: [serverSaleId, companyId],
              );
              if (existingServerRow.isNotEmpty) {
                // Server row already pulled. Transfer detailed items and invoices, then remove placeholder.
                await db.delete('sale_items', where: 'sale_id = ? AND product_id = "synced-summary"', whereArgs: [serverSaleId]);
                await db.update(
                  'sale_items',
                  {'sale_id': serverSaleId},
                  where: 'sale_id = ? AND company_id = ?',
                  whereArgs: [op['entity_id'], companyId],
                );
                await db.delete('invoices', where: 'sale_id = ? AND company_id = ?', whereArgs: [serverSaleId, companyId]);
                await db.update(
                  'invoices',
                  {'sale_id': serverSaleId},
                  where: 'sale_id = ? AND company_id = ?',
                  whereArgs: [op['entity_id'], companyId],
                );
                await db.delete('sales', where: 'id = ? AND company_id = ?', whereArgs: [op['entity_id'], companyId]);
              } else {
                await db.update(
                  'sales',
                  {'id': serverSaleId, 'synced': 1},
                  where: 'id = ? AND company_id = ?',
                  whereArgs: [op['entity_id'], companyId],
                );
                await db.update(
                  'sale_items',
                  {'sale_id': serverSaleId},
                  where: 'sale_id = ? AND company_id = ?',
                  whereArgs: [op['entity_id'], companyId],
                );
                await db.update(
                  'invoices',
                  {'sale_id': serverSaleId},
                  where: 'sale_id = ? AND company_id = ?',
                  whereArgs: [op['entity_id'], companyId],
                );
              }
              await db.update(
                'sync_queue',
                {'entity_id': serverSaleId},
                where: 'entity_id = ? AND company_id = ?',
                whereArgs: [op['entity_id'], companyId],
              );
            } else {
              await db.update('sales', {'synced': 1}, where: 'id = ? AND company_id = ?', whereArgs: [op['entity_id'], companyId]);
            }

            if (res is Map && res['data'] is Map && res['data']['invoice'] is Map) {
              final inv = res['data']['invoice'] as Map<String, dynamic>;
              final serverInvoiceId = inv['id']?.toString();
              final serverInvoiceNumber = inv['invoice_number']?.toString();
              final effectiveSaleId = serverSaleId ?? op['entity_id'];
              final invoiceUpdates = <String, dynamic>{};
              if (serverInvoiceId != null) invoiceUpdates['id'] = serverInvoiceId;
              if (serverInvoiceNumber != null) invoiceUpdates['invoice_number'] = serverInvoiceNumber;

              if (invoiceUpdates.isNotEmpty) {
                await db.update(
                  'invoices',
                  invoiceUpdates,
                  where: 'sale_id = ? AND company_id = ?',
                  whereArgs: [effectiveSaleId, companyId],
                );
              }
            }
          } else if (entityType == 'expense' && opType == 'CREATE') {
            final res = await client.post('/expenses', body: {
              ...payload,
              'clientId': clientTxId,
            });
            String? serverId;
            if (res is Map && res['data'] is Map && res['data']['id'] != null) {
              serverId = res['data']['id'].toString();
            }
            if (serverId != null && serverId != op['entity_id']) {
              await db.update(
                'expenses',
                {'id': serverId, 'synced': 1},
                where: 'id = ?',
                whereArgs: [op['entity_id']],
              );
            } else {
              await db.update('expenses', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            }
          } else if (entityType == 'payment' && opType == 'CREATE') {
            await client.post('/credit/payments', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('credit_payments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'credit_purchase' && opType == 'CREATE') {
            await client.post('/credit/purchases', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('credit_purchases', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'employee' && opType == 'CREATE') {
            await client.post('/employees', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('employees', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'employee' && opType == 'UPDATE') {
            await client.put('/employees/${op['entity_id']}', body: payload);
            await db.update('employees', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'employee' && opType == 'DELETE') {
            await client.delete('/employees/${op['entity_id']}');
          } else if ((entityType == 'salary_payment' && opType == 'CREATE') ||
              (entityType == 'employee' && opType == 'PAY_SALARY')) {
            final empId = payload['employeeId'] ?? op['entity_id'];
            await client.post('/employees/$empId/pay-salary', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('salary_payments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'appointment' && opType == 'CREATE') {
            await client.post('/appointments', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('appointments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'appointment' && opType == 'UPDATE') {
            await client.put('/appointments/${payload['id'] ?? op['entity_id']}', body: payload);
            await db.update('appointments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'appointment' && opType == 'UPDATE_STATUS') {
            await client.put('/appointments/${payload['id']}/status', body: {
              'status': payload['status'],
            });
            await db.update('appointments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'product' && opType == 'CREATE') {
            final res = await client.post('/products', body: {
              ...payload,
              'id': op['entity_id'],
              'clientId': clientTxId,
            });
            if (res is Map && res['data'] is Map && res['data']['id'] != null) {
              final serverId = res['data']['id'].toString();
              if (serverId != op['entity_id']) {
                await db.update('products', {'id': serverId}, where: 'id = ?', whereArgs: [op['entity_id']]);
              }
            }
            await db.update('products', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'supplier' && opType == 'CREATE') {
            await client.post('/suppliers', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('suppliers', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'supplier' && opType == 'UPDATE') {
            await client.put('/suppliers/${op['entity_id']}', body: payload);
            await db.update('suppliers', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'supplier' && opType == 'DELETE') {
            await client.delete('/suppliers/${op['entity_id']}');
          } else if (entityType == 'supplier_purchase' && opType == 'CREATE') {
            final supplierId = payload['supplierId'] ?? payload['supplier_id'];
            final res = await client.post('/suppliers/$supplierId/purchases', body: {
              ...payload,
              'clientTransactionId': clientTxId,
            });
            String? serverPurchaseId;
            if (res is Map && res['data'] is Map && res['data']['purchase'] is Map) {
              serverPurchaseId = res['data']['purchase']['id']?.toString();
            }
            if (serverPurchaseId != null && serverPurchaseId != op['entity_id']) {
              await db.update('supplier_purchases', {'id': serverPurchaseId, 'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
              await db.update('supplier_purchase_items', {'purchase_id': serverPurchaseId}, where: 'purchase_id = ?', whereArgs: [op['entity_id']]);
            } else {
              await db.update('supplier_purchases', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            }
            // Mark corresponding initial payment as synced if created locally with purchase
            try {
              await db.update('supplier_payments', {'synced': 1}, where: 'client_id = ?', whereArgs: ['pay_$clientTxId']);
            } catch (_) {}
          } else if (entityType == 'supplier_payment' && opType == 'CREATE') {
            final supplierId = payload['supplierId'] ?? payload['supplier_id'];
            final res = await client.post('/suppliers/$supplierId/payments', body: {
              ...payload,
              'clientId': clientTxId,
            });
            String? serverPaymentId;
            if (res is Map && res['data'] is Map && res['data']['payment'] is Map) {
              serverPaymentId = res['data']['payment']['id']?.toString();
            }
            if (serverPaymentId != null && serverPaymentId != op['entity_id']) {
              await db.update('supplier_payments', {'id': serverPaymentId, 'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else {
              await db.update('supplier_payments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            }
          } else if (entityType == 'restaurant_order' && opType == 'CREATE') {
            await client.post('/restaurant/orders', body: payload);
            await db.update('restaurant_orders', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'restaurant_order' && opType == 'UPDATE') {
            await client.put('/restaurant/orders/${payload['id'] ?? op['entity_id']}', body: payload);
            await db.update('restaurant_orders', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'restaurant_order' && opType == 'UPDATE_STATUS') {
            await client.patch('/restaurant/orders/${op['entity_id']}/status', body: payload);
            await db.update('restaurant_orders', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'restaurant_order' && opType == 'RECORD_PAYMENT') {
            await client.post('/restaurant/orders/${payload['orderId'] ?? op['entity_id']}/payments', body: payload);
            await db.update('restaurant_payments', {'synced': 1}, where: 'order_id = ?', whereArgs: [op['entity_id']]);
          } else if (entityType == 'business_data' && opType == 'CLEAR_DATA') {
            // Under online-only policy, legacy queued CLEAR_DATA operations cannot bypass
            // the online-only rule or silently delete backend data upon reconnection.
            // Safely cancel the legacy entry, leave server and local business records intact.
            await db.update(
              'sync_queue',
              {
                'status': 'cancelled',
                'last_error': 'Legacy offline CLEAR_DATA cancelled: data reset requires direct online confirmation.',
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [opId],
            );
            hasUncompletedClear = false;
            continue;
          }

          // Mark op synced
          await db.update(
            'sync_queue',
            {
              'status': 'synced',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [opId],
          );
        } on ApiException catch (e) {
          // Account restriction or revoked session: preserve queue item as pending without incrementing retry_count and stop syncing immediately.
          if (e.isAccountSuspended || e.isTrialExpired || e.isSessionRevoked) {
            break;
          }

          // If server reports duplicate or 404 on delete, treat as idempotent success
          final isDuplicateSalary = e.statusCode == 409 ||
              e.code == 'DUPLICATE_SALARY_PAYMENT' ||
              e.message.contains('A salary payment for this employee') ||
              e.message.contains('already exists');
          final isDuplicate = (e.statusCode == 400 && (e.message.contains('already exists') || e.code == 'DUPLICATE')) ||
              isDuplicateSalary;
          final isIdempotent404 = e.statusCode == 404 && (opType == 'DELETE' || opType == 'UPDATE_STATUS');

          if (isDuplicate || isIdempotent404) {
            // Update entity to synced = 1 so local entity state is consistent
            if (entityType == 'expense') {
              await db.update('expenses', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else if (entityType == 'sale') {
              await db.update('sales', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else if (entityType == 'payment') {
              await db.update('credit_payments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else if (entityType == 'customer') {
              await db.update('customers', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else if (entityType == 'employee') {
              await db.update('employees', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else if (entityType == 'product') {
              await db.update('products', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else if (entityType == 'supplier') {
              await db.update('suppliers', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            } else if (entityType == 'supplier_purchase') {
              await db.update('supplier_purchases', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
              if (clientTxId.isNotEmpty) {
                try {
                  await db.update('supplier_payments', {'synced': 1}, where: 'client_id = ?', whereArgs: ['pay_$clientTxId']);
                } catch (_) {}
              }
            } else if (entityType == 'supplier_payment') {
              await db.update('supplier_payments', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            }
            await db.update(
              'sync_queue',
              {
                'status': 'synced',
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [opId],
            );
          } else {
            await db.update(
              'sync_queue',
              {
                'status': 'failed',
                'retry_count': currentRetry + 1,
                'last_error': e.message,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [opId],
            );
            if (entityType == 'business_data' && opType == 'CLEAR_DATA') {
              break;
            }
          }
        } catch (e) {
          await db.update(
            'sync_queue',
            {
              'status': 'failed',
              'retry_count': currentRetry + 1,
              'last_error': e.toString(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [opId],
          );
          if (entityType == 'business_data' && opType == 'CLEAR_DATA') {
            break;
          }
        }
      }

      if (mounted) {
        await refreshQueueCounts();
      }
      if (mounted) {
        state = state.copyWith(isSyncing: false, lastSyncedAt: DateTime.now());
      }
      invalidateAllReports(_ref);
      _ref.invalidate(dashboardRepositoryProvider);
      _ref.invalidate(expensesRepositoryProvider);
      _ref.invalidate(salesRepositoryProvider);
    } finally {
      if (mounted) {
        _ref.read(connectionStatusProvider.notifier).setSyncing(false);
      }
      _isLocked = false;
    }
  }

  /// Downloads existing backend data into local SQLite so app is immediately
  /// usable offline after first login.
  Future<void> pullInitialData() async {
    final session = _ref.read(sessionProvider);
    if (!session.isLoggedIn || session.isSuspendedLocked || session.isTrialOrLicenseExpired) {
      return;
    }
    final status = _ref.read(connectionStatusProvider);
    if (status != ConnectionStatus.online) return;

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final client = _ref.read(apiClientProvider);
      final db = await AppDatabase.instance.database;

      // Defensive check: if a reset is pending or failed for this company, never pull stale data!
      if (await AppDatabase.instance.hasUncompletedClearData(companyId)) return;

      // 1. Company info (scoped by companyId)
      try {
        final res = await client.get('/companies/me');
        if (res is Map && res['data'] is Map) {
          await db.insert(
            'sync_metadata',
            {
              'key': 'company_info_$companyId',
              'value': jsonEncode(res['data']),
              'updated_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (_) {}

      // 2. Products
      try {
        final res = await client.get('/products');
        if (res is Map && res['data'] is List) {
          final batch = db.batch();
          for (final p in res['data']) {
            batch.insert(
              'products',
              {
                'id': p['id'],
                'company_id': companyId,
                'name': p['name'],
                'category': p['category'],
                'purchase_price': (p['purchase_price'] ?? p['purchasePrice'] ?? 0),
                'selling_price': (p['selling_price'] ?? p['sellingPrice'] ?? 0),
                'quantity': (p['quantity'] ?? 0),
                'minimum_stock': (p['minimum_stock'] ?? p['minimumStock'] ?? 5),
                'barcode': p['barcode'],
                'expiration_date': p['expiration_date'] ?? p['expirationDate'],
                'image_url': p['image_url'] ?? p['imageUrl'],
                'size': p['size'],
                'color': p['color'],
                'brand': p['brand'],
                'updated_at': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 3. Customers
      try {
        final res = await client.get('/customers');
        if (res is Map && res['data'] is List) {
          final batch = db.batch();
          for (final c in res['data']) {
            batch.insert(
              'customers',
              {
                'id': c['id'],
                'company_id': companyId,
                'name': c['name'],
                'phone': c['phone'],
                'address': c['address'],
                'balance_due': (c['balance_due'] ?? c['balanceDue'] ?? 0),
                'created_at': c['created_at'] ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 4. Employees
      try {
        final res = await client.get('/employees');
        if (res is Map && res['data'] is List) {
          final batch = db.batch();
          for (final e in res['data']) {
            batch.insert(
              'employees',
              {
                'id': e['id'],
                'company_id': companyId,
                'name': e['name'],
                'position': e['position'],
                'base_salary': (e['base_salary'] ?? e['baseSalary'] ?? 0),
                'phone': e['phone'],
                'created_at': e['created_at'] ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 5. Appointments
      try {
        final res = await client.get('/appointments');
        if (res is Map && res['data'] is List) {
          final batch = db.batch();
          for (final a in res['data']) {
            batch.insert(
              'appointments',
              {
                'id': a['id'],
                'company_id': companyId,
                'customer_id': a['customer_id'] ?? a['customerId'],
                'customer_name': a['customer_name'] ?? a['customerName'],
                'title': a['title'],
                'notes': a['notes'],
                'scheduled_at': a['scheduled_at'] ?? a['scheduledAt'] ?? DateTime.now().toIso8601String(),
                'status': a['status'] ?? 'scheduled',
                'created_at': a['created_at'] ?? DateTime.now().toIso8601String(),
                'updated_at': a['updated_at'] ?? a['updatedAt'],
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 6. Suppliers
      try {
        final res = await client.get('/suppliers');
        if (res is Map && res['data'] is List) {
          final batch = db.batch();
          for (final s in res['data']) {
            batch.insert(
              'suppliers',
              {
                'id': s['id'],
                'company_id': companyId,
                'name': s['name'],
                'phone': s['phone'],
                'products_supplied': (s['products_supplied'] ?? s['productsSupplied'] ?? 0),
                'created_at': s['created_at'] ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 7. Sales & Sale items (critical for offline revenue accuracy)
      try {
        final res = await client.get('/sales');
        if (res is Map && res['data'] is List) {
          final batch = db.batch();
          final existingItemSaleIds = (await db.rawQuery(
            'SELECT DISTINCT sale_id FROM sale_items WHERE company_id = ?',
            [companyId],
          )).map((r) => r['sale_id'] as String).toSet();

          final unsyncedSaleRows = await db.query(
            'sales',
            columns: ['id', 'client_transaction_id'],
            where: 'company_id = ? AND synced = 0',
            whereArgs: [companyId],
          );
          final unsyncedSaleIds = unsyncedSaleRows.map((r) => r['id'] as String).toSet();
          final unsyncedClientTxIds = unsyncedSaleRows
              .map((r) => r['client_transaction_id'] as String?)
              .whereType<String>()
              .toSet();

          for (final s in res['data']) {
            final saleId = s['id']?.toString() ?? '';
            final clientTxId = s['client_transaction_id']?.toString() ?? s['clientTransactionId']?.toString();
            if (saleId.isEmpty || unsyncedSaleIds.contains(saleId)) continue;
            if (clientTxId != null && unsyncedClientTxIds.contains(clientTxId)) continue;

            if (clientTxId != null && clientTxId.isNotEmpty) {
              final dupRows = await db.query(
                'sales',
                columns: ['id'],
                where: 'company_id = ? AND client_transaction_id = ? AND id != ? AND synced = 1',
                whereArgs: [companyId, clientTxId, saleId],
              );
              for (final dup in dupRows) {
                final dupId = dup['id'] as String;
                final detailedItems = await db.query(
                  'sale_items',
                  where: 'sale_id = ? AND company_id = ? AND product_id != "synced-summary"',
                  whereArgs: [dupId, companyId],
                );
                if (detailedItems.isNotEmpty) {
                  await db.delete('sale_items', where: 'sale_id = ? AND product_id = "synced-summary"', whereArgs: [saleId]);
                  await db.update('sale_items', {'sale_id': saleId}, where: 'sale_id = ? AND company_id = ?', whereArgs: [dupId, companyId]);
                } else {
                  await db.delete('sale_items', where: 'sale_id = ? AND company_id = ?', whereArgs: [dupId, companyId]);
                }
                await db.update('invoices', {'sale_id': saleId}, where: 'sale_id = ? AND company_id = ?', whereArgs: [dupId, companyId]);
                await db.delete('sales', where: 'id = ? AND company_id = ?', whereArgs: [dupId, companyId]);
              }
            }

            final soldAtStr = (s['sold_at'] ?? s['soldAt'] ?? s['created_at'] ?? s['createdAt'] ?? DateTime.now().toIso8601String()).toString();
            final total = (s['total'] as num?)?.toDouble() ?? 0.0;
            final subtotal = (s['subtotal'] as num?)?.toDouble() ?? total;
            final discount = (s['discount'] as num?)?.toDouble() ?? 0.0;
            final paymentStatus = s['payment_status'] ?? s['paymentStatus'] ?? 'paid';
            final customerName = s['customer_name'] ?? s['customerName'];
            final margin = (s['margin'] as num?)?.toDouble();

            batch.insert(
              'sales',
              {
                'id': saleId,
                if (clientTxId != null) 'client_transaction_id': clientTxId,
                'company_id': companyId,
                'customer_name': customerName,
                'subtotal': subtotal,
                'discount': discount,
                'total': total,
                'payment_status': paymentStatus,
                'sold_at': soldAtStr,
                'created_at': soldAtStr,
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            if (!existingItemSaleIds.contains(saleId)) {
              final lineProfit = margin ?? 0.0;
              final cogs = (total - lineProfit).clamp(0.0, double.infinity);
              batch.insert(
                'sale_items',
                {
                  'id': 'summary-$saleId',
                  'sale_id': saleId,
                  'company_id': companyId,
                  'product_id': 'synced-summary',
                  'product_name': 'Sale Items',
                  'quantity': 1,
                  'unit_price': total,
                  'unit_cost': cogs,
                  'line_total': total,
                  'line_profit': lineProfit,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 8. Expenses (critical for offline net profit accuracy)
      try {
        final res = await client.get('/expenses');
        if (res is Map && res['data'] is List) {
          final batch = db.batch();
          final unsyncedRows = await db.query(
            'expenses',
            columns: ['id', 'client_id'],
            where: 'company_id = ? AND synced = 0',
            whereArgs: [companyId],
          );
          final unsyncedExpenseIds = unsyncedRows.map((r) => r['id'] as String).toSet();
          final unsyncedClientIds = unsyncedRows
              .map((r) => r['client_id'] as String?)
              .whereType<String>()
              .toSet();

          for (final exp in res['data']) {
            final expId = exp['id']?.toString() ?? '';
            final expClientId = exp['client_id']?.toString() ?? exp['clientId']?.toString();
            if (expId.isEmpty || unsyncedExpenseIds.contains(expId)) continue;
            if (expClientId != null && unsyncedClientIds.contains(expClientId)) continue;

            if (expClientId != null && expClientId.isNotEmpty) {
              await db.delete(
                'expenses',
                where: 'company_id = ? AND client_id = ? AND id != ?',
                whereArgs: [companyId, expClientId, expId],
              );
            }

            final dateStr = (exp['expense_date'] ?? exp['expenseDate'] ?? exp['created_at'] ?? exp['createdAt'] ?? DateTime.now().toIso8601String()).toString().substring(0, 10);
            final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
            batch.insert(
              'expenses',
              {
                'id': expId,
                if (expClientId != null) 'client_id': expClientId,
                'company_id': companyId,
                'category': exp['category'] ?? 'other',
                'description': exp['description'],
                'amount': amount,
                'expense_date': dateStr,
                'period_type': exp['period_type'] ?? exp['periodType'] ?? 'daily',
                'employee_id': exp['employee_id'] ?? exp['employeeId'],
                'salary_period': exp['salary_period'] ?? exp['salaryPeriod'],
                'duration': exp['duration'],
                'created_at': exp['created_at'] ?? exp['createdAt'] ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // Invalidate reports and providers once data is populated locally
      invalidateAllReports(_ref);
      _ref.invalidate(dashboardRepositoryProvider);
      _ref.invalidate(expensesRepositoryProvider);
      _ref.invalidate(salesRepositoryProvider);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  ref.watch(sessionProvider.select((s) => s.companyId ?? s.userId));
  return SyncService(ref);
});
