import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';

class Customer {
  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.balanceDue = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double balanceDue;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        balanceDue: double.tryParse((json['balance_due'] ?? json['balanceDue'] ?? 0).toString()) ?? 0.0,
      );
}

class CustomersRepository extends StateNotifier<AsyncValue<List<Customer>>> {
  CustomersRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> load({String? query}) async {
    // 1. Read from local SQLite first (always sets data, even if empty)
    try {
      final local = await _fetchFromLocal(query: query);
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {}

    // 2. Fetch from backend if online
    final status = _ref.read(connectionStatusProvider);
    if (status != ConnectionStatus.online) {
      return;
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/customers');
      final serverCustomers = (response['data'] as List)
          .map((j) => Customer.fromJson(j as Map<String, dynamic>))
          .toList();

      await _upsertToLocal(serverCustomers);
      final fresh = await _fetchFromLocal(query: query);
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current != null) {
        return; // Keep existing local customers smoothly
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Customer>> _fetchFromLocal({String? query}) async {
    final companyId = _companyId;
    // TENANT ISOLATION: return nothing when no account is active.
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    List<Map<String, dynamic>> rows;
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      rows = await db.query(
        'customers',
        where: 'company_id = ? AND (name LIKE ? OR phone LIKE ?)',
        whereArgs: [companyId, q, q],
        orderBy: 'name ASC',
      );
    } else {
      rows = await db.query(
        'customers',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
    }

    return rows
        .map((r) => Customer(
              id: r['id'] as String,
              name: r['name'] as String,
              phone: r['phone'] as String?,
              address: r['address'] as String?,
              balanceDue: (r['balance_due'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();
  }

  Future<void> _upsertToLocal(List<Customer> customers) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final c in customers) {
      // Keep un-synced local changes if any exist
      final unSynced = await db.query(
        'customers',
        where: 'id = ? AND company_id = ? AND synced = 0',
        whereArgs: [c.id, companyId],
      );
      if (unSynced.isNotEmpty) continue;

      batch.insert(
        'customers',
        {
          'id': c.id,
          'company_id': companyId,
          'name': c.name,
          'phone': c.phone,
          'address': c.address,
          'balance_due': c.balanceDue,
          'created_at': DateTime.now().toIso8601String(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> addCustomer(String name, String? phone, {String? address}) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final newId = const Uuid().v4();
    final clientId = const Uuid().v4();
    final db = await AppDatabase.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.insert('customers', {
      'id': newId,
      'client_id': clientId,
      'company_id': companyId,
      'name': name,
      'phone': phone,
      'address': address,
      'balance_due': 0.0,
      'created_at': nowIso,
      'synced': 0,
    });

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    // Queue for sync
    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: clientId,
          entityType: 'customer',
          entityId: newId,
          operationType: 'CREATE',
          payload: {
            'name': name,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            if (address != null && address.isNotEmpty) 'address': address,
          },
        );
  }

  Future<void> updateCustomer(String id, String name, String? phone, {String? address}) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    // Scoped by company_id  -  cannot update another company's customer
    await db.update(
      'customers',
      {
        'name': name,
        'phone': phone,
        'address': address,
        'synced': 0,
      },
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'customer',
          entityId: id,
          operationType: 'UPDATE',
          payload: {
            'name': name,
            if (phone != null) 'phone': phone,
            if (address != null) 'address': address,
          },
        );
  }

  Future<void> deleteCustomer(String id) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    // Scoped by company_id  -  cannot read or delete another company's customer
    final row = await db.query(
      'customers',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );
    if (row.isNotEmpty) {
      final balance = (row.first['balance_due'] as num?)?.toDouble() ?? 0.0;
      if (balance > 0) {
        throw ApiException(
          statusCode: 400,
          message: 'Cannot delete customer with unpaid debt ($balance DZD)',
          code: 'CUSTOMER_HAS_DEBT',
        );
      }
    }

    await db.delete(
      'customers',
      where: 'id = ? AND company_id = ?',
      whereArgs: [id, companyId],
    );

    final fresh = await _fetchFromLocal();
    state = AsyncValue.data(fresh);

    await _ref.read(syncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'customer',
          entityId: id,
          operationType: 'DELETE',
          payload: {'id': id},
        );
  }
}

final customersRepositoryProvider =
    StateNotifierProvider<CustomersRepository, AsyncValue<List<Customer>>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return CustomersRepository(ref);
  },
);
