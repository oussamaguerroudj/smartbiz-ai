import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desktop_components.dart';
import '../../../core/widgets/glass_panel.dart';

class DesktopInventoryScreen extends StatefulWidget {
  const DesktopInventoryScreen({super.key});

  @override
  State<DesktopInventoryScreen> createState() => _DesktopInventoryScreenState();
}

class _DesktopInventoryScreenState extends State<DesktopInventoryScreen> {
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _items = [
    {
      'sku': '6191234567890',
      'name': 'Premium Espresso Beans 1kg',
      'category': 'Beverages',
      'stock': 42,
      'cost': 14.00,
      'price': 24.50,
    },
    {
      'sku': '6191234567891',
      'name': 'Organic Colombian Roast 500g',
      'category': 'Beverages',
      'stock': 18,
      'cost': 9.50,
      'price': 16.00,
    },
    {
      'sku': '6191234567892',
      'name': 'Artisan Sourdough Loaf',
      'category': 'Bakery',
      'stock': 6,
      'cost': 2.80,
      'price': 6.50,
    },
    {
      'sku': '6191234567893',
      'name': 'French Butter Croissant (x4)',
      'category': 'Bakery',
      'stock': 12,
      'cost': 4.20,
      'price': 9.00,
    },
    {
      'sku': '6191234567894',
      'name': 'Extra Virgin Olive Oil 750ml',
      'category': 'Pantry',
      'stock': 3,
      'cost': 11.00,
      'price': 18.25,
    },
  ];

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final skuCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevatedDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add New Product', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Selling Price (\$)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Cost Price (\$)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Stock Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: skuCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Barcode / SKU'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                setState(() {
                  _items.add({
                    'sku': skuCtrl.text.isNotEmpty ? skuCtrl.text : 'SKU-${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameCtrl.text,
                    'category': 'General',
                    'stock': int.tryParse(stockCtrl.text) ?? 10,
                    'cost': double.tryParse(costCtrl.text) ?? 0.0,
                    'price': double.tryParse(priceCtrl.text) ?? 1.0,
                  });
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save Product'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((i) {
      return query.isEmpty ||
          i['name'].toString().toLowerCase().contains(query) ||
          i['sku'].toString().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopPageHeader(
            title: 'Inventory & Product Catalog',
            subtitle: 'Manage stock levels, cost valuation, and barcode tracking.',
            actions: [
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Product'),
              ),
            ],
          ),

          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search by product name, SKU, or barcode...',
                    prefixIcon: Icon(Icons.search, color: AppColors.electricBlue),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Table
          Expanded(
            child: GlassPanel(
              padding: EdgeInsets.zero,
              child: DesktopDataTable(
                columns: const [
                  'SKU / Barcode',
                  'Product Name',
                  'Category',
                  'In Stock',
                  'Cost Price',
                  'Sale Price',
                  'Margin',
                ],
                rows: filtered.map((item) {
                  final cost = item['cost'] as double;
                  final price = item['price'] as double;
                  final margin = price > 0 ? ((price - cost) / price) * 100 : 0.0;
                  final stock = item['stock'] as int;
                  final isLow = stock <= 5;

                  return [
                    Text(item['sku'] as String, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text(item['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(item['category'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$stock units', style: TextStyle(color: isLow ? AppColors.neonRose : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        if (isLow) ...[
                          const SizedBox(width: 6),
                          const DesktopBadge(label: 'LOW', color: AppColors.neonRose),
                        ],
                      ],
                    ),
                    Text(_currency.format(cost), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(_currency.format(price), style: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${margin.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.neonEmerald, fontWeight: FontWeight.w600, fontSize: 12)),
                  ];
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
