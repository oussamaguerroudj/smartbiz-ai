import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/barcode_scanner_handler.dart';
import '../../../core/utils/barcode_validator.dart';
import '../../../core/utils/receipt_printer.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../ai/presentation/desktop_ai_invoice_scanner_screen.dart';
import '../../customers/presentation/desktop_customers_screen.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';

class CartLine {
  final Product product;
  int quantity;

  CartLine({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

class DesktopCartSession {
  final String id;
  String customerName;
  String? customerId;
  double discount;
  String paymentMethod;
  String status; // 'ACTIVE' | 'ON_HOLD' | 'COMPLETED'
  final List<CartLine> items;

  DesktopCartSession({
    required this.id,
    this.customerName = 'Walk-in Customer',
    this.customerId,
    this.discount = 0.0,
    this.paymentMethod = 'cash',
    this.status = 'ACTIVE',
    List<CartLine>? items,
  }) : items = items ?? [];
}

class DesktopPosScreen extends ConsumerStatefulWidget {
  const DesktopPosScreen({super.key});

  @override
  ConsumerState<DesktopPosScreen> createState() => _DesktopPosScreenState();
}

class _DesktopPosScreenState extends ConsumerState<DesktopPosScreen> with SingleTickerProviderStateMixin {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);

  String _formatCurrency(num? amount, [String? langCode]) {
    return ModiriFormatters.formatCurrency(amount, languageCode: langCode ?? ref.read(desktopLocaleProvider).languageCode);
  }

  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _salesSearchController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  late final BarcodeScannerHandler _scannerHandler;
  late final TabController _tabController;

  int _activeCartIndex = 0;
  final List<DesktopCartSession> _cartSessions = [
    DesktopCartSession(id: const Uuid().v4()),
  ];

  String? _scannerFeedback;
  bool _scannerError = false;

  String _selectedCustomer = 'Walk-in Customer';
  List<String> _customerList = ['Walk-in Customer'];
  String _paymentMethod = 'cash'; // 'cash' | 'card' | 'credit'

  // Sales History State
  bool _loadingSales = false;
  bool _isCheckingOut = false;
  List<dynamic> _salesHistory = [];
  String _salesSearchQuery = '';
  String? _salesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scannerHandler = BarcodeScannerHandler(onScan: _onScan);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _loadSalesHistory();
    _loadCustomers();
    _loadCartSessions();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (_barcodeFocusNode.hasFocus || primaryFocus?.context?.widget is EditableText) {
      return false;
    }
    return _scannerHandler.handleKeyEvent(event);
  }

  Future<void> _loadCustomers() async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final rows = await db.query(
        'customers',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
      final names = ['Walk-in Customer', ...rows.map((r) => r['name'] as String).where((n) => n != 'Walk-in Customer')];
      if (mounted) {
        setState(() {
          _customerList = names;
          if (!_customerList.contains(_selectedCustomer)) {
            _selectedCustomer = 'Walk-in Customer';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCartSessions() async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final sessionRows = await db.query(
        'cart_sessions',
        where: "company_id = ? AND status IN ('ACTIVE', 'ON_HOLD')",
        whereArgs: [companyId],
        orderBy: 'created_at ASC',
      );

      if (sessionRows.isNotEmpty) {
        final List<DesktopCartSession> loaded = [];
        for (final sRow in sessionRows) {
          final sId = sRow['id'] as String;
          final itemRows = await db.query(
            'cart_session_items',
            where: 'cart_session_id = ? AND company_id = ?',
            whereArgs: [sId, companyId],
          );

          final List<CartLine> lines = [];
          for (final iRow in itemRows) {
            final pId = iRow['product_id'] as String;
            final pName = iRow['product_name'] as String;
            final pPrice = (iRow['unit_price'] as num?)?.toDouble() ?? 0.0;
            final pCost = (iRow['unit_cost'] as num?)?.toDouble() ?? 0.0;
            final pQty = (iRow['quantity'] as num?)?.toInt() ?? 1;

            lines.add(CartLine(
              product: Product(
                id: pId,
                companyId: companyId,
                name: pName,
                price: pPrice,
                costPrice: pCost,
              ),
              quantity: pQty,
            ));
          }

          loaded.add(DesktopCartSession(
            id: sId,
            customerName: (sRow['customer_name'] as String?) ?? 'Walk-in Customer',
            customerId: sRow['customer_id'] as String?,
            discount: (sRow['discount'] as num?)?.toDouble() ?? 0.0,
            status: (sRow['status'] as String?) ?? 'ACTIVE',
            items: lines,
          ));
        }

        if (loaded.isEmpty) {
          loaded.add(DesktopCartSession(id: const Uuid().v4()));
        }

        if (mounted) {
          setState(() {
            _cartSessions.clear();
            _cartSessions.addAll(loaded);
            _activeCartIndex = 0;
            _selectedCustomer = _cartSessions[0].customerName;
            _paymentMethod = _cartSessions[0].paymentMethod;
            _discountController.text = _cartSessions[0].discount > 0 ? _cartSessions[0].discount.toStringAsFixed(0) : '0';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _persistCurrentCart() async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    if (_activeCartIndex < 0 || _activeCartIndex >= _cartSessions.length) return;
    final current = _cartSessions[_activeCartIndex];
    current.discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    current.customerName = _selectedCustomer;
    current.paymentMethod = _paymentMethod;
    final nowIso = DateTime.now().toIso8601String();

    try {
      final db = await ModiriDesktopDatabase.instance.database;
      await db.insert(
        'cart_sessions',
        {
          'id': current.id,
          'company_id': companyId,
          'customer_id': current.customerId,
          'customer_name': current.customerName,
          'status': current.status,
          'discount': current.discount,
          'created_at': nowIso,
          'updated_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await db.delete('cart_session_items', where: 'cart_session_id = ?', whereArgs: [current.id]);
      for (final it in current.items) {
        await db.insert('cart_session_items', {
          'id': const Uuid().v4(),
          'cart_session_id': current.id,
          'company_id': companyId,
          'product_id': it.product.id,
          'product_name': it.product.name,
          'quantity': it.quantity,
          'unit_price': it.product.price,
          'unit_cost': it.product.costPrice,
        });
      }
    } catch (_) {}
  }

  Future<void> _switchCart(int idx) async {
    if (idx == _activeCartIndex || idx < 0 || idx >= _cartSessions.length) return;
    await _persistCurrentCart();
    if (mounted) {
      setState(() {
        _activeCartIndex = idx;
        final target = _cartSessions[idx];
        _selectedCustomer = target.customerName;
        _paymentMethod = target.paymentMethod;
        _discountController.text = target.discount > 0 ? target.discount.toStringAsFixed(0) : '0';
      });
    }
  }

  Future<void> _parkCurrentCart() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    if (_activeCart.isEmpty) return;
    setState(() {
      _cartSessions[_activeCartIndex].status = 'ON_HOLD';
    });
    await _persistCurrentCart();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('cart_parked_success')),
          backgroundColor: ModiriColors.brandAmber,
        ),
      );
    }
    int next = _cartSessions.indexWhere((c) => c.status == 'ACTIVE' && c.items.isEmpty);
    if (next == -1) {
      next = _cartSessions.indexWhere((c) => c.status == 'ACTIVE');
    }
    if (next != -1 && next != _activeCartIndex) {
      await _switchCart(next);
    } else {
      _addNewCart();
    }
  }

  void _addNewCart() {
    final newCart = DesktopCartSession(id: const Uuid().v4());
    setState(() {
      _cartSessions.add(newCart);
    });
    _switchCart(_cartSessions.length - 1);
  }

  Future<void> _deleteCartSession(int idx) async {
    if (idx < 0 || idx >= _cartSessions.length) return;
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final session = _cartSessions[idx];
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      await db.delete('cart_session_items', where: 'cart_session_id = ?', whereArgs: [session.id]);
      await db.delete('cart_sessions', where: 'id = ?', whereArgs: [session.id]);
    } catch (_) {}

    final wasMultiple = _cartSessions.length > 1;

    if (mounted) {
      setState(() {
        if (wasMultiple) {
          _cartSessions.removeAt(idx);
          if (_activeCartIndex >= _cartSessions.length) {
            _activeCartIndex = _cartSessions.length - 1;
          } else if (_activeCartIndex == idx) {
            _activeCartIndex = _activeCartIndex.clamp(0, _cartSessions.length - 1);
          }
        } else {
          _cartSessions[0].items.clear();
          _cartSessions[0].discount = 0.0;
          _cartSessions[0].customerName = 'Walk-in Customer';
          _cartSessions[0].status = 'ACTIVE';
          _activeCartIndex = 0;
        }
        final target = _cartSessions[_activeCartIndex];
        _selectedCustomer = target.customerName;
        _paymentMethod = target.paymentMethod;
        _discountController.text = target.discount > 0 ? target.discount.toStringAsFixed(0) : '0';
      });
      await _persistCurrentCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasMultiple ? loc.get('cart_deleted') : loc.get('cart_cleared')),
            backgroundColor: ModiriColors.brandTeal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _clearCurrentCart() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    setState(() {
      _activeCart.clear();
      _discountController.text = '0';
      _cartSessions[_activeCartIndex].customerName = 'Walk-in Customer';
      _selectedCustomer = 'Walk-in Customer';
      _paymentMethod = 'cash';
    });
    await _persistCurrentCart();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('cart_cleared')),
          backgroundColor: ModiriColors.brandTeal,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _scannerHandler.clear();
    _searchController.dispose();
    _barcodeController.dispose();
    _discountController.dispose();
    _salesSearchController.dispose();
    _barcodeFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<CartLine> get _activeCart => _cartSessions[_activeCartIndex].items;
  double get _subtotal => _activeCart.fold(0.0, (acc, line) => acc + line.total);
  double get _discount => (double.tryParse(_discountController.text.trim()) ?? 0.0).clamp(0.0, _subtotal);
  double get _total => (_subtotal - _discount).clamp(0.0, double.infinity);

  Future<List<Map<String, dynamic>>> _attachSaleItems(Database db, String companyId, List<Map<String, dynamic>> salesRows) async {
    final enriched = <Map<String, dynamic>>[];
    for (final row in salesRows) {
      final saleMap = Map<String, dynamic>.from(row);
      final saleId = saleMap['id']?.toString() ?? '';
      final itemRows = await db.query(
        'sale_items',
        where: 'sale_id = ? AND company_id = ?',
        whereArgs: [saleId, companyId],
      );
      if (itemRows.isNotEmpty) {
        final totalQty = itemRows.fold<int>(0, (acc, it) => acc + ((it['quantity'] as num?)?.toInt() ?? 1));
        saleMap['items'] = itemRows;
        saleMap['item_count'] = totalQty > 0 ? totalQty : itemRows.length;
      }
      enriched.add(saleMap);
    }
    return enriched;
  }

  Future<void> _loadSalesHistory() async {
    setState(() {
      _loadingSales = true;
      _salesError = null;
    });

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

    // 1. Fetch from local SQLite first
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final localRows = await db.query(
        'sales',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'sold_at DESC',
      );
      if (mounted && localRows.isNotEmpty) {
        final withItems = await _attachSaleItems(db, companyId, localRows);
        if (mounted) {
          setState(() {
            _salesHistory = withItems;
            _loadingSales = false;
          });
        }
      }
    } catch (_) {}

    // 2. Fetch from backend if online
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/sales');
      final list = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);

      final db = await ModiriDesktopDatabase.instance.database;
      final batch = db.batch();
      for (final s in list) {
        final id = s['id']?.toString() ?? const Uuid().v4();
        final total = (s['total'] ?? s['total_amount'] ?? 0.0 as num).toDouble();
        final soldAt = s['sold_at'] ?? s['created_at'] ?? DateTime.now().toIso8601String();

        batch.insert(
          'sales',
          {
            'id': id,
            'company_id': companyId,
            'customer_name': s['customer_name'] ?? s['customerName'],
            'total': total,
            'subtotal': (s['subtotal'] ?? total as num).toDouble(),
            'discount': (s['discount'] ?? 0.0 as num).toDouble(),
            'payment_method': s['payment_method'] ?? s['paymentMethod'] ?? 'cash',
            'payment_status': s['payment_status'] ?? s['paymentStatus'] ?? 'paid',
            'sold_at': soldAt,
            'created_at': soldAt,
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      final fresh = await db.query(
        'sales',
        where: 'company_id = ?',
        whereArgs: [companyId],
        orderBy: 'sold_at DESC',
      );
      final withItems = await _attachSaleItems(db, companyId, fresh);

      if (mounted) {
        setState(() {
          _salesHistory = withItems;
          _loadingSales = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSales = false;
          if (_salesHistory.isEmpty) _salesError = e.toString();
        });
      }
    }
  }

  void _onScan(String barcode) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final status = BarcodeValidator.validate(barcode);
    if (status == BarcodeValidationStatus.invalidCharacters || status == BarcodeValidationStatus.empty) {
      setState(() {
        _scannerFeedback = '${loc.get('pos_invalid_barcode_error')} ($barcode)';
        _scannerError = true;
      });
      return;
    }

    final products = ref.read(productsRepositoryProvider).valueOrNull ?? [];
    final match = products.where((p) => p.barcode == barcode.trim());
    if (match.isNotEmpty) {
      _addToCart(match.first);
      setState(() {
        _scannerFeedback = '${loc.get('pos_scanned_label')} ${match.first.name}';
        _scannerError = false;
      });
    } else {
      setState(() {
        _scannerFeedback = '${loc.get('pos_unknown_barcode_error')} ($barcode)';
        _scannerError = true;
      });
    }

    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }

  void _addToCart(Product p) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final session = ref.read(sessionProvider);
    final bType = session.businessType ?? 'company';
    final isStrictStock = bType == 'superette' || bType == 'grocery' || bType == 'supermarket' || bType == 'pharmacy' || bType == 'clothing';

    if (isStrictStock && p.stockQuantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${p.name}" — ${loc.get('pos_out_of_stock_error')}'), backgroundColor: ModiriColors.brandRose),
        );
      }
      return;
    }

    setState(() {
      final idx = _activeCart.indexWhere((l) => l.product.id == p.id);
      if (idx >= 0) {
        if (_activeCart[idx].quantity >= p.stockQuantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${p.name}" — ${loc.get('pos_max_stock_error')} (${p.stockQuantity})'),
              backgroundColor: ModiriColors.brandAmber,
            ),
          );
          return;
        }
        _activeCart[idx].quantity += 1;
      } else {
        _activeCart.add(CartLine(product: p));
      }
    });
    _persistCurrentCart();
  }

  void _showReceiptDialog({
    required String saleId,
    required String customer,
    required String paymentMethod,
    required List<CartLine> items,
    required double total,
  }) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: ModiriColors.brandTeal, size: 22),
                  const SizedBox(width: 8),
                  Text(loc.get('sale_receipt'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: ModiriColors.textMuted(isDark)),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ModiriColors.border(isDark)),
                  ),
                  child: Column(
                    children: [
                      Text(loc.get('pos_terminal_title'),
                          style: TextStyle(fontWeight: FontWeight.w800, color: ModiriColors.textPrimary(isDark), letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text('${loc.get('receipt_id')}: #$saleId',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: ModiriColors.brandBlue)),
                      const SizedBox(height: 2),
                      Text(dateStr, style: TextStyle(fontSize: 11, color: ModiriColors.textMuted(isDark))),
                      const SizedBox(height: 12),
                      Divider(color: ModiriColors.border(isDark), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${loc.get('customer_colon')} ${customer == 'Walk-in Customer' ? loc.get('walk_in_customer') : customer}', style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark))),
                          Text('${loc.get('payment_colon')} ${paymentMethod.toUpperCase()}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ModiriColors.brandTeal)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...items.map((line) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${line.quantity}x ${line.product.name}',
                                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12)),
                                Text(_formatCurrency(line.total),
                                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontFamily: 'monospace', fontSize: 12)),
                              ],
                            ),
                          )),
                      const SizedBox(height: 12),
                      Divider(color: ModiriColors.border(isDark), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('grand_total'), style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 14)),
                          Text(_formatCurrency(total),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandTeal, fontSize: 18, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: Text(loc.get('print_receipt_action')),
            onPressed: () async {
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              final company = ref.read(sessionProvider).companyName ?? 'Modiri Business';
              try {
                await ReceiptPrinter.printReceipt(
                  companyName: company,
                  invoiceNumber: saleId.toString(),
                  date: DateTime.now(),
                  items: items
                      .map((line) => {
                            'name': line.product.name,
                            'quantity': line.quantity,
                            'price': line.product.price,
                            'lineTotal': line.total,
                          })
                      .toList(),
                  total: total,
                  subtotal: total,
                  discount: 0.0,
                  paymentMethod: paymentMethod,
                  customerName: customer,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Print preview: $e'), backgroundColor: ModiriColors.brandRose),
                  );
                }
              }
            },
          ),
        ],
      );
    },
  );
}

  void _showSaleDetailsModal(dynamic sale) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final s = Map<String, dynamic>.from(sale is Map ? sale : {});
    final id = s['id'] ?? s['invoice_number'] ?? 'TX-100';
    final cust = s['customer_name'] ?? s['customerName'] ?? 'Walk-in Customer';
    final pm = (s['payment_method'] ?? s['paymentMethod'] ?? 'cash').toString().toUpperCase();
    final pStatus = (s['payment_status'] ?? s['paymentStatus'] ?? 'paid').toString().toUpperCase();
    final rawDate = s['created_at'] ?? s['createdAt'] ?? s['sold_at'];
    final dateStr = rawDate != null ? rawDate.toString().replaceAll('T', ' ').substring(0, 16) : loc.get('recent');
    final total = (s['total'] ?? s['total_amount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (s['subtotal'] as num?)?.toDouble() ?? total;
    final discount = (s['discount'] as num?)?.toDouble() ?? 0.0;
    final rawItems = s['items'] as List? ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: ModiriColors.brandBlue, size: 22),
                  const SizedBox(width: 8),
                  Text('${loc.get('sale_details_num')}$id',
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: ModiriColors.textMuted(isDark)),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${loc.get('customer_colon')} ${cust == 'Walk-in Customer' ? loc.get('walk_in_customer') : cust}', style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('${loc.get('date_colon')} $dateStr', style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ModiriColors.brandBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(pm, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.brandBlue)),
                            ),
                            const SizedBox(height: 4),
                            Text(pStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pStatus == 'PAID' ? ModiriColors.brandTeal : ModiriColors.brandRose)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(loc.get('items_purchased'), style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                  const SizedBox(height: 8),
                  if (rawItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('${loc.get('summary_transaction')} (${_formatCurrency(total)})', style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12)),
                    )
                  else
                    ...rawItems.map((item) {
                      final m = Map<String, dynamic>.from(item is Map ? item : {});
                      final name = m['product_name'] ?? m['name'] ?? loc.get('product_item');
                      final qty = (m['quantity'] as num?)?.toInt() ?? 1;
                      final price = (m['unit_price'] ?? m['price'] as num?)?.toDouble() ?? 0.0;
                      final lineTotal = (m['line_total'] ?? m['lineTotal'] as num?)?.toDouble() ?? (qty * price);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('$qty x $name', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12))),
                            Text(_formatCurrency(lineTotal), style: TextStyle(fontFamily: 'monospace', color: ModiriColors.textPrimary(isDark), fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  Divider(color: ModiriColors.border(isDark)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.get('subtotal'), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12)),
                      Text(_formatCurrency(subtotal), style: TextStyle(fontFamily: 'monospace', color: ModiriColors.textPrimary(isDark), fontSize: 12)),
                    ],
                  ),
                  if (discount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(loc.get('discount'), style: TextStyle(color: ModiriColors.brandRose, fontSize: 12)),
                        Text('- ${_formatCurrency(discount)}', style: TextStyle(fontFamily: 'monospace', color: ModiriColors.brandRose, fontSize: 12)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.get('total'), style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 14)),
                      Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: ModiriColors.brandTeal, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (pStatus != 'VOIDED')
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16, color: ModiriColors.brandRose),
                label: Text(loc.get('void_sale'), style: const TextStyle(color: ModiriColors.brandRose)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _voidSale(s);
                },
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _voidSale(Map<String, dynamic> sale) async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final saleId = sale['id']?.toString() ?? '';
    final invoiceNum = sale['invoice_number']?.toString() ?? saleId;
    final paymentStatus = (sale['payment_status'] ?? sale['paymentStatus'] ?? '').toString().toLowerCase();

    if (paymentStatus == 'voided') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.get('sale_voided')),
            backgroundColor: ModiriColors.brandAmber,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: ModiriColors.brandRose, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.get('confirm_void_sale_title'),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            '${loc.get('confirm_void_sale_desc')}\n\nInvoice: #$invoiceNum',
            style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(loc.get('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ModiriColors.brandRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.get('void_sale')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final nowIso = DateTime.now().toIso8601String();

    try {
      final db = await ModiriDesktopDatabase.instance.database;

      await db.transaction((txn) async {
        // 1. Get sale items to restore product stock
        final items = await txn.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        for (final item in items) {
          final pid = item['product_id']?.toString();
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          if (pid != null && pid.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [qty, pid],
            );
          }
        }

        // 2. If it was a credit sale, reverse customer debt
        final paymentMethod = (sale['payment_method'] ?? sale['paymentMethod'] ?? '').toString().toLowerCase();
        final customerName = sale['customer_name'] ?? sale['customerName'] ?? '';
        final total = (sale['total'] ?? sale['total_amount'] as num?)?.toDouble() ?? 0.0;

        if (paymentMethod == 'credit' && customerName.isNotEmpty && customerName != 'Walk-in Customer') {
          final custRows = await txn.query(
            'customers',
            where: 'name = ?',
            whereArgs: [customerName],
          );
          if (custRows.isNotEmpty) {
            final cid = custRows.first['id'].toString();
            final oldBal = (custRows.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
            final newBal = (oldBal - total).clamp(0.0, double.infinity);

            await txn.update(
              'customers',
              {'credit_balance': newBal},
              where: 'id = ?',
              whereArgs: [cid],
            );

            await txn.insert('customer_transactions', {
              'id': const Uuid().v4(),
              'company_id': companyId,
              'customer_id': cid,
              'type': 'adjustment',
              'amount': -total,
              'balance_after': newBal,
              'description': 'Void Credit Sale $invoiceNum',
              'created_at': nowIso,
            });
          }
        }

        // 3. Mark sale as voided
        await txn.update(
          'sales',
          {
            'payment_status': 'voided',
            'synced': 0,
          },
          where: 'id = ?',
          whereArgs: [saleId],
        );

        // 4. Mark invoice as cancelled
        await txn.update(
          'invoices',
          {'status': 'cancelled'},
          where: 'sale_id = ?',
          whereArgs: [saleId],
        );

        // 5. Enqueue VOID operation atomically
        await txn.insert('sync_queue', {
          'id': const Uuid().v4(),
          'company_id': companyId,
          'client_transaction_id': const Uuid().v4(),
          'entity_type': 'sale',
          'entity_id': saleId,
          'operation_type': 'VOID',
          'payload': jsonEncode({
            'id': saleId,
            'sale_id': saleId,
            'invoice_number': invoiceNum,
            'status': 'voided',
            'reason': 'POS operator void',
          }),
          'status': 'pending',
          'retry_count': 0,
          'last_error': null,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      });

      // Refresh inventory & sync queue
      ref.read(productsRepositoryProvider.notifier).load();
      ref.read(desktopSyncServiceProvider.notifier).refreshQueueCounts();
      unawaited(ref.read(desktopSyncServiceProvider.notifier).syncPending());

      await _loadSalesHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.get('sale_voided')),
            backgroundColor: ModiriColors.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ModiriColors.brandRose,
          ),
        );
      }
    }
  }

  Future<void> _processCheckout() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    if (_activeCart.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.get('cart_is_empty_warning')),
            backgroundColor: ModiriColors.brandAmber,
          ),
        );
      }
      return;
    }
    if (_isCheckingOut) return;

    for (final item in _activeCart) {
      if (item.quantity <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.get('pos_invalid_qty_error')} ("${item.product.name}")'), backgroundColor: ModiriColors.brandRose),
          );
        }
        return;
      }
    }

    if (_paymentMethod == 'credit' && _selectedCustomer == 'Walk-in Customer') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.get('select_registered_customer_error')),
            backgroundColor: ModiriColors.brandAmber,
          ),
        );
      }
      return;
    }

    setState(() => _isCheckingOut = true);

    try {
      final saleItems = _activeCart.map((l) => CartLine(product: l.product, quantity: l.quantity)).toList();
      final subTotal = _subtotal;
      final discountAmt = _discount;
      final grandTotal = _total;
      final currentMethod = _paymentMethod;
      final customer = _selectedCustomer;
      final companyId = ref.read(sessionProvider).companyId ?? 'default_company';

      final saleId = const Uuid().v4();
      final clientTxId = const Uuid().v4();
      final nowIso = DateTime.now().toIso8601String();
      String invoiceNumber = 'INV-1001';

      final db = await ModiriDesktopDatabase.instance.database;

      await db.transaction((txn) async {
        // 1. Stock check: ensure every product has sufficient stock before write if inventory tracked
        final session = ref.read(sessionProvider);
        final bType = session.businessType ?? 'company';
        final isStrictStock = bType == 'superette' || bType == 'grocery' || bType == 'supermarket' || bType == 'pharmacy' || bType == 'clothing';

        for (final item in saleItems) {
          final pRows = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [item.product.id],
          );
          if (pRows.isNotEmpty) {
            final availableStock = (pRows.first['stock_quantity'] as num?)?.toInt() ?? 0;
            if (isStrictStock && availableStock < item.quantity && availableStock > 0) {
              throw Exception('${loc.get('insufficient_stock_error')} "${item.product.name}" (${loc.get('available_label')}: $availableStock, ${loc.get('requested_label')}: ${item.quantity})');
            }
          }
        }

        String? resolvedCustomerId;
        if (customer != 'Walk-in Customer') {
          final custLookup = await txn.query(
            'customers',
            where: 'name = ? AND company_id = ?',
            whereArgs: [customer, companyId],
          );
          if (custLookup.isNotEmpty) {
            resolvedCustomerId = custLookup.first['id']?.toString();
          }
        }

        // 2. Next sequential invoice number (monotonic across restarts)
        final maxRes = await txn.rawQuery(
          "SELECT COALESCE(MAX(CAST(SUBSTR(invoice_number, 5) AS INTEGER)), 1000) AS max_seq FROM invoices WHERE company_id = ? AND invoice_number LIKE 'INV-%'",
          [companyId],
        );
        final nextSeq = ((maxRes.first['max_seq'] as num?)?.toInt() ?? 1000) + 1;
        invoiceNumber = 'INV-$nextSeq';

        // 3. Insert Sale
        await txn.insert('sales', {
          'id': saleId,
          'company_id': companyId,
          'customer_id': resolvedCustomerId,
          'customer_name': customer,
          'invoice_number': invoiceNumber,
          'total': grandTotal,
          'subtotal': subTotal,
          'discount': discountAmt,
          'payment_status': currentMethod == 'credit' ? 'unpaid' : 'paid',
          'payment_method': currentMethod,
          'sold_at': nowIso,
          'created_at': nowIso,
          'synced': 0,
        });

        // 4. Insert Sale Items & decrement stock
        for (final item in saleItems) {
          await txn.insert('sale_items', {
            'id': const Uuid().v4(),
            'company_id': companyId,
            'sale_id': saleId,
            'product_id': item.product.id,
            'product_name': item.product.name,
            'quantity': item.quantity,
            'unit_price': item.product.price,
            'unit_cost': item.product.costPrice,
            'line_total': item.total,
            'line_profit': (item.product.price - item.product.costPrice) * item.quantity,
          });

          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.product.id],
          );
        }

        // 5. Insert Invoice
        final isCreditSale = currentMethod == 'credit';
        await txn.insert('invoices', {
          'id': const Uuid().v4(),
          'company_id': companyId,
          'sale_id': saleId,
          'invoice_number': invoiceNumber,
          'customer_name': customer,
          'total': grandTotal,
          'paid_amount': isCreditSale ? 0.0 : grandTotal,
          'remaining_amount': isCreditSale ? grandTotal : 0.0,
          'status': isCreditSale ? 'unpaid' : 'paid',
          'sold_at': nowIso,
          'created_at': nowIso,
        });

        // 6. Update Customer Debt if Credit Sale
        if (currentMethod == 'credit' && customer != 'Walk-in Customer') {
          final custRows = await txn.query(
            'customers',
            where: 'name = ? AND company_id = ?',
            whereArgs: [customer, companyId],
          );
          if (custRows.isNotEmpty) {
            final cid = custRows.first['id'].toString();
            final oldBal = (custRows.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
            final newBal = oldBal + grandTotal;

            await txn.update(
              'customers',
              {'credit_balance': newBal},
              where: 'id = ?',
              whereArgs: [cid],
            );

            await txn.insert('customer_transactions', {
              'id': const Uuid().v4(),
              'company_id': companyId,
              'customer_id': cid,
              'type': 'purchase',
              'amount': grandTotal,
              'balance_after': newBal,
              'description': 'POS Credit Sale $invoiceNumber',
              'created_at': nowIso,
            });
          }
        }

        // 7. Enqueue Sync Operation atomically in the same transaction
        await txn.insert(
          'sync_queue',
          {
            'id': const Uuid().v4(),
            'company_id': companyId,
            'client_transaction_id': clientTxId,
            'entity_type': 'sale',
            'entity_id': saleId,
            'operation_type': 'CREATE',
            'payload': jsonEncode({
              'id': saleId,
              'customerId': resolvedCustomerId,
              'customer_id': resolvedCustomerId,
              'customer_name': customer,
              'payment_method': currentMethod,
              'paymentStatus': currentMethod == 'credit' ? 'unpaid' : 'paid',
              'total': grandTotal,
              'subtotal': subTotal,
              'discount': discountAmt,
              'items': saleItems.map((i) => {
                'productId': i.product.id,
                'product_id': i.product.id,
                'name': i.product.name,
                'quantity': i.quantity,
                'unitPrice': i.product.price,
                'unit_price': i.product.price,
                'unit_cost': i.product.costPrice,
              }).toList(),
            }),
            'status': 'pending',
            'retry_count': 0,
            'last_error': null,
            'created_at': nowIso,
            'updated_at': nowIso,
          },
        );
      });

      // Notify sync service to check pending queue
      ref.read(desktopSyncServiceProvider.notifier).refreshQueueCounts();
      unawaited(ref.read(desktopSyncServiceProvider.notifier).syncPending());

      // Refresh inventory state to immediately reflect deducted stock
      ref.read(productsRepositoryProvider.notifier).load();

      final current = _cartSessions[_activeCartIndex];
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        await db.delete('cart_session_items', where: 'cart_session_id = ?', whereArgs: [current.id]);
        await db.update(
          'cart_sessions',
          {'status': 'COMPLETED', 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [current.id],
        );
      } catch (_) {}

      setState(() {
        current.items.clear();
        current.discount = 0.0;
        current.status = 'ACTIVE';
        current.customerName = 'Walk-in Customer';
        _selectedCustomer = 'Walk-in Customer';
        _discountController.text = '0';
      });

      _showReceiptDialog(
        saleId: invoiceNumber,
        customer: customer,
        paymentMethod: currentMethod,
        items: saleItems,
        total: grandTotal,
      );

      _loadSalesHistory();
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.substring('Exception: '.length);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.get('pos_sale_failed_error')} $msg'), backgroundColor: ModiriColors.brandRose),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  Future<void> _importScannedItemsToActiveCart(List<ScannedLineItem> scannedItems, String? customerName) async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));

    try {
      final db = await ModiriDesktopDatabase.instance.database;
      int addedTotal = 0;

      for (final item in scannedItems) {
        final name = item.nameController.text.trim();
        if (name.isEmpty) continue;
        final qty = item.quantity;
        final salePrice = item.sellingPrice > 0 ? item.sellingPrice : (item.purchasePrice * 1.25);
        final buyPrice = item.purchasePrice;

        Product foundProduct;
        final pRows = await db.query(
          'products',
          where: 'company_id = ? AND LOWER(name) = LOWER(?)',
          whereArgs: [companyId, name],
        );

        if (pRows.isNotEmpty) {
          foundProduct = Product.fromJson(pRows.first);
        } else {
          final newId = const Uuid().v4();
          final autoBarcode = 'AUTO${DateTime.now().millisecondsSinceEpoch % 1000000}';
          final newProdMap = {
            'id': newId,
            'company_id': companyId,
            'name': name,
            'barcode': autoBarcode,
            'price': salePrice,
            'cost_price': buyPrice,
            'purchase_price': buyPrice,
            'stock_quantity': qty + 10,
            'category': 'General',
            'created_at': DateTime.now().toIso8601String(),
          };
          await db.insert('products', newProdMap);
          foundProduct = Product.fromJson(newProdMap);
        }

        final activeCart = _cartSessions[_activeCartIndex];
        final existingIndex = activeCart.items.indexWhere((it) => it.product.id == foundProduct.id);
        if (existingIndex >= 0) {
          activeCart.items[existingIndex].quantity += qty;
        } else {
          activeCart.items.add(CartLine(product: foundProduct, quantity: qty));
        }
        addedTotal += qty;
      }

      if (customerName != null && customerName.isNotEmpty && customerName != 'Walk-in Customer') {
        _selectedCustomer = customerName;
        _cartSessions[_activeCartIndex].customerName = customerName;
        if (!_customerList.contains(customerName)) {
          _customerList.add(customerName);
        }
      }

      await _persistCurrentCart();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedTotal ${loc.get('items_imported_to_cart')}'),
            backgroundColor: ModiriColors.brandTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import items to cart: $e'),
            backgroundColor: ModiriColors.brandRose,
          ),
        );
      }
    }
  }

  void _showScanInvoiceModal({InvoiceScanMode mode = InvoiceScanMode.sales}) {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
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
            body: DesktopAiInvoiceScannerScreen(
              initialMode: mode,
              onImportToCart: (scannedItems, customerName) async {
                await _importScannedItemsToActiveCart(scannedItems, customerName);
              },
            ),
          ),
        ),
      ),
    ).then((_) {
      ref.invalidate(productsRepositoryProvider);
      _loadSalesHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final productsAsync = ref.watch(productsRepositoryProvider);
    final allProducts = productsAsync.valueOrNull ?? [];
    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredProducts = allProducts.where((p) {
      if (searchQuery.isEmpty) return true;
      final nameMatch = p.name.toLowerCase().contains(searchQuery);
      final barcodeMatch = p.barcode != null && p.barcode!.toLowerCase().contains(searchQuery);
      final catMatch = p.category != null && p.category!.toLowerCase().contains(searchQuery);
      return nameMatch || barcodeMatch || catMatch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Tab Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.point_of_sale, color: ModiriColors.brandBlue, size: 26),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            loc.get('pos_terminal_title'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.get('pos_terminal_desc'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.document_scanner_outlined, size: 20, color: ModiriColors.brandBlue),
                    tooltip: loc.get('scan_invoice_button'),
                    onPressed: () => _showScanInvoiceModal(mode: InvoiceScanMode.sales),
                    style: IconButton.styleFrom(
                      backgroundColor: ModiriColors.brandBlue.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: ModiriColors.surface(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicator: BoxDecoration(
                        color: ModiriColors.brandBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: ModiriColors.textSecondary(isDark),
                      tabs: [
                        Tab(icon: const Icon(Icons.shopping_cart_checkout, size: 16), text: loc.get('tab_pos_register')),
                        Tab(icon: const Icon(Icons.history, size: 16), text: loc.get('tab_pos_ledger')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: POS REGISTER
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: Catalog & Barcode Scanner Area (Flex 7)
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          // Hardware Scanner Feedback & Test Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _scannerError
                                  ? ModiriColors.brandRose.withOpacity(0.12)
                                  : _scannerFeedback != null
                                      ? ModiriColors.brandTeal.withOpacity(0.12)
                                      : ModiriColors.surface(isDark),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _scannerError
                                    ? ModiriColors.brandRose.withOpacity(0.4)
                                    : _scannerFeedback != null
                                        ? ModiriColors.brandTeal.withOpacity(0.4)
                                        : ModiriColors.border(isDark),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _scannerError
                                      ? Icons.error_outline
                                      : _scannerFeedback != null
                                          ? Icons.check_circle_outline
                                          : Icons.qr_code_scanner,
                                  color: _scannerError
                                      ? ModiriColors.brandRose
                                      : _scannerFeedback != null
                                          ? ModiriColors.brandTeal
                                          : ModiriColors.brandBlue,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _scannerFeedback ?? loc.get('scanner_ready_wedge'),
                                        style: TextStyle(
                                          color: _scannerError
                                              ? ModiriColors.brandRose
                                              : _scannerFeedback != null
                                                  ? ModiriColors.brandTeal
                                                  : ModiriColors.textPrimary(isDark),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        loc.get('pos_barcode_hint'),
                                        style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: TextField(
                                    controller: _barcodeController,
                                    focusNode: _barcodeFocusNode,
                                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12, fontFamily: 'monospace'),
                                    decoration: InputDecoration(
                                      hintText: loc.get('manual_wedge_sku_hint'),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onSubmitted: (code) {
                                      _onScan(code);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Search Catalog Input with AI Invoice Scanner Button
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            decoration: InputDecoration(
                              hintText: loc.get('search_products_barcode_hint'),
                              prefixIcon: const Icon(Icons.search, color: ModiriColors.brandBlue, size: 20),
                              suffixIcon: Tooltip(
                                message: loc.get('scan_invoice_button'),
                                child: IconButton(
                                  icon: const Icon(Icons.document_scanner_outlined, color: ModiriColors.brandBlue, size: 20),
                                  onPressed: _showScanInvoiceModal,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Product Grid
                          Expanded(
                            child: filteredProducts.isEmpty
                                ? Center(
                                    child: Text(loc.get('no_catalog_products'),
                                        style: TextStyle(color: ModiriColors.textMuted(isDark))),
                                  )
                                : GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.4,
                                    ),
                                    itemCount: filteredProducts.length,
                                    itemBuilder: (ctx, idx) {
                                      final p = filteredProducts[idx];
                                      return InkWell(
                                        onTap: () => _addToCart(p),
                                        borderRadius: BorderRadius.circular(14),
                                        child: ModiriPanel(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      (p.category != null && p.category!.isNotEmpty) ? p.category! : loc.get('general_category'),
                                                      style: TextStyle(fontSize: 10, color: ModiriColors.textSecondary(isDark)),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${p.stockQuantity} ${loc.get('in_stock')}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: p.stockQuantity <= 5 ? ModiriColors.brandAmber : ModiriColors.brandTeal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                p.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 13),
                                              ),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    _formatCurrency(p.price),
                                                    style: const TextStyle(
                                                      color: ModiriColors.brandTeal,
                                                      fontWeight: FontWeight.w800,
                                                      fontFamily: 'monospace',
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: const BoxDecoration(
                                                      color: ModiriColors.brandBlue,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.add, size: 14, color: Colors.white),
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

                    const SizedBox(width: 18),

                    // RIGHT: Multi-Cart, Checkout & Totals (Flex 5)
                    Expanded(
                      flex: 5,
                      child: ModiriPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Multi-Cart Selector Tabs
                            Row(
                              children: [
                                for (int i = 0; i < _cartSessions.length; i++) ...[
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _activeCartIndex == i
                                            ? ModiriColors.brandBlue
                                            : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _activeCartIndex == i ? ModiriColors.brandBlue : ModiriColors.border(isDark),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _switchCart(i),
                                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (_cartSessions[i].status == 'ON_HOLD') ...[
                                                      const Icon(Icons.pause, size: 12, color: ModiriColors.brandAmber),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Flexible(
                                                      child: Text(
                                                        '${loc.get("cart_tab")} ${i + 1} (${_cartSessions[i].items.length})',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: _activeCartIndex == i ? Colors.white : ModiriColors.textSecondary(isDark),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Tooltip(
                                            message: _cartSessions.length > 1 ? loc.get('delete_cart') : loc.get('clear_cart'),
                                            child: InkWell(
                                              onTap: () => _deleteCartSession(i),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 13,
                                                  color: _activeCartIndex == i ? Colors.white70 : ModiriColors.textMuted(isDark),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20, color: ModiriColors.brandBlue),
                                  tooltip: loc.get('new_cart'),
                                  onPressed: _addNewCart,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.document_scanner_outlined, size: 20, color: ModiriColors.brandBlue),
                                  tooltip: loc.get('scan_invoice_to_cart'),
                                  onPressed: () => _showScanInvoiceModal(mode: InvoiceScanMode.sales),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: ModiriColors.brandBlue,
                                  ),
                                  icon: const Icon(Icons.document_scanner_outlined, size: 14),
                                  label: Text(loc.get('scan_invoice_to_cart'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  onPressed: () => _showScanInvoiceModal(mode: InvoiceScanMode.sales),
                                ),
                                if (_activeCart.isNotEmpty) ...[
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(Icons.pause_circle_outline, size: 15, color: ModiriColors.brandAmber),
                                    label: Text(loc.get('park_cart'), style: const TextStyle(color: ModiriColors.brandAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: _parkCurrentCart,
                                  ),
                                ],
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.close, size: 15, color: ModiriColors.brandRose),
                                  label: Text(loc.get('delete_cart'), style: const TextStyle(color: ModiriColors.brandRose, fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _deleteCartSession(_activeCartIndex),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.delete_sweep_outlined, size: 15, color: ModiriColors.brandRose),
                                  label: Text(loc.get('clear_cart'), style: const TextStyle(color: ModiriColors.brandRose, fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: _clearCurrentCart,
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Customer & Payment Method Selector
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCustomer,
                                    isExpanded: true,
                                    dropdownColor: ModiriColors.card(isDark),
                                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: loc.get('customer_label'),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: _customerList
                                        .map((name) => DropdownMenuItem(
                                              value: name,
                                              child: Text(
                                                name == 'Walk-in Customer' ? loc.get('walk_in_customer') : name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _selectedCustomer = v ?? 'Walk-in Customer'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _paymentMethod,
                                    isExpanded: true,
                                    dropdownColor: ModiriColors.card(isDark),
                                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: loc.get('payment_method'),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: [
                                      DropdownMenuItem(value: 'cash', child: Text(loc.get('cash_f1'), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'card', child: Text(loc.get('card_f2'), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'credit', child: Text(loc.get('credit_account'), overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            Divider(color: ModiriColors.border(isDark), height: 1),
                            const SizedBox(height: 10),

                            // Cart Line Items List
                            Expanded(
                              child: _activeCart.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.shopping_basket_outlined, size: 36, color: ModiriColors.textMuted(isDark)),
                                          const SizedBox(height: 8),
                                          Text(
                                            loc.get('active_cart_empty_hint'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.document_scanner_outlined, size: 16),
                                            label: Text(loc.get('scan_invoice_to_cart')),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: ModiriColors.brandBlue.withOpacity(0.12),
                                              foregroundColor: ModiriColors.brandBlue,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () => _showScanInvoiceModal(mode: InvoiceScanMode.sales),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _activeCart.length,
                                      separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 12),
                                      itemBuilder: (ctx, i) {
                                        final line = _activeCart[i];
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(line.product.name,
                                                      style: TextStyle(
                                                          color: ModiriColors.textPrimary(isDark), fontSize: 12, fontWeight: FontWeight.bold)),
                                                  Text('${_formatCurrency(line.product.price)} ${loc.get('each_unit')}',
                                                      style: TextStyle(
                                                          color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                                                  color: ModiriColors.textSecondary(isDark),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (line.quantity > 1) {
                                                        line.quantity -= 1;
                                                      } else {
                                                        _activeCart.removeAt(i);
                                                      }
                                                    });
                                                    _persistCurrentCart();
                                                  },
                                                ),
                                                Text('${line.quantity}',
                                                    style: TextStyle(
                                                        color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 12)),
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline, size: 16),
                                                  color: ModiriColors.brandBlue,
                                                  onPressed: () {
                                                    if (line.quantity >= line.product.stockQuantity) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('${loc.get('max_stock_reached')} ${line.product.name} (${line.product.stockQuantity})'),
                                                          backgroundColor: ModiriColors.brandAmber,
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    setState(() => line.quantity += 1);
                                                    _persistCurrentCart();
                                                  },
                                                ),
                                                const SizedBox(width: 4),
                                                SizedBox(
                                                  width: 55,
                                                  child: Text(
                                                    _formatCurrency(line.total),
                                                    textAlign: TextAlign.right,
                                                    style: TextStyle(
                                                        color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 16, color: ModiriColors.brandRose),
                                                  tooltip: loc.get('remove'),
                                                  onPressed: () {
                                                    setState(() {
                                                      _activeCart.removeAt(i);
                                                    });
                                                    _persistCurrentCart();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),

                            Divider(color: ModiriColors.border(isDark), height: 20),

                            // Discount Input
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('${loc.get('discount')} (DZD)',
                                      style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 110,
                                  height: 32,
                                  child: TextField(
                                    controller: _discountController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    onChanged: (_) => setState(() {}),
                                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12, fontFamily: 'monospace'),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Total & Checkout
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(loc.get('total'),
                                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatCurrency(_total),
                                  style: const TextStyle(
                                      color: ModiriColors.brandTeal,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ModiriColors.brandTeal,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _isCheckingOut ? null : _processCheckout,
                              child: _isCheckingOut
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(loc.get('complete_sale_print_receipt'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // TAB 2: SALES TRANSACTION HISTORY LEDGER
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _salesSearchController,
                                decoration: InputDecoration(
                                  hintText: loc.get('search_sales_hint'),
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onChanged: (v) => setState(() => _salesSearchQuery = v.trim().toLowerCase()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: loc.get('refresh_sales'),
                            onPressed: _loadSalesHistory,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loadingSales
                          ? const Center(child: CircularProgressIndicator(color: ModiriColors.brandBlue))
                          : () {
                              final displayedSales = _salesHistory.where((s) {
                                if (_salesSearchQuery.isEmpty) return true;
                                final id = (s['id'] ?? s['invoice_number'] ?? '').toString().toLowerCase();
                                final cust = (s['customer_name'] ?? s['customerName'] ?? '').toString().toLowerCase();
                                return id.contains(_salesSearchQuery) || cust.contains(_salesSearchQuery);
                              }).toList();

                              if (displayedSales.isEmpty) {
                                return Center(
                                  child: ModiriPanel(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.receipt_long, color: ModiriColors.brandBlue, size: 48),
                                        const SizedBox(height: 12),
                                        Text(loc.get('no_sales_recorded'),
                                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text(loc.get('no_sales_recorded_desc'),
                                            style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ModiriPanel(
                                padding: EdgeInsets.zero,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(ModiriColors.tableHeader(isDark)),
                                      columns: [
                                        DataColumn(label: Text(loc.get('sale_id'), style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text(loc.get('customer_label'), style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text(loc.get('items_count'), style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text(loc.get('payment_method'), style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text(loc.get('date_time'), style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text(loc.get('total_amount'), style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text(loc.get('action'), style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: displayedSales.map((s) {
                                        final id = s['id'] ?? 'TX-100';
                                        final cust = s['customer_name'] ?? s['customerName'] ?? 'Walk-in Customer';
                                        final rawItems = s['items'] as List?;
                                        final itemCount = (rawItems != null && rawItems.isNotEmpty) ? rawItems.length : (s['item_count'] ?? 1);
                                        final pm = (s['payment_method'] ?? s['paymentMethod'] ?? 'cash').toString().toUpperCase();
                                        final isVoided = (s['payment_status'] ?? s['paymentStatus'] ?? '').toString().toLowerCase() == 'voided';
                                        final rawDate = s['created_at'] ?? s['createdAt'];
                                        final dateStr = rawDate != null ? rawDate.toString().replaceAll('T', ' ').substring(0, 16) : loc.get('recent');
                                        final total = (s['total'] ?? s['total_amount'] as num?)?.toDouble() ?? 0.0;
                                        final subtotal = (s['subtotal'] as num?)?.toDouble() ?? total;
                                        final discount = (s['discount'] as num?)?.toDouble() ?? 0.0;

                                        return DataRow(
                                          cells: [
                                            DataCell(Text('#$id', style: TextStyle(fontFamily: 'monospace', color: ModiriColors.textPrimary(isDark)))),
                                            DataCell(Text(cust == 'Walk-in Customer' ? loc.get('walk_in_customer') : cust, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)))),
                                            DataCell(Text('$itemCount ${loc.get('items_count_suffix')}', style: TextStyle(color: ModiriColors.textSecondary(isDark)))),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isVoided ? ModiriColors.brandRose.withOpacity(0.15) : ModiriColors.brandBlue.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: isVoided ? ModiriColors.brandRose.withOpacity(0.3) : ModiriColors.brandBlue.withOpacity(0.3)),
                                                ),
                                                child: Text(
                                                  isVoided
                                                      ? loc.get('cancelled').toUpperCase()
                                                      : (pm.toLowerCase() == 'cash'
                                                          ? loc.get('cash')
                                                          : (pm.toLowerCase() == 'card'
                                                              ? loc.get('card')
                                                              : (pm.toLowerCase() == 'credit' ? loc.get('credit') : pm))),
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isVoided ? ModiriColors.brandRose : ModiriColors.brandBlue),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(ModiriFormatters.toLatinDigits(dateStr), style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11))),
                                            DataCell(Text(_formatCurrency(total),
                                                style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.bold,
                                                    decoration: isVoided ? TextDecoration.lineThrough : null,
                                                    color: isVoided ? ModiriColors.brandRose : ModiriColors.brandTeal))),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.visibility_outlined, size: 18, color: ModiriColors.brandBlue),
                                                    tooltip: loc.get('view_sale_details'),
                                                    onPressed: () => _showSaleDetailsModal(s),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.print_outlined, size: 18, color: ModiriColors.brandTeal),
                                                    tooltip: loc.get('reprint_receipt'),
                                                    onPressed: () async {
                                                      final company = ref.read(sessionProvider).companyName ?? 'Modiri Business';
                                                      final receiptItems = (rawItems != null && rawItems.isNotEmpty)
                                                          ? rawItems.map((it) {
                                                              final m = Map<String, dynamic>.from(it as Map);
                                                              final q = (m['quantity'] as num?)?.toInt() ?? 1;
                                                              final u = (m['unit_price'] ?? m['price'] as num?)?.toDouble() ?? 0.0;
                                                              final lt = (m['line_total'] ?? m['lineTotal'] as num?)?.toDouble() ?? (q * u);
                                                              return {
                                                                'name': m['product_name'] ?? m['name'] ?? loc.get('product_item'),
                                                                'quantity': q,
                                                                'price': u,
                                                                'lineTotal': lt,
                                                              };
                                                            }).toList()
                                                          : [
                                                              {'name': 'Sale Transaction #$id', 'quantity': itemCount, 'price': total, 'lineTotal': total}
                                                            ];
                                                      try {
                                                        await ReceiptPrinter.printReceipt(
                                                          companyName: company,
                                                          invoiceNumber: id.toString(),
                                                          date: DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now(),
                                                          items: receiptItems,
                                                          total: total,
                                                          subtotal: subtotal,
                                                          discount: discount,
                                                          paymentMethod: pm,
                                                          customerName: cust,
                                                        );
                                                      } catch (e) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Print preview: $e'), backgroundColor: ModiriColors.brandRose),
                                                          );
                                                        }
                                                      }
                                                    },
                                                  ),
                                                  if (!isVoided)
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 18, color: ModiriColors.brandRose),
                                                      tooltip: loc.get('void_sale'),
                                                      onPressed: () => _voidSale(s),
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
                              );
                            }(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
