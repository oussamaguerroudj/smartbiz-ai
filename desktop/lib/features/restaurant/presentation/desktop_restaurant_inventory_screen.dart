import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../ai/presentation/desktop_ai_invoice_scanner_screen.dart';

class RestaurantInventoryItem {
  final String id;
  final String companyId;
  final String name;
  final String? category;
  final String unit;
  final double quantity;
  final double minimumStock;
  final double purchasePrice;
  final double? sellingPrice;
  final String? supplier;
  final String? expirationDate;
  final String? notes;

  const RestaurantInventoryItem({
    required this.id,
    required this.companyId,
    required this.name,
    this.category,
    this.unit = 'unit',
    this.quantity = 0.0,
    this.minimumStock = 0.0,
    this.purchasePrice = 0.0,
    this.sellingPrice,
    this.supplier,
    this.expirationDate,
    this.notes,
  });

  bool get isLowStock => quantity <= minimumStock;
  bool get isOutOfStock => quantity <= 0.0;
  double get totalValuation => (quantity > 0 ? quantity : 0.0) * purchasePrice;

  factory RestaurantInventoryItem.fromMap(Map<String, dynamic> map) {
    return RestaurantInventoryItem(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Item',
      category: map['category']?.toString(),
      unit: map['unit']?.toString() ?? 'unit',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (map['minimum_stock'] as num?)?.toDouble() ?? (map['minimumStock'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? (map['sellingPrice'] as num?)?.toDouble(),
      supplier: map['supplier']?.toString(),
      expirationDate: map['expiration_date']?.toString() ?? map['expirationDate']?.toString(),
      notes: map['notes']?.toString(),
    );
  }
}

class DesktopRestaurantInventoryScreen extends ConsumerStatefulWidget {
  const DesktopRestaurantInventoryScreen({super.key});

  @override
  ConsumerState<DesktopRestaurantInventoryScreen> createState() =>
      _DesktopRestaurantInventoryScreenState();
}

class _DesktopRestaurantInventoryScreenState
    extends ConsumerState<DesktopRestaurantInventoryScreen> {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  final _searchController = TextEditingController();
  bool _isLoading = true;
  bool _lowStockOnly = false;
  String _searchQuery = '';
  List<RestaurantInventoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    List<RestaurantInventoryItem> localItems = [];
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final rows = await db.query(
        'restaurant_inventory_items',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      localItems = rows.map(RestaurantInventoryItem.fromMap).toList();
    } catch (_) {}

    // Online refresh
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/restaurant/inventory');
      if (res is Map && res['data'] is List) {
        final serverRows = (res['data'] as List).cast<Map<String, dynamic>>();
        final db = await ModiriDesktopDatabase.instance.database;
        final batch = db.batch();
        for (final r in serverRows) {
          batch.insert(
            'restaurant_inventory_items',
            {
              'id': r['id']?.toString() ?? const Uuid().v4(),
              'company_id': companyId,
              'name': r['name'] ?? 'Item',
              'category': r['category'],
              'unit': r['unit'] ?? 'unit',
              'quantity': (r['quantity'] as num?)?.toDouble() ?? 0.0,
              'minimum_stock': (r['minimum_stock'] as num?)?.toDouble() ?? (r['minimumStock'] as num?)?.toDouble() ?? 0.0,
              'purchase_price': (r['purchase_price'] as num?)?.toDouble() ?? (r['purchasePrice'] as num?)?.toDouble() ?? 0.0,
              'selling_price': (r['selling_price'] as num?)?.toDouble() ?? (r['sellingPrice'] as num?)?.toDouble(),
              'supplier': r['supplier'],
              'expiration_date': r['expiration_date'] ?? r['expirationDate'],
              'notes': r['notes'],
              'created_at': r['created_at'] ?? DateTime.now().toIso8601String(),
              'synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);

        final updatedRows = await db.query(
          'restaurant_inventory_items',
          where: 'company_id = ?',
          whereArgs: [companyId],
          orderBy: 'name ASC',
        );
        localItems = updatedRows.map(RestaurantInventoryItem.fromMap).toList();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _items = localItems;
        _isLoading = false;
      });
    }
  }

  List<RestaurantInventoryItem> get _filteredItems {
    return _items.where((it) {
      if (_lowStockOnly && !it.isLowStock) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = it.name.toLowerCase().contains(q);
        final matchesCat = it.category?.toLowerCase().contains(q) ?? false;
        final matchesSup = it.supplier?.toLowerCase().contains(q) ?? false;
        if (!matchesName && !matchesCat && !matchesSup) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _showAddModal({RestaurantInventoryItem? existing}) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'kg');
    final qtyCtrl = TextEditingController(text: existing?.quantity.toString() ?? '0');
    final minCtrl = TextEditingController(text: existing?.minimumStock.toString() ?? '5');
    final priceCtrl = TextEditingController(text: existing?.purchasePrice.toString() ?? '0');
    final supCtrl = TextEditingController(text: existing?.supplier ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        title: Text(
          existing == null ? loc.get('add_raw_material') : loc.get('edit'),
          style: TextStyle(color: ModiriColors.textPrimary(isDark)),
        ),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '${loc.get("name_label")} *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? loc.get('required') : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: catCtrl,
                          decoration: InputDecoration(
                            labelText: loc.get('category'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: unitCtrl,
                          decoration: InputDecoration(
                            labelText: loc.get('unit'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: loc.get('quantity_unit'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: minCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: loc.get('min_stock'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: loc.get('purchase_cost'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: supCtrl,
                          decoration: InputDecoration(
                            labelText: loc.get('suppliers'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text(loc.get('save_changes')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
      final id = existing?.id ?? const Uuid().v4();
      final nowIso = DateTime.now().toIso8601String();
      final name = nameCtrl.text.trim();
      final category = catCtrl.text.trim();
      final unit = unitCtrl.text.trim();
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
      final minStock = double.tryParse(minCtrl.text.trim()) ?? 0.0;
      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
      final supplier = supCtrl.text.trim();

      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.insert(
          'restaurant_inventory_items',
          {
            'id': id,
            'company_id': companyId,
            'name': name,
            'category': category.isEmpty ? null : category,
            'unit': unit.isEmpty ? 'unit' : unit,
            'quantity': qty,
            'minimum_stock': minStock,
            'purchase_price': price,
            'supplier': supplier.isEmpty ? null : supplier,
            'created_at': nowIso,
            'synced': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'restaurant_inventory_item',
          entityId: id,
          operationType: existing == null ? 'CREATE' : 'UPDATE',
          payload: {
            'name': name,
            'category': category,
            'unit': unit,
            'openingQuantity': qty,
            'minimumStock': minStock,
            'purchasePrice': price,
            'supplier': supplier,
          },
        );

        _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.get('ingredient_added_success')), backgroundColor: ModiriColors.brandTeal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('restaurant_item_save_failed')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  Future<void> _showAdjustModal(RestaurantInventoryItem item) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String movementType = 'purchase'; // 'purchase' | 'consumption'

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          title: Text('${loc.get("adjust_stock")}: ${item.name}', style: TextStyle(color: ModiriColors.textPrimary(isDark))),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(loc.get('restock_purchase'), style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark))),
                        value: 'purchase',
                        groupValue: movementType,
                        onChanged: (v) => setDialogState(() => movementType = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(loc.get('consumption'), style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark))),
                        value: 'consumption',
                        groupValue: movementType,
                        onChanged: (v) => setDialogState(() => movementType = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${loc.get("quantity_unit")} (${item.unit})',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: loc.get('notes'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(loc.get('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.get('save_changes')),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final change = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
      if (change <= 0) return;
      final delta = movementType == 'purchase' ? change : -change;
      final newQty = (item.quantity + delta).clamp(0.0, double.infinity);

      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.update(
          'restaurant_inventory_items',
          {'quantity': newQty, 'synced': 0},
          where: 'id = ?',
          whereArgs: [item.id],
        );

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'restaurant_inventory_item',
          entityId: item.id,
          operationType: 'UPDATE',
          payload: {
            'movementType': movementType,
            'quantityChange': delta,
            'note': noteCtrl.text.trim(),
          },
        );

        _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.get('stock_adjusted_success')), backgroundColor: ModiriColors.brandTeal),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('restaurant_stock_adjust_failed')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(RestaurantInventoryItem item) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        title: Text(loc.get('delete'), style: TextStyle(color: ModiriColors.textPrimary(isDark))),
        content: Text('${loc.get('confirm_remove_ingredient')} "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(loc.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.get('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('restaurant_inventory_items', where: 'id = ?', whereArgs: [item.id]);

        await ref.read(desktopSyncServiceProvider.notifier).enqueueOperation(
          id: const Uuid().v4(),
          clientTransactionId: const Uuid().v4(),
          entityType: 'restaurant_inventory_item',
          entityId: item.id,
          operationType: 'DELETE',
          payload: {},
        );

        _loadInventory();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('delete_failed_prefix')} $e'), backgroundColor: ModiriColors.brandRose),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final items = _filteredItems;

    final totalItems = _items.length;
    final lowStockCount = _items.where((it) => it.isLowStock).length;
    final outOfStockCount = _items.where((it) => it.isOutOfStock).length;
    final totalValuation = _items.fold<double>(0.0, (acc, it) => acc + it.totalValuation);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.get('raw_materials'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ModiriColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.get('raw_materials_subtitle'),
                        style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.document_scanner_outlined, size: 16, color: ModiriColors.brandAmber),
                      label: Text(loc.get('ai_scanner')),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (sCtx) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Scaffold(
                                appBar: AppBar(
                                  title: Text(loc.get('ai_scanner_title')),
                                  leading: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.of(sCtx).pop(),
                                  ),
                                ),
                                body: const DesktopAiInvoiceScannerScreen(initialMode: InvoiceScanMode.purchase),
                              ),
                            ),
                          ),
                        ).then((_) => _loadInventory());
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModiriColors.brandAmber,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(loc.get('add_raw_material')),
                      onPressed: () => _showAddModal(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: loc.get('refresh'),
                      onPressed: _loadInventory,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Top Metric Cards
            Row(
              children: [
                Expanded(
                  child: ModiriPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.get('total_ingredients'), style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark))),
                        const SizedBox(height: 6),
                        Text('$totalItems', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModiriPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.get('low_stock_items'), style: const TextStyle(fontSize: 12, color: ModiriColors.brandAmber)),
                        const SizedBox(height: 6),
                        Text('$lowStockCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.brandAmber)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModiriPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.get('out_of_stock'), style: const TextStyle(fontSize: 12, color: ModiriColors.brandRose)),
                        const SizedBox(height: 6),
                        Text('$outOfStockCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.brandRose)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModiriPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.get('stock_valuation'), style: const TextStyle(fontSize: 12, color: ModiriColors.brandTeal)),
                        const SizedBox(height: 6),
                        Text(_formatCurrency(totalValuation), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ModiriColors.brandTeal, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Filter Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: loc.get('search_ingredients_hint'),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text('${loc.get('low_stock_only')} ($lowStockCount)'),
                  selected: _lowStockOnly,
                  onSelected: (v) => setState(() => _lowStockOnly = v),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? Center(
                          child: Text(
                            loc.get('no_raw_materials_found'),
                            style: TextStyle(color: ModiriColors.textSecondary(isDark)),
                          ),
                        )
                      : ModiriPanel(
                          padding: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                              ),
                              columns: [
                                DataColumn(label: Text(loc.get('name_label'))),
                                DataColumn(label: Text(loc.get('category'))),
                                DataColumn(label: Text(loc.get('quantity_unit'))),
                                DataColumn(label: Text(loc.get('min_stock'))),
                                DataColumn(label: Text(loc.get('purchase_cost'))),
                                DataColumn(label: Text(loc.get('status'))),
                                DataColumn(label: Text(loc.get('suppliers'))),
                                DataColumn(label: Text(loc.get('actions'))),
                              ],
                              rows: items.map((it) {
                                Color statusColor = ModiriColors.brandTeal;
                                String statusLabel = loc.get('in_stock');
                                if (it.isOutOfStock) {
                                  statusColor = ModiriColors.brandRose;
                                  statusLabel = loc.get('out_of_stock');
                                } else if (it.isLowStock) {
                                  statusColor = ModiriColors.brandAmber;
                                  statusLabel = loc.get('low_stock');
                                }

                                return DataRow(
                                  cells: [
                                    DataCell(Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(it.category ?? '-')),
                                    DataCell(Text('${it.quantity} ${it.unit}', style: const TextStyle(fontFamily: 'monospace'))),
                                    DataCell(Text('${it.minimumStock} ${it.unit}', style: const TextStyle(fontFamily: 'monospace'))),
                                    DataCell(Text(_formatCurrency(it.purchasePrice), style: const TextStyle(fontFamily: 'monospace'))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
                                        ),
                                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    DataCell(Text(it.supplier ?? '-')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.tune, size: 16, color: ModiriColors.brandAmber),
                                            tooltip: loc.get('adjust_stock'),
                                            onPressed: () => _showAdjustModal(it),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 16, color: ModiriColors.brandBlue),
                                            tooltip: loc.get('edit'),
                                            onPressed: () => _showAddModal(existing: it),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: ModiriColors.brandRose),
                                            tooltip: loc.get('delete'),
                                            onPressed: () => _deleteItem(it),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
