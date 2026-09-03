import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';

/// AI Invoice Scanner — Spec Ch. 15.
///
/// IMPORTANT SCOPE NOTE: this batch implements the full SCREEN FLOW and
/// the mandatory human-review/confirm gate, but the "AI Vision Structuring"
/// step is MOCKED (a fixed delay + fixed extracted items) rather than a
/// real OpenAI Vision call — that integration is explicitly Phase 6
/// ("OpenAI + OCR + AI Assistant + AI Insights + Invoice Scanner"), and
/// requires a backend proxy endpoint that doesn't exist until Phase 5.
/// What IS real and enforced here: extracted items are NEVER written to
/// ProductsRepository until the user reviews and taps Confirm — matching
/// the spec's "AI layer never writes directly to inventory" design
/// principle (Ch. 15.2).
class ScannedItem {
  ScannedItem(
      {required this.name,
      required this.quantity,
      required this.purchasePrice});
  String name;
  int quantity;
  double purchasePrice;
}

class AiScannerScreen extends StatelessWidget {
  const AiScannerScreen({super.key});

  void _startScan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiProcessingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Invoice')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text('Point camera at invoice', textAlign: TextAlign.center),
                  Text('Keep the invoice flat and well lit',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: () => _startScan(context),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => _startScan(context),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => _startScan(context),
              child: const Text('▶ Try Demo Invoice'),
            ),
          ],
        ),
      ),
    );
  }
}

class AiProcessingScreen extends StatefulWidget {
  const AiProcessingScreen({super.key});

  @override
  State<AiProcessingScreen> createState() => _AiProcessingScreenState();
}

class _AiProcessingScreenState extends State<AiProcessingScreen> {
  @override
  void initState() {
    super.initState();
    // MOCK: simulates OCR + AI Vision latency. Real Phase 6 wiring
    // replaces this with an actual POST /ai/invoices/scan call.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AiResultsScreen(
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
    return const Scaffold(
      appBar: PreferredSize(
          preferredSize: Size.fromHeight(0), child: SizedBox.shrink()),
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Analyzing invoice...', style: TextStyle(color: Colors.white)),
            Text(
              'Reading text, detecting products and quantities',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class AiResultsScreen extends StatelessWidget {
  const AiResultsScreen({super.key, required this.items});
  final List<ScannedItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detected Items')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text('Qty: ${item.quantity}'),
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
                MaterialPageRoute(builder: (_) => AiReviewScreen(items: items)),
              ),
              child: const Text('Review & Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Review screen — the MANDATORY human confirmation gate before anything
/// touches ProductsRepository (Spec Ch. 15.2 "Design Principle").
class AiReviewScreen extends ConsumerStatefulWidget {
  const AiReviewScreen({super.key, required this.items});
  final List<ScannedItem> items;

  @override
  ConsumerState<AiReviewScreen> createState() => _AiReviewScreenState();
}

class _AiReviewScreenState extends ConsumerState<AiReviewScreen> {
  late List<ScannedItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  void _confirmAndAddToInventory() {
    final repo = ref.read(productsRepositoryProvider.notifier);
    for (final item in _items) {
      repo.addProduct(
        Product(
          id: repo.generateId(),
          name: item.name,
          category: 'Uncategorized',
          purchasePrice: item.purchasePrice,
          sellingPrice:
              item.purchasePrice * 1.3, // placeholder markup; user edits later
          quantity: item.quantity,
        ),
      );
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_items.length} product(s) added to inventory')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Items')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final item = _items[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: item.name,
                            decoration: const InputDecoration(
                                labelText: 'Product name'),
                            onChanged: (v) => item.name = v,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: '${item.quantity}',
                                  decoration: const InputDecoration(
                                      labelText: 'Quantity'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => item.quantity =
                                      int.tryParse(v) ?? item.quantity,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: TextFormField(
                                  initialValue: '${item.purchasePrice}',
                                  decoration: const InputDecoration(
                                      labelText: 'Purchase price'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => item.purchasePrice =
                                      double.tryParse(v) ?? item.purchasePrice,
                                ),
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
            ElevatedButton(
              onPressed: _confirmAndAddToInventory,
              child: const Text('Confirm & Add to Inventory'),
            ),
          ],
        ),
      ),
    );
  }
}
