import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/sale.dart';
import '../../../../l10n/app_localizations.dart';

/// AI Invoice Scanner — Spec Ch. 15.
///
/// IMPORTANT SCOPE NOTE: this batch implements the full SCREEN FLOW and
/// the mandatory human-review/confirm gate, but the "AI Vision Structuring"
/// step is MOCKED (a fixed delay + fixed extracted items) rather than a
/// real OpenAI Vision call — that integration is explicitly Phase 6
/// ("OpenAI + OCR + AI Assistant + AI Insights + Invoice Scanner"), and
/// requires a real OpenAI-backed endpoint that doesn't exist until
/// Phase 6.
/// What IS real and enforced here: extracted items are NEVER written to
/// ProductsRepository/SalesRepository until the user reviews and taps
/// Confirm — matching the spec's "AI layer never writes directly to
/// inventory" design principle (Ch. 15.2).
///
/// This scanner now serves TWO different invoice types, chosen up front
/// from the Dashboard's scan-invoice chooser (see dashboard_screen.dart
/// `showScanInvoiceChooser`), because they have opposite effects on
/// inventory and can't be told apart from the photo alone:
///   - [InvoiceScanMode.stock]: a purchase/supplier invoice — goods
///     coming IN. Confirming creates brand-new products in inventory
///     (original, unchanged behavior).
///   - [InvoiceScanMode.sales]: a sales receipt/invoice — goods going
///     OUT. Confirming records one real Sale, so every line has to be
///     matched to a product that already exists in stock (you can't
///     sell something you don't have on the shelf) — see
///     _AiReviewScreenState's sales-mode branch.
enum InvoiceScanMode { stock, sales }

class ScannedItem {
  ScannedItem({
    required this.name,
    required this.quantity,
    required this.purchasePrice,
    this.matchedProductId,
  });
  String name;
  int quantity;
  double purchasePrice;

  /// Sales mode only: which existing product this scanned line has been
  /// matched to. Null means "no match yet / needs the user to pick one"
  /// — a sale cannot be submitted while any item is still null.
  String? matchedProductId;
}

class AiScannerScreen extends StatelessWidget {
  const AiScannerScreen({super.key, required this.mode});

  final InvoiceScanMode mode;

  void _startScan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiProcessingScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modeLabel = mode == InvoiceScanMode.sales
        ? l10n.scanSalesInvoiceOption
        : l10n.scanStockInvoiceOption;

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.scanInvoiceTitle} · $modeLabel')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              ),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(l10n.pointCameraAtInvoice, textAlign: TextAlign.center),
                  Text(l10n.keepInvoiceFlatWellLit, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: () => _startScan(context),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(l10n.cameraButton),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => _startScan(context),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.chooseFromGallery),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => _startScan(context),
              child: Text(l10n.tryDemoInvoice),
            ),
          ],
        ),
      ),
    );
  }
}

class AiProcessingScreen extends StatefulWidget {
  const AiProcessingScreen({super.key, required this.mode});

  final InvoiceScanMode mode;

  @override
  State<AiProcessingScreen> createState() => _AiProcessingScreenState();
}

