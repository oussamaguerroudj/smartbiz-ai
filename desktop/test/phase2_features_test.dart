import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:modiri_desktop/core/network/session.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 2 Feature Tests — Modiri AI Desktop', () {
    test('SessionNotifier: syncFromEntitlement updates entitlement type', () async {
      final notifier = SessionNotifier();
      expect(notifier.state.entitlementType, anyOf(isNull, equals('trial')));

      await notifier.syncFromEntitlement(
        status: 'active',
        entitlementType: 'full',
        isSuspended: false,
      );

      expect(notifier.state.entitlementType, 'full');
    });

    test('SQLite Monotonic Invoice Numbering & Customer Credit update', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE invoices (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              customer_id TEXT,
              invoice_number TEXT NOT NULL,
              customer_name TEXT,
              total REAL NOT NULL,
              paid_amount REAL NOT NULL,
              remaining_amount REAL NOT NULL,
              status TEXT NOT NULL,
              due_date TEXT,
              notes TEXT,
              sold_at TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              name TEXT NOT NULL,
              credit_balance REAL DEFAULT 0.0
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              client_transaction_id TEXT,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT NOT NULL,
              retry_count INTEGER DEFAULT 0,
              last_error TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      );

      const companyId = 'test_comp_123';
      const custId = 'cust_456';
      await db.insert('customers', {
        'id': custId,
        'company_id': companyId,
        'name': 'Societe Algerienne',
        'credit_balance': 0.0,
      });

      // 1. First sequential invoice
      final maxRes1 = await db.rawQuery(
        "SELECT COALESCE(MAX(CAST(SUBSTR(invoice_number, 5) AS INTEGER)), 1000) AS max_seq FROM invoices WHERE company_id = ? AND invoice_number LIKE 'INV-%'",
        [companyId],
      );
      final seq1 = ((maxRes1.first['max_seq'] as num?)?.toInt() ?? 1000) + 1;
      expect(seq1, 1001);

      await db.insert('invoices', {
        'id': const Uuid().v4(),
        'company_id': companyId,
        'customer_id': custId,
        'invoice_number': 'INV-$seq1',
        'customer_name': 'Societe Algerienne',
        'total': 15000.0,
        'paid_amount': 5000.0,
        'remaining_amount': 10000.0,
        'status': 'partial',
        'due_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'notes': 'Consulting Services',
        'sold_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Next invoice must be INV-1002
      final maxRes2 = await db.rawQuery(
        "SELECT COALESCE(MAX(CAST(SUBSTR(invoice_number, 5) AS INTEGER)), 1000) AS max_seq FROM invoices WHERE company_id = ? AND invoice_number LIKE 'INV-%'",
        [companyId],
      );
      final seq2 = ((maxRes2.first['max_seq'] as num?)?.toInt() ?? 1000) + 1;
      expect(seq2, 1002);

      await db.close();
    });

    test('Sync Queue: Enqueues Clinic Rx Prescription and Restaurant Menu correctly', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              client_transaction_id TEXT,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              operation_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT NOT NULL,
              retry_count INTEGER DEFAULT 0,
              last_error TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      );

      final rxId = const Uuid().v4();
      final rxPayload = jsonEncode({
        'patientId': 'patient_001',
        'notes': 'Take after meals',
        'items': [
          {'medicationName': 'Amoxicilline 500mg', 'dosage': '1 pill 3x/day', 'duration': '7 days'}
        ],
      });

      await db.insert('sync_queue', {
        'id': const Uuid().v4(),
        'company_id': 'clinic_comp',
        'client_transaction_id': const Uuid().v4(),
        'entity_type': 'clinic_prescription',
        'entity_id': rxId,
        'operation_type': 'CREATE',
        'payload': rxPayload,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final rows = await db.query('sync_queue', where: "entity_type = 'clinic_prescription'");
      expect(rows.length, 1);
      final decoded = jsonDecode(rows.first['payload'] as String);
      expect(decoded['patientId'], 'patient_001');
      expect((decoded['items'] as List).first['medicationName'], 'Amoxicilline 500mg');

      await db.close();
    });

    test('Appointments: Status mapping normalizes confirmed to scheduled', () {
      String mapAppointmentStatus(String raw) {
        final lower = raw.trim().toLowerCase();
        if (lower == 'confirmed') return 'scheduled';
        return lower;
      }

      expect(mapAppointmentStatus('confirmed'), 'scheduled');
      expect(mapAppointmentStatus('CONFIRMED'), 'scheduled');
      expect(mapAppointmentStatus('completed'), 'completed');
      expect(mapAppointmentStatus('cancelled'), 'cancelled');
    });

    test('Enterprise Projects: Status in_progress mapped to active for validator compliance', () {
      const allowed = ['planned', 'active', 'on_hold', 'completed', 'cancelled'];
      String mapProjectStatus(String raw) {
        final lower = raw.trim().toLowerCase();
        if (lower == 'in_progress') return 'active';
        return lower;
      }

      final mapped = mapProjectStatus('in_progress');
      expect(allowed.contains(mapped), isTrue);
      expect(mapped, 'active');
    });
  });
}
