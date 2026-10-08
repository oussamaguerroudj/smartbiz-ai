import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';

/// Appointments  -  Spec Ch. 18.
/// Real Offline-First implementation backed by local SQLite & Sync Queue.
class Appointment {
  Appointment({
    required this.id,
    required this.scheduledAt,
    required this.status,
    this.customerName,
    this.title,
    this.notes,
    this.tableId,
    this.tableName,
  });

  final String id;
  final DateTime scheduledAt;
  final String status; // scheduled | completed | cancelled | no_show
  final String? customerName;
  final String? title;
  final String? notes;
  final String? tableId;
  final String? tableName;

  String get displayName => customerName ?? title ?? 'Appointment';

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        status: json['status'] as String,
        customerName: json['customer_name'] as String?,
        title: json['title'] as String?,
        notes: json['notes'] as String?,
        tableId: json['table_id'] as String? ?? json['tableId'] as String?,
        tableName: json['table_name'] as String? ?? json['tableName'] as String?,
      );

  factory Appointment.fromMap(Map<String, dynamic> map) => Appointment(
        id: map['id'] as String,
        scheduledAt: DateTime.parse(map['scheduled_at'] as String),
        status: map['status'] as String,
        customerName: map['customer_name'] as String?,
        title: map['title'] as String?,
        notes: map['notes'] as String?,
        tableId: map['table_id'] as String?,
        tableName: map['table_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'scheduled_at': scheduledAt.toIso8601String(),
        'status': status,
        'customer_name': customerName,
        'title': title,
        'notes': notes,
        'table_id': tableId,
        'table_name': tableName,
      };
}

class AppointmentsRepository extends StateNotifier<AsyncValue<List<Appointment>>> {
  AppointmentsRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<List<Appointment>> _fetchFromLocal({String? query}) async {
    final companyId = _companyId;
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    String whereClause = 'company_id = ?';
    List<dynamic> whereArgs = [companyId];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      whereClause += ' AND (customer_name LIKE ? OR title LIKE ? OR notes LIKE ?)';
      whereArgs.addAll([q, q, q]);
    }

    final rows = await db.query(
      'appointments',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'scheduled_at ASC',
    );

    return rows.map((r) => Appointment.fromMap(r)).toList();
  }

  Future<void> load({String? query}) async {
    // 1. Instant local read
    final local = await _fetchFromLocal(query: query);
    if (!mounted) return;
    state = AsyncValue.data(local);

    // 2. Fetch from network in background if online
    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (!isOnline) return;

    final companyId = _companyId;
    if (companyId == null) return;

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/appointments');
      final appointments = (response['data'] as List)
          .map((json) => Appointment.fromJson(json as Map<String, dynamic>))
          .toList();

      final db = await AppDatabase.instance.database;
      final batch = db.batch();
      for (final a in appointments) {
        batch.insert(
          'appointments',
          {
            'id': a.id,
            'client_id': a.id,
            'company_id': companyId,
            'customer_name': a.customerName,
            'title': a.title ?? a.customerName,
            'notes': a.notes,
            'scheduled_at': a.scheduledAt.toIso8601String(),
            'status': a.status,
            'table_id': a.tableId,
            'table_name': a.tableName,
            'created_at': DateTime.now().toIso8601String(),
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      if (!mounted) return;
      final fresh = await _fetchFromLocal(query: query);
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (_) {
      // Offline/server error: remain on cached local data without crashing
    }
  }

  Future<void> search(String query) async {
    final results = await _fetchFromLocal(query: query);
    if (!mounted) return;
    state = AsyncValue.data(results);
  }

  Future<void> addAppointment({
    required String customerName,
    required DateTime scheduledAt,
    String? notes,
    String? tableId,
    String? tableName,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final appointmentId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final db = await AppDatabase.instance.database;

    await db.insert('appointments', {
      'id': appointmentId,
      'client_id': appointmentId,
      'company_id': companyId,
      'customer_name': customerName,
      'title': customerName,
      'notes': notes,
      'scheduled_at': scheduledAt.toIso8601String(),
      'status': 'scheduled',
      'reminder_enabled': 1,
      'table_id': tableId,
      'table_name': tableName,
      'created_at': nowIso,
      'synced': 0,
    });

    final payload = {
      'title': customerName,
      'scheduledAt': scheduledAt.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (tableId != null) 'tableId': tableId,
    };

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: appointmentId,
          entityType: 'appointment',
          entityId: appointmentId,
          operationType: 'CREATE',
          payload: payload,
        );

    final fresh = await _fetchFromLocal();
    if (!mounted) return;
    state = AsyncValue.data(fresh);

    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
  }

  Future<void> updateAppointment({
    required String id,
    String? customerName,
    DateTime? scheduledAt,
    String? notes,
    String? status,
    String? tableId,
    String? tableName,
    bool clearTable = false,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final Map<String, dynamic> updateValues = {
      'synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (customerName != null) {
      updateValues['customer_name'] = customerName;
      updateValues['title'] = customerName;
    }
    if (scheduledAt != null) updateValues['scheduled_at'] = scheduledAt.toIso8601String();
    if (notes != null) updateValues['notes'] = notes;
    if (status != null) updateValues['status'] = status;
    if (clearTable) {
      updateValues['table_id'] = null;
      updateValues['table_name'] = null;
    } else if (tableId != null) {
      updateValues['table_id'] = tableId;
      updateValues['table_name'] = tableName;
    }

    final rowsAffected = await db.update(
      'appointments',
      updateValues,
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
    if (rowsAffected == 0) return;

    final payload = {
      'id': id,
      if (customerName != null) 'title': customerName,
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (clearTable) 'tableId': null else if (tableId != null) 'tableId': tableId,
    };

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'appointment',
          entityId: id,
          operationType: 'UPDATE',
          payload: payload,
        );

    final fresh = await _fetchFromLocal();
    if (!mounted) return;
    state = AsyncValue.data(fresh);

    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
  }

  Future<void> updateStatus(String id, String status) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final rowsAffected = await db.update(
      'appointments',
      {
        'status': status,
        'synced': 0,
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
    if (rowsAffected == 0) return;

    final payload = {
      'id': id,
      'status': status,
    };

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'appointment',
          entityId: id,
          operationType: 'UPDATE_STATUS',
          payload: payload,
        );

    final fresh = await _fetchFromLocal();
    if (!mounted) return;
    state = AsyncValue.data(fresh);

    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());
  }
}

final appointmentsRepositoryProvider =
    StateNotifierProvider.autoDispose<AppointmentsRepository, AsyncValue<List<Appointment>>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return AppointmentsRepository(ref);
  },
);