class _AiProcessingScreenState extends State<AiProcessingScreen> {
  @override
  void initState() {
    super.initState();
    // MOCK: simulates OCR + AI Vision latency. Real Phase 6 wiring
    // replaces this with an actual POST /ai/invoices/scan call. The
    // demo items are the same regardless of mode — this is a stand-in
    // for whatever the real OCR step will return, and the user reviews
    // (and can edit) everything before anything is written anywhere.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AiResultsScreen(
              mode: widget.mode,
              items: [
                ScannedItem(name: 'Milk', quantity: 10, purchasePrice: 120),
                ScannedItem(name: 'Bread', quantity: 20, purchasePrice: 15),
                ScannedItem(name: 'Sugar', quantity: 5, purchasePrice: 90),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: PreferredSize(preferredSize: const Size.fromHeight(0), child: const SizedBox.shrink()),
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(l10n.analyzingInvoice, style: const TextStyle(color: Colors.white)),
            Text(
              l10n.readingTextDetecting,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class AiResultsScreen extends StatelessWidget {
  const AiResultsScreen({super.key, required this.mode, required this.items});

  final InvoiceScanMode mode;
  final List<ScannedItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.detectedItemsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      boxShadow: AppSpacing.cardElevation,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                              Text(l10n.qtyValue(item.quantity)),
                            ],
                          ),
                        ),
                        Text('${item.purchasePrice.toStringAsFixed(0)} DZD'),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AiReviewScreen(mode: mode, items: items)),
              ),
              child: Text(l10n.reviewAndEdit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Review screen — the MANDATORY human confirmation gate before anything
/// touches ProductsRepository/SalesRepository (Spec Ch. 15.2 "Design
/// Principle"). Branches completely between the two modes: stock mode
/// edits+creates new products (original behavior); sales mode requires
/// matching every line to an existing product before it will let the
/// user submit, then records one real Sale.
class AiReviewScreen extends ConsumerStatefulWidget {
  const AiReviewScreen({super.key, required this.mode, required this.items});
  final InvoiceScanMode mode;
  final List<ScannedItem> items;

  @override
  ConsumerState<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends ConsumerState<AiReviewScreen> {
  late List<ScannedItem> _items;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items;

    if (widget.mode == InvoiceScanMode.sales) {
      // Best-effort auto-match by name so the user usually just has to
      // confirm rather than pick every line from scratch — this is a
      // convenience default, never assumed to be correct: the dropdown
      // is always fully editable, and submission is blocked until every
      // line has an explicit match (auto- or manually-chosen).
      final products = ref.read(productsRepositoryProvider).valueOrNull ?? [];
      for (final item in _items) {
        item.matchedProductId = _bestNameMatch(item.name, products)?.id;
      }
    }
  }

  Product? _bestNameMatch(String scannedName, List<Product> products) {
    final target = scannedName.trim().toLowerCase();
    if (target.isEmpty || products.isEmpty) return null;
    for (final p in products) {
      if (p.name.trim().toLowerCase() == target) return p;
    }
    for (final p in products) {
      final n = p.name.trim().toLowerCase();
      if (n.contains(target) || target.contains(n)) return p;
    }
    return null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Stock mode: unchanged original behavior ----

  Future<void> _confirmAndAddToInventory() async {
    setState(() => _isSubmitting = true);
    final repo = ref.read(productsRepositoryProvider.notifier);
    try {
      for (final item in _items) {
        await repo.addProduct(
          name: item.name,
          category: AppLocalizations.of(context)!.uncategorized,
          purchasePrice: item.purchasePrice,
          sellingPrice: item.purchasePrice * 1.3, // placeholder markup; user edits later
          quantity: item.quantity,
        );
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.productsAddedToInventory(_items.length))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---- Sales mode: match every line to a real product, then create
  // one Sale for the whole invoice ----

  Future<void> _confirmAndRecordSale() async {
    final l10n = AppLocalizations.of(context)!;

    if (_items.isEmpty || _items.any((item) => item.matchedProductId == null)) {
      _showSnack(l10n.pleaseMatchAllItems);
      return;
    }

    setState(() => _isSubmitting = true);
    final products = ref.read(productsRepositoryProvider).valueOrNull ?? [];
    final saleItems = <SaleItemInput>[];

    for (final item in _items) {
      Product? matched;
      for (final p in products) {
        if (p.id == item.matchedProductId) {
          matched = p;
          break;
        }
      }
      // Falls back to the scanned name for display only — the server
      // trusts productId, not this string, for anything that matters.
      saleItems.add(SaleItemInput(
        productId: item.matchedProductId!,
        productName: matched?.name ?? item.name,
        quantity: item.quantity,
      ));
    }

    try {
      await ref.read(salesRepositoryProvider.notifier).createSale(
            items: saleItems,
            paymentStatus: PaymentStatus.paid,
          );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saleRecordedFromScan)),
        );
      }
    } on ApiException catch (e) {
      // e.g. INSUFFICIENT_STOCK — nothing was written server-side, so
      // the review stays exactly as the user left it to adjust and retry.
      _showSnack(e.message);
    } catch (_) {
      _showSnack(AppLocalizations.of(context)!.networkError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSales = widget.mode == InvoiceScanMode.sales;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSales ? l10n.salesInvoiceReviewTitle : l10n.reviewItemsTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => isSales
                    ? _SalesReviewCard(
                        item: _items[i],
                        onRemove: () => setState(() => _items.removeAt(i)),
                        onMatchedProductChanged: (productId) =>
                            setState(() => _items[i].matchedProductId = productId),
                        onQuantityChanged: (qty) => setState(() => _items[i].quantity = qty),
                      )
                    : _StockReviewCard(item: _items[i]),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : (isSales ? _confirmAndRecordSale : _confirmAndAddToInventory),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isSales ? l10n.confirmRecordSale : l10n.confirmAddToInventory),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stock-mode review card — name/quantity/purchase price, all editable.
/// Extracted unchanged from the original inline builder.
class _StockReviewCard extends StatelessWidget {
  const _StockReviewCard({required this.item});
  final ScannedItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: item.name,
              decoration: InputDecoration(labelText: l10n.productNameFieldLabel),
              onChanged: (v) => item.name = v,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '${item.quantity}',
                    decoration: InputDecoration(labelText: l10n.quantityFieldLabel),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => item.quantity = int.tryParse(v) ?? item.quantity,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    initialValue: '${item.purchasePrice}',
                    decoration: InputDecoration(labelText: l10n.purchasePriceFieldLabel),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        item.purchasePrice = double.tryParse(v) ?? item.purchasePrice,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sales-mode review card — the scanned line has to be matched to a
/// real, already-in-stock product (via dropdown) before it counts
/// toward the sale; quantity is still editable, price is shown from
/// the matched product's own selling price rather than the OCR guess,
/// since a real sale has to use the actual price policy in stock.
class _SalesReviewCard extends ConsumerWidget {
  const _SalesReviewCard({
    required this.item,
    required this.onRemove,
    required this.onMatchedProductChanged,
    required this.onQuantityChanged,
  });

  final ScannedItem item;
  final VoidCallback onRemove;
  final void Function(String? productId) onMatchedProductChanged;
  final void Function(int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final products = ref.watch(productsRepositoryProvider).valueOrNull ?? [];

    Product? matched;
    for (final p in products) {
      if (p.id == item.matchedProductId) {
        matched = p;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.removeItemLabel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              value: item.matchedProductId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.matchProductLabel,
                hintText: l10n.selectProductHint,
              ),
              items: products
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onMatchedProductChanged,
            ),
            if (item.matchedProductId == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.noMatchFound,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('qty-${item.hashCode}'),
                    initialValue: '${item.quantity}',
                    decoration: InputDecoration(labelText: l10n.quantityFieldLabel),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed > 0) onQuantityChanged(parsed);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.unitPriceLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        matched == null ? '—' : '${matched.sellingPrice.toStringAsFixed(0)} DZD',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
