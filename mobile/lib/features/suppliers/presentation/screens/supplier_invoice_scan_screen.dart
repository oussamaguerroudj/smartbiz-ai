import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
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
import '../../../products/domain/product.dart';
import 'supplier_details_screen.dart';
import 'suppliers_screen.dart';

/// Item in the editable invoice review list.
class _InvoiceReviewItem {
  _InvoiceReviewItem({
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.isNewProduct = true,
    this.matchedProductId,
    this.matchedProductName,
    this.category = 'General',
    this.sellingPrice,
    this.isSkipped = false,
  }) {
    nameCtrl = TextEditingController(text: name);
    qtyCtrl = TextEditingController(text: quantity.toString());
    costCtrl = TextEditingController(text: unitCost.toStringAsFixed(unitCost.truncateToDouble() == unitCost ? 0 : 2));
    sellingPriceCtrl = TextEditingController(
      text: (sellingPrice ?? (unitCost * 1.3)).toStringAsFixed(0),
    );
  }

  String name;
  double quantity;
  double unitCost;
  bool isNewProduct;
  String? matchedProductId;
  String? matchedProductName;
  String category;
  double? sellingPrice;
  bool isSkipped;

  late final TextEditingController nameCtrl;
  late final TextEditingController qtyCtrl;
  late final TextEditingController costCtrl;
  late final TextEditingController sellingPriceCtrl;

  double get currentQty => double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
  double get currentCost => double.tryParse(costCtrl.text.trim()) ?? 0.0;
  double get currentSellingPrice => double.tryParse(sellingPriceCtrl.text.trim()) ?? (currentCost * 1.3);
  double get lineTotal => currentQty * currentCost;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    costCtrl.dispose();
    sellingPriceCtrl.dispose();
  }
}

class SupplierInvoiceScanScreen extends ConsumerStatefulWidget {
  const SupplierInvoiceScanScreen({super.key, required this.supplier});

  final Supplier supplier;

  @override
  ConsumerState<SupplierInvoiceScanScreen> createState() => _SupplierInvoiceScanScreenState();
}

enum _ScanStep { capture, processing, review }

class _SupplierInvoiceScanScreenState extends ConsumerState<SupplierInvoiceScanScreen> {
  _ScanStep _step = _ScanStep.capture;
  String? _imageBase64;
  String? _logId;
  String? _scanId;
  int _elapsedSeconds = 0;
  Timer? _tickerTimer;
  http.Client? _activeClient;

  // Invoice metadata
  final _invoiceNumberCtrl = TextEditingController();
  final _invoiceDateCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  double? _detectedTotal;

