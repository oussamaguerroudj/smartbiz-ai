import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/desktop_database.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/session.dart';

class DesktopSyncState {
  final int pendingCount;
  final int syncedCount;
  final int failedCount;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? lastError;

  const DesktopSyncState({
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.isSyncing = false,
    this.lastSyncedAt,
    this.lastError,
  });

  DesktopSyncState copyWith({
    int? pendingCount,
    int? syncedCount,
    int? failedCount,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? lastError,
  }) {
    return DesktopSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      failedCount: failedCount ?? this.failedCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError,
    );
  }
}

class DesktopSyncService extends StateNotifier<DesktopSyncState> {
  DesktopSyncService(this._ref) : super(const DesktopSyncState()) {
    _init();
  }

  final Ref _ref;
  bool _isLocked = false;
  Timer? _pollingTimer;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  void _init() {
    refreshQueueCounts();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.pendingCount > 0) {
        syncPending();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshQueueCounts() async {
    final companyId = _companyId;
    if (companyId == null) {
      if (mounted) state = state.copyWith(pendingCount: 0, syncedCount: 0, failedCount: 0);
      return;
    }

    try {
      final db = await ModiriDesktopDatabase.instance.database;
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
      state = state.copyWith(
        pendingCount: (pendingRes.first['count'] as num?)?.toInt() ?? 0,
        syncedCount: (syncedRes.first['count'] as num?)?.toInt() ?? 0,
        failedCount: (failedRes.first['count'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {}
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
    final db = await ModiriDesktopDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'sync_queue',
      {
        'id': id,
        'company_id': companyId,
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await refreshQueueCounts();
    unawaited(syncPending());
  }

  Future<void> syncPending() async {
    if (!mounted) return;
    final companyId = _companyId;
    if (companyId == null) return;

    if (_isLocked) return;
    _isLocked = true;
    if (mounted) state = state.copyWith(isSyncing: true);

    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final pendingRows = await db.query(
        'sync_queue',
        where: "company_id = ? AND status = 'pending'",
        whereArgs: [companyId],
        orderBy: 'created_at ASC',
        limit: 25,
      );

      final client = _ref.read(apiClientProvider);

      for (final row in pendingRows) {
        final id = row['id'] as String;
        final entityType = row['entity_type'] as String;
        final localId = row['entity_id']?.toString() ?? '';
        final op = row['operation_type'] as String;
        final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        try {
          if (entityType == 'sale' && op == 'CREATE') {
            final body = Map<String, dynamic>.from(payload);
            body['clientTransactionId'] ??= row['client_transaction_id'];
            await client.post('/sales', body: body);
            if ((body['payment_method'] == 'credit' ||
                    body['paymentStatus'] == 'unpaid') &&
                body['customerId'] != null &&
                body['customerId'].toString().isNotEmpty) {
              try {
                final rawItems = (body['items'] as List?) ?? [];
                await client.post('/credit/purchases', body: {
                  'customerId': body['customerId'],
                  'items': rawItems
                      .map((it) => {
                            if (it['productId'] != null)
                              'productId': it['productId'],
                            'name':
                                it['name'] ?? it['product_name'] ?? 'Item',
                            'quantity': it['quantity'] ?? 1,
                            'unitPrice':
                                it['unitPrice'] ?? it['unit_price'] ?? 0.0,
                          })
                      .toList(),
                  'amountPaidNow': body['amountPaidNow'] ?? 0,
                  'notes': 'POS Credit Sale',
                });
              } catch (_) {}
            }
          } else if (entityType == 'credit_purchase' && op == 'CREATE') {
            await client.post('/credit/purchases', body: payload);
          } else if (entityType == 'product') {
            if (op == 'CREATE') {
              final res = await client.post('/products', body: payload);
              await _remapEntityIdIfCreated(
                  db, companyId, 'products', 'product', localId, res);
            } else if (op == 'UPDATE') {
              await client.put('/products/$localId', body: payload);
            } else if (op == 'DELETE') {
              await client.delete('/products/$localId');
            } else {
              throw UnsupportedError('Unsupported product operation: $op');
            }
          } else if (entityType == 'customer') {
            if (op == 'CREATE') {
              final res = await client.post('/customers', body: payload);
              await _remapEntityIdIfCreated(
                  db, companyId, 'customers', 'customer', localId, res);
            } else if (op == 'UPDATE') {
              await client.put('/customers/$localId', body: payload);
            } else if (op == 'DELETE') {
              await client.delete('/customers/$localId');
            } else {
              throw UnsupportedError('Unsupported customer operation: $op');
            }
          } else if (entityType == 'supplier') {
            if (op == 'CREATE') {
              final res = await client.post('/suppliers', body: payload);
              await _remapEntityIdIfCreated(
                  db, companyId, 'suppliers', 'supplier', localId, res);
            } else if (op == 'UPDATE') {
              await client.put('/suppliers/$localId', body: payload);
            } else if (op == 'DELETE') {
              await client.delete('/suppliers/$localId');
            } else {
              throw UnsupportedError('Unsupported supplier operation: $op');
            }
          } else if (entityType == 'employee') {
            if (op == 'CREATE') {
              final res = await client.post('/employees', body: payload);
              await _remapEntityIdIfCreated(
                  db, companyId, 'employees', 'employee', localId, res);
            } else if (op == 'UPDATE') {
              await client.put('/employees/$localId', body: payload);
            } else if (op == 'DELETE') {
              await client.delete('/employees/$localId');
            } else {
              throw UnsupportedError('Unsupported employee operation: $op');
            }
          } else if (entityType == 'salary_payment' && op == 'CREATE') {
            await client.post(
                '/employees/$localId/pay-salary',
                body: payload);
          } else if (entityType == 'employee_attendance' && op == 'CREATE') {
            await client.post('/employees/$localId/attendance',
                body: payload);
          } else if (entityType == 'expense') {
            if (op == 'CREATE') {
              final res = await client.post('/expenses', body: payload);
              await _remapEntityIdIfCreated(
                  db, companyId, 'expenses', 'expense', localId, res);
            } else if (op == 'UPDATE') {
              await client.put('/expenses/$localId', body: payload);
            } else if (op == 'DELETE') {
              await client.delete('/expenses/$localId');
            } else {
              throw UnsupportedError('Unsupported expense operation: $op');
            }
          } else if (entityType == 'invoice') {
            if (op == 'CREATE') {
              // Standalone manual billing invoices created on desktop reside in local SQLite.
              // The backend invoices module provides read-only views derived from sales/orders,
              // and does not have a POST /invoices endpoint. Creating an invoice locally is authoritative.
            } else if (op == 'UPDATE') {
              if (payload['status'] == 'paid') {
                try {
                  await client.put('/invoices/$localId/mark-paid', body: payload);
                } catch (_) {
                  // Best-effort remote update; invoice is already marked paid locally
                }
              }
            }
          } else if (entityType == 'credit_payment' && op == 'CREATE') {
            final body = Map<String, dynamic>.from(payload);
            body['clientId'] ??= row['client_transaction_id'];
            body['clientTransactionId'] ??= row['client_transaction_id'];
            await client.post('/credit/payments', body: body);
          } else if (entityType == 'appointment') {
            final isClinic = payload['isClinic'] == true;
            if (op == 'CREATE') {
              dynamic res;
              if (isClinic && payload['patientId'] != null) {
                res = await client.post('/clinic/appointments', body: {
                  'patientId': payload['patientId'],
                  'scheduledAt':
                      payload['scheduledAt'] ?? payload['appointmentDate'],
                  'notes': payload['notes'] ?? payload['serviceType'],
                });
              } else {
                final aptDate = payload['scheduledAt'] ??
                    payload['appointmentDate'] ??
                    payload['appointment_date'] ??
                    DateTime.now().toIso8601String();
                res = await client.post('/appointments', body: {
                  if (payload['customerId'] != null)
                    'customerId': payload['customerId'],
                  'title': payload['title'] ??
                      payload['customerName'] ??
                      payload['customer_name'] ??
                      'Appointment',
                  'customerName':
                      payload['customerName'] ?? payload['customer_name'],
                  'scheduledAt': aptDate,
                  'appointmentDate': aptDate,
                  if (payload['durationMinutes'] != null)
                    'durationMinutes': payload['durationMinutes'],
                  'notes': payload['notes'] ?? payload['serviceType'],
                });
              }
              await _remapEntityIdIfCreated(
                  db, companyId, 'appointments', 'appointment', localId, res);
            } else if (op == 'UPDATE') {
              final rawStatus = payload['status']?.toString();
              final serverStatus = rawStatus == 'confirmed' ? 'scheduled' : rawStatus;
              if (payload.containsKey('title') ||
                  payload.containsKey('customerName') ||
                  payload.containsKey('customer_name') ||
                  payload.containsKey('appointmentDate') ||
                  payload.containsKey('appointment_date') ||
                  payload.containsKey('scheduledAt')) {
                final aptDate = payload['scheduledAt'] ??
                    payload['appointmentDate'] ??
                    payload['appointment_date'];
                await client.put('/appointments/$localId', body: {
                  if (payload['customerId'] != null)
                    'customerId': payload['customerId'],
                  'title': payload['title'] ??
                      payload['customerName'] ??
                      payload['customer_name'] ??
                      'Appointment',
                  if (aptDate != null) 'scheduledAt': aptDate,
                  if (aptDate != null) 'appointmentDate': aptDate,
                  if (serverStatus != null) 'status': serverStatus,
                  if (payload['notes'] != null) 'notes': payload['notes'],
                });
              } else if (isClinic) {
                await client.patch(
                    '/clinic/appointments/$localId/status',
                    body: {'status': payload['status']});
              } else {
                await client.put('/appointments/$localId/status',
                    body: {'status': serverStatus});
              }
            } else if (op == 'DELETE') {
              if (isClinic) {
                await client.delete('/clinic/appointments/$localId');
              } else {
                await client.put('/appointments/$localId/status',
                    body: {'status': 'cancelled'});
              }
            }
          } else if (entityType == 'clinic_queue_complete' && op == 'CREATE') {
            try {
              await client.patch('/clinic/appointments/$localId/complete',
                  body: payload);
            } catch (_) {
              await client.post('/clinic/queue/$localId/complete',
                  body: payload);
            }
          } else if (entityType == 'clinic_prescription') {
            if (op == 'CREATE') {
              await client.post('/clinic/prescriptions', body: payload);
            } else if (op == 'DELETE') {
              await client.delete('/clinic/prescriptions/$localId');
            }
          } else if (entityType == 'restaurant_table') {
            if (op == 'CREATE') {
              final res = await client.post('/restaurant/tables', body: payload);
              await _remapEntityIdIfCreated(db, companyId,
                  'restaurant_tables', 'restaurant_table', localId, res);
            } else if (op == 'UPDATE') {
              if (payload.containsKey('name') || payload.containsKey('seats')) {
                await client.put('/restaurant/tables/$localId', body: payload);
              } else {
                await client.patch(
                    '/restaurant/tables/$localId/status',
                    body: {'status': payload['status']});
              }
            } else if (op == 'DELETE') {
              await client.delete('/restaurant/tables/$localId');
            }
          } else if (entityType == 'restaurant_menu_item') {
            if (op == 'CREATE') {
              await client.post('/restaurant/menu-items', body: payload);
            } else if (op == 'UPDATE') {
              await client.put('/restaurant/menu-items/$localId', body: payload);
            } else if (op == 'DELETE') {
              await client.delete('/restaurant/menu-items/$localId');
            }
          } else if (entityType == 'restaurant_order') {
            if (op == 'CREATE') {
              final rawItems = (payload['items'] as List?) ?? [];
              final sanitizedItems = rawItems.map((it) {
                final m = Map<String, dynamic>.from(it as Map);
                return <String, dynamic>{
                  if (m['menuItemId'] != null) 'menuItemId': m['menuItemId'],
                  'name': m['name'] ?? 'Order Item',
                  'unitPrice':
                      ((m['unitPrice'] ?? m['price'] ?? 0.0) as num).toDouble(),
                  'quantity': ((m['quantity'] ?? 1) as num).toInt(),
                };
              }).toList();
              final res = await client.post('/restaurant/orders', body: {
                if (payload['tableId'] != null) 'tableId': payload['tableId'],
                if (payload['orderType'] != null)
                  'orderType': payload['orderType'],
                if (payload['notes'] != null) 'notes': payload['notes'],
                'items': sanitizedItems,
              });
              await _remapEntityIdIfCreated(db, companyId,
                  'restaurant_orders', 'restaurant_order', localId, res);
            } else if (op == 'UPDATE') {
              if (payload.containsKey('items')) {
                await client.put('/restaurant/orders/$localId', body: payload);
              } else if (payload.containsKey('status')) {
                await client.patch(
                    '/restaurant/orders/$localId/status',
                    body: {'status': payload['status']});
              } else {
                await client.put('/restaurant/orders/$localId', body: payload);
              }
            }
          } else if (entityType == 'restaurant_payment') {
            if (op == 'CREATE') {
              final orderId = payload['order_id'] ?? payload['orderId'] ?? localId;
              await client.post('/restaurant/orders/$orderId/payments', body: {
                'amount': payload['amount'],
                if (payload['method'] != null) 'method': payload['method'],
                if (payload['note'] != null) 'note': payload['note'],
              });
            }
          } else if (entityType == 'restaurant_inventory_item') {
            if (op == 'CREATE') {
              final res = await client.post('/restaurant/inventory', body: payload);
              await _remapEntityIdIfCreated(db, companyId,
                  'restaurant_inventory_items', 'restaurant_inventory_item', localId, res);
            } else if (op == 'UPDATE') {
              if (payload.containsKey('quantityChange')) {
                await client.post('/restaurant/inventory/$localId/adjust', body: payload);
              } else {
                await client.patch('/restaurant/inventory/$localId', body: payload);
              }
            } else if (op == 'DELETE') {
              await client.delete('/restaurant/inventory/$localId');
            }
          } else if (entityType == 'restaurant_reservation') {
            if (op == 'CREATE') {
              final res = await client.post('/restaurant/reservations', body: payload);
              await _remapEntityIdIfCreated(db, companyId,
                  'restaurant_reservations', 'restaurant_reservation', localId, res);
            } else if (op == 'UPDATE') {
              if (payload.containsKey('status') && payload.length == 1) {
                await client.patch(
                    '/restaurant/reservations/$localId/status',
                    body: {'status': payload['status']});
              } else {
                await client.put('/restaurant/reservations/$localId', body: payload);
              }
            } else if (op == 'DELETE') {
              await client.patch(
                  '/restaurant/reservations/$localId/status',
                  body: {'status': 'cancelled'});
            }
          } else if (entityType == 'enterprise_project') {
            if (op == 'CREATE') {
              final rawStatus = payload['status']?.toString() ?? 'active';
              final validStatus =
                  rawStatus == 'in_progress' ? 'active' : rawStatus;
              final cleanBody = <String, dynamic>{
                'name': payload['name'],
                'status': validStatus,
                if (payload['budget'] != null) 'budget': payload['budget'],
                if (payload['description'] != null ||
                    payload['clientName'] != null ||
                    payload['client_name'] != null)
                  'description': payload['description'] ??
                      'Client: ${payload['clientName'] ?? payload['client_name']}',
                if (payload['dueDate'] != null || payload['deadline'] != null)
                  'dueDate': payload['dueDate'] ?? payload['deadline'],
                if (payload['startDate'] != null)
                  'startDate': payload['startDate'],
                if (payload['customerId'] != null)
                  'customerId': payload['customerId'],
              };
              final res =
                  await client.post('/enterprise/projects', body: cleanBody);
              await _remapEntityIdIfCreated(db, companyId,
                  'enterprise_projects', 'enterprise_project', localId, res);
            } else if (op == 'UPDATE') {
              final rawStatus = payload['status']?.toString() ?? 'active';
              final validStatus =
                  rawStatus == 'in_progress' ? 'active' : rawStatus;
              await client.patch(
                  '/enterprise/projects/$localId/status',
                  body: {'status': validStatus});
            } else if (op == 'DELETE') {
              await client.patch(
                  '/enterprise/projects/$localId/status',
                  body: {'status': 'cancelled'});
            }
          } else if (entityType == 'supplier_purchase' && op == 'CREATE') {
            final supplierId = payload['supplierId'] ?? payload['supplier_id'];
            final body = Map<String, dynamic>.from(payload);
            body['clientTransactionId'] ??= row['client_transaction_id'];
            final res = await client.post('/suppliers/$supplierId/purchases', body: body);
            await _remapEntityIdIfCreated(db, companyId, 'supplier_purchases', 'supplier_purchase', localId, res);
          } else if (entityType == 'supplier_payment' && op == 'CREATE') {
            final supplierId = payload['supplierId'] ?? payload['supplier_id'];
            final body = Map<String, dynamic>.from(payload);
            body['clientId'] ??= row['client_transaction_id'];
            final res = await client.post('/suppliers/$supplierId/payments', body: body);
            await _remapEntityIdIfCreated(db, companyId, 'supplier_payments', 'supplier_payment', localId, res);
          } else {
            throw UnsupportedError(
                'Unsupported sync operation: entityType=$entityType, op=$op');
          }

          // Mark successfully synced
          await db.update(
            'sync_queue',
            {
              'status': 'synced',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } catch (e) {
          final retries = (row['retry_count'] as num?)?.toInt() ?? 0;
          final errStr = e.toString();

          final isNetworkOrOffline = (e is ApiException && e.statusCode == 0) ||
              errStr.contains('SocketException') ||
              errStr.contains('TimeoutException') ||
              errStr.contains('Network connection error') ||
              errStr.contains('HandshakeException');
          final isAuthError = (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) ||
              errStr.contains('(401)') ||
              errStr.contains('(403)');

          if (isNetworkOrOffline || isAuthError) {
            // Preserve pending status, do NOT consume retries during network outages or unauthenticated state
            await db.update(
              'sync_queue',
              {
                'last_error': errStr,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            // Abort further attempts in this sync loop since network or auth is unavailable
            break;
          }

          final isPermanentValidationError = errStr.contains('(400)') ||
              errStr.contains('(422)') ||
              errStr.contains('VALIDATION_ERROR') ||
              e is UnsupportedError;
          await db.update(
            'sync_queue',
            {
              'retry_count': retries + 1,
              'status': (isPermanentValidationError || retries >= 5)
                  ? 'failed'
                  : 'pending',
              'last_error': errStr,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }

      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          lastSyncedAt: DateTime.now(),
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isSyncing: false, lastError: e.toString());
      }
    } finally {
      _isLocked = false;
      await refreshQueueCounts();
    }
  }

  Future<void> retryFailedOperations() async {
    final companyId = _companyId;
    if (companyId == null) return;
    final db = await ModiriDesktopDatabase.instance.database;
    await db.rawUpdate(
      "UPDATE sync_queue SET status = 'pending', retry_count = 0 WHERE company_id = ? AND status = 'failed'",
      [companyId],
    );
    await refreshQueueCounts();
    await syncPending();
  }

  Future<void> _remapEntityIdIfCreated(
    Database db,
    String companyId,
    String tableName,
    String entityType,
    String localId,
    dynamic res,
  ) async {
    try {
      String? serverId;
      if (res is Map) {
        if (res['data'] is Map && res['data']['id'] != null) {
          serverId = res['data']['id'].toString();
        } else if (res['id'] != null) {
          serverId = res['id'].toString();
        } else if (res['data'] is Map && res['data']['_id'] != null) {
          serverId = res['data']['_id'].toString();
        }
      }

      if (serverId == null || serverId.isEmpty || serverId == localId) {
        return;
      }

      // Remap the primary table
      await db.rawUpdate(
        'UPDATE $tableName SET id = ?, synced = 1 WHERE id = ? AND company_id = ?',
        [serverId, localId, companyId],
      );

      // Remap any subsequent pending sync operations queued for this local entity
      await db.rawUpdate(
        'UPDATE sync_queue SET entity_id = ? WHERE entity_type = ? AND entity_id = ? AND status = ?',
        [serverId, entityType, localId, 'pending'],
      );

      // Cascading foreign keys for local relationships
      if (entityType == 'customer') {
        await db.rawUpdate(
          'UPDATE appointments SET customer_id = ? WHERE customer_id = ? AND company_id = ?',
          [serverId, localId, companyId],
        );
        await db.rawUpdate(
          'UPDATE sales SET customer_id = ? WHERE customer_id = ? AND company_id = ?',
          [serverId, localId, companyId],
        );
        await db.rawUpdate(
          'UPDATE invoices SET customer_id = ? WHERE customer_id = ? AND company_id = ?',
          [serverId, localId, companyId],
        );
      } else if (entityType == 'restaurant_table') {
        await db.rawUpdate(
          'UPDATE restaurant_orders SET table_id = ? WHERE table_id = ? AND company_id = ?',
          [serverId, localId, companyId],
        );
      }
    } catch (_) {
      // Best-effort local ID remapping; ignore if record was already migrated
    }
  }
}

final desktopSyncServiceProvider =
    StateNotifierProvider<DesktopSyncService, DesktopSyncState>((ref) {
  return DesktopSyncService(ref);
});
