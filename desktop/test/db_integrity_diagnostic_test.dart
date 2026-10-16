// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Diagnostic: Read-Only Verification of Local Database Integrity', () async {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? 'C:\\Users\\Haoui\\AppData\\Local';
    final dbPath = '$localAppData\\ModiriAI\\modiri_desktop.db';
    final backupPath = '$localAppData\\ModiriAI\\modiri_desktop_backup_20261015.db';

    print('=== DATABASE DIAGNOSTIC REPORT ===');
    print('Target DB path: $dbPath');
    final dbFile = File(dbPath);
    final backupFile = File(backupPath);
    expect(dbFile.existsSync(), isTrue, reason: 'Active SQLite DB must exist');
    expect(backupFile.existsSync(), isTrue, reason: 'Safety backup DB must exist');

    print('Active DB size: ${dbFile.lengthSync()} bytes');
    print('Backup DB size: ${backupFile.lengthSync()} bytes');

    final factory = databaseFactoryFfi;
    final db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(readOnly: true),
    );

    try {
      // 1. PRAGMA integrity_check
      final integrityRes = await db.rawQuery('PRAGMA integrity_check');
      final integrityStatus = integrityRes.isNotEmpty ? integrityRes.first.values.first.toString() : 'UNKNOWN';
      print('PRAGMA integrity_check: $integrityStatus');
      expect(integrityStatus, equals('ok'), reason: 'Database integrity must be OK');

      // 2. PRAGMA foreign_key_check
      final fkRes = await db.rawQuery('PRAGMA foreign_key_check');
      print('PRAGMA foreign_key_check violations: ${fkRes.length}');

      // 3. Table lists and record counts
      final tablesRes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
      print('\nTable record counts:');
      for (final row in tablesRes) {
        final tbl = row['name'] as String;
        final cntRes = await db.rawQuery('SELECT COUNT(*) as count FROM "$tbl"');
        final cnt = cntRes.first['count'];
        print('  - $tbl: $cnt records');
      }

      // 4. Sync queue status distribution
      final sqCount = await db.rawQuery('SELECT status, COUNT(*) as count FROM sync_queue GROUP BY status');
      print('\nSync queue statuses:');
      for (final r in sqCount) {
        print('  - ${r['status']}: ${r['count']} operations');
      }

      final failedOps = await db.query('sync_queue', where: "status = 'failed'");
      for (final op in failedOps) {
        print('  Failed op info: entityType=${op['entity_type']}, op=${op['operation_type']}, retries=${op['retry_count']}, error=${op['error_message']}');
      }

      // 5. Distinct tenants
      final compCount = await db.rawQuery('SELECT DISTINCT company_id FROM products UNION SELECT DISTINCT company_id FROM sales');
      print('\nDistinct tenant company IDs in database: ${compCount.length}');
      print('=== END DIAGNOSTIC REPORT ===\n');
    } finally {
      await db.close();
    }
  });
}