  // Review items and catalog products
  final List<_InvoiceReviewItem> _items = [];
  List<Product> _catalogProducts = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _invoiceDateCtrl.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadCatalog();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _activeClient?.close();
    _invoiceNumberCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _paidAmountCtrl.dispose();
    _notesCtrl.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final companyId = ref.read(sessionProvider).companyId;
    if (companyId == null) return;
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'products',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      if (mounted) {
        setState(() {
          _catalogProducts = rows.map((r) => Product.fromJson(r)).toList();
        });
      }
    } catch (_) {}
  }

  void _matchItemsWithCatalog() {
    for (final it in _items) {
      if (it.matchedProductId != null) continue;
      final cleanName = it.name.trim().toLowerCase();
      Product? match;
      for (final p in _catalogProducts) {
        final pName = p.name.trim().toLowerCase();
        if (pName == cleanName || pName.contains(cleanName) || cleanName.contains(pName)) {
          match = p;
          break;
        }
      }
      if (match != null) {
        it.isNewProduct = false;
        it.matchedProductId = match.id;
        it.matchedProductName = match.name;
        it.sellingPrice = match.sellingPrice;
        it.sellingPriceCtrl.text = match.sellingPrice.toStringAsFixed(0);
      }
    }
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 70,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cameraPermissionRequired)),
        );
      }
      return;
    }

    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);

    setState(() {
      _imageBase64 = b64;
      _step = _ScanStep.processing;
      _elapsedSeconds = 0;
    });

    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _step != _ScanStep.processing) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
    });

    await _runExtraction(b64);
  }

  void _loadDemoInvoice() {
    _tickerTimer?.cancel();
    for (final it in _items) {
      it.dispose();
    }
    _items.clear();

    _invoiceNumberCtrl.text = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _detectedTotal = 4250.0;

    _items.addAll([
      _InvoiceReviewItem(name: 'Huile de table 5L', quantity: 10, unitCost: 650.0),
      _InvoiceReviewItem(name: 'Sucre blanc 1kg', quantity: 20, unitCost: 90.0),
      _InvoiceReviewItem(name: 'Farine T55 10kg', quantity: 5, unitCost: 350.0),
    ]);

    _matchItemsWithCatalog();

    setState(() {
      _step = _ScanStep.review;
    });
  }

  Future<void> _runExtraction(String imageBase64) async {
    final scanId = 'SCAN_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    _scanId = scanId;
    _activeClient?.close();
    final client = http.Client();
    _activeClient = client;

    try {
      await ApiClient.detectBestBaseUrl();
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.post(
        '/ai/invoices/scan',
        body: {
          'imageBase64': imageBase64,
          'mimeType': 'image/jpeg',
          'scanId': scanId,
        },
        timeout: const Duration(seconds: 60),
        client: client,
      );

      if (!mounted) return;
      _tickerTimer?.cancel();

      final data = response is Map ? (response['data'] as Map<String, dynamic>? ?? {}) : <String, dynamic>{};
      _logId = data['logId'] as String?;

      if (data['invoiceNumber'] != null && data['invoiceNumber'].toString().isNotEmpty) {
        _invoiceNumberCtrl.text = data['invoiceNumber'].toString();
      } else if (data['invoice_number'] != null && data['invoice_number'].toString().isNotEmpty) {
        _invoiceNumberCtrl.text = data['invoice_number'].toString();
      }

      if (data['date'] != null && data['date'].toString().isNotEmpty) {
        final d = data['date'].toString();
        if (d.length >= 10) _invoiceDateCtrl.text = d.substring(0, 10);
      }

      if (data['total'] is num) {
        _detectedTotal = (data['total'] as num).toDouble();
      }

      final rawItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final it in _items) {
        it.dispose();
      }
      _items.clear();

      for (final raw in rawItems) {
        final name = (raw['name'] ?? raw['product_name'] ?? '').toString();
        final qty = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
        final cost = (raw['unitPrice'] ?? raw['unit_cost'] ?? raw['price'] as num?)?.toDouble() ?? 0.0;
        _items.add(_InvoiceReviewItem(
          name: name.isNotEmpty ? name : 'Article',
          quantity: qty > 0 ? qty : 1.0,
          unitCost: cost >= 0 ? cost : 0.0,
        ));
      }

      if (_items.isEmpty) {
        _items.add(_InvoiceReviewItem(name: '', quantity: 1, unitCost: 0));
      }

      _matchItemsWithCatalog();

      setState(() {
        _step = _ScanStep.review;
      });
    } catch (e) {
      if (!mounted) return;
      _tickerTimer?.cancel();

      // Fallback: let user review with manual entry pre-filled rather than crashing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI extraction unavailable. Please enter items or try demo.'),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'Demo',
            textColor: Colors.white,
            onPressed: _loadDemoInvoice,
          ),
        ),
      );

      if (_items.isEmpty) {
        _items.add(_InvoiceReviewItem(name: '', quantity: 1, unitCost: 0));
      }
      setState(() {
        _step = _ScanStep.review;
      });
    }
  }

  void _addNewLineItem() {
    setState(() {
      _items.add(_InvoiceReviewItem(name: '', quantity: 1, unitCost: 0));
    });
  }

  void _removeOrSkipLineItem(int index) {
    setState(() {
      _items[index].isSkipped = !_items[index].isSkipped;
    });
  }

  void _deleteLineItem(int index) {
    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  double get _calculatedTotal {
    double sum = 0.0;
    for (final it in _items) {
      if (!it.isSkipped) {
        sum += it.lineTotal;
      }
    }
    return sum;
  }

  List<_InvoiceReviewItem> get _activeItems => _items.where((it) => !it.isSkipped).toList();

  Future<void> _handleConfirmReceipt() async {
    final l10n = AppLocalizations.of(context)!;
    final active = _activeItems;

    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noLineItemsWarning), backgroundColor: AppColors.danger),
      );
      return;
    }

    for (final it in active) {
      if (it.nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide names for all active products.'), backgroundColor: AppColors.danger),
        );
        return;
      }
      if (it.currentQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity must be greater than zero.'), backgroundColor: AppColors.danger),
        );
        return;
      }
      if (it.currentCost < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit cost cannot be negative.'), backgroundColor: AppColors.danger),
        );
        return;
      }
    }

    final total = _calculatedTotal;
    final paid = double.tryParse(_paidAmountCtrl.text.trim()) ?? 0.0;
    if (paid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.amountMustBePositive), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (paid > total + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.downPaymentCannotExceedTotal), backgroundColor: AppColors.danger),
      );
      return;
    }

    final invoiceNumber = _invoiceNumberCtrl.text.trim();
    final companyId = ref.read(sessionProvider).companyId;
    if (companyId == null) return;

    // 1. Duplicate Invoice Check
    if (invoiceNumber.isNotEmpty) {
      final db = await AppDatabase.instance.database;
      final existing = await db.query(
        'supplier_purchases',
        where: 'company_id = ? AND supplier_id = ? AND invoice_number = ?',
        whereArgs: [companyId, widget.supplier.id, invoiceNumber],
      );

      if (existing.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: Text(l10n.duplicateInvoiceWarning),
            content: Text('${l10n.invoiceFallback}: $invoiceNumber'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dCtx).pop(false),
                child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(dCtx).pop(true),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    // 2. Receipt Confirmation Summary Dialog
    if (!mounted) return;
    final int toUpdateCount = active.where((it) => !it.isNewProduct).length;
    final int toCreateCount = active.where((it) => it.isNewProduct).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.receivingSummaryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.supplierLabel}: ${widget.supplier.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (invoiceNumber.isNotEmpty) Text('${l10n.invoiceNumberLabel}: $invoiceNumber'),
            Text('${l10n.totalInvoiceAmountLabel}: ${total.toStringAsFixed(0)} DZD'),
            if (paid > 0) Text('${l10n.amountPaidLabel}: ${paid.toStringAsFixed(0)} DZD'),
            Text('${l10n.outstandingDebtLabel}: ${(total - paid).toStringAsFixed(0)} DZD'),
            const Divider(height: 20),
            if (toUpdateCount > 0)
              Row(
                children: [
                  const Icon(Icons.sync, color: AppColors.info, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.productsToUpdateCount(toUpdateCount))),
                ],
              ),
            if (toCreateCount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.newProductsToCreateCount(toCreateCount))),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: Text(l10n.confirmAndReceiveInventory),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dCtx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await _executeReceiptTransaction(
        companyId: companyId,
        activeItems: active,
        totalAmount: total,
        amountPaid: paid,
        invoiceNumber: invoiceNumber.isEmpty ? null : invoiceNumber,
      );

      if (mounted) {
        ref.invalidate(supplierProfileProvider(widget.supplier));
        ref.invalidate(suppliersRepositoryProvider);
        ref.invalidate(productsRepositoryProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryReceivedSuccess(active.length)),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save receipt: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _executeReceiptTransaction({
    required String companyId,
    required List<_InvoiceReviewItem> activeItems,
    required double totalAmount,
    required double amountPaid,
    String? invoiceNumber,
  }) async {
    final db = await AppDatabase.instance.database;
    final clientTxId = 'purch_${DateTime.now().millisecondsSinceEpoch}';
    final purchaseId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();
    final purchaseDate = _invoiceDateCtrl.text.trim().isNotEmpty ? _invoiceDateCtrl.text.trim() : nowIso;
    final outstanding = (totalAmount - amountPaid).clamp(0.0, double.infinity);
    final paymentStatus = outstanding <= 0.005 ? 'paid' : (amountPaid > 0 ? 'partially_paid' : 'unpaid');
    final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final List<Map<String, dynamic>> itemsPayload = [];
    final List<Map<String, dynamic>> newProductsToSync = [];

    await db.transaction((txn) async {
      // 1. Process items: create new products or increment existing
      for (final it in activeItems) {
        String prodId;
        final qtyInt = it.currentQty.round();

        if (it.isNewProduct || it.matchedProductId == null) {
          prodId = const Uuid().v4();
          it.matchedProductId = prodId;

          await txn.insert('products', {
            'id': prodId,
            'company_id': companyId,
            'name': it.nameCtrl.text.trim(),
            'category': it.category.isNotEmpty ? it.category : 'General',
            'purchase_price': it.currentCost,
            'selling_price': it.currentSellingPrice,
            'quantity': qtyInt,
            'minimum_stock': 5,
            'supplier_id': widget.supplier.id,
            'updated_at': nowIso,
          });

          newProductsToSync.add({
            'id': prodId,
            'name': it.nameCtrl.text.trim(),
            'category': it.category.isNotEmpty ? it.category : 'General',
            'purchase_price': it.currentCost,
            'selling_price': it.currentSellingPrice,
            'quantity': qtyInt,
            'supplier_id': widget.supplier.id,
          });
        } else {
          prodId = it.matchedProductId!;
          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ?, purchase_price = ? WHERE id = ? AND company_id = ?',
            [qtyInt, it.currentCost, prodId, companyId],
          );
        }

        // Add line item record
        final itemId = const Uuid().v4();
        await txn.insert('supplier_purchase_items', {
          'id': itemId,
          'purchase_id': purchaseId,
          'company_id': companyId,
          'product_id': prodId,
          'product_name': it.nameCtrl.text.trim(),
          'quantity': it.currentQty,
          'unit_cost': it.currentCost,
          'line_total': it.lineTotal,
          'created_at': nowIso,
        });

        itemsPayload.add({
          'productId': prodId,
          'productName': it.nameCtrl.text.trim(),
          'quantity': it.currentQty,
          'unitCost': it.currentCost,
          'lineTotal': it.lineTotal,
        });
      }

      // 2. Insert supplier purchase header
      await txn.insert('supplier_purchases', {
        'id': purchaseId,
        'company_id': companyId,
        'supplier_id': widget.supplier.id,
        'invoice_number': invoiceNumber,
        'purchase_date': purchaseDate,
        'total_amount': totalAmount,
        'amount_paid': amountPaid,
        'outstanding_balance': outstanding,
        'payment_status': paymentStatus,
        'notes': notes,
        'client_transaction_id': clientTxId,
        'created_at': nowIso,
        'synced': 0,
      });

      // 3. Insert initial down payment if any
      if (amountPaid > 0) {
        final paymentId = const Uuid().v4();
        await txn.insert('supplier_payments', {
          'id': paymentId,
          'company_id': companyId,
          'supplier_id': widget.supplier.id,
          'purchase_id': purchaseId,
          'amount': amountPaid,
          'payment_date': purchaseDate,
          'payment_method': 'cash',
          'reference': invoiceNumber != null ? 'Invoice $invoiceNumber' : null,
          'notes': 'Initial invoice payment',
          'client_id': 'pay_$clientTxId',
          'created_at': nowIso,
          'synced': 0,
        });
      }
    });

    // 4. Enqueue operations for offline sync
    for (final np in newProductsToSync) {
      await ref.read(syncServiceProvider.notifier).enqueueOperation(
        id: const Uuid().v4(),
        clientTransactionId: const Uuid().v4(),
        entityType: 'product',
        entityId: np['id'] as String,
        operationType: 'CREATE',
        payload: np,
      );
    }

    await ref.read(syncServiceProvider.notifier).enqueueOperation(
      id: const Uuid().v4(),
      clientTransactionId: clientTxId,
      entityType: 'supplier_purchase',
      entityId: purchaseId,
      operationType: 'CREATE',
      payload: {
        'supplierId': widget.supplier.id,
        'invoiceNumber': invoiceNumber,
        'purchaseDate': purchaseDate,
        'items': itemsPayload,
        'amountPaid': amountPaid,
        'notes': notes,
      },
    );

    // 5. If online, trigger background sync
    final conn = ref.read(connectionStatusProvider);
    if (conn == ConnectionStatus.online) {
      unawaited(ref.read(syncServiceProvider.notifier).syncPending());
      if (_logId != null) {
        try {
          final client = ref.read(apiClientProvider);
          unawaited(client.post('/ai/invoices/scan/$_logId/confirm'));
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanSupplierInvoiceTitle),
      ),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    switch (_step) {
      case _ScanStep.capture:
        return _buildCaptureStep(context, l10n);
      case _ScanStep.processing:
        return _buildProcessingStep(context, l10n);
      case _ScanStep.review:
        return _buildReviewStep(context, l10n);
    }
  }

  Widget _buildCaptureStep(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Supplier Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.supplier.phone ?? '-', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Viewfinder card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              boxShadow: AppSpacing.cardElevation,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.document_scanner_outlined, size: 54, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.pointCameraAtInvoice,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.keepInvoiceFlatWellLit,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Primary Actions
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: Text(l10n.cameraButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _pickAndScan(ImageSource.camera),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.chooseFromGallery),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => _pickAndScan(ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            icon: const Icon(Icons.play_circle_outline),
            label: Text(l10n.tryDemoInvoice),
            onPressed: _loadDemoInvoice,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingStep(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.analyzingInvoice,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_elapsedSeconds}s',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () {
                _tickerTimer?.cancel();
                _activeClient?.close();
                setState(() => _step = _ScanStep.capture);
              },
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context, AppLocalizations l10n) {
    final calcTotal = _calculatedTotal;
    final bool hasDiscrepancy = _detectedTotal != null && (_detectedTotal! - calcTotal).abs() > 0.5;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Header Summary Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  boxShadow: AppSpacing.cardElevation,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(widget.supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(l10n.retakePhoto),
                          onPressed: () => setState(() => _step = _ScanStep.capture),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _invoiceNumberCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.invoiceNumberLabel,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _invoiceDateCtrl,
                            decoration: InputDecoration(
                              labelText: l10n.invoiceDateLabel,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Discrepancy warning banner if detected total != calculated total
              if (hasDiscrepancy)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.totalDiscrepancyWarning} (${l10n.detectedTotalLabel}: ${_detectedTotal!.toStringAsFixed(0)} DZD vs ${l10n.calculatedTotalLabel}: ${calcTotal.toStringAsFixed(0)} DZD)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A5A00)),
                        ),
                      ),
                    ],
                  ),
                ),

              // Items Section Title & Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.invoiceLinesTitle(_activeItems.length)} (${_activeItems.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.addLineItemButton),
                    onPressed: _addNewLineItem,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Review Items List
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final it = entry.value;
                return _buildItemCard(context, l10n, idx, it);
              }),

              const SizedBox(height: AppSpacing.sm),

              // Down Payment & Notes Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _paidAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.downPaymentLabel,
                        suffixText: 'DZD',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _notesCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.purchaseNotesOptional,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sticky Bottom Confirmation Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${calcTotal.toStringAsFixed(0)} DZD',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                      ),
                      Text(
                        l10n.itemsToReceiveCount(_activeItems.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(l10n.confirmAndReceiveInventory),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onPressed: _isSaving ? null : _handleConfirmReceipt,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, AppLocalizations l10n, int index, _InvoiceReviewItem item) {
    final isSkipped = item.isSkipped;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isSkipped ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: isSkipped ? Colors.grey.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Item Index, Line total, Skip/Delete buttons
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isSkipped ? Colors.grey : AppColors.primary,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.lineTotal.toStringAsFixed(0)} DZD',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(isSkipped ? Icons.undo : Icons.visibility_off_outlined, size: 20),
                  tooltip: isSkipped ? l10n.restoreItem : l10n.skipItem,
                  onPressed: () => _removeOrSkipLineItem(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                  tooltip: l10n.removeLineItemButton,
                  onPressed: () => _deleteLineItem(index),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Product Name input
            TextField(
              controller: item.nameCtrl,
              enabled: !isSkipped,
              decoration: InputDecoration(
                labelText: l10n.dishNameLabel,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (val) {
                item.name = val;
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.xs),

            // Quantity & Unit Cost
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.qtyCtrl,
                    enabled: !isSkipped,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.quantityLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (val) {
                      item.quantity = double.tryParse(val.trim()) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: item.costCtrl,
                    enabled: !isSkipped,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.unitCostLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (val) {
                      item.unitCost = double.tryParse(val.trim()) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Catalog Matching row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.isNewProduct
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isNewProduct ? Icons.add_box_outlined : Icons.link,
                    size: 16,
                    color: item.isNewProduct ? AppColors.success : AppColors.info,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.isNewProduct
                          ? l10n.createNewProductOption
                          : '${l10n.matchedProductLabel}: ${item.matchedProductName ?? item.name}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.isNewProduct ? AppColors.success : AppColors.info,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: isSkipped ? null : () => _showProductMatchingPicker(index, item),
                    child: Text(item.isNewProduct ? l10n.matchedProductLabel : l10n.editAction, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            if (item.isNewProduct && !isSkipped) ...[
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: item.sellingPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.sellingPriceLabel,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (val) {
                  item.sellingPrice = double.tryParse(val.trim());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showProductMatchingPicker(int index, _InvoiceReviewItem item) {
    final l10n = AppLocalizations.of(context)!;
    final searchCtrl = TextEditingController();
    List<Product> filtered = List.from(_catalogProducts);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bCtx) => SizedBox(
        height: MediaQuery.of(bCtx).size.height * 0.75,
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.of(bCtx).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.matchedProductLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchCatalogHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (q) {
                  setSheetState(() {
                    if (q.trim().isEmpty) {
                      filtered = List.from(_catalogProducts);
                    } else {
                      final term = q.trim().toLowerCase();
                      filtered = _catalogProducts.where((p) => p.name.toLowerCase().contains(term)).toList();
                    }
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: const Icon(Icons.add_circle_outline, color: AppColors.success),
                title: Text(l10n.createNewProductOption),
                onTap: () {
                  setState(() {
                    item.isNewProduct = true;
                    item.matchedProductId = null;
                    item.matchedProductName = null;
                  });
                  Navigator.of(bCtx).pop();
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    return ListTile(
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${l10n.inStockLabel}: ${p.quantity} · ${p.sellingPrice.toStringAsFixed(0)} DZD'),
                      onTap: () {
                        setState(() {
                          item.isNewProduct = false;
                          item.matchedProductId = p.id;
                          item.matchedProductName = p.name;
                          item.sellingPrice = p.sellingPrice;
                          item.sellingPriceCtrl.text = p.sellingPrice.toStringAsFixed(0);
                        });
                        Navigator.of(bCtx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
