import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/utils/modiri_formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';

class DesktopAiAssistantScreen extends ConsumerStatefulWidget {
  const DesktopAiAssistantScreen({super.key});

  @override
  ConsumerState<DesktopAiAssistantScreen> createState() => _DesktopAiAssistantScreenState();
}

class _DesktopAiAssistantScreenState extends ConsumerState<DesktopAiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  String _formatCurrency(num? amount) {
    return ModiriFormatters.formatCurrency(
      amount,
      languageCode: ref.read(desktopLocaleProvider).languageCode,
      decimalDigits: 2,
      showSymbol: true,
    );
  }

  // Chat Advisor State
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoadingChat = false;

  // Invoice Scanner State
  bool _isScanning = false;
  bool _isDemoMode = false;
  String? _scanStatusMessage;
  String? _scanLogId;
  String? _scannedFileName;
  final List<_DesktopScannedItem> _scannedItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final session = ref.read(sessionProvider);
    _messages.add({
      'role': 'assistant',
      'content':
          'Hello! I am your Modiri AI business advisor for **${session.companyName ?? "your enterprise"}**.\n\nI have direct access to your real-time sales, inventory metrics, and expense logs from the shared backend. Ask me any question regarding your financial performance, inventory reorders, or operational trends!',
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // AI ADVISOR CHAT METHODS
  // -------------------------------------------------------------
  Future<void> _sendMessage([String? quickText]) async {
    final text = (quickText ?? _messageController.text).trim();
    if (text.isEmpty || _isLoadingChat) return;

    _messageController.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoadingChat = true;
    });

    _scrollToBottom();

    String? reply;
    final session = ref.read(sessionProvider);

    // Try backend if not in an explicit offline session
    if (!session.isOfflineSession) {
      try {
        final client = ref.read(apiClientProvider);
        final history = _messages.sublist(1).map((m) => {
              'role': m['role'],
              'content': m['content'],
            }).toList();

        final res = await client.post('/ai/chat', body: {
          'message': text,
          'history': history,
        }).timeout(const Duration(seconds: 15));

        if (res is Map) {
          if (res['data'] is Map) {
            reply = res['data']['reply']?.toString() ?? res['data']['message']?.toString();
          }
          reply ??= res['reply']?.toString() ?? res['response']?.toString() ?? res['message']?.toString();
        }
      } catch (_) {
        // Fallback to grounded local AI engine
        reply = null;
      }
    }

    // Grounded Local AI Advisor fallback (works 100% offline from local database)
    if (reply == null || reply.trim().isEmpty) {
      reply = await _generateLocalAiAdvisorReply(text);
    }

    if (mounted) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': reply!});
        _isLoadingChat = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _generateLocalAiAdvisorReply(String query) async {
    final companyId = ref.read(sessionProvider).companyId ?? 'default_company';
    final lang = ref.read(desktopLocaleProvider).languageCode;
    final lower = query.toLowerCase();

    try {
      final db = await ModiriDesktopDatabase.instance.database;

      // 1. Sales & Revenue questions
      if (lower.contains('sale') || lower.contains('vente') || lower.contains('chiffre') || lower.contains('revenue') || lower.contains('بيع') || lower.contains('دخل') || lower.contains('اليوم')) {
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        var salesRows = await db.rawQuery(
          "SELECT COUNT(*) AS count, COALESCE(SUM(total), 0.0) AS total FROM sales WHERE company_id = ? AND date(created_at) = ?",
          [companyId, todayStr],
        );
        if ((salesRows.first['count'] as num?)?.toInt() == 0) {
          salesRows = await db.rawQuery(
            "SELECT COUNT(*) AS count, COALESCE(SUM(total), 0.0) AS total FROM sales WHERE date(created_at) = ?",
            [todayStr],
          );
        }
        final count = (salesRows.first['count'] as num?)?.toInt() ?? 0;
        final total = (salesRows.first['total'] as num?)?.toDouble() ?? 0.0;

        final formattedToday = ModiriFormatters.toLatinDigits(todayStr);
        final formattedCount = ModiriFormatters.formatNumber(count);
        if (lang == 'ar') {
          return 'تقرير المبيعات لليوم ($formattedToday):\n• عدد العمليات: $formattedCount\n• إجمالي الإيرادات: ${_formatCurrency(total)}\n\nجميع البيانات مستخرجة بدقة من قاعدة بياناتك المحلية.';
        } else if (lang == 'fr') {
          return 'Rapport d\'activité du jour ($formattedToday) :\n• Nombre de ventes : $formattedCount\n• Chiffre d\'affaires total : ${_formatCurrency(total)}\n\nCes statistiques sont calculées directement depuis votre base de données locale.';
        } else {
          return 'Today\'s Sales Report ($formattedToday):\n• Total transactions: $formattedCount\n• Total revenue: ${_formatCurrency(total)}\n\nCalculated authoritatively from your local database.';
        }
      }

      // 2. Low stock / Products questions
      if (lower.contains('stock') || lower.contains('produit') || lower.contains('inventaire') || lower.contains('rupture') || lower.contains('مخزون') || lower.contains('منتج') || lower.contains('سلع')) {
        var lowStockRows = await db.rawQuery(
          "SELECT name, stock_quantity, price FROM products WHERE company_id = ? AND stock_quantity <= 5 ORDER BY stock_quantity ASC LIMIT 6",
          [companyId],
        );
        if (lowStockRows.isEmpty) {
          lowStockRows = await db.rawQuery(
            "SELECT name, stock_quantity, price FROM products WHERE stock_quantity <= 5 ORDER BY stock_quantity ASC LIMIT 6",
          );
        }
        if (lowStockRows.isEmpty) {
          if (lang == 'ar') return 'حالة المخزون ممتازة: لا توجد منتجات في حالة نقص أو قرب نفاد المخزون.';
          if (lang == 'fr') return 'Excellente gestion de stock : aucun produit en rupture ou sous le seuil d\'alerte.';
          return 'Inventory health is good: no products are currently below the critical stock threshold.';
        }

        final itemsList = lowStockRows
            .map((r) => '• ${r['name']} : ${ModiriFormatters.formatNumber((r['stock_quantity'] as num?)?.toInt() ?? 0)} unités restantes (${_formatCurrency((r['price'] as num?)?.toDouble() ?? 0.0)})')
            .join('\n');

        if (lang == 'ar') {
          return 'تنبيه المخزون المنخفض (أقل من 5 قطع):\n$itemsList\n\nيُنصح بإصدار طلبية شراء أو مسح فاتورة مورد لتجديد هذه المواد.';
        } else if (lang == 'fr') {
          return 'Alerte stock critique (≤ 5 unités) :\n$itemsList\n\nConseil : Effectuez un réapprovisionnement ou scannez une facture fournisseur.';
        } else {
          return 'Critical Stock Alert (≤ 5 units):\n$itemsList\n\nRecommendation: Restock these items via supplier purchase or invoice scan.';
        }
      }

      // 3. Customer Debts / Credit questions
      if (lower.contains('credit') || lower.contains('debt') || lower.contains('dette') || lower.contains('creance') || lower.contains('دين') || lower.contains('ديون') || lower.contains('عميل')) {
        var debtRows = await db.rawQuery(
          "SELECT name, credit_balance, phone FROM customers WHERE company_id = ? AND credit_balance > 0 ORDER BY credit_balance DESC LIMIT 5",
          [companyId],
        );
        if (debtRows.isEmpty) {
          debtRows = await db.rawQuery(
            "SELECT name, credit_balance, phone FROM customers WHERE credit_balance > 0 ORDER BY credit_balance DESC LIMIT 5",
          );
        }
        var sumRows = await db.rawQuery(
          "SELECT COALESCE(SUM(credit_balance), 0.0) AS total_debt FROM customers WHERE company_id = ?",
          [companyId],
        );
        if ((sumRows.first['total_debt'] as num?)?.toDouble() == 0.0) {
          sumRows = await db.rawQuery(
            "SELECT COALESCE(SUM(credit_balance), 0.0) AS total_debt FROM customers",
          );
        }
        final totalDebt = (sumRows.first['total_debt'] as num?)?.toDouble() ?? 0.0;

        if (debtRows.isEmpty || totalDebt <= 0) {
          if (lang == 'ar') return 'سجل الديون سليم: لا توجد ديون مستحقة على العملاء حالياً.';
          if (lang == 'fr') return 'Aucune créance en attente : tous vos clients sont à jour de règlement.';
          return 'Credit ledger clean: no outstanding customer balances found.';
        }

        final topDebtors = debtRows
            .map((d) => '• ${d['name']} : ${_formatCurrency((d['credit_balance'] as num?)?.toDouble() ?? 0.0)}')
            .join('\n');

        if (lang == 'ar') {
          return 'تقرير ديون العملاء المستحقة:\n• إجمالي الديون: ${_formatCurrency(totalDebt)}\n• أبرز العملاء المدينين:\n$topDebtors\n\nيمكنك تسجيل دفعات التسوية من شاشة الديون.';
        } else if (lang == 'fr') {
          return 'Situation des créances clients :\n• Total des dettes en attente : ${_formatCurrency(totalDebt)}\n• Principaux débiteurs :\n$topDebtors\n\nVous pouvez enregistrer les règlements directement depuis l\'onglet Dettes.';
        } else {
          return 'Customer Credit Ledger Summary:\n• Total outstanding balance: ${_formatCurrency(totalDebt)}\n• Top accounts due:\n$topDebtors\n\nSettlement payments can be recorded from the Credit & Debts screen.';
        }
      }

      // Default General Summary / Advisor Guidance
      var prodCount = await db.rawQuery("SELECT COUNT(*) AS count FROM products WHERE company_id = ?", [companyId]);
      if ((prodCount.first['count'] as num?)?.toInt() == 0) {
        prodCount = await db.rawQuery("SELECT COUNT(*) AS count FROM products");
      }
      var custCount = await db.rawQuery("SELECT COUNT(*) AS count FROM customers WHERE company_id = ?", [companyId]);
      if ((custCount.first['count'] as num?)?.toInt() == 0) {
        custCount = await db.rawQuery("SELECT COUNT(*) AS count FROM customers");
      }
      var invCount = await db.rawQuery("SELECT COUNT(*) AS count FROM invoices WHERE company_id = ?", [companyId]);
      if ((invCount.first['count'] as num?)?.toInt() == 0) {
        invCount = await db.rawQuery("SELECT COUNT(*) AS count FROM invoices");
      }

      final pC = (prodCount.first['count'] as num?)?.toInt() ?? 0;
      final cC = (custCount.first['count'] as num?)?.toInt() ?? 0;
      final iC = (invCount.first['count'] as num?)?.toInt() ?? 0;

      if (lang == 'ar') {
        return 'مرحباً بك! أنا مستشارك الذكي في Modiri AI.\n\nملخص نشاطك الحالي:\n• عدد المنتجات في الكتالوج: ${ModiriFormatters.formatNumber(pC)}\n• عدد العملاء المسجلين: ${ModiriFormatters.formatNumber(cC)}\n• عدد الفواتير المسجلة: ${ModiriFormatters.formatNumber(iC)}\n\nيمكنك أن تسألني عن: مبيعات اليوم، حالة المخزون، المنتجات الناقصة، أو ديون العملاء.';
      } else if (lang == 'fr') {
        return 'Bonjour ! Je suis votre conseiller d\'affaires Modiri AI.\n\nAperçu de votre activité :\n• Produits en catalogue : ${ModiriFormatters.formatNumber(pC)}\n• Clients enregistrés : ${ModiriFormatters.formatNumber(cC)}\n• Factures émises : ${ModiriFormatters.formatNumber(iC)}\n\nPosez-moi une question sur : les ventes du jour, les alertes de stock, les dettes clients ou le bilan global.';
      } else {
        return 'Hello! I am your Modiri AI business advisor.\n\nQuick snapshot of your business:\n• Catalog products: ${ModiriFormatters.formatNumber(pC)}\n• Registered clients: ${ModiriFormatters.formatNumber(cC)}\n• Invoices created: ${ModiriFormatters.formatNumber(iC)}\n\nFeel free to ask about: today\'s revenue, inventory alerts, customer debts, or business performance.';
      }
    } catch (e) {
      if (lang == 'ar') return 'أنا جاهز للإجابة عن استفساراتك حول المبيعات والمخزون والديون.';
      if (lang == 'fr') return 'Je suis prêt à vous guider sur vos ventes, votre stock et vos créances.';
      return 'I am ready to assist you with sales analysis, inventory health, and customer credit.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // -------------------------------------------------------------
  // AI INVOICE SCANNER METHODS
  // -------------------------------------------------------------
  Future<void> _pickAndScanInvoice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.get('file_empty_unreadable')),
              backgroundColor: ModiriColors.brandRose,
            ),
          );
        }
        return;
      }

      final fileName = file.name;
      final ext = fileName.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.get('unsupported_file_format')} (.$ext)'),
              backgroundColor: ModiriColors.brandRose,
            ),
          );
        }
        return;
      }

      final imageBase64 = base64Encode(bytes);
      final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/jpeg';
      final scanId = 'SCAN_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

      setState(() {
        _isScanning = true;
        _isDemoMode = false;
        _scannedFileName = fileName;
        _scanStatusMessage = 'Uploading and analyzing invoice with AI vision...';
        _scannedItems.clear();
      });

      final client = ref.read(apiClientProvider);
      final response = await client.post(
        '/ai/invoices/scan',
        body: {
          'imageBase64': imageBase64,
          'mimeType': mimeType,
          'scanId': scanId,
        },
      );

      final data = response is Map ? (response['data'] as Map<String, dynamic>? ?? {}) : <String, dynamic>{};
      final logId = data['logId'] as String?;
      final rawItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final existingProducts = ref.read(productsRepositoryProvider).valueOrNull ?? [];

      final parsed = rawItems.map((r) {
        final name = (r['name'] ?? '').toString();
        final qty = (r['quantity'] as num?)?.toInt() ?? 1;
        final cost = (r['unitPrice'] as num?)?.toDouble() ?? 0.0;
        
        // Match existing product selling price if already present in catalog
        final existingMatch = existingProducts.cast<Product?>().firstWhere(
          (p) => p != null && p.name.trim().toLowerCase() == name.trim().toLowerCase(),
          orElse: () => null,
        );

        final sell = (r['sellingPrice'] as num?)?.toDouble() ?? existingMatch?.price;
        return _DesktopScannedItem(
          name: name,
          quantity: qty,
          purchasePrice: cost,
          sellingPrice: sell,
          matchedProductId: existingMatch?.id,
        );
      }).where((it) => it.name.trim().isNotEmpty).toList();

      if (mounted) {
        final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
        setState(() {
          _isScanning = false;
          _isDemoMode = false;
          _scanLogId = logId;
          if (parsed.isNotEmpty) {
            _scannedItems.addAll(parsed);
            _scanStatusMessage = '${loc.get('purchase_invoice_recorded')}: ${parsed.length} ($fileName)';
          } else {
            _scanStatusMessage = loc.get('no_products_found_desc');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isDemoMode = false;
          _scannedItems.clear();
          _scanStatusMessage = 'AI Scan Error: $e';
        });
        final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.get('failed_process_invoice')} $e'),
            backgroundColor: ModiriColors.brandRose,
          ),
        );
      }
    }
  }

  void _loadDemoInvoice() {
    setState(() {
      _isDemoMode = true;
      _scannedFileName = 'sample_algerian_supplier_invoice.pdf';
      _scanStatusMessage = 'Demo invoice template loaded. Use for review inspection; not from genuine scan.';
      _scannedItems.clear();
      _scannedItems.addAll(_getDemoItems());
    });
  }

  List<_DesktopScannedItem> _getDemoItems() {
    return [
      _DesktopScannedItem(name: 'Lait Entier Candia 1L', quantity: 24, purchasePrice: 110.0, sellingPrice: 135.0),
      _DesktopScannedItem(name: 'Huile de Tournesol Elio 5L', quantity: 10, purchasePrice: 620.0, sellingPrice: 750.0),
      _DesktopScannedItem(name: 'Sucre Blanc En Poudre 1kg', quantity: 20, purchasePrice: 90.0, sellingPrice: 110.0),
      _DesktopScannedItem(name: 'Pâtes Couscous Sim 1kg', quantity: 15, purchasePrice: 95.0, sellingPrice: 125.0),
      _DesktopScannedItem(name: 'Café Moulu Famico 250g', quantity: 12, purchasePrice: 220.0, sellingPrice: 270.0),
    ];
  }

  Future<void> _confirmAndImportToInventory() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final validItems = _scannedItems.where((it) => it.name.trim().isNotEmpty && it.quantity > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('no_valid_items_to_import')),
          backgroundColor: ModiriColors.brandAmber,
        ),
      );
      return;
    }

    // If in demo mode, enforce explicit confirmation before saving sample records
    if (_isDemoMode) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: ModiriColors.brandAmber, size: 22),
              const SizedBox(width: 8),
              Text(loc.get('import_demo_samples_title'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16)),
            ],
          ),
          content: Text(
            'You are in Demo Preview Mode. Confirming will add these 5 sample mock products to your real inventory database.\n\nDo you want to proceed?',
            style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandAmber),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.get('import_demo_samples_confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    // Validate that every item has a selling price specified
    for (final item in validItems) {
      if (item.sellingPrice == null || item.sellingPrice! < 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.get('selling_price_required_item')} "${item.name}". ${loc.get('specify_before_import')}'),
            backgroundColor: ModiriColors.brandRose,
          ),
        );
        return;
      }
    }

    setState(() => _isScanning = true);

    int addedCount = 0;
    int updatedCount = 0;
    try {
      final repo = ref.read(productsRepositoryProvider.notifier);
      final currentProducts = ref.read(productsRepositoryProvider).valueOrNull ?? [];

      for (final item in validItems) {
        // Prevent duplicate creation: match existing product by name or matchedProductId
        final existing = currentProducts.cast<Product?>().firstWhere(
          (p) =>
              p != null &&
              (p.id == item.matchedProductId ||
                  p.name.trim().toLowerCase() == item.name.trim().toLowerCase()),
          orElse: () => null,
        );

        if (existing != null) {
          // Restock existing product in place
          final updatedProduct = Product(
            id: existing.id,
            companyId: existing.companyId,
            name: existing.name,
            category: existing.category,
            costPrice: item.purchasePrice > 0 ? item.purchasePrice : existing.costPrice,
            price: item.sellingPrice!,
            stockQuantity: existing.stockQuantity + item.quantity,
            minimumStock: existing.minimumStock,
            barcode: existing.barcode,
            expirationDate: existing.expirationDate,
            size: existing.size,
            color: existing.color,
            brand: existing.brand,
          );
          await repo.updateProduct(updatedProduct);
          updatedCount++;
        } else {
          // Create new product
          await repo.addProduct(
            name: item.name.trim(),
            category: 'General',
            costPrice: item.purchasePrice,
            price: item.sellingPrice!,
            stockQuantity: item.quantity,
            minimumStock: 5,
          );
          addedCount++;
        }
      }

      // Notify backend confirmation using canonical endpoint if scanLogId exists
      if (_scanLogId != null) {
        try {
          final client = ref.read(apiClientProvider);
          await client.post('/ai/invoices/scan/$_scanLogId/confirm');
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$addedCount new product(s) added, $updatedCount existing product(s) restocked.',
            ),
            backgroundColor: ModiriColors.brandTeal,
          ),
        );
        setState(() {
          _isScanning = false;
          _isDemoMode = false;
          _scannedItems.clear();
          _scannedFileName = null;
          _scanStatusMessage = 'Items successfully imported into inventory.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.get('failed_import_inventory')} $e'),
            backgroundColor: ModiriColors.brandRose,
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // BUILD METHOD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation Header with Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandViolet.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, color: ModiriColors.brandViolet, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.get('ai_assistant'),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.get('ai_subtitle'),
                        style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: ModiriColors.card(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ModiriColors.border(isDark)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: ModiriColors.brandViolet,
                  labelColor: ModiriColors.textPrimary(isDark),
                  unselectedLabelColor: ModiriColors.textSecondary(isDark),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      text: loc.get('ai_advisor'),
                    ),
                    Tab(
                      icon: const Icon(Icons.document_scanner_outlined, size: 16),
                      text: loc.get('ai_scanner'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // TabBar Content Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAiAdvisorTab(loc, isDark),
                _buildInvoiceScannerTab(loc, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: AI ADVISOR CHAT
  // -------------------------------------------------------------
  Widget _buildAiAdvisorTab(ModiriLocalizations loc, bool isDark) {
    final suggestions = [
      'How much did I earn this month?',
      'Which products are low in stock?',
      'Do I have any unpaid invoices?',
      'Who are my top customers with unpaid debt?',
    ];

    return Column(
      children: [
        // Quick Prompts Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions.map((p) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  label: Text(p),
                  backgroundColor: ModiriColors.card(isDark),
                  labelStyle: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: ModiriColors.border(isDark)),
                  ),
                  onPressed: () => _sendMessage(p),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Chat Messages View
        Expanded(
          child: ModiriPanel(
            padding: const EdgeInsets.all(16),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: _messages.length + (_isLoadingChat ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                if (i == _messages.length && _isLoadingChat) {
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ModiriColors.brandViolet.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome, color: ModiriColors.brandViolet, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Analyzing business data...',
                        style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 13),
                      ),
                    ],
                  );
                }

                final msg = _messages[i];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? ModiriColors.brandBlue.withOpacity(isDark ? 0.2 : 0.1)
                          : (isDark ? ModiriColors.ink850 : ModiriColors.lightInk850),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUser
                            ? ModiriColors.brandBlue.withOpacity(isDark ? 0.4 : 0.25)
                            : ModiriColors.border(isDark),
                      ),
                    ),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(
                        color: ModiriColors.textPrimary(isDark),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Prompt Input Row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Ask Modiri AI a question about your business performance...',
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: Text(loc.get('send')),
              onPressed: _isLoadingChat ? null : () => _sendMessage(),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 2: AI INVOICE SCANNER
  // -------------------------------------------------------------
  Widget _buildInvoiceScannerTab(ModiriLocalizations loc, bool isDark) {
    final double totalEstimatedCost = _scannedItems.fold(
      0.0,
      (sum, item) => sum + (item.quantity * item.purchasePrice),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Controls Panel
        ModiriPanel(
          padding: const EdgeInsets.all(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.get('scan_invoice_title'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.get('scan_invoice_subtitle'),
                      style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
                    ),
                    if (_scanStatusMessage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _isScanning
                                ? Icons.sync
                                : (_scanStatusMessage!.startsWith('AI Scan Error')
                                    ? Icons.error_outline
                                    : Icons.info_outline),
                            size: 14,
                            color: _isScanning
                                ? ModiriColors.brandViolet
                                : (_scanStatusMessage!.startsWith('AI Scan Error')
                                    ? ModiriColors.brandRose
                                    : ModiriColors.brandTeal),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _scanStatusMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isScanning
                                    ? ModiriColors.brandViolet
                                    : (_scanStatusMessage!.startsWith('AI Scan Error')
                                        ? ModiriColors.brandRose
                                        : ModiriColors.brandTeal),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on_outlined, size: 16),
                    label: Text(loc.get('try_demo_invoice')),
                    onPressed: _isScanning ? null : _loadDemoInvoice,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModiriColors.brandViolet,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file, size: 16),
                    label: Text(loc.get('browse_invoice_file')),
                    onPressed: _isScanning ? null : _pickAndScanInvoice,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Extracted Table & Confirmation
        Expanded(
          child: ModiriPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Demo Warning Banner if in Demo Mode
                if (_isDemoMode) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandAmber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: ModiriColors.brandAmber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'DEMO PREVIEW MODE: These are mock invoice items for UI inspection. They are not from a genuine scan.',
                            style: TextStyle(
                              color: ModiriColors.brandAmber,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          loc.get('scanned_items_title'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isDemoMode
                                ? ModiriColors.brandAmber.withOpacity(0.15)
                                : ModiriColors.brandViolet.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isDemoMode
                                  ? ModiriColors.brandAmber.withOpacity(0.3)
                                  : ModiriColors.brandViolet.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _isDemoMode
                                ? '${_scannedItems.length} DEMO ITEMS'
                                : '${_scannedItems.length} items',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isDemoMode ? ModiriColors.brandAmber : ModiriColors.brandViolet,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_scannedFileName != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            'File: $_scannedFileName',
                            style: TextStyle(fontSize: 12, color: ModiriColors.textMuted(isDark)),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(loc.get('add_row')),
                          onPressed: () {
                            setState(() {
                              _scannedItems.add(_DesktopScannedItem(
                                name: 'New Item',
                                quantity: 1,
                                purchasePrice: 0.0,
                                sellingPrice: 0.0,
                              ));
                            });
                          },
                        ),
                        if (_scannedItems.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: Text(loc.get('clear_all')),
                            onPressed: () {
                              setState(() {
                                _scannedItems.clear();
                                _isDemoMode = false;
                                _scannedFileName = null;
                                _scanStatusMessage = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                Divider(height: 20, color: ModiriColors.border(isDark)),

                Expanded(
                  child: _scannedItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: ModiriColors.textMuted(isDark).withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No invoice scanned yet.',
                                style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Upload a supplier invoice (Image/PDF) or click "Try Demo Invoice" to preview the review & import workflow.',
                                style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(3),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                              4: FixedColumnWidth(50),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: ModiriColors.border(isDark))),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(loc.get('item_name'), style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(loc.get('quantity'), style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('${loc.get('unit_cost')} (DZD)', style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('${loc.get('selling_price')} (DZD) *', style: TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                                  ),
                                  const SizedBox.shrink(),
                                ],
                              ),
                              ..._scannedItems.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;

                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                                      child: TextFormField(
                                        initialValue: item.name,
                                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                                        onChanged: (val) => item.name = val,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                                      child: TextFormField(
                                        initialValue: item.quantity.toString(),
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                                        onChanged: (val) {
                                          final parsed = int.tryParse(val);
                                          if (parsed != null && parsed >= 0) {
                                            setState(() => item.quantity = parsed);
                                          }
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                                      child: TextFormField(
                                        initialValue: item.purchasePrice.toStringAsFixed(2),
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                                        onChanged: (val) {
                                          final parsed = double.tryParse(val);
                                          if (parsed != null && parsed >= 0) {
                                            setState(() => item.purchasePrice = parsed);
                                          }
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 4.0),
                                      child: TextFormField(
                                        initialValue: item.sellingPrice != null
                                            ? item.sellingPrice!.toStringAsFixed(2)
                                            : '',
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: loc.get('enter_price_hint'),
                                          hintStyle: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.all(8),
                                        ),
                                        onChanged: (val) {
                                          final parsed = double.tryParse(val);
                                          if (parsed != null && parsed >= 0) {
                                            setState(() => item.sellingPrice = parsed);
                                          }
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: ModiriColors.brandRose),
                                      onPressed: () {
                                        setState(() {
                                          _scannedItems.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                ),

                Divider(height: 20, color: ModiriColors.border(isDark)),

                // Bottom Action & Total Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Estimated Total Cost: ',
                          style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13),
                        ),
                        Text(
                          _formatCurrency(totalEstimatedCost),
                          style: const TextStyle(
                            color: ModiriColors.brandTeal,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDemoMode ? ModiriColors.brandAmber : ModiriColors.brandTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        _isDemoMode ? 'Import Demo Samples' : loc.get('confirm_import_inventory'),
                      ),
                      onPressed: (_scannedItems.isEmpty || _isScanning) ? null : _confirmAndImportToInventory,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopScannedItem {
  String name;
  int quantity;
  double purchasePrice;
  double? sellingPrice;
  String? matchedProductId;

  _DesktopScannedItem({
    required this.name,
    required this.quantity,
    required this.purchasePrice,
    this.sellingPrice,
    this.matchedProductId,
  });
}
