import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../../products/data/products_repository.dart';
import '../../invoices/data/invoices_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../domain/sale.dart';

class SalesRepository extends StateNotifier<AsyncValue<List<Sale>>> {
  SalesRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> load() async {
    // 1. Immediately read from local SQLite
    try {
      final localSales = await _fetchFromLocal();
      if (!mounted) return;
      state = AsyncValue.data(localSales);
    } catch (_) {}

    // 2. Fetch from backend in the background if online
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/sales');
      final sales = (response['data'] as List)
          .map((json) => Sale.fromJson(json as Map<String, dynamic>))
          .toList();

      await _upsertToLocal(sales);

      final fresh = await _fetchFromLocal();
      if (!mounted) return;
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current != null) {
        return; // Keep existing offline sales
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<Sale>> _fetchFromLocal() async {
    final companyId = _companyId;
    // TENANT ISOLATION: return nothing when no account is active.
    if (companyId == null) return [];

    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        s.*,
        s.customer_name,
        i.id AS invoice_id,
        i.invoice_number,
        (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) AS item_count,
        (SELECT COALESCE(SUM(si.line_profit), 0) FROM sale_items si WHERE si.sale_id = s.id) AS margin
      FROM sales s
      LEFT JOIN invoices i ON i.sale_id = s.id
      WHERE s.company_id = ?
      ORDER BY s.sold_at DESC
    ''', [companyId]);
    return rows.map((r) => Sale.fromJson(r)).toList();
  }

  Future<void> _upsertToLocal(List<Sale> sales) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final s in sales) {
      batch.insert(
        'sales',
        {
          'id': s.id,
          'company_id': companyId,
          'customer_name': s.customerName,
          'subtotal': s.subtotal,
          'discount': s.discount,
          'total': s.total,
          'payment_status': paymentStatusToApi(s.paymentStatus),
          'sold_at': s.soldAt.toIso8601String(),
          'created_at': s.soldAt.toIso8601String(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (s.invoiceId != null && s.invoiceNumber != null) {
        batch.insert(
          'invoices',
          {
            'id': s.invoiceId!,
            'sale_id': s.id,
            'company_id': companyId,
            'invoice_number': s.invoiceNumber!,
            'status': paymentStatusToApi(s.paymentStatus),
            'customer_name': s.customerName,
            'total': s.total,
            'sold_at': s.soldAt.toIso8601String(),
            'created_at': s.soldAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Atomic local transaction for offline POS sale.
  /// All records written with the active company_id.
  Future<Map<String, dynamic>> createSale({
    required List<SaleItemInput> items,
    double discount = 0,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    String? customerId,
  }) async {
    final companyId = _companyId;
    if (companyId == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated', code: 'NOT_AUTHENTICATED');
    }
    if (items.isEmpty) {
      throw ApiException(statusCode: 400, message: 'Cart cannot be empty', code: 'EMPTY_CART');
    }

    final db = await AppDatabase.instance.database;
    final saleId = const Uuid().v4();
    final clientTxId = const Uuid().v4();
    final invoiceId = const Uuid().v4();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    Map<String, dynamic> result = {};

    await db.transaction((txn) async {
      // 1. Verify stock locally (scoped by company to avoid cross-company stock access)
      double subtotal = 0.0;
      final List<Map<String, dynamic>> verifiedItems = [];

      for (final item in items) {
        final productRows = await txn.query(
          'products',
          where: 'id = ? AND company_id = ?',
          whereArgs: [item.productId, companyId],
        );

        if (productRows.isEmpty) {
          throw ApiException(
            statusCode: 400,
            message: 'Product not found: ${item.productName}',
            code: 'PRODUCT_NOT_FOUND',
          );
        }

        final p = productRows.first;
        final currentStock = (p['quantity'] as num).toInt();
        if (currentStock < item.quantity) {
          throw ApiException(
            statusCode: 400,
            message: 'Insufficient stock for ${p['name']}: requested ${item.quantity}, have $currentStock',
            code: 'INSUFFICIENT_STOCK',
          );
        }

        final sellingPrice = (p['selling_price'] as num).toDouble();
        final purchasePrice = (p['purchase_price'] as num).toDouble();
        final lineTotal = sellingPrice * item.quantity;
        final lineProfit = (sellingPrice - purchasePrice) * item.quantity;

        subtotal += lineTotal;
        verifiedItems.add({
          'productId': item.productId,
          'productName': p['name'],
          'quantity': item.quantity,
          'unitPrice': sellingPrice,
          'unitCost': purchasePrice,
          'lineTotal': lineTotal,
          'lineProfit': lineProfit,
        });
      }

      final total = (subtotal - discount).clamp(0.0, double.infinity);

      // Customer name if any (scoped to this company's customers)
      String? customerName;
      if (customerId != null) {
        final custRows = await txn.query(
          'customers',
          where: 'id = ? AND company_id = ?',
          whereArgs: [customerId, companyId],
        );
        if (custRows.isNotEmpty) {
          customerName = custRows.first['name'] as String?;
        }
      }

      // Next sequential local invoice number (scoped to this company)
      final countRes = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM invoices WHERE company_id = ?',
        [companyId],
      );
      final nextSeq = ((countRes.first['count'] as num?)?.toInt() ?? 0) + 1;
      final invoiceNumber = 'INV-$nextSeq';

      // 2. Insert Sale (tagged with company_id)
      await txn.insert('sales', {
        'id': saleId,
        'client_transaction_id': clientTxId,
        'company_id': companyId,
        'customer_id': customerId,
        'customer_name': customerName,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'payment_status': paymentStatusToApi(paymentStatus),
        'sold_at': nowIso,
        'created_at': nowIso,
        'synced': 0,
      });

      // 3. Insert Sale Items (tagged with company_id) & decrement inventory
      for (final vi in verifiedItems) {
        await txn.insert('sale_items', {
          'id': const Uuid().v4(),
          'sale_id': saleId,
          'company_id': companyId,
          'product_id': vi['productId'],
          'product_name': vi['productName'],
          'quantity': vi['quantity'],
          'unit_price': vi['unitPrice'],
          'unit_cost': vi['unitCost'],
          'line_total': vi['lineTotal'],
          'line_profit': vi['lineProfit'],
        });

        // Scoped UPDATE: only decrement stock for this company's product
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ? AND company_id = ?',
          [vi['quantity'], vi['productId'], companyId],
        );
      }

      // 4. Insert Invoice (tagged with company_id)
      await txn.insert('invoices', {
        'id': invoiceId,
        'sale_id': saleId,
        'company_id': companyId,
        'invoice_number': invoiceNumber,
        'status': paymentStatusToApi(paymentStatus),
        'customer_name': customerName,
        'total': total,
        'sold_at': nowIso,
        'created_at': nowIso,
      });

      // 5. Enqueue in Sync Queue (tagged with company_id)
      await txn.insert('sync_queue', {
        'id': const Uuid().v4(),
        'company_id': companyId,
        'client_transaction_id': clientTxId,
        'entity_type': 'sale',
        'entity_id': saleId,
        'operation_type': 'CREATE',
        'payload': jsonEncode({
          'items': verifiedItems.map((vi) => {
            'productId': vi['productId'],
            'quantity': vi['quantity'],
          }).toList(),
          'discount': discount,
          'paymentStatus': paymentStatusToApi(paymentStatus),
          if (customerId != null) 'customerId': customerId,
        }),
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      result = {
        'sale': {
          'id': saleId,
          'client_transaction_id': clientTxId,
          'total': total,
          'sold_at': nowIso,
        },
        'items': verifiedItems,
        'invoice': {
          'id': invoiceId,
          'invoice_number': invoiceNumber,
          'total': total,
          'status': paymentStatusToApi(paymentStatus),
        },
      };
    });

    // Refresh affected repositories locally
    await load();
    await _ref.read(productsRepositoryProvider.notifier).load();
    await _ref.read(invoicesRepositoryProvider.notifier).load();
    await _ref.read(dashboardRepositoryProvider.notifier).load();
    await _ref.read(syncServiceProvider.notifier).refreshQueueCounts();

    // Trigger sync in background if online
    unawaited(_ref.read(syncServiceProvider.notifier).syncPending());

    return result;
  }
}

final salesRepositoryProvider =
    StateNotifierProvider.autoDispose<SalesRepository, AsyncValue<List<Sale>>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return SalesRepository(ref);
  },
);
