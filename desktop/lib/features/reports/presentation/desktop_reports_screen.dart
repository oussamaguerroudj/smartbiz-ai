import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../../core/utils/receipt_printer.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopSlowMovingItem {
  final String id;
  final String name;
  final String? category;
  final String? barcode;
  final int currentStock;
  final double purchasePrice;
  final double sellingPrice;
  final int unitsSold;
  final int daysInInventory;
  final double stockValuation;
  final bool insufficientHistory;

  DesktopSlowMovingItem({
    required this.id,
    required this.name,
    this.category,
    this.barcode,
    required this.currentStock,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.unitsSold,
    required this.daysInInventory,
    required this.stockValuation,
    required this.insufficientHistory,
  });
}

class DesktopReportsScreen extends ConsumerStatefulWidget {
  const DesktopReportsScreen({super.key});

  @override
  ConsumerState<DesktopReportsScreen> createState() => _DesktopReportsScreenState();
}

class _DesktopReportsScreenState extends ConsumerState<DesktopReportsScreen>
    with SingleTickerProviderStateMixin {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }
  bool _isLoading = true;
  String? _error;

  String _period = 'monthly'; // 'daily' | 'monthly' | 'yearly'
  DateTime _selectedDate = DateTime.now();

  double _allRevenue = 0.0;
  double _allExpenses = 0.0;
  double _globalNetProfit = 0.0;

  double _periodRevenue = 0.0;
  double _periodCogs = 0.0;
  double _periodGrossProfit = 0.0;
  double _periodExpenses = 0.0;
  double _periodNetProfit = 0.0;
  double _profitMargin = 0.0;
  int _salesCount = 0;

  List<dynamic> _topProducts = [];
  List<dynamic> _expensesByCategory = [];

  late final TabController _tabController;
  int _slowMovingDays = 30;
  int _slowMovingThreshold = 2;
  String _slowMovingSearch = '';
  final _slowMovingSearchCtrl = TextEditingController();
  List<DesktopSlowMovingItem> _slowMovingItems = [];
  bool _isLoadingSlowMoving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadReports();
    _loadSlowMovingReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slowMovingSearchCtrl.dispose();
    super.dispose();
  }

  List<DesktopSlowMovingItem> get _filteredSlowMoving {
    if (_slowMovingSearch.isEmpty) return _slowMovingItems;
    final q = _slowMovingSearch.toLowerCase();
    return _slowMovingItems.where((it) {
      return it.name.toLowerCase().contains(q) ||
          (it.barcode?.toLowerCase().contains(q) ?? false) ||
          (it.category?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _loadSlowMovingReport() async {
    setState(() => _isLoadingSlowMoving = true);
    final session = ref.read(sessionProvider);
    final companyId = session.companyId ?? session.userId ?? 'default_company';

    // 1. Try online endpoint first if available
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/reports/slow-moving', query: {
        'days': '$_slowMovingDays',
        'threshold': '$_slowMovingThreshold',
      });
      if (res is Map && res['data'] is Map && res['data']['items'] is List) {
        final list = (res['data']['items'] as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final stock = (m['currentStock'] ?? m['current_stock'] ?? 0) as int;
          final cost = ((m['purchasePrice'] ?? m['purchase_price'] ?? 0.0) as num).toDouble();
          return DesktopSlowMovingItem(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? 'Product',
            category: m['category']?.toString(),
            barcode: m['barcode']?.toString(),
            currentStock: stock,
            purchasePrice: cost,
            sellingPrice: ((m['sellingPrice'] ?? m['selling_price'] ?? 0.0) as num).toDouble(),
            unitsSold: (m['unitsSold'] ?? m['units_sold'] ?? 0) as int,
            daysInInventory: (m['daysInInventory'] ?? m['days_in_inventory'] ?? 0) as int,
            stockValuation: (m['stockValuation'] as num?)?.toDouble() ?? (stock * cost),
            insufficientHistory: m['insufficientHistory'] == true,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _slowMovingItems = list;
            _isLoadingSlowMoving = false;
          });
          return;
        }
      }
    } catch (_) {}

    // 2. Fallback to local SQLite evaluation matching mobile ReportsRepository
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final cutoff = DateTime.now().subtract(Duration(days: _slowMovingDays)).toIso8601String();

      const sql = '''
        SELECT
          p.id,
          p.name,
          p.category,
          p.barcode,
          p.quantity AS current_stock,
          p.purchase_price,
          p.price AS selling_price,
          p.created_at,
          COALESCE(sales_agg.units_sold, 0) AS units_sold
        FROM products p
        LEFT JOIN (
          SELECT si.product_id, SUM(si.quantity) AS units_sold
          FROM sale_items si
          JOIN sales s ON s.id = si.sale_id
          WHERE s.company_id = ? AND (s.created_at >= ?)
          GROUP BY si.product_id
        ) sales_agg ON sales_agg.product_id = p.id
        WHERE p.company_id = ?
          AND COALESCE(sales_agg.units_sold, 0) <= ?
        ORDER BY units_sold ASC, current_stock DESC, p.name ASC
      ''';

      final rows = await db.rawQuery(sql, [
        companyId,
        cutoff,
        companyId,
        _slowMovingThreshold,
      ]);

      final now = DateTime.now();
      final items = rows.map((r) {
        final createdAtStr = r['created_at'] as String?;
        final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
        final daysInInv = createdAt != null ? now.difference(createdAt).inDays : 0;
        final isInsufficient = createdAt != null && createdAt.isAfter(DateTime.now().subtract(Duration(days: _slowMovingDays)));
        final currentStock = ((r['current_stock'] as num?)?.toDouble() ?? 0.0).round();
        final purchasePrice = (r['purchase_price'] as num?)?.toDouble() ?? 0.0;
        final sellingPrice = (r['selling_price'] as num?)?.toDouble() ?? 0.0;
        final unitsSold = ((r['units_sold'] as num?)?.toDouble() ?? 0.0).round();

        return DesktopSlowMovingItem(
          id: (r['id'] ?? '').toString(),
          name: (r['name'] ?? 'Product').toString(),
          category: r['category'] as String?,
          barcode: r['barcode'] as String?,
          currentStock: currentStock,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          unitsSold: unitsSold,
          daysInInventory: daysInInv,
          stockValuation: currentStock * purchasePrice,
          insufficientHistory: isInsufficient,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _slowMovingItems = items;
          _isLoadingSlowMoving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSlowMoving = false);
      }
    }
  }

  void _exportSlowMovingCsvDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final csv = StringBuffer();
    csv.writeln('Modiri AI - Slow-Moving Inventory Report');
    csv.writeln('Period,Last $_slowMovingDays days');
    csv.writeln('Sales Threshold,<= $_slowMovingThreshold units');
    csv.writeln('Product Name,Category,Barcode,Current Stock,Unit Cost (DZD),Selling Price (DZD),Units Sold,Tied-up Capital (DZD),Days in Inventory');

    for (final it in _filteredSlowMoving) {
      csv.writeln('"${it.name}","${it.category ?? ''}","${it.barcode ?? ''}",${it.currentStock},${it.purchasePrice},${it.sellingPrice},${it.unitsSold},${it.stockValuation},${it.daysInInventory}');
    }

    final csvText = csv.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.table_view, color: ModiriColors.brandAmber, size: 22),
            const SizedBox(width: 8),
            Text(loc.get('export_csv'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.get('copy_export_csv_slow_moving'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ModiriColors.border(isDark)),
                ),
                child: SelectableText(
                  csvText,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: ModiriColors.textPrimary(isDark)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.get('close'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: Text(loc.get('copy_to_clipboard')),
            style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandAmber),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.get('slow_moving_csv_copied')), backgroundColor: ModiriColors.brandTeal),
              );
            },
          ),
        ],
      ),
    );
  }

  String get _periodLabel {
    if (_period == 'daily') {
      return ModiriFormatters.toLatinDigits(DateFormat('yyyy-MM-dd', 'en_US').format(_selectedDate));
    } else if (_period == 'monthly') {
      return ModiriFormatters.toLatinDigits(DateFormat('MMMM yyyy', 'en_US').format(_selectedDate));
    } else {
      return ModiriFormatters.toLatinDigits(DateFormat('yyyy', 'en_US').format(_selectedDate));
    }
  }

  void _prevPeriod() {
    setState(() {
      if (_period == 'daily') {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      } else if (_period == 'monthly') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
      }
    });
    _loadReports();
  }

  void _nextPeriod() {
    setState(() {
      if (_period == 'daily') {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      } else if (_period == 'monthly') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
      }
    });
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final session = ref.read(sessionProvider);
    final companyId = session.companyId ?? session.userId ?? 'default_company';

    try {
      final client = ref.read(apiClientProvider);
      final query = <String, String>{'period': _period};
      if (_period == 'daily') {
        query['date'] = DateFormat('yyyy-MM-dd').format(_selectedDate);
      } else if (_period == 'monthly') {
        query['month'] = DateFormat('yyyy-MM').format(_selectedDate);
      } else {
        query['year'] = _selectedDate.year.toString();
      }

      final res = await client.get('/reports/summary', query: query);
      final rep = res is Map ? (res['data'] ?? res) : {};

      final allRev = ((rep['global']?['allRevenue'] ?? rep['allRevenue']) as num?)?.toDouble() ?? 0.0;
      final allExp = ((rep['global']?['allExpenses'] ?? rep['allExpenses']) as num?)?.toDouble() ?? 0.0;
      final pRev = ((rep['revenue'] ?? rep['totalRevenue']) as num?)?.toDouble() ?? 0.0;
      final pCogs = ((rep['costOfGoodsSold'] ?? rep['cogs'] ?? rep['costOfGoods']) as num?)?.toDouble() ?? 0.0;
      final pExp = ((rep['expenses'] ?? rep['totalExpenses']) as num?)?.toDouble() ?? 0.0;
      final pGross = ((rep['grossProfit']) as num?)?.toDouble() ?? (pRev - pCogs);
      final pNet = ((rep['netProfit']) as num?)?.toDouble() ?? (pGross - pExp);
      final margin = (rep['profitMargin'] as num?)?.toDouble() ?? (pRev > 0 ? (pNet / pRev) * 100 : 0.0);

      setState(() {
        _allRevenue = allRev;
        _allExpenses = allExp;
        _globalNetProfit = ((rep['global']?['globalNetProfit']) as num?)?.toDouble() ?? (allRev - allExp);
        _periodRevenue = pRev;
        _periodCogs = pCogs;
        _periodGrossProfit = pGross;
        _periodExpenses = pExp;
        _periodNetProfit = pNet;
        _profitMargin = margin;
        _salesCount = (rep['salesCount'] as num?)?.toInt() ?? 0;
        _topProducts = (rep['topProducts'] as List?) ?? [];
        _expensesByCategory = (rep['expensesByCategory'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (_) {
      // Offline fallback: Use DesktopLocalFinancialCalculator
      try {
        final local = await DesktopLocalFinancialCalculator.calculateReport(
          period: _period,
          companyId: companyId,
          businessType: session.businessType,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
          month: DateFormat('yyyy-MM').format(_selectedDate),
          year: _selectedDate.year,
        );

        setState(() {
          _allRevenue = local.allRevenue;
          _allExpenses = local.allExpenses;
          _globalNetProfit = local.globalNetProfit;
          _periodRevenue = local.periodRevenue;
          _periodCogs = local.periodCogs;
          _periodGrossProfit = local.periodGrossProfit;
          _periodExpenses = local.periodExpenses;
          _periodNetProfit = local.periodNetProfit;
          _profitMargin = local.profitMargin;
          _salesCount = local.salesCount;
          _topProducts = local.topProducts;
          _expensesByCategory = local.expensesByCategory;
          _isLoading = false;
        });
      } catch (err) {
        setState(() {
          _error = err.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPeriodStatCard({
    required String label,
    required String value,
    required String sublabel,
    required Color tone,
    IconData? icon,
    bool isDark = true,
  }) {
    return ModiriPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark))),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: tone.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: tone, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: tone,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(sublabel, style: TextStyle(fontSize: 11, color: ModiriColors.textMuted(isDark))),
        ],
      ),
    );
  }

  Future<void> _pickPeriodDate() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    if (_period == 'daily') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _loadReports();
      }
    } else if (_period == 'monthly') {
      int tempYear = _selectedDate.year;
      int tempMonth = _selectedDate.month;
      final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
      final picked = await showDialog<DateTime>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return StatefulBuilder(
            builder: (dCtx, setDialogState) => AlertDialog(
              backgroundColor: ModiriColors.surface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ModiriColors.border(isDark)),
              ),
              title: Text(loc.get('select_month_year'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: ModiriColors.textPrimary(isDark)),
                          onPressed: () => setDialogState(() => tempYear--),
                        ),
                        Text('$tempYear', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: ModiriColors.textPrimary(isDark)),
                          onPressed: () => setDialogState(() => tempYear++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final m = index + 1;
                        final label = DateFormat('MMM').format(DateTime(tempYear, m, 1));
                        final selected = tempMonth == m;
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          selectedColor: ModiriColors.brandBlue,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : ModiriColors.textPrimary(isDark),
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setDialogState(() => tempMonth = m),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(DateTime(tempYear, tempMonth, 1)),
                  child: Text(loc.get('apply')),
                ),
              ],
            ),
          );
        },
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _loadReports();
      }
    } else {
      int tempYear = _selectedDate.year;
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final years = List.generate(12, (i) => DateTime.now().year - 6 + i);
          return StatefulBuilder(
            builder: (dCtx, setDialogState) => AlertDialog(
              backgroundColor: ModiriColors.surface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: ModiriColors.border(isDark)),
              ),
              title: Text(loc.get('select_year'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 320,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: years.map((y) {
                    final selected = tempYear == y;
                    return ChoiceChip(
                      label: Text('$y'),
                      selected: selected,
                      selectedColor: ModiriColors.brandBlue,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : ModiriColors.textPrimary(isDark),
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setDialogState(() => tempYear = y),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(tempYear),
                  child: Text(loc.get('apply')),
                ),
              ],
            ),
          );
        },
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked, 1, 1));
        _loadReports();
      }
    }
  }

  void _printStatement() {
    final companyName = ref.read(sessionProvider).companyName ?? 'Modiri Business';
    ReceiptPrinter.printFinancialReport(
      companyName: companyName,
      periodLabel: _periodLabel,
      revenue: _periodRevenue,
      cogs: _periodCogs,
      grossProfit: _periodGrossProfit,
      operatingExpenses: _periodExpenses,
      netProfit: _periodNetProfit,
      profitMargin: _profitMargin,
      salesCount: _salesCount,
      topProducts: _topProducts,
      expensesByCategory: _expensesByCategory,
    );
  }

  void _exportCsvDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final csv = StringBuffer();
    csv.writeln('Modiri AI - Financial Report Statement');
    csv.writeln('Period,$_periodLabel');
    csv.writeln('Metric,Amount (DZD),Notes');
    csv.writeln('Gross Revenue,$_periodRevenue,$_salesCount transactions');
    csv.writeln('Cost of Goods Sold,$_periodCogs,Procurement cost basis');
    csv.writeln('Gross Profit,$_periodGrossProfit,');
    csv.writeln('Operating Expenses,$_periodExpenses,Rent/utilities/salaries');
    csv.writeln('Net Operating Profit,$_periodNetProfit,Margin: ${_profitMargin.toStringAsFixed(1)}%');
    csv.writeln('');
    csv.writeln('Top Products');
    csv.writeln('Name,Units Sold,Revenue');
    for (final p in _topProducts) {
      final name = p['name'] ?? 'Product';
      final qty = p['unitsSold'] ?? p['quantity'] ?? 0;
      final rev = p['revenue'] ?? 0.0;
      csv.writeln('"$name",$qty,$rev');
    }
    csv.writeln('');
    csv.writeln(loc.get('expenses_by_category'));
    csv.writeln('Category,Amount (DZD)');
    for (final e in _expensesByCategory) {
      final cat = e['category'] ?? 'General';
      final amt = e['total'] ?? e['amount'] ?? 0.0;
      csv.writeln('"$cat",$amt');
    }

    final csvText = csv.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ModiriColors.surface(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.table_view, color: ModiriColors.brandTeal, size: 22),
            const SizedBox(width: 8),
            Text(loc.get('export_financial_csv'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.get('copy_export_csv_financial'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ModiriColors.border(isDark)),
                ),
                child: SelectableText(
                  csvText,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: ModiriColors.textPrimary(isDark)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.get('close'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: Text(loc.get('copy_to_clipboard')),
            style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandBlue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.get('csv_report_copied')), backgroundColor: ModiriColors.brandTeal),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final isFinancialTab = _tabController.index == 0;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isFinancialTab ? Icons.bar_chart : Icons.hourglass_bottom,
                        color: isFinancialTab ? ModiriColors.brandBlue : ModiriColors.brandAmber,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isFinancialTab
                            ? loc.get('financial_reports_header_title')
                            : loc.get('slow_moving_stock'),
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ModiriColors.textPrimary(isDark),
                            letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFinancialTab
                        ? loc.get('financial_reports_header_desc')
                        : 'Identify low-velocity products, tied-up working capital, and dead stock to optimize inventory reorders.',
                    style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: ModiriColors.card(isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: ModiriColors.brandBlue,
                      labelColor: ModiriColors.textPrimary(isDark),
                      unselectedLabelColor: ModiriColors.textSecondary(isDark),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(icon: const Icon(Icons.bar_chart, size: 16), text: loc.get('financial_reports_header_title')),
                        Tab(icon: const Icon(Icons.hourglass_bottom, size: 16), text: loc.get('slow_moving_stock')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isFinancialTab) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: Text(loc.get('print_statement')),
                      onPressed: _printStatement,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: Text(loc.get('export_csv')),
                      onPressed: _exportCsvDialog,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(loc.get('recalculate')),
                      onPressed: _loadReports,
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: Text(loc.get('export_csv')),
                      onPressed: _exportSlowMovingCsvDialog,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandAmber),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(loc.get('recalculate')),
                      onPressed: _loadSlowMovingReport,
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFinancialSummaryTab(isDark, loc),
                _buildSlowMovingTab(isDark, loc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryTab(bool isDark, ModiriLocalizations loc) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 1. GLOBAL / ALL-TIME NET PROFIT BANNER CARD matching website
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ModiriColors.lineDark),
              gradient: const LinearGradient(
                colors: [ModiriColors.ink900, ModiriColors.ink950, Color(0xFF0F172A)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ModiriColors.brandBlue.withOpacity(0.3)),
                        ),
                        child: Text(loc.get('all_time_overview'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ModiriColors.brandBlue)),
                      ),
                      const SizedBox(height: 10),
                      Text(loc.get('global_net_profit'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        loc.get('cumulative_ledger_desc'),
                        style: const TextStyle(fontSize: 12, color: ModiriColors.textDarkSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ModiriColors.ink950.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('all_revenue'), style: const TextStyle(color: ModiriColors.textDarkMuted, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(_formatCurrency(_allRevenue),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ModiriColors.brandTeal, fontFamily: 'monospace')),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('all_expenses'), style: const TextStyle(color: ModiriColors.textDarkMuted, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(_formatCurrency(_allExpenses),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ModiriColors.brandAmber, fontFamily: 'monospace')),
                          ],
                        ),
                        Container(width: 1, height: 35, color: ModiriColors.lineDark),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('global_net_profit'), style: const TextStyle(color: ModiriColors.textDarkMuted, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(_globalNetProfit),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: _globalNetProfit >= 0 ? ModiriColors.brandTeal : ModiriColors.brandRose,
                                fontFamily: 'monospace',
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

          const SizedBox(height: 24),

          // 2. PERIOD SELECTOR & CONTROLS ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Segmented Period Picker
              Container(
                decoration: BoxDecoration(
                  color: ModiriColors.surface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ModiriColors.border(isDark)),
                ),
                child: Row(
                  children: [
                    for (final p in ['daily', 'monthly', 'yearly']) ...[
                      InkWell(
                        onTap: () {
                          setState(() => _period = p);
                          _loadReports();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _period == p ? ModiriColors.brandBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _period == p ? Colors.white : ModiriColors.textSecondary(isDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Date Navigators (< Today / Month > + Interactive Picker)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModiriColors.surface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ModiriColors.border(isDark)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, size: 20, color: ModiriColors.textPrimary(isDark)),
                      onPressed: _prevPeriod,
                    ),
                    InkWell(
                      onTap: _pickPeriodDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 16, color: ModiriColors.brandBlue),
                            const SizedBox(width: 6),
                            Text(
                              _periodLabel,
                              style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, size: 20, color: ModiriColors.textPrimary(isDark)),
                      onPressed: _nextPeriod,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. PERIOD SPECIFIC KPI CARDS GRID
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.8,
              children: [
                _buildPeriodStatCard(
                  label: loc.get('period_gross_revenue'),
                  value: _formatCurrency(_periodRevenue),
                  sublabel: '$_salesCount ${loc.get('sales_transactions_count')}',
                  tone: ModiriColors.brandTeal,
                  icon: Icons.attach_money,
                  isDark: isDark,
                ),
                _buildPeriodStatCard(
                  label: loc.get('cost_of_goods_sold'),
                  value: _formatCurrency(_periodCogs),
                  sublabel: loc.get('inventory_purchase_costs'),
                  tone: ModiriColors.brandAmber,
                  icon: Icons.inventory_2_outlined,
                  isDark: isDark,
                ),
                _buildPeriodStatCard(
                  label: loc.get('gross_profit_label'),
                  value: _formatCurrency(_periodGrossProfit),
                  sublabel: loc.get('revenue_minus_cogs'),
                  tone: ModiriColors.brandBlue,
                  icon: Icons.trending_up,
                  isDark: isDark,
                ),
                _buildPeriodStatCard(
                  label: loc.get('period_net_profit'),
                  value: _formatCurrency(_periodNetProfit),
                  sublabel: '${loc.get('profit_margin_label')}: ${_profitMargin.toStringAsFixed(1)}%',
                  tone: _periodNetProfit >= 0 ? ModiriColors.brandTeal : ModiriColors.brandRose,
                  icon: Icons.account_balance_wallet,
                  isDark: isDark,
                ),
              ],
            );
          }),

          const SizedBox(height: 24),

          // 4. DETAILED BREAKDOWNS (Top Selling Items & Expenses by Category)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_outline, color: ModiriColors.brandAmber, size: 18),
                          const SizedBox(width: 8),
                          Text(loc.get('top_products'),
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _topProducts.length,
                        separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 16),
                        itemBuilder: (ctx, i) {
                          final item = _topProducts[i];
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? 'Product', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('${item['quantity']} ${loc.get('quantity_sold')}', style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                ],
                              ),
                              Text(_formatCurrency((item['revenue'] as num?)?.toDouble() ?? 0.0),
                                  style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: ModiriPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pie_chart_outline, color: ModiriColors.brandViolet, size: 18),
                          const SizedBox(width: 8),
                          Text(loc.get('expenses_by_category'),
                              style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _expensesByCategory.length,
                        separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 16),
                        itemBuilder: (ctx, i) {
                          final exp = _expensesByCategory[i];
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(exp['category'] ?? 'Operations', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(_formatCurrency((exp['amount'] as num?)?.toDouble() ?? 0.0),
                                  style: const TextStyle(color: ModiriColors.brandAmber, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlowMovingTab(bool isDark, ModiriLocalizations loc) {
    if (_isLoadingSlowMoving) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filteredSlowMoving;
    final totalValuation = filtered.fold<double>(0.0, (sum, i) => sum + i.stockValuation);
    final deadStockCount = filtered.where((i) => i.unitsSold == 0).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Panel
          ModiriPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Period Chips
                    Text(loc.get('days_period'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.textPrimary(isDark))),
                    const SizedBox(width: 10),
                    Wrap(
                      spacing: 6,
                      children: [7, 30, 60, 90].map((d) {
                        final isSel = _slowMovingDays == d;
                        return ChoiceChip(
                          label: Text('$d d'),
                          selected: isSel,
                          selectedColor: ModiriColors.brandAmber,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.black : ModiriColors.textPrimary(isDark),
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setState(() => _slowMovingDays = d);
                              _loadSlowMovingReport();
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 24),
                    // Threshold Chips
                    Text(loc.get('threshold_units'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.textPrimary(isDark))),
                    const SizedBox(width: 10),
                    Wrap(
                      spacing: 6,
                      children: [0, 1, 2, 5].map((val) {
                        final isSel = _slowMovingThreshold == val;
                        final chipLabel = val == 0 ? loc.get('dead_stock_chip') : '<= $val';
                        return ChoiceChip(
                          label: Text(chipLabel),
                          selected: isSel,
                          selectedColor: ModiriColors.brandAmber,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.black : ModiriColors.textPrimary(isDark),
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (sel) {
                            if (sel) {
                              setState(() => _slowMovingThreshold = val);
                              _loadSlowMovingReport();
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search bar
                TextField(
                  controller: _slowMovingSearchCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: loc.get('filter_reports_hint'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _slowMovingSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _slowMovingSearchCtrl.clear();
                              setState(() => _slowMovingSearch = '');
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _slowMovingSearch = v.trim()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metric Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildPeriodStatCard(
                  label: loc.get('slow_moving_stock'),
                  value: '${filtered.length} ${loc.get('products_count')}',
                  sublabel: loc.get('sales_threshold_in_days').replaceAll('{th}', '$_slowMovingThreshold').replaceAll('{days}', '$_slowMovingDays'),
                  icon: Icons.inventory_2_outlined,
                  tone: ModiriColors.brandAmber,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildPeriodStatCard(
                  label: loc.get('tied_up_capital'),
                  value: _formatCurrency(totalValuation),
                  sublabel: loc.get('cost_basis_slow_moving'),
                  icon: Icons.monetization_on_outlined,
                  tone: ModiriColors.brandRose,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildPeriodStatCard(
                  label: loc.get('zero_sales_dead_stock'),
                  value: '$deadStockCount ${loc.get('products_count')}',
                  sublabel: loc.get('no_sales_in_days').replaceAll('{days}', '$_slowMovingDays'),
                  icon: Icons.warning_amber_rounded,
                  tone: ModiriColors.brandRose,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items Table
          if (filtered.isEmpty)
            ModiriPanel(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 48, color: ModiriColors.brandTeal),
                    const SizedBox(height: 12),
                    Text(
                      loc.get('no_slow_moving_detected'),
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc.get('all_items_above_threshold'),
                      style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ModiriPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} ${loc.get("slow_moving_stock")}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ModiriColors.textPrimary(isDark)),
                      ),
                      Text(
                        '${loc.get("tied_up_capital")}: ${_formatCurrency(totalValuation)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ModiriColors.brandAmber, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(ModiriColors.card(isDark)),
                      columns: [
                        DataColumn(label: Text(loc.get('products'))),
                        DataColumn(label: Text(loc.get('category'))),
                        DataColumn(label: Text(loc.get('current_stock_label'))),
                        DataColumn(label: Text(loc.get('unit_cost'))),
                        DataColumn(label: Text(loc.get('selling_price'))),
                        DataColumn(label: Text('${loc.get("units_sold")} ($_slowMovingDays d)')),
                        DataColumn(label: Text(loc.get('tied_up_capital'))),
                        DataColumn(label: Text(loc.get('days_in_inventory'))),
                      ],
                      rows: filtered.map((it) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(it.name, style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                                  if (it.barcode != null && it.barcode!.isNotEmpty)
                                    Text(it.barcode!, style: TextStyle(fontSize: 10, color: ModiriColors.textMuted(isDark))),
                                ],
                              ),
                            ),
                            DataCell(Text(it.category ?? '-', style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark)))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: it.currentStock > 0 ? ModiriColors.brandAmber.withOpacity(0.15) : ModiriColors.brandRose.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${it.currentStock}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: it.currentStock > 0 ? ModiriColors.brandAmber : ModiriColors.brandRose)),
                              ),
                            ),
                            DataCell(Text(_formatCurrency(it.purchasePrice), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                            DataCell(Text(_formatCurrency(it.sellingPrice), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: it.unitsSold == 0 ? ModiriColors.brandRose.withOpacity(0.15) : ModiriColors.brandTeal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${it.unitsSold}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: it.unitsSold == 0 ? ModiriColors.brandRose : ModiriColors.brandTeal)),
                              ),
                            ),
                            DataCell(Text(_formatCurrency(it.stockValuation), style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandRose, fontSize: 12, fontFamily: 'monospace'))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${it.daysInInventory} d', style: TextStyle(fontSize: 12, color: ModiriColors.textPrimary(isDark))),
                                  if (it.insufficientHistory) ...[
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: loc.get('newly_created_product_tooltip').replaceAll('{days}', '$_slowMovingDays'),
                                      child: const Icon(Icons.info_outline, size: 14, color: ModiriColors.brandAmber),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
