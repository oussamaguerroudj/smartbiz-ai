import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../features/products/data/products_repository.dart';
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
  DesktopSyncService(this._ref, {Database? customDb})
      : _customDb = customDb,
        super(const DesktopSyncState()) {
    _init();
  }

  static bool enablePeriodicTimer = true;
  static bool enableStartupSync = true;

  final Ref _ref;
  final Database? _customDb;
  bool _isLocked = false;
  bool _isPulling = false;
  Timer? _pollingTimer;

  Future<Database> _getDb([Database? customDb]) async {
    return customDb ?? _customDb ?? await ModiriDesktopDatabase.instance.database;
  }

  String? get _companyId => _ref.read(sessionProvider).companyId;

  void _init() {
    refreshQueueCounts();
    final companyId = _companyId;
    if (enableStartupSync && companyId != null && !Platform.environment.containsKey('FLUTTER_TEST')) {
      Future.microtask(() async {
        if (!mounted) return;
        await syncPending();
        await pullInitialData();
      });
    }

    if (enablePeriodicTimer && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_companyId != null) {
          if (state.pendingCount > 0) {
            syncPending();
          }
          pullInitialData();
        }
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshQueueCounts([Database? customDb]) async {
    final companyId = _companyId;
    if (companyId == null) {
      if (mounted) state = state.copyWith(pendingCount: 0, syncedCount: 0, failedCount: 0);
      return;
    }

    try {
      final db = await _getDb(customDb);
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

  /// Downloads authoritative backend data into local SQLite so the desktop application
  /// displays the exact same data and metrics as the mobile app.
  Future<void> pullInitialData({Database? customDb}) async {
    final session = _ref.read(sessionProvider);
    if (!session.isLoggedIn) return;

    final companyId = _companyId;
    if (companyId == null || companyId.isEmpty) return;

    if (_isPulling) return;
    _isPulling = true;
    if (mounted) state = state.copyWith(isSyncing: true);

    try {
      final client = _ref.read(apiClientProvider);
      final db = await _getDb(customDb);

      // 1. Company profile info
      try {
        final res = await client.get('/companies/me');
        if (res is Map && res['data'] is Map) {
          final c = Map<String, dynamic>.from(res['data'] as Map);
          final serverBusinessType = c['businessType']?.toString();
          if (serverBusinessType != null &&
              serverBusinessType.isNotEmpty &&
              serverBusinessType != session.businessType) {
            await _ref.read(sessionProvider.notifier).updateBusinessType(serverBusinessType);
          }
        }
      } catch (_) {}

      // 2. Products
      try {
        final res = await client.get('/products');
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'product' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final p = Map<String, dynamic>.from(item as Map);
            final id = p['id']?.toString() ?? '';
            if (id.isEmpty || pendingIds.contains(id)) continue;

            final sellingPrice = (p['selling_price'] ?? p['sellingPrice'] ?? p['price'] ?? 0.0 as num).toDouble();
            final purchasePrice = (p['purchase_price'] ?? p['purchasePrice'] ?? p['cost_price'] ?? p['costPrice'] ?? 0.0 as num).toDouble();
            final costPrice = (p['cost_price'] ?? p['costPrice'] ?? purchasePrice as num).toDouble();
            final qty = (p['stock_quantity'] ?? p['stockQuantity'] ?? p['quantity'] ?? 0 as num).toInt();
            final minStock = (p['minimum_stock'] ?? p['minimumStock'] ?? 5 as num).toInt();

            batch.insert(
              'products',
              {
                'id': id,
                'company_id': companyId,
                'name': p['name']?.toString() ?? 'Product',
                'price': sellingPrice,
                'cost_price': costPrice,
                'purchase_price': purchasePrice,
                'stock_quantity': qty,
                'minimum_stock': minStock,
                'barcode': p['barcode']?.toString(),
                'category': p['category']?.toString(),
                'expiration_date': p['expiration_date']?.toString() ?? p['expirationDate']?.toString(),
                'size': p['size']?.toString(),
                'color': p['color']?.toString(),
                'brand': p['brand']?.toString(),
                'created_at': p['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'updated_at': p['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
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
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'customer' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final c = Map<String, dynamic>.from(item as Map);
            final id = c['id']?.toString() ?? '';
            if (id.isEmpty || pendingIds.contains(id)) continue;

            final bal = (c['credit_balance'] ?? c['creditBalance'] ?? c['balance_due'] ?? c['balanceDue'] ?? 0.0 as num).toDouble();
            batch.insert(
              'customers',
              {
                'id': id,
                'company_id': companyId,
                'name': c['name']?.toString() ?? 'Customer',
                'phone': c['phone']?.toString(),
                'credit_balance': bal,
                'notes': c['notes']?.toString() ?? c['address']?.toString(),
                'created_at': c['created_at']?.toString() ?? DateTime.now().toIso8601String(),
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
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'employee' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final e = Map<String, dynamic>.from(item as Map);
            final id = e['id']?.toString() ?? '';
            if (id.isEmpty || pendingIds.contains(id)) continue;

            batch.insert(
              'employees',
              {
                'id': id,
                'company_id': companyId,
                'name': e['name']?.toString() ?? 'Employee',
                'position': e['position']?.toString() ?? 'Staff',
                'base_salary': (e['base_salary'] ?? e['baseSalary'] ?? 0.0 as num).toDouble(),
                'phone': e['phone']?.toString(),
                'created_at': e['created_at']?.toString() ?? DateTime.now().toIso8601String(),
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
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'appointment' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final a = Map<String, dynamic>.from(item as Map);
            final id = a['id']?.toString() ?? '';
            if (id.isEmpty || pendingIds.contains(id)) continue;

            final aptDate = (a['appointment_date'] ?? a['appointmentDate'] ?? a['scheduled_at'] ?? a['scheduledAt'] ?? DateTime.now().toIso8601String()).toString();
            batch.insert(
              'appointments',
              {
                'id': id,
                'company_id': companyId,
                'customer_name': a['customer_name'] ?? a['customerName'] ?? 'Client',
                'service_type': a['service_type'] ?? a['serviceType'] ?? a['title'] ?? 'General',
                'appointment_date': aptDate,
                'status': a['status']?.toString() ?? 'confirmed',
                'notes': a['notes']?.toString(),
                'created_at': a['created_at']?.toString() ?? DateTime.now().toIso8601String(),
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
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'supplier' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final s = Map<String, dynamic>.from(item as Map);
            final id = s['id']?.toString() ?? '';
            if (id.isEmpty || pendingIds.contains(id)) continue;

            batch.insert(
              'suppliers',
              {
                'id': id,
                'company_id': companyId,
                'name': s['name']?.toString() ?? 'Supplier',
                'phone': s['phone']?.toString(),
                'address': s['address']?.toString(),
                'products_supplied': (s['products_supplied'] ?? s['productsSupplied'] ?? 0 as num).toInt(),
                'created_at': s['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 7. Supplier Purchases & Purchase Items
      try {
        final res = await client.get('/suppliers/purchases');
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'supplier_purchase' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final sp = Map<String, dynamic>.from(item as Map);
            final spId = sp['id']?.toString() ?? '';
            if (spId.isEmpty || pendingIds.contains(spId)) continue;

            final totalAmt = (sp['total_amount'] as num?)?.toDouble() ?? (sp['totalAmount'] as num?)?.toDouble() ?? 0.0;
            final paidAmt = (sp['amount_paid'] as num?)?.toDouble() ?? (sp['amountPaid'] as num?)?.toDouble() ?? 0.0;
            final balance = (sp['outstanding_balance'] as num?)?.toDouble() ?? (sp['outstandingBalance'] as num?)?.toDouble() ?? (totalAmt - paidAmt);

            batch.insert(
              'supplier_purchases',
              {
                'id': spId,
                'company_id': companyId,
                'supplier_id': sp['supplier_id']?.toString() ?? sp['supplierId']?.toString() ?? '',
                'invoice_number': sp['invoice_number']?.toString() ?? sp['invoiceNumber']?.toString(),
                'purchase_date': (sp['purchase_date'] ?? sp['purchaseDate'] ?? sp['created_at'] ?? DateTime.now().toIso8601String()).toString(),
                'total_amount': totalAmt,
                'amount_paid': paidAmt,
                'outstanding_balance': balance,
                'payment_status': sp['payment_status']?.toString() ?? sp['paymentStatus']?.toString() ?? 'unpaid',
                'notes': sp['notes']?.toString(),
                'client_transaction_id': sp['client_transaction_id']?.toString() ?? sp['clientTransactionId']?.toString(),
                'created_at': sp['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            if (sp['items'] is List) {
              for (final it in sp['items']) {
                final itMap = Map<String, dynamic>.from(it as Map);
                final itId = itMap['id']?.toString() ?? const Uuid().v4();
                final unitCost = (itMap['unit_cost'] as num?)?.toDouble() ?? (itMap['unitCost'] as num?)?.toDouble() ?? 0.0;
                final qty = (itMap['quantity'] as num?)?.toDouble() ?? 1.0;
                final lineTotal = (itMap['line_total'] as num?)?.toDouble() ?? (itMap['lineTotal'] as num?)?.toDouble() ?? (unitCost * qty);

                batch.insert(
                  'supplier_purchase_items',
                  {
                    'id': itId,
                    'company_id': companyId,
                    'purchase_id': spId,
                    'product_id': itMap['product_id']?.toString() ?? itMap['productId']?.toString(),
                    'product_name': itMap['product_name']?.toString() ?? itMap['productName']?.toString() ?? 'Item',
                    'quantity': qty,
                    'unit_cost': unitCost,
                    'line_total': lineTotal,
                    'created_at': sp['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 8. Supplier Payments
      try {
        final res = await client.get('/suppliers/payments');
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'supplier_payment' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final sp = Map<String, dynamic>.from(item as Map);
            final spId = sp['id']?.toString() ?? '';
            if (spId.isEmpty || pendingIds.contains(spId)) continue;

            batch.insert(
              'supplier_payments',
              {
                'id': spId,
                'company_id': companyId,
                'supplier_id': sp['supplier_id']?.toString() ?? sp['supplierId']?.toString() ?? '',
                'purchase_id': sp['purchase_id']?.toString() ?? sp['purchaseId']?.toString(),
                'amount': (sp['amount'] as num?)?.toDouble() ?? 0.0,
                'payment_date': (sp['payment_date'] ?? sp['paymentDate'] ?? sp['created_at'] ?? DateTime.now().toIso8601String()).toString(),
                'payment_method': sp['payment_method']?.toString() ?? sp['paymentMethod']?.toString() ?? 'cash',
                'reference': sp['reference']?.toString(),
                'notes': sp['notes']?.toString(),
                'client_id': sp['client_id']?.toString() ?? sp['clientId']?.toString(),
                'created_at': sp['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 9. Sales & Sale items (Authoritative Revenue and Profit!)
      try {
        final res = await client.get('/sales');
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final existingItemSaleIds = (await db.rawQuery(
            'SELECT DISTINCT sale_id FROM sale_items WHERE company_id = ?',
            [companyId],
          )).map((r) => r['sale_id'] as String).toSet();

          final unsyncedSaleRows = await db.query(
            'sales',
            columns: ['id'],
            where: 'company_id = ? AND synced = 0',
            whereArgs: [companyId],
          );
          final unsyncedSaleIds = unsyncedSaleRows.map((r) => r['id'] as String).toSet();

          final batch = db.batch();
          for (final item in list) {
            final s = Map<String, dynamic>.from(item as Map);
            final saleId = s['id']?.toString() ?? '';
            if (saleId.isEmpty || unsyncedSaleIds.contains(saleId)) continue;

            final total = (s['total'] ?? s['total_amount'] ?? 0.0 as num).toDouble();
            final subtotal = (s['subtotal'] ?? total as num).toDouble();
            final discount = (s['discount'] ?? 0.0 as num).toDouble();
            final paymentStatus = s['payment_status'] ?? s['paymentStatus'] ?? 'paid';
            final paymentMethod = s['payment_method'] ?? s['paymentMethod'] ?? 'cash';
            final soldAt = (s['sold_at'] ?? s['soldAt'] ?? s['created_at'] ?? DateTime.now().toIso8601String()).toString();
            final customerName = s['customer_name'] ?? s['customerName'];
            final margin = (s['margin'] as num?)?.toDouble();

            batch.insert(
              'sales',
              {
                'id': saleId,
                'company_id': companyId,
                'customer_id': s['customer_id'] ?? s['customerId'],
                'customer_name': customerName,
                'invoice_number': s['invoice_number'] ?? s['invoiceNumber'],
                'subtotal': subtotal,
                'discount': discount,
                'total': total,
                'payment_status': paymentStatus,
                'payment_method': paymentMethod,
                'sold_at': soldAt,
                'created_at': soldAt,
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            if (s['items'] is List && (s['items'] as List).isNotEmpty) {
              for (final it in s['items']) {
                final itMap = Map<String, dynamic>.from(it as Map);
                final itId = itMap['id']?.toString() ?? const Uuid().v4();
                final pId = itMap['product_id']?.toString() ?? itMap['productId']?.toString() ?? 'unknown';
                final pName = itMap['product_name']?.toString() ?? itMap['productName']?.toString() ?? 'Item';
                final qty = (itMap['quantity'] as num?)?.toInt() ?? 1;
                final uPrice = (itMap['unit_price'] as num?)?.toDouble() ?? (itMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
                final uCost = (itMap['unit_cost'] as num?)?.toDouble() ?? (itMap['unitCost'] as num?)?.toDouble() ?? 0.0;
                final lineTot = (itMap['line_total'] as num?)?.toDouble() ?? (itMap['lineTotal'] as num?)?.toDouble() ?? (uPrice * qty);
                final lineProf = (itMap['line_profit'] as num?)?.toDouble() ?? (itMap['lineProfit'] as num?)?.toDouble() ?? (lineTot - (uCost * qty));

                batch.insert(
                  'sale_items',
                  {
                    'id': itId,
                    'company_id': companyId,
                    'sale_id': saleId,
                    'product_id': pId,
                    'product_name': pName,
                    'quantity': qty,
                    'unit_price': uPrice,
                    'unit_cost': uCost,
                    'line_total': lineTot,
                    'line_profit': lineProf,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            } else if (!existingItemSaleIds.contains(saleId)) {
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

      // 10. Invoices
      try {
        final res = await client.get('/invoices');
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'invoice' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final inv = Map<String, dynamic>.from(item as Map);
            final id = inv['id']?.toString() ?? '';
            if (id.isEmpty || pendingIds.contains(id)) continue;

            final total = (inv['total'] as num?)?.toDouble() ?? 0.0;
            final status = inv['status']?.toString() ?? 'paid';
            final paidAmt = (inv['paid_amount'] ?? inv['paidAmount'] ?? (status == 'paid' ? total : 0.0) as num).toDouble();
            final remAmt = (inv['remaining_amount'] ?? inv['remainingAmount'] ?? (status == 'unpaid' ? total : (total - paidAmt).clamp(0.0, double.infinity)) as num).toDouble();
            final soldAt = (inv['sold_at'] ?? inv['soldAt'] ?? inv['created_at'] ?? DateTime.now().toIso8601String()).toString();

            batch.insert(
              'invoices',
              {
                'id': id,
                'company_id': companyId,
                'sale_id': inv['sale_id'] ?? inv['saleId'],
                'invoice_number': inv['invoice_number'] ?? inv['invoiceNumber'] ?? 'INV-$id',
                'customer_name': inv['customer_name'] ?? inv['customerName'],
                'total': total,
                'paid_amount': paidAmt,
                'remaining_amount': remAmt,
                'status': status,
                'sold_at': soldAt,
                'created_at': soldAt,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 11. Expenses
      try {
        final res = await client.get('/expenses');
        final list = res is Map ? (res['data'] as List? ?? res['expenses'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final pendingRows = await db.query(
            'sync_queue',
            columns: ['entity_id'],
            where: "company_id = ? AND entity_type = 'expense' AND status = 'pending'",
            whereArgs: [companyId],
          );
          final pendingIds = pendingRows.map((r) => r['entity_id']?.toString() ?? '').toSet();

          final batch = db.batch();
          for (final item in list) {
            final exp = Map<String, dynamic>.from(item as Map);
            final id = exp['id']?.toString() ?? '';
            if (id.isEmpty || pendingIds.contains(id)) continue;

            final dateStr = (exp['expense_date'] ?? exp['expenseDate'] ?? exp['date'] ?? exp['created_at'] ?? DateTime.now().toIso8601String()).toString().substring(0, 10);
            final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;

            batch.insert(
              'expenses',
              {
                'id': id,
                'company_id': companyId,
                'category': exp['category']?.toString() ?? 'other',
                'amount': amount,
                'description': exp['description']?.toString(),
                'date': dateStr,
                'created_at': exp['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 12. Credit Transactions & Debts
      try {
        final resPay = await client.get('/credit/payments');
        final payList = resPay is Map ? (resPay['data'] as List? ?? []) : (resPay as List? ?? []);
        final resPur = await client.get('/credit/purchases');
        final purList = resPur is Map ? (resPur['data'] as List? ?? []) : (resPur as List? ?? []);

        final batch = db.batch();
        for (final p in payList) {
          final map = Map<String, dynamic>.from(p as Map);
          final id = map['id']?.toString() ?? '';
          final custId = map['customer_id']?.toString() ?? map['customerId']?.toString() ?? '';
          if (id.isEmpty || custId.isEmpty) continue;
          batch.insert(
            'customer_transactions',
            {
              'id': 'pay-$id',
              'company_id': companyId,
              'customer_id': custId,
              'type': 'payment',
              'amount': (map['amount'] as num?)?.toDouble() ?? 0.0,
              'balance_after': (map['balance_after'] as num?)?.toDouble() ?? 0.0,
              'description': map['note']?.toString() ?? 'Credit Payment',
              'created_at': (map['paid_at'] ?? map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final p in purList) {
          final map = Map<String, dynamic>.from(p as Map);
          final id = map['id']?.toString() ?? '';
          final custId = map['customer_id']?.toString() ?? map['customerId']?.toString() ?? '';
          if (id.isEmpty || custId.isEmpty) continue;
          batch.insert(
            'customer_transactions',
            {
              'id': 'pur-$id',
              'company_id': companyId,
              'customer_id': custId,
              'type': 'purchase',
              'amount': (map['subtotal'] as num?)?.toDouble() ?? (map['total'] as num?)?.toDouble() ?? 0.0,
              'balance_after': (map['remaining_credit'] as num?)?.toDouble() ?? 0.0,
              'description': map['note']?.toString() ?? 'Credit Purchase',
              'created_at': (map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      } catch (_) {}

      // 13. Restaurant Vertical (tables, orders, reservations, raw materials)
      try {
        final resTables = await client.get('/restaurant/tables');
        final tablesList = resTables is Map ? (resTables['data'] as List? ?? []) : (resTables as List? ?? []);
        if (tablesList.isNotEmpty) {
          final batch = db.batch();
          for (final t in tablesList) {
            final tMap = Map<String, dynamic>.from(t as Map);
            final id = tMap['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            batch.insert(
              'restaurant_tables',
              {
                'id': id,
                'company_id': companyId,
                'name': tMap['name']?.toString() ?? tMap['table_number']?.toString() ?? tMap['tableNumber']?.toString() ?? 'Table',
                'seats': (tMap['seats'] ?? tMap['capacity'] ?? 4 as num).toInt(),
                'status': tMap['status']?.toString() ?? 'available',
                'created_at': tMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }

        final resOrders = await client.get('/restaurant/orders');
        final ordersList = resOrders is Map ? (resOrders['data'] as List? ?? []) : (resOrders as List? ?? []);
        if (ordersList.isNotEmpty) {
          final batch = db.batch();
          for (final o in ordersList) {
            final oMap = Map<String, dynamic>.from(o as Map);
            final id = oMap['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            batch.insert(
              'restaurant_orders',
              {
                'id': id,
                'company_id': companyId,
                'table_name': oMap['table_name'] ?? oMap['tableName'] ?? 'Walk-in',
                'items_json': jsonEncode(oMap['items'] ?? []),
                'status': oMap['status']?.toString() ?? 'preparing',
                'total': (oMap['total'] as num?)?.toDouble() ?? 0.0,
                'notes': oMap['notes']?.toString(),
                'created_at': oMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }

        final resRes = await client.get('/restaurant/reservations');
        final resList = resRes is Map ? (resRes['data'] as List? ?? []) : (resRes as List? ?? []);
        if (resList.isNotEmpty) {
          final batch = db.batch();
          for (final r in resList) {
            final rMap = Map<String, dynamic>.from(r as Map);
            final id = rMap['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            batch.insert(
              'restaurant_reservations',
              {
                'id': id,
                'company_id': companyId,
                'customer_name': rMap['customer_name'] ?? rMap['customerName'] ?? 'Guest',
                'phone': rMap['phone']?.toString(),
                'party_size': (rMap['party_size'] ?? rMap['partySize'] ?? 2 as num).toInt(),
                'table_id': rMap['table_id']?.toString() ?? rMap['tableId']?.toString(),
                'table_name': rMap['table_name']?.toString() ?? rMap['tableName']?.toString(),
                'reserved_at': (rMap['reserved_at'] ?? rMap['reservation_time'] ?? rMap['created_at'] ?? DateTime.now().toIso8601String()).toString(),
                'status': rMap['status']?.toString() ?? 'pending',
                'notes': rMap['notes']?.toString(),
                'created_at': rMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }

        final resInv = await client.get('/restaurant/inventory');
        final invList = resInv is Map ? (resInv['data'] as List? ?? []) : (resInv as List? ?? []);
        if (invList.isNotEmpty) {
          final batch = db.batch();
          for (final r in invList) {
            final rMap = Map<String, dynamic>.from(r as Map);
            final id = rMap['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            batch.insert(
              'restaurant_inventory_items',
              {
                'id': id,
                'company_id': companyId,
                'name': rMap['name']?.toString() ?? 'Item',
                'category': rMap['category']?.toString(),
                'unit': rMap['unit']?.toString() ?? 'unit',
                'quantity': (rMap['quantity'] as num?)?.toDouble() ?? 0.0,
                'minimum_stock': (rMap['minimum_stock'] ?? rMap['minimumStock'] ?? 0.0 as num).toDouble(),
                'purchase_price': (rMap['purchase_price'] ?? rMap['purchasePrice'] ?? 0.0 as num).toDouble(),
                'selling_price': (rMap['selling_price'] as num?)?.toDouble() ?? (rMap['sellingPrice'] as num?)?.toDouble(),
                'supplier': rMap['supplier']?.toString(),
                'expiration_date': rMap['expiration_date']?.toString() ?? rMap['expirationDate']?.toString(),
                'notes': rMap['notes']?.toString(),
                'created_at': rMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // 14. Enterprise Projects
      try {
        final res = await client.get('/enterprise/projects');
        final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
        if (list.isNotEmpty) {
          final batch = db.batch();
          for (final p in list) {
            final pMap = Map<String, dynamic>.from(p as Map);
            final id = pMap['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            batch.insert(
              'enterprise_projects',
              {
                'id': id,
                'company_id': companyId,
                'name': pMap['name']?.toString() ?? 'Project',
                'client_name': pMap['client_name'] ?? pMap['clientName'] ?? 'Client',
                'budget': (pMap['budget'] as num?)?.toDouble() ?? 0.0,
                'status': pMap['status']?.toString() ?? 'in_progress',
                'notes': pMap['notes']?.toString(),
                'created_at': pMap['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      } catch (_) {}

      // Refresh product repository state if initialized
      try {
        _ref.read(productsRepositoryProvider.notifier).load();
      } catch (_) {}

      await refreshQueueCounts();
    } catch (_) {
    } finally {
      _isPulling = false;
      if (mounted) {
        state = state.copyWith(isSyncing: false, lastSyncedAt: DateTime.now());
      }
    }
  }
}

final desktopSyncServiceProvider =
    StateNotifierProvider<DesktopSyncService, DesktopSyncState>((ref) {
  ref.watch(sessionProvider.select((s) => s.companyId));
  return DesktopSyncService(ref);
});
