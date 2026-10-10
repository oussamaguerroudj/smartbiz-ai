import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';

class PosItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String barcode;

  const PosItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.barcode,
  });
}

class CartLine {
  final PosItem item;
  int quantity;

  CartLine({required this.item, this.quantity = 1});

  double get total => item.price * quantity;
}

class DesktopPosScreen extends StatefulWidget {
  const DesktopPosScreen({super.key});

  @override
  State<DesktopPosScreen> createState() => _DesktopPosScreenState();
}

class _DesktopPosScreenState extends State<DesktopPosScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _searchController = TextEditingController();

  // Multi-Cart State
  int _activeCartIndex = 0;
  final List<List<CartLine>> _carts = [
    [],
    [],
    [],
  ];

  String _selectedCategory = 'All';

  final List<PosItem> _catalog = const [
    PosItem(id: '1', name: 'Premium Espresso Beans 1kg', price: 24.50, category: 'Beverages', barcode: '6191234567890'),
    PosItem(id: '2', name: 'Organic Colombian Roast 500g', price: 16.00, category: 'Beverages', barcode: '6191234567891'),
    PosItem(id: '3', name: 'Artisan Sourdough Loaf', price: 6.50, category: 'Bakery', barcode: '6191234567892'),
    PosItem(id: '4', name: 'French Butter Croissant (x4)', price: 9.00, category: 'Bakery', barcode: '6191234567893'),
    PosItem(id: '5', name: 'Extra Virgin Olive Oil 750ml', price: 18.25, category: 'Pantry', barcode: '6191234567894'),
    PosItem(id: '6', name: 'Organic Almond Milk 1L', price: 4.80, category: 'Dairy & Alt', barcode: '6191234567895'),
    PosItem(id: '7', name: 'Dark Chocolate Bar 85%', price: 5.50, category: 'Snacks', barcode: '6191234567896'),
    PosItem(id: '8', name: 'Sparkling Mineral Water 330ml', price: 2.20, category: 'Beverages', barcode: '6191234567897'),
  ];

  List<CartLine> get _activeCart => _carts[_activeCartIndex];

  double get _subtotal => _activeCart.fold(0.0, (sum, line) => sum + line.total);
  double get _discount => 0.0;
  double get _total => _subtotal - _discount;

  void _addToCart(PosItem item) {
    setState(() {
      final existingIndex = _activeCart.indexWhere((line) => line.item.id == item.id);
      if (existingIndex >= 0) {
        _activeCart[existingIndex].quantity += 1;
      } else {
        _activeCart.add(CartLine(item: item));
      }
    });
  }

  void _completeSale(String method) {
    if (_activeCart.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevatedDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.neonEmerald),
            SizedBox(width: 10),
            Text('Sale Completed', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paid via $method: ${_currencyFormat.format(_total)}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Receipt sent to thermal printer & recorded in local SQLite database.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _activeCart.clear();
              });
            },
            child: const Text('Start Next Order'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _catalog.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final query = _searchController.text.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.barcode.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Multi-Cart Tab Bar
          Row(
            children: [
              for (int i = 0; i < _carts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => setState(() => _activeCartIndex = i),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeCartIndex == i
                            ? AppColors.electricBlue.withOpacity(0.15)
                            : AppColors.surfaceElevatedDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _activeCartIndex == i
                              ? AppColors.electricBlue
                              : AppColors.borderDark,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 16,
                            color: _activeCartIndex == i
                                ? AppColors.electricBlue
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cart ${i + 1}',
                            style: TextStyle(
                              color: _activeCartIndex == i
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (_carts[i].isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.electricBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_carts[i].fold(0, (sum, l) => sum + l.quantity)}',
                                style: const TextStyle(
                                  color: AppColors.cyberNavyDeep,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Main Split Panes
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Product Catalog & Search
                Expanded(
                  flex: 3,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Catalog Search & Hardware Scanner Barcode Input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Scan Barcode or Search Products...',
                                  prefixIcon: const Icon(Icons.qr_code_scanner, color: AppColors.electricBlue),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () => setState(() => _searchController.clear()),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Category Pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Beverages', 'Bakery', 'Pantry', 'Dairy & Alt', 'Snacks']
                                .map((cat) => Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ChoiceChip(
                                        label: Text(cat),
                                        selected: _selectedCategory == cat,
                                        onSelected: (_) => setState(() => _selectedCategory = cat),
                                        backgroundColor: AppColors.surfaceElevatedDark,
                                        selectedColor: AppColors.electricBlue.withOpacity(0.2),
                                        labelStyle: TextStyle(
                                          color: _selectedCategory == cat
                                              ? AppColors.electricBlue
                                              : AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                        side: BorderSide(
                                          color: _selectedCategory == cat
                                              ? AppColors.electricBlue
                                              : AppColors.borderDark,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Products Grid
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, i) {
                              final item = filteredItems[i];
                              return InkWell(
                                onTap: () => _addToCart(item),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevatedDark,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.borderDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _currencyFormat.format(item.price),
                                            style: const TextStyle(
                                              color: AppColors.electricBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppColors.electricBlue.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.add, size: 16, color: AppColors.electricBlue),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Right: Active Cart & Fast Checkout
                Expanded(
                  flex: 2,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cart ${_activeCartIndex + 1} Checkout',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (_activeCart.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() => _activeCart.clear()),
                                child: const Text('Clear', style: TextStyle(color: AppColors.neonRose, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Cart Line Items List
                        Expanded(
                          child: _activeCart.isEmpty
                              ? const Center(
                                  child: Text('No items in cart.\nClick products to add.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                )
                              : ListView.separated(
                                  itemCount: _activeCart.length,
                                  separatorBuilder: (_, __) => const Divider(color: AppColors.borderDark, height: 1),
                                  itemBuilder: (context, i) {
                                    final line = _activeCart[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(line.item.name,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                                Text(_currencyFormat.format(line.item.price),
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                              ],
                                            ),
                                          ),
                                          // Stepper
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove, size: 14),
                                                onPressed: () {
                                                  setState(() {
                                                    if (line.quantity > 1) {
                                                      line.quantity--;
                                                    } else {
                                                      _activeCart.removeAt(i);
                                                    }
                                                  });
                                                },
                                              ),
                                              Text('${line.quantity}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                              IconButton(
                                                icon: const Icon(Icons.add, size: 14),
                                                onPressed: () => setState(() => line.quantity++),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_currencyFormat.format(line.total),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        const Divider(color: AppColors.borderDark),

                        // Totals Calculation
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  Text(_currencyFormat.format(_subtotal), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Due', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                  Text(_currencyFormat.format(_total),
                                      style: const TextStyle(color: AppColors.electricBlue, fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Payment Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _activeCart.isEmpty ? null : () => _completeSale('Cash'),
                                icon: const Icon(Icons.money, size: 18),
                                label: const Text('Cash (F1)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neonEmerald,
                                  foregroundColor: AppColors.cyberNavyDeep,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _activeCart.isEmpty ? null : () => _completeSale('Card'),
                                icon: const Icon(Icons.credit_card, size: 18),
                                label: const Text('Card (F2)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.electricBlue,
                                  foregroundColor: AppColors.cyberNavyDeep,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
