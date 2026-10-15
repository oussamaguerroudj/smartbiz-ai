import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../products/data/products_repository.dart';
import 'suppliers_screen.dart';

class SupplierProductItem {
  SupplierProductItem({
    required this.id,
    required this.name,
    this.category,
    this.barcode,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.quantity = 0,
    this.expirationDate,
  });

  final String id;
  final String name;
  final String? category;
  final String? barcode;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final String? expirationDate;

  factory SupplierProductItem.fromJson(Map<String, dynamic> json) => SupplierProductItem(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        barcode: json['barcode'] as String?,
        purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0,
        sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        expirationDate: json['expiration_date'] as String?,
      );
}

class SupplierPurchaseRecord {
  SupplierPurchaseRecord({
    required this.id,
    this.invoiceNumber,
    required this.purchaseDate,
    required this.totalAmount,
    required this.amountPaid,
    required this.outstandingBalance,
    required this.paymentStatus,
    this.notes,
    this.items = const [],
  });

  final String id;
  final String? invoiceNumber;
  final String purchaseDate;
  final double totalAmount;
  final double amountPaid;
  final double outstandingBalance;
  final String paymentStatus;
  final String? notes;
  final List<Map<String, dynamic>> items;

  factory SupplierPurchaseRecord.fromJson(Map<String, dynamic> json) => SupplierPurchaseRecord(
        id: json['id']?.toString() ?? '',
        invoiceNumber: json['invoice_number']?.toString(),
        purchaseDate: json['purchase_date']?.toString() ?? '',
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
        amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
        outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
        notes: json['notes']?.toString(),
        items: (json['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
}

class SupplierPaymentRecord {
  SupplierPaymentRecord({
    required this.id,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.reference,
    this.notes,
    this.purchaseInvoiceNumber,
  });

  final String id;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final String? purchaseInvoiceNumber;

  factory SupplierPaymentRecord.fromJson(Map<String, dynamic> json) => SupplierPaymentRecord(
        id: json['id']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        paymentDate: json['payment_date']?.toString() ?? '',
        paymentMethod: json['payment_method']?.toString() ?? 'cash',
        reference: json['reference']?.toString(),
        notes: json['notes']?.toString(),
        purchaseInvoiceNumber: json['purchase_invoice_number']?.toString(),
      );
}

class SupplierProfileData {
  SupplierProfileData({
    required this.supplier,
    required this.products,
    required this.totalStockUnits,
    required this.totalPurchaseValue,
    this.totalPurchasesAmount = 0.0,
    this.totalPurchasesPaid = 0.0,
    this.outstandingBalance = 0.0,
    this.purchasesCount = 0,
    this.paymentsCount = 0,
    this.purchases = const [],
    this.payments = const [],
  });

  final Supplier supplier;
  final List<SupplierProductItem> products;
  final int totalStockUnits;
  final double totalPurchaseValue;
  final double totalPurchasesAmount;
  final double totalPurchasesPaid;
  final double outstandingBalance;
  final int purchasesCount;
  final int paymentsCount;
  final List<SupplierPurchaseRecord> purchases;
  final List<SupplierPaymentRecord> payments;
}

final supplierProfileProvider =
    FutureProvider.family.autoDispose<SupplierProfileData, Supplier>((ref, supplier) async {
  final session = ref.watch(sessionProvider);
  final companyId = session.companyId;
  final connStatus = ref.watch(connectionStatusProvider);

  // 1. Try fetching live from backend if online
  if (connStatus == ConnectionStatus.online) {
    try {
      final client = ref.read(apiClientProvider);
      final resp = await client.get('/suppliers/${supplier.id}');
      final data = resp['data'] as Map<String, dynamic>;
      final productsList = (data['products'] as List? ?? [])
          .map((p) => SupplierProductItem.fromJson(p as Map<String, dynamic>))
          .toList();
      final totalUnits = (data['total_stock_units'] as num?)?.toInt() ?? 0;
      final totalValue = (data['total_purchase_value'] as num?)?.toDouble() ?? 0.0;
      final totalPurchAmount = (data['total_purchases_amount'] as num?)?.toDouble() ?? 0.0;
      final totalPurchPaid = (data['total_purchases_paid'] as num?)?.toDouble() ?? 0.0;
      final outBalance = (data['outstanding_balance'] as num?)?.toDouble() ?? 0.0;
      final purchCount = (data['purchases_count'] as num?)?.toInt() ?? 0;
      final payCount = (data['payments_count'] as num?)?.toInt() ?? 0;

      // Also fetch purchases and payments lists
      List<SupplierPurchaseRecord> purchasesList = [];
      try {
        final pResp = await client.get('/suppliers/${supplier.id}/purchases');
        purchasesList = (pResp['data'] as List? ?? [])
            .map((p) => SupplierPurchaseRecord.fromJson(p as Map<String, dynamic>))
            .toList();
      } catch (_) {}

      List<SupplierPaymentRecord> paymentsList = [];
      try {
        final payResp = await client.get('/suppliers/${supplier.id}/payments');
        paymentsList = (payResp['data'] as List? ?? [])
            .map((p) => SupplierPaymentRecord.fromJson(p as Map<String, dynamic>))
            .toList();
      } catch (_) {}

      // Cache server data into local SQLite for offline persistence
      if (companyId != null) {
        try {
          final db = await AppDatabase.instance.database;
          for (final p in purchasesList) {
            final pending = await db.query(
              'supplier_purchases',
              where: 'id = ? AND synced = 0',
              whereArgs: [p.id],
            );
            if (pending.isEmpty) {
              await db.insert(
                'supplier_purchases',
                {
                  'id': p.id,
                  'company_id': companyId,
                  'supplier_id': supplier.id,
                  'invoice_number': p.invoiceNumber,
                  'purchase_date': p.purchaseDate,
                  'total_amount': p.totalAmount,
                  'amount_paid': p.amountPaid,
                  'outstanding_balance': p.outstandingBalance,
                  'payment_status': p.paymentStatus,
                  'notes': p.notes,
                  'synced': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              for (final it in p.items) {
                final itemId = it['id']?.toString() ?? const Uuid().v4();
                await db.insert(
                  'supplier_purchase_items',
                  {
                    'id': itemId,
                    'purchase_id': p.id,
                    'company_id': companyId,
                    'product_id': it['product_id']?.toString() ?? it['productId']?.toString(),
                    'product_name': it['product_name']?.toString() ?? it['productName']?.toString() ?? '',
                    'quantity': (it['quantity'] as num?)?.toDouble() ?? 1.0,
                    'unit_cost': (it['unit_cost'] as num?)?.toDouble() ?? (it['unitCost'] as num?)?.toDouble() ?? 0.0,
                    'line_total': (it['line_total'] as num?)?.toDouble() ?? (it['lineTotal'] as num?)?.toDouble() ?? 0.0,
                    'created_at': it['created_at']?.toString() ?? p.purchaseDate,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }

          for (final pay in paymentsList) {
            final pending = await db.query(
              'supplier_payments',
              where: 'id = ? AND synced = 0',
              whereArgs: [pay.id],
            );
            if (pending.isEmpty) {
              await db.insert(
                'supplier_payments',
                {
                  'id': pay.id,
                  'company_id': companyId,
                  'supplier_id': supplier.id,
                  'amount': pay.amount,
                  'payment_date': pay.paymentDate,
                  'payment_method': pay.paymentMethod,
                  'reference': pay.reference,
                  'notes': pay.notes,
                  'synced': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        } catch (_) {}
      }

      return SupplierProfileData(
        supplier: supplier,
        products: productsList,
        totalStockUnits: totalUnits,
        totalPurchaseValue: totalValue,
        totalPurchasesAmount: totalPurchAmount,
        totalPurchasesPaid: totalPurchPaid,
        outstandingBalance: outBalance,
        purchasesCount: purchCount,
        paymentsCount: payCount,
        purchases: purchasesList,
        payments: paymentsList,
      );
    } catch (_) {
      // Fallback to local SQLite on network error
    }
  }

  // 2. Local SQLite fallback
  if (companyId == null) {
    return SupplierProfileData(
      supplier: supplier,
      products: [],
      totalStockUnits: 0,
      totalPurchaseValue: 0,
    );
  }

  final db = await AppDatabase.instance.database;
  final rows = await db.query(
    'products',
    where: 'company_id = ? AND supplier_id = ?',
    whereArgs: [companyId, supplier.id],
    orderBy: 'name ASC',
  );

  final products = rows.map((r) => SupplierProductItem(
        id: r['id'] as String,
        name: r['name'] as String,
        category: r['category'] as String?,
        barcode: r['barcode'] as String?,
        purchasePrice: (r['purchase_price'] as num?)?.toDouble() ?? 0,
        sellingPrice: (r['selling_price'] as num?)?.toDouble() ?? 0,
        quantity: (r['quantity'] as num?)?.toInt() ?? 0,
        expirationDate: r['expiration_date'] as String?,
      )).toList();

  final totalUnits = products.fold<int>(0, (sum, p) => sum + p.quantity);
  final totalValue = products.fold<double>(0.0, (sum, p) => sum + (p.purchasePrice * p.quantity));

  // Local AP ledger
  List<SupplierPurchaseRecord> localPurchases = [];
  try {
    final pRows = await db.query(
      'supplier_purchases',
      where: 'company_id = ? AND supplier_id = ?',
      whereArgs: [companyId, supplier.id],
      orderBy: 'purchase_date DESC, created_at DESC',
    );

    for (final r in pRows) {
      final purchId = r['id'] as String;
      List<Map<String, dynamic>> itemsList = [];
      try {
        final itemRows = await db.query(
          'supplier_purchase_items',
          where: 'purchase_id = ?',
          whereArgs: [purchId],
        );
        itemsList = itemRows.map((it) => Map<String, dynamic>.from(it)).toList();
      } catch (_) {}

      localPurchases.add(SupplierPurchaseRecord(
        id: purchId,
        invoiceNumber: r['invoice_number'] as String?,
        purchaseDate: r['purchase_date'] as String? ?? '',
        totalAmount: (r['total_amount'] as num?)?.toDouble() ?? 0.0,
        amountPaid: (r['amount_paid'] as num?)?.toDouble() ?? 0.0,
        outstandingBalance: (r['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
        paymentStatus: r['payment_status'] as String? ?? 'unpaid',
        notes: r['notes'] as String?,
        items: itemsList,
      ));
    }
  } catch (_) {}

  List<SupplierPaymentRecord> localPayments = [];
  try {
    final payRows = await db.query(
      'supplier_payments',
      where: 'company_id = ? AND supplier_id = ?',
      whereArgs: [companyId, supplier.id],
      orderBy: 'payment_date DESC, created_at DESC',
    );
    localPayments = payRows.map((r) => SupplierPaymentRecord(
      id: r['id'] as String,
      amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: r['payment_date'] as String? ?? '',
      paymentMethod: r['payment_method'] as String? ?? 'cash',
      reference: r['reference'] as String?,
      notes: r['notes'] as String?,
    )).toList();
  } catch (_) {}

  final totalPurchAmount = localPurchases.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
  final totalPurchPaid = localPurchases.fold<double>(0.0, (sum, p) => sum + p.amountPaid);
  final outBalance = localPurchases.fold<double>(0.0, (sum, p) => sum + p.outstandingBalance);

  return SupplierProfileData(
    supplier: supplier,
    products: products,
    totalStockUnits: totalUnits,
    totalPurchaseValue: totalValue,
    totalPurchasesAmount: totalPurchAmount,
    totalPurchasesPaid: totalPurchPaid,
    outstandingBalance: outBalance,
    purchasesCount: localPurchases.length,
    paymentsCount: localPayments.length,
    purchases: localPurchases,
    payments: localPayments,
  );
});

class SupplierDetailsScreen extends ConsumerStatefulWidget {
  const SupplierDetailsScreen({super.key, required this.supplier});

  final Supplier supplier;

  @override
  ConsumerState<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _PurchaseLineItemDraft {
  String? productId;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController costCtrl = TextEditingController(text: '0');

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
  double get unitCost => double.tryParse(costCtrl.text.trim()) ?? 0.0;
  double get lineTotal => quantity * unitCost;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}

class _SupplierDetailsScreenState extends ConsumerState<SupplierDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _showCreatePurchaseDialog(BuildContext context, SupplierProfileData profile) async {
    final invoiceCtrl = TextEditingController();
    final initialPaidCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    final List<_PurchaseLineItemDraft> items = [_PurchaseLineItemDraft()];

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bCtx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final totalInvoiceAmount = items.fold<double>(0.0, (sum, it) => sum + it.lineTotal);
            final paid = double.tryParse(initialPaidCtrl.text.trim()) ?? 0.0;
            final remainingDebt = (totalInvoiceAmount - paid) < 0 ? 0.0 : (totalInvoiceAmount - paid);

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom: MediaQuery.of(bCtx).viewInsets.bottom + AppSpacing.md,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nouvel Achat Fournisseur',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(bCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: invoiceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° Facture / Bon de commande (Optionnel)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Articles commandés (${items.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: TextField(
                                    controller: item.nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Désignation article *',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setSheetState(() {}),
                                  ),
                                ),
                                if (profile.products.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  PopupMenuButton<SupplierProductItem>(
                                    icon: const Icon(Icons.list_alt, color: AppColors.primary),
                                    tooltip: 'Choisir parmi les produits du catalogue',
                                    itemBuilder: (c) => profile.products.map((p) => PopupMenuItem(
                                      value: p,
                                      child: Text('${p.name} (${p.purchasePrice.toStringAsFixed(0)} DZD)'),
                                    )).toList(),
                                    onSelected: (p) {
                                      setSheetState(() {
                                        item.productId = p.id;
                                        item.nameCtrl.text = p.name;
                                        item.costCtrl.text = p.purchasePrice.toStringAsFixed(0);
                                      });
                                    },
                                  ),
                                ],
                                if (items.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                    onPressed: () {
                                      setSheetState(() {
                                        final removed = items.removeAt(idx);
                                        removed.dispose();
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: item.qtyCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Quantité *',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setSheetState(() {}),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextField(
                                    controller: item.costCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'P.U d\'achat (DZD) *',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setSheetState(() {}),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.lineTotal.toStringAsFixed(0)} DZD',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter une ligne d\'article'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        setSheetState(() {
                          items.add(_PurchaseLineItemDraft());
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total facture:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${totalInvoiceAmount.toStringAsFixed(2)} DZD',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: initialPaidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Acompte versé (DZD)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              helperText: 'Dette restante: ${remainingDebt.toStringAsFixed(0)} DZD',
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observations (Optionnel)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Valider et enregistrer l\'achat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez ajouter au moins un article'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }
                        for (int i = 0; i < items.length; i++) {
                          final it = items[i];
                          if (it.nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('La désignation de l\'article #${i + 1} est requise'), backgroundColor: AppColors.danger),
                            );
                            return;
                          }
                          if (it.quantity <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('La quantité de l\'article #${i + 1} doit être > 0'), backgroundColor: AppColors.danger),
                            );
                            return;
                          }
                          if (it.unitCost < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Le coût unitaire de l\'article #${i + 1} ne peut être négatif'), backgroundColor: AppColors.danger),
                            );
                            return;
                          }
                        }

                        if (totalInvoiceAmount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Le total de la facture doit être supérieur à 0 DZD'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }

                        if (paid < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('L\'acompte ne peut pas être négatif'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }

                        if (paid > totalInvoiceAmount + 0.001) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('L\'acompte ($paid DZD) ne peut excéder le total ($totalInvoiceAmount DZD)'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }

                        final companyId = ref.read(sessionProvider).companyId;
                        final clientTxId = 'purch_${DateTime.now().millisecondsSinceEpoch}';
                        final purchaseId = const Uuid().v4();
                        final nowIso = DateTime.now().toIso8601String();
                        final balance = (totalInvoiceAmount - paid) <= 0.005 ? 0.0 : (totalInvoiceAmount - paid);
                        final status = balance <= 0.005 ? 'paid' : (paid > 0 ? 'partially_paid' : 'unpaid');

                        // Save locally in SQLite atomically
                        final db = await AppDatabase.instance.database;
                        await db.transaction((txn) async {
                          await txn.insert('supplier_purchases', {
                            'id': purchaseId,
                            'company_id': companyId,
                            'supplier_id': widget.supplier.id,
                            'invoice_number': invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
                            'purchase_date': nowIso,
                            'total_amount': totalInvoiceAmount,
                            'amount_paid': paid,
                            'outstanding_balance': balance,
                            'payment_status': status,
                            'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            'client_transaction_id': clientTxId,
                            'created_at': nowIso,
                            'synced': 0,
                          });

                          for (final it in items) {
                            await txn.insert('supplier_purchase_items', {
                              'id': const Uuid().v4(),
                              'purchase_id': purchaseId,
                              'company_id': companyId,
                              'product_id': it.productId,
                              'product_name': it.nameCtrl.text.trim(),
                              'quantity': it.quantity,
                              'unit_cost': it.unitCost,
                              'line_total': it.lineTotal,
                              'created_at': nowIso,
                            });

                            // Automatic inventory stock increment for catalog products
                            if (it.productId != null && it.quantity > 0) {
                              await txn.rawUpdate(
                                'UPDATE products SET quantity = quantity + ? WHERE id = ? AND company_id = ?',
                                [it.quantity.round(), it.productId, companyId],
                              );
                            }
                          }

                          if (paid > 0) {
                            await txn.insert('supplier_payments', {
                              'id': const Uuid().v4(),
                              'company_id': companyId,
                              'supplier_id': widget.supplier.id,
                              'purchase_id': purchaseId,
                              'amount': paid,
                              'payment_date': nowIso,
                              'payment_method': 'cash',
                              'reference': 'Acompte initial',
                              'client_id': 'pay_$clientTxId',
                              'created_at': nowIso,
                              'synced': 0,
                            });
                          }
                        });

                        final itemsPayload = items.map((it) => {
                          if (it.productId != null) 'productId': it.productId,
                          'productName': it.nameCtrl.text.trim(),
                          'quantity': it.quantity,
                          'unitCost': it.unitCost,
                        }).toList();

                        // Enqueue sync operation
                        final conn = ref.read(connectionStatusProvider);
                        if (conn == ConnectionStatus.online) {
                          try {
                            final client = ref.read(apiClientProvider);
                            await client.post('/suppliers/${widget.supplier.id}/purchases', body: {
                              'invoiceNumber': invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
                              'items': itemsPayload,
                              'amountPaid': paid,
                              'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              'clientTransactionId': clientTxId,
                            });
                            await db.update('supplier_purchases', {'synced': 1}, where: 'id = ?', whereArgs: [purchaseId]);
                          } catch (_) {
                            await ref.read(syncServiceProvider.notifier).enqueueOperation(
                              id: const Uuid().v4(),
                              clientTransactionId: clientTxId,
                              entityType: 'supplier_purchase',
                              entityId: purchaseId,
                              operationType: 'CREATE',
                              payload: {
                                'supplierId': widget.supplier.id,
                                'invoiceNumber': invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
                                'items': itemsPayload,
                                'amountPaid': paid,
                                'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              },
                            );
                          }
                        } else {
                          await ref.read(syncServiceProvider.notifier).enqueueOperation(
                            id: const Uuid().v4(),
                            clientTransactionId: clientTxId,
                            entityType: 'supplier_purchase',
                            entityId: purchaseId,
                            operationType: 'CREATE',
                            payload: {
                              'supplierId': widget.supplier.id,
                              'invoiceNumber': invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
                              'items': itemsPayload,
                              'amountPaid': paid,
                              'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            },
                          );
                        }

                        if (context.mounted) {
                          Navigator.of(bCtx).pop();
                          ref.invalidate(supplierProfileProvider(widget.supplier));
                          ref.invalidate(productsRepositoryProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Achat enregistré avec succès !'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      invoiceCtrl.dispose();
      initialPaidCtrl.dispose();
      notesCtrl.dispose();
      for (final it in items) {
        it.dispose();
      }
    }
  }

  Future<void> _showRecordPaymentDialog(
    BuildContext context,
    SupplierProfileData profile, {
    String? preselectedPurchaseId,
  }) async {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedMethod = 'cash';
    String? selectedPurchaseId = preselectedPurchaseId;

    // Filter unpaid purchases
    final unpaidPurchases = profile.purchases.where((p) => p.outstandingBalance > 0.005).toList();

    if (selectedPurchaseId != null) {
      try {
        final p = profile.purchases.firstWhere((it) => it.id == selectedPurchaseId);
        amountCtrl.text = p.outstandingBalance.toStringAsFixed(0);
      } catch (_) {}
    }

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (bCtx) => StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: MediaQuery.of(bCtx).viewInsets.bottom + AppSpacing.md,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Enregistrer un Paiement',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(bCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Dette totale en cours: ${profile.outstandingBalance.toStringAsFixed(2)} DZD',
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedPurchaseId,
                    decoration: const InputDecoration(
                      labelText: 'Affecter à une facture (Optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Dette globale (Allocation FIFO)'),
                      ),
                      ...unpaidPurchases.map((p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(
                              '${p.invoiceNumber ?? 'Facture'} · Reste: ${p.outstandingBalance.toStringAsFixed(0)} DZD',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      setSheetState(() {
                        selectedPurchaseId = val;
                        if (val != null) {
                          final p = unpaidPurchases.firstWhere((it) => it.id == val);
                          amountCtrl.text = p.outstandingBalance.toStringAsFixed(0);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Montant du versement (DZD) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'Mode de règlement',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Espèces (Cash)')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Virement bancaire')),
                      DropdownMenuItem(value: 'ccp', child: Text('Versement CCP')),
                      DropdownMenuItem(value: 'check', child: Text('Chèque')),
                    ],
                    onChanged: (val) => setSheetState(() => selectedMethod = val ?? 'cash'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Référence / N° Reçu (Optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Confirmer le paiement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Le montant doit être supérieur à zéro'), backgroundColor: AppColors.danger),
                        );
                        return;
                      }

                      // Strict overpayment validation client-side
                      if (selectedPurchaseId != null) {
                        final p = unpaidPurchases.firstWhere((it) => it.id == selectedPurchaseId);
                        if (amount > p.outstandingBalance + 0.001) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Le montant ($amount DZD) dépasse le reste à payer (${p.outstandingBalance} DZD)'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }
                      } else {
                        if (amount > profile.outstandingBalance + 0.001) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Le montant ($amount DZD) dépasse la dette totale (${profile.outstandingBalance} DZD)'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }
                      }

                      final companyId = ref.read(sessionProvider).companyId;
                      final clientTxId = 'pay_${DateTime.now().millisecondsSinceEpoch}';
                      final paymentId = const Uuid().v4();
                      final nowIso = DateTime.now().toIso8601String();

                      // Save locally in SQLite
                      final db = await AppDatabase.instance.database;
                      await db.insert('supplier_payments', {
                        'id': paymentId,
                        'company_id': companyId,
                        'supplier_id': widget.supplier.id,
                        'purchase_id': selectedPurchaseId,
                        'amount': amount,
                        'payment_date': nowIso,
                        'payment_method': selectedMethod,
                        'reference': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                        'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        'client_id': clientTxId,
                        'created_at': nowIso,
                        'synced': 0,
                      });

                      // Update local purchase balance
                      if (selectedPurchaseId != null) {
                        final p = unpaidPurchases.firstWhere((it) => it.id == selectedPurchaseId);
                        final newPaid = p.amountPaid + amount;
                        final newBal = (p.totalAmount - newPaid) <= 0.005 ? 0.0 : (p.totalAmount - newPaid);
                        final newStatus = newBal <= 0.005 ? 'paid' : 'partially_paid';
                        await db.update('supplier_purchases', {
                          'amount_paid': newPaid,
                          'outstanding_balance': newBal,
                          'payment_status': newStatus,
                        }, where: 'id = ?', whereArgs: [selectedPurchaseId]);
                      } else {
                        // Chronological FIFO allocation across unpaid purchases
                        final unpaidPurchasesSorted = List<SupplierPurchaseRecord>.from(unpaidPurchases)
                          ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
                        double remainingPayment = amount;
                        for (final p in unpaidPurchasesSorted) {
                          if (remainingPayment <= 0.005) break;
                          final toPay = math.min(remainingPayment, p.outstandingBalance);
                          final newPaid = p.amountPaid + toPay;
                          final newBal = (p.totalAmount - newPaid) <= 0.005 ? 0.0 : (p.totalAmount - newPaid);
                          final newStatus = newBal <= 0.005 ? 'paid' : 'partially_paid';
                          await db.update(
                            'supplier_purchases',
                            {
                              'amount_paid': newPaid,
                              'outstanding_balance': newBal,
                              'payment_status': newStatus,
                            },
                            where: 'id = ?',
                            whereArgs: [p.id],
                          );
                          remainingPayment -= toPay;
                        }
                      }

                      // Enqueue or send
                      final conn = ref.read(connectionStatusProvider);
                      if (conn == ConnectionStatus.online) {
                        try {
                          final client = ref.read(apiClientProvider);
                          await client.post('/suppliers/${widget.supplier.id}/payments', body: {
                            'purchaseId': selectedPurchaseId,
                            'amount': amount,
                            'paymentMethod': selectedMethod,
                            'reference': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                            'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            'clientId': clientTxId,
                          });
                          await db.update('supplier_payments', {'synced': 1}, where: 'id = ?', whereArgs: [paymentId]);
                        } catch (_) {
                          await ref.read(syncServiceProvider.notifier).enqueueOperation(
                            id: const Uuid().v4(),
                            clientTransactionId: clientTxId,
                            entityType: 'supplier_payment',
                            entityId: paymentId,
                            operationType: 'CREATE',
                            payload: {
                              'supplierId': widget.supplier.id,
                              'purchaseId': selectedPurchaseId,
                              'amount': amount,
                              'paymentMethod': selectedMethod,
                              'reference': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                              'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            },
                          );
                        }
                      } else {
                        await ref.read(syncServiceProvider.notifier).enqueueOperation(
                          id: const Uuid().v4(),
                          clientTransactionId: clientTxId,
                          entityType: 'supplier_payment',
                          entityId: paymentId,
                          operationType: 'CREATE',
                          payload: {
                            'supplierId': widget.supplier.id,
                            'purchaseId': selectedPurchaseId,
                            'amount': amount,
                            'paymentMethod': selectedMethod,
                            'reference': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                            'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          },
                        );
                      }

                      if (context.mounted) {
                        Navigator.of(bCtx).pop();
                        ref.invalidate(supplierProfileProvider(widget.supplier));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Paiement enregistré !'), backgroundColor: AppColors.success),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      amountCtrl.dispose();
      refCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<void> _showPurchaseDetailsDialog(
    BuildContext context,
    SupplierPurchaseRecord purchase,
    SupplierProfileData profile,
  ) async {
    final isPaid = purchase.paymentStatus == 'paid';
    final isPartial = purchase.paymentStatus == 'partially_paid';
    final badgeColor = isPaid ? AppColors.success : (isPartial ? AppColors.warning : AppColors.danger);
    final badgeText = isPaid ? 'Payée en totalité' : (isPartial ? 'Partiellement payée' : 'Non payée');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase.invoiceNumber ?? 'Facture #${purchase.id.substring(0, 8)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Date: ${purchase.purchaseDate.length >= 10 ? purchase.purchaseDate.substring(0, 10) : purchase.purchaseDate}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Financial breakdown card
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant Total Facture:'),
                        Text(
                          '${purchase.totalAmount.toStringAsFixed(2)} DZD',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant Réglé:'),
                        Text(
                          '${purchase.amountPaid.toStringAsFixed(2)} DZD',
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reste à payer (Dette):', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${purchase.outstandingBalance.toStringAsFixed(2)} DZD',
                          style: TextStyle(
                            color: purchase.outstandingBalance > 0.005 ? AppColors.danger : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Line items list
              Text(
                'Lignes de la facture (${purchase.items.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (purchase.items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Aucun détail d\'article enregistré.', style: TextStyle(color: Colors.grey)),
                )
              else
                ...purchase.items.map((it) {
                  final name = it['product_name'] ?? it['productName'] ?? 'Article';
                  final qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
                  final unitCost = (it['unit_cost'] as num?)?.toDouble() ?? (it['unitCost'] as num?)?.toDouble() ?? 0.0;
                  final lineTotal = (it['line_total'] as num?)?.toDouble() ?? (it['lineTotal'] as num?)?.toDouble() ?? (qty * unitCost);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} x ${unitCost.toStringAsFixed(0)} DZD',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${lineTotal.toStringAsFixed(0)} DZD',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),
              if (purchase.notes != null && purchase.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('Observations: ${purchase.notes!}', style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.md),
              if (purchase.outstandingBalance > 0.005)
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment),
                  label: Text('Payer cette facture (${purchase.outstandingBalance.toStringAsFixed(0)} DZD)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(bCtx).pop();
                    _showRecordPaymentDialog(context, profile, preselectedPurchaseId: purchase.id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(supplierProfileProvider(widget.supplier));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier.name),
        actions: [
          if (widget.supplier.phone != null && widget.supplier.phone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
              tooltip: l10n.phoneLabel,
              onPressed: () => _makeCall(widget.supplier.phone!),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(l10n.errorPrefix(err))),
        data: (profile) => RefreshIndicator(
          onRefresh: () async => ref.refresh(supplierProfileProvider(widget.supplier).future),
          child: Column(
            children: [
              // Supplier Summary & Action Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    // Profile Contact Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        boxShadow: AppSpacing.cardElevation,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              widget.supplier.name.isNotEmpty ? widget.supplier.name[0].toUpperCase() : 'F',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.supplier.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                if (widget.supplier.phone != null && widget.supplier.phone!.isNotEmpty)
                                  InkWell(
                                    onTap: () => _makeCall(widget.supplier.phone!),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.supplier.phone!,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Text('-', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Financial AP & Valuation KPI Grid
                    Row(
                      children: [
                        Expanded(
                          child: _KpiMetricCard(
                            icon: Icons.inventory_2_outlined,
                            color: AppColors.info,
                            title: '${profile.totalPurchaseValue.toStringAsFixed(0)} DZD',
                            subtitle: 'Valeur du stock',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _KpiMetricCard(
                            icon: Icons.receipt_long_outlined,
                            color: AppColors.primary,
                            title: '${profile.totalPurchasesAmount.toStringAsFixed(0)} DZD',
                            subtitle: 'Total Facturé',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: _KpiMetricCard(
                            icon: Icons.check_circle_outline,
                            color: AppColors.success,
                            title: '${profile.totalPurchasesPaid.toStringAsFixed(0)} DZD',
                            subtitle: 'Total Réglé',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _KpiMetricCard(
                            icon: Icons.warning_amber_rounded,
                            color: profile.outstandingBalance > 0.005 ? AppColors.danger : AppColors.success,
                            title: '${profile.outstandingBalance.toStringAsFixed(0)} DZD',
                            subtitle: 'Reste à payer (Dette)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Nouvel achat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _showCreatePurchaseDialog(context, profile),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.payment, size: 18),
                            label: const Text('Payer dette'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(color: AppColors.success),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _showRecordPaymentDialog(context, profile),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // TabBar Navigation
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                tabs: [
                  Tab(text: 'Factures (${profile.purchases.length})'),
                  Tab(text: 'Paiements (${profile.payments.length})'),
                  Tab(text: 'Produits (${profile.products.length})'),
                ],
              ),

              // TabBarView Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Purchases Invoices List
                    _buildPurchasesList(context, profile),

                    // Tab 2: Payments Ledger List
                    _buildPaymentsList(context, profile),

                    // Tab 3: Catalog Products List
                    _buildProductsList(context, profile, l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchasesList(BuildContext context, SupplierProfileData profile) {
    if (profile.purchases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: AppSpacing.sm),
              const Text('Aucune facture d\'achat enregistrée.'),
              const SizedBox(height: AppSpacing.xs),
              ElevatedButton(
                onPressed: () => _showCreatePurchaseDialog(context, profile),
                child: const Text('Enregistrer le premier achat'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: profile.purchases.length,
      itemBuilder: (ctx, i) {
        final p = profile.purchases[i];
        final isPaid = p.paymentStatus == 'paid';
        final isPartial = p.paymentStatus == 'partially_paid';
        final badgeColor = isPaid ? AppColors.success : (isPartial ? AppColors.warning : AppColors.danger);
        final badgeText = isPaid ? 'Payée' : (isPartial ? 'Partielle' : 'Non payée');

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            onTap: () => _showPurchaseDetailsDialog(context, p, profile),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description_outlined, color: badgeColor, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.invoiceNumber ?? 'Facture #${p.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          p.purchaseDate.length >= 10 ? p.purchaseDate.substring(0, 10) : p.purchaseDate,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.totalAmount.toStringAsFixed(0)} DZD',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (p.outstandingBalance > 0.005)
                        Text(
                          'Reste: ${p.outstandingBalance.toStringAsFixed(0)} DZD',
                          style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                        )
                      else
                        Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsList(BuildContext context, SupplierProfileData profile) {
    if (profile.payments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payment_outlined, size: 48, color: Colors.grey),
              SizedBox(height: AppSpacing.sm),
              Text('Aucun paiement enregistré.'),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: profile.payments.length,
      itemBuilder: (ctx, i) {
        final pay = profile.payments[i];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paiement · ${pay.paymentMethod.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (pay.reference != null && pay.reference!.isNotEmpty)
                      Text(
                        pay.reference!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      pay.paymentDate.length >= 10 ? pay.paymentDate.substring(0, 10) : pay.paymentDate,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '-${pay.amount.toStringAsFixed(0)} DZD',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductsList(BuildContext context, SupplierProfileData profile, AppLocalizations l10n) {
    if (profile.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(l10n.noProductsYetMessage),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: profile.products.length,
      itemBuilder: (ctx, i) {
        final p = profile.products[i];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medication_outlined, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (p.category != null) ...[
                          Text(
                            p.category!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                ),
                          ),
                          const Text(' · '),
                        ],
                        Text(
                          '${l10n.inStockLabel}: ${p.quantity}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (p.expirationDate != null) ...[
                          const Text(' · '),
                          Text(
                            'Exp: ${p.expirationDate}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.purchasePrice.toStringAsFixed(0)} DZD',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Vente: ${p.sellingPrice.toStringAsFixed(0)} DZD',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  const _KpiMetricCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            child: Icon(icon, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
