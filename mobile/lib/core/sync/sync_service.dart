import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/session.dart';

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

  final Ref _ref;
  bool _isLocked = false;
  Timer? _pollingTimer;

  /// Active company from the current session. Null when not logged in.
  String? get _companyId => _ref.read(sessionProvider).companyId;

  void _init() {
    refreshQueueCounts();

    // Listen to network changes: when back online, trigger auto-sync
    _ref.listen<ConnectionStatus>(connectionStatusProvider, (previous, current) {
      if (current == ConnectionStatus.online && (previous != ConnectionStatus.online)) {
        syncPending();
        pullInitialData();
      }
    });

    // Periodic check every 45 seconds if online
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      final status = _ref.read(connectionStatusProvider);
      if (status == ConnectionStatus.online && state.pendingCount > 0) {
        syncPending();
      }
    });
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

  Future<void> syncPending() async {
    if (!mounted) return;
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

      for (final op in pendingOps) {
        final opId = op['id'] as String;
        final clientTxId = op['client_transaction_id'] as String;
        final entityType = op['entity_type'] as String;
        final opType = op['operation_type'] as String;
        final payload = jsonDecode(op['payload'] as String) as Map<String, dynamic>;
        final currentRetry = (op['retry_count'] as num?)?.toInt() ?? 0;

        try {
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
            await db.update('sales', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
            if (res is Map && res['data'] is Map && res['data']['invoice'] is Map) {
              final inv = res['data']['invoice'] as Map<String, dynamic>;
              if (inv['invoice_number'] != null) {
                await db.update(
                  'invoices',
                  {'invoice_number': inv['invoice_number'].toString()},
                  where: 'sale_id = ?',
                  whereArgs: [op['entity_id']],
                );
              }
            }
          } else if (entityType == 'expense' && opType == 'CREATE') {
            await client.post('/expenses', body: {
              ...payload,
              'clientId': clientTxId,
            });
            await db.update('expenses', {'synced': 1}, where: 'id = ?', whereArgs: [op['entity_id']]);
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
            await client.post('/products', body: {
              ...payload,
              'clientId': clientTxId,
            });
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
          // If server reports duplicate or 404 on delete, treat as idempotent success
          if ((e.statusCode == 400 && (e.message.contains('already exists') || e.code == 'DUPLICATE')) ||
              (e.statusCode == 404 && (opType == 'DELETE' || opType == 'UPDATE_STATUS'))) {
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
        }
      }

      if (mounted) {
        await refreshQueueCounts();
      }
      if (mounted) {
        state = state.copyWith(isSyncing: false, lastSyncedAt: DateTime.now());
      }
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
    final status = _ref.read(connectionStatusProvider);
    if (status != ConnectionStatus.online) return;

    final companyId = _ref.read(sessionProvider).companyId;
    if (companyId == null) return;

    try {
      final client = _ref.read(apiClientProvider);
      final db = await AppDatabase.instance.database;

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  ref.watch(sessionProvider.select((s) => s.companyId));
  return SyncService(ref);
});
