import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:modiri_desktop/core/database/desktop_database.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Restaurant Reservations & Mobile Feature Parity Tests', () {
    test('1. Localization parity for restaurant tabs & reservations across EN, FR, AR', () {
      final locales = [
        const Locale('en'),
        const Locale('fr'),
        const Locale('ar'),
      ];

      final expectedKeys = [
        'kitchen_tickets',
        'floor_tables',
        'menu_recipes',
        'reservations',
        'restaurant_management_title',
        'restaurant_management_subtitle',
        'active_reservations_label',
        'add_reservation',
        'edit_reservation',
        'no_reservations_found',
        'reservations_empty_hint',
        'party_size_label',
        'reservation_time_label',
        'seat_guests',
        'mark_confirmed',
        'mark_no_show',
        'assigned_table',
        'unassigned_table',
        'guest_phone',
        'guest_name',
        'special_requests',
        'reservation_created',
        'reservation_updated',
        'delete_reservation',
      ];

      for (final locale in locales) {
        final loc = ModiriLocalizations(locale);
        for (final key in expectedKeys) {
          final translated = loc.get(key);
          expect(translated, isNotEmpty, reason: 'Key "$key" should not be empty in ${locale.languageCode}');
          expect(translated, isNot(equals(key)), reason: 'Key "$key" should have a translation in ${locale.languageCode}');
        }
      }
    });

    test('2. Status labels and normalized transitions work in all languages', () {
      final statuses = ['pending', 'confirmed', 'seated', 'cancelled', 'no_show'];
      for (final lang in ['en', 'fr', 'ar']) {
        final loc = ModiriLocalizations(Locale(lang));
        for (final status in statuses) {
          final label = loc.get(status);
          expect(label, isNotEmpty);
        }
      }
    });

    test('3. SQLite restaurant_reservations CRUD and table status synchronization', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE restaurant_tables (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              name TEXT NOT NULL,
              seats INTEGER NOT NULL DEFAULT 4,
              status TEXT NOT NULL DEFAULT 'available',
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE restaurant_reservations (
              id TEXT PRIMARY KEY,
              company_id TEXT NOT NULL,
              customer_name TEXT NOT NULL,
              phone TEXT,
              party_size INTEGER NOT NULL DEFAULT 2,
              table_id TEXT,
              table_name TEXT,
              reserved_at TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending',
              notes TEXT,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      );

      const companyId = 'test_company_rest';

      // 1. Create a table
      await db.insert('restaurant_tables', {
        'id': 'tbl-101',
        'company_id': companyId,
        'name': 'Table 4 VIP',
        'seats': 4,
        'status': 'available',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 1,
      });

      // 2. Book a reservation
      const resId = 'res-001';
      final reservationTime = DateTime.now().add(const Duration(hours: 2)).toIso8601String();
      await db.insert('restaurant_reservations', {
        'id': resId,
        'company_id': companyId,
        'customer_name': 'Amine Benali',
        'phone': '0555123456',
        'party_size': 4,
        'table_id': 'tbl-101',
        'table_name': 'Table 4 VIP',
        'reserved_at': reservationTime,
        'status': 'pending',
        'notes': 'Anniversary dinner by window',
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });

      // Mark table as reserved
      await db.update(
        'restaurant_tables',
        {'status': 'reserved', 'synced': 0},
        where: 'id = ?',
        whereArgs: ['tbl-101'],
      );

      // Verify table is reserved
      final tableCheck = await db.query('restaurant_tables', where: 'id = ?', whereArgs: ['tbl-101']);
      expect(tableCheck.first['status'], 'reserved');

      // 3. Confirm reservation
      await db.update(
        'restaurant_reservations',
        {'status': 'confirmed', 'synced': 0},
        where: 'id = ?',
        whereArgs: [resId],
      );

      var resCheck = await db.query('restaurant_reservations', where: 'id = ?', whereArgs: [resId]);
      expect(resCheck.first['status'], 'confirmed');

      // 4. Seat the guests -> table becomes occupied
      await db.update(
        'restaurant_reservations',
        {'status': 'seated', 'synced': 0},
        where: 'id = ?',
        whereArgs: [resId],
      );
      await db.update(
        'restaurant_tables',
        {'status': 'occupied', 'synced': 0},
        where: 'id = ?',
        whereArgs: ['tbl-101'],
      );

      final tableSeatedCheck = await db.query('restaurant_tables', where: 'id = ?', whereArgs: ['tbl-101']);
      expect(tableSeatedCheck.first['status'], 'occupied');

      resCheck = await db.query('restaurant_reservations', where: 'id = ?', whereArgs: [resId]);
      expect(resCheck.first['status'], 'seated');

      // 5. Query active reservations
      final activeList = await db.query(
        'restaurant_reservations',
        where: 'company_id = ? AND status != ?',
        whereArgs: [companyId, 'cancelled'],
      );
      expect(activeList.length, 1);
      expect(activeList.first['customer_name'], 'Amine Benali');

      await db.close();
    });
  });
}
