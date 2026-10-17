import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modiri_desktop/core/database/desktop_database.dart';
import 'package:modiri_desktop/core/localization/desktop_localizations.dart';
import 'package:modiri_desktop/core/network/api_client.dart';
import 'package:modiri_desktop/core/network/session.dart';
import 'package:modiri_desktop/core/sync/desktop_sync_service.dart';
import 'package:modiri_desktop/features/shell/presentation/desktop_navigation_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockSyncApiClient extends ApiClient {
  MockSyncApiClient(super.ref);

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    switch (path) {
      case '/companies/me':
        return {
          'data': {
            'id': 'test_comp_1',
            'name': 'Synced Test Company',
            'businessType': 'restaurant',
          }
        };
      case '/products':
        return {
          'data': [
            {
              'id': 'prod_cloud_1',
              'name': 'Cloud Burger',
              'selling_price': 850.0,
              'cost_price': 450.0,
              'stock_quantity': 25,
              'category': 'Food',
              'barcode': '1234567890',
            },
            {
              'id': 'prod_cloud_pending',
              'name': 'Stale Name In Cloud',
              'selling_price': 100.0,
              'cost_price': 50.0,
              'stock_quantity': 10,
            }
          ]
        };
      case '/customers':
        return {
          'data': [
            {
              'id': 'cust_cloud_1',
              'name': 'John Cloud',
              'phone': '0555123456',
              'credit_balance': 1500.0,
            }
          ]
        };
      case '/sales':
        return {
          'data': [
            {
              'id': 'sale_cloud_1',
              'total': 2500.0,
              'payment_status': 'paid',
              'sold_at': '2026-10-17T12:00:00Z',
              'items': [
                {
                  'id': 'item_cloud_1',
                  'sale_id': 'sale_cloud_1',
                  'product_name': 'Cloud Burger',
                  'quantity': 2,
                  'unit_price': 850.0,
                  'subtotal': 1700.0,
                }
              ]
            }
          ]
        };
      case '/invoices':
        return {
          'data': [
            {
              'id': 'inv_cloud_1',
              'invoice_number': 'INV-999',
              'total_amount': 2500.0,
              'status': 'paid',
              'created_at': '2026-10-17T12:00:00Z',
            }
          ]
        };
      case '/expenses':
        return {
          'data': [
            {
              'id': 'exp_cloud_1',
              'category': 'Rent',
              'amount': 30000.0,
              'date': '2026-10-01',
            }
          ]
        };
      case '/restaurant/tables':
        return {
          'data': [
            {
              'id': 'table_cloud_1',
              'table_number': 'T1',
              'capacity': 4,
              'status': 'available',
            }
          ]
        };
      default:
        return {'data': []};
    }
  }

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    return {'success': true};
  }

  @override
  Future<dynamic> put(String path, {dynamic body}) async {
    return {'success': true};
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await ModiriDesktopDatabase.instance.database;
  });

  group('Desktop Mobile-Data Parity & Initial Sync Verification', () {
    test('1. pullInitialData populates local SQLite across entities and respects sync_queue pending records', () async {
      final db = await ModiriDesktopDatabase.instance.database;

      // Clean test company records if any
      await db.delete('products', where: 'company_id = ?', whereArgs: ['test_comp_1']);
      await db.delete('customers', where: 'company_id = ?', whereArgs: ['test_comp_1']);
      await db.delete('sales', where: 'company_id = ?', whereArgs: ['test_comp_1']);
      await db.delete('sale_items', where: 'company_id = ?', whereArgs: ['test_comp_1']);
      await db.delete('invoices', where: 'company_id = ?', whereArgs: ['test_comp_1']);
      await db.delete('expenses', where: 'company_id = ?', whereArgs: ['test_comp_1']);
      await db.delete('restaurant_tables', where: 'company_id = ?', whereArgs: ['test_comp_1']);
      await db.delete('sync_queue', where: 'company_id = ?', whereArgs: ['test_comp_1']);

      // Seed local unpushed change in sync_queue for prod_cloud_pending
      await db.insert('products', {
        'id': 'prod_cloud_pending',
        'company_id': 'test_comp_1',
        'name': 'Fresh Offline Name Edited By User',
        'price': 150.0,
        'cost_price': 70.0,
        'purchase_price': 70.0,
        'stock_quantity': 15,
        'minimum_stock': 5,
      });
      await db.insert('sync_queue', {
        'id': 'sync_op_1',
        'company_id': 'test_comp_1',
        'client_transaction_id': 'tx_prod_1',
        'entity_type': 'product',
        'entity_id': 'prod_cloud_pending',
        'operation_type': 'update',
        'payload': '{"name":"Fresh Offline Name Edited By User"}',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWith((ref) => MockSyncApiClient(ref)),
          desktopSyncServiceProvider.overrideWith((ref) => DesktopSyncService(ref, customDb: db)),
          sessionProvider.overrideWith((ref) => SessionNotifier()..applyLogin(
            accessToken: 'mock_token',
            userId: 'user_1',
            companyId: 'test_comp_1',
            businessType: 'grocery',
          )),
        ],
      );

      final syncNotifier = container.read(desktopSyncServiceProvider.notifier);

      // Perform initial data pull
      await syncNotifier.pullInitialData();

      // Verify Cloud Burger product was inserted
      final burgerRows = await db.query('products', where: 'id = ?', whereArgs: ['prod_cloud_1']);
      expect(burgerRows.length, equals(1));
      expect(burgerRows.first['name'], equals('Cloud Burger'));
      expect(burgerRows.first['stock_quantity'], equals(25));

      // Verify pending product was NOT overwritten by stale cloud name
      final pendingRows = await db.query('products', where: 'id = ?', whereArgs: ['prod_cloud_pending']);
      expect(pendingRows.first['name'], equals('Fresh Offline Name Edited By User'));
      expect(pendingRows.first['stock_quantity'], equals(15));

      // Verify customer was inserted
      final custRows = await db.query('customers', where: 'id = ?', whereArgs: ['cust_cloud_1']);
      expect(custRows.length, equals(1));
      expect(custRows.first['name'], equals('John Cloud'));
      expect(custRows.first['credit_balance'], equals(1500.0));

      // Verify sale and sale items were inserted
      final saleRows = await db.query('sales', where: 'id = ?', whereArgs: ['sale_cloud_1']);
      expect(saleRows.length, equals(1));
      expect(saleRows.first['total'], equals(2500.0));

      final itemRows = await db.query('sale_items', where: 'sale_id = ?', whereArgs: ['sale_cloud_1']);
      expect(itemRows.length, equals(1));
      expect(itemRows.first['product_name'], equals('Cloud Burger'));

      // Verify invoice was inserted
      final invRows = await db.query('invoices', where: 'id = ?', whereArgs: ['inv_cloud_1']);
      expect(invRows.length, equals(1));
      expect(invRows.first['invoice_number'], equals('INV-999'));

      // Verify expense was inserted
      final expRows = await db.query('expenses', where: 'id = ?', whereArgs: ['exp_cloud_1']);
      expect(expRows.length, equals(1));
      expect(expRows.first['amount'], equals(30000.0));

      // Verify restaurant table was inserted
      final tableRows = await db.query('restaurant_tables', where: 'id = ?', whereArgs: ['table_cloud_1']);
      expect(tableRows.length, equals(1));
      expect(tableRows.first['name'], equals('T1'));

      // Verify session business type was updated to match server ('restaurant')
      expect(container.read(sessionProvider).businessType, equals('restaurant'));
    });

    test('2. Multi-language sync keys exist in EN, FR, and AR dictionaries', () {
      final locEn = ModiriLocalizations(const Locale('en'));
      final locFr = ModiriLocalizations(const Locale('fr'));
      final locAr = ModiriLocalizations(const Locale('ar'));

      expect(locEn.get('sync_all_data'), equals('Sync all data with cloud'));
      expect(locEn.get('syncing_data'), equals('Syncing data with cloud...'));
      expect(locEn.get('sync_completed'), equals('Data synchronized successfully'));

      expect(locFr.get('sync_all_data'), equals('Synchroniser toutes les données avec le cloud'));
      expect(locFr.get('syncing_data'), equals('Synchronisation des données en cours...'));
      expect(locFr.get('sync_completed'), equals('Données synchronisées avec succès'));

      expect(locAr.get('sync_all_data'), equals('مزامنة كافة البيانات مع السحابة'));
      expect(locAr.get('syncing_data'), equals('جارٍ مزامنة البيانات مع السحابة...'));
      expect(locAr.get('sync_completed'), equals('تمت مزامنة البيانات بنجاح'));
    });
  });
}
