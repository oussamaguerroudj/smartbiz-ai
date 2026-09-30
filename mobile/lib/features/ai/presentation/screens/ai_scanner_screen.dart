import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../settings/data/ai_settings_provider.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../../auth/data/companies_repository.dart';
import '../../../restaurant/data/restaurant_repository.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/sale.dart';
import '../../../../l10n/app_localizations.dart';

/// AI Invoice Scanner — Spec Ch. 15.
///
/// Phase 6 update: "Take Photo" / "Choose from Gallery" now capture a
/// real image and send it to the real POST /ai/invoices/scan endpoint
/// (OpenAI vision-based extraction, server-side). "Try Demo Invoice"
/// is kept as a fixed, offline mock — useful for trying the review
/// flow without a camera/OpenAI key handy, and as a fallback if AI
/// isn't configured on the server yet (503 AI_NOT_CONFIGURED).
///
/// What's real and enforced regardless of which path got the items
/// here: they are NEVER written to ProductsRepository/SalesRepository
/// until the user reviews and taps Confirm — matching the spec's "AI
/// layer never writes directly to inventory" design principle
/// (Ch. 15.2), and matching the ai_logs table's own `confirmed` column
/// (true only once the client calls the confirm endpoint below, after
/// the products/sale were actually created).
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
///   - [InvoiceScanMode.restaurantInventory] (Restaurant Ch. 15): same
///     shape as [stock] (a purchase invoice, goods coming IN, reviewed
///     with the same _StockReviewCard) but confirming creates/updates
///     items in the Restaurant module's own inventory ledger
///     (POST /restaurant/inventory + /adjust) instead of the CORE
///     Products table — restaurant accounts don't have CORE
///     Products/Stock (see main_shell.dart's _middleTabsFor comment).
enum InvoiceScanMode { stock, sales, restaurantInventory }

class ScannedItem {
  ScannedItem({
    required this.name,
    required this.quantity,
    required this.purchasePrice,
    this.sellingPrice,
    this.matchedProductId,
    this.expirationDate,
    this.size,
    this.color,
    this.brand,
  });
  String name;
  int quantity;
  double purchasePrice;

  /// Sale price entered manually by the user on review.
  /// Not extracted from invoice. If the item matches an existing product
  /// in inventory, this can be pre-filled with the existing selling price.
  double? sellingPrice;

  /// Sales mode only: which existing product this scanned line has been
  /// matched to. Null means "no match yet / needs the user to pick one"
  /// — a sale cannot be submitted while any item is still null.
  String? matchedProductId;

  /// Stock mode only (Phase 2 finding) — an invoice/receipt scan can't
  /// OCR an expiration date or clothing attributes that aren't printed
  /// on it, so these are user-entered on the review card, exactly like
  /// name/quantity/purchasePrice already were. Null unless the account
  /// is pharmacy (expirationDate) / clothing (size/color/brand) and the
  /// user actually filled them in — see _StockReviewCard.
  DateTime? expirationDate;
  String? size;
  String? color;
  String? brand;
}

class AiScannerScreen extends ConsumerWidget {
  const AiScannerScreen({super.key, required this.mode});

  final InvoiceScanMode mode;

  Future<void> _pickAndScan(BuildContext context, WidgetRef ref, ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final aiSettings = ref.read(aiSettingsProvider);

    if (!aiSettings.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiServiceDisabledMessage),
          action: SnackBarAction(
            label: l10n.aiSettingsTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    XFile? file;

    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 65,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cameraPermissionRequired)),
        );
      }
      return;
    }

    if (file == null || !context.mounted) return;

    final bytes = await file.readAsBytes();
    final imageBase64 = base64Encode(bytes);

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiProcessingScreen(mode: mode, imageBase64: imageBase64),
      ),
    );
  }

  void _startDemoScan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiProcessingScreen(mode: mode, imageBase64: null)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final modeLabel = mode == InvoiceScanMode.sales
        ? l10n.scanSalesInvoiceOption
        : l10n.scanStockInvoiceOption;

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.scanInvoiceTitle} · $modeLabel')),
      body: SingleChildScrollView(
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
              onPressed: () => _pickAndScan(context, ref, ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(l10n.cameraButton),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => _pickAndScan(context, ref, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.chooseFromGallery),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => _startDemoScan(context),
              child: Text(l10n.tryDemoInvoice),
            ),
          ],
        ),
      ),
    );
  }
}

enum ScannerStage {
  idle,
  imageProcessing,
  uploading,
  extracting,
  parsing,
  success,
  error,
  timeout,
  cancelled,
}

class AiProcessingScreen extends ConsumerStatefulWidget {
  const AiProcessingScreen({super.key, required this.mode, required this.imageBase64});

  final InvoiceScanMode mode;
  final String? imageBase64;

  @override
  ConsumerState<AiProcessingScreen> createState() => _AiProcessingScreenState();
}

class _AiProcessingScreenState extends ConsumerState<AiProcessingScreen> {
  ScannerStage _stage = ScannerStage.idle;
  int _elapsedSeconds = 0;
  Timer? _tickerTimer;
  String? _errorMessage;
  http.Client? _activeClient;
  bool _isDisposed = false;
  String? _currentScanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _startScan();
      }
    });
  }

  void _startScan() {
    _tickerTimer?.cancel();
    _elapsedSeconds = 0;
    _errorMessage = null;
    _currentScanId = 'SCAN_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

    // Alive ticker timer — purely increments elapsed seconds for UI display.
    // It does NOT advance any stages or fake progress.
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      if (_stage == ScannerStage.error ||
          _stage == ScannerStage.timeout ||
          _stage == ScannerStage.success ||
          _stage == ScannerStage.cancelled) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
    });

    if (widget.imageBase64 == null) {
      _runDemoMock();
    } else {
      _runRealScan(widget.imageBase64!, _currentScanId!);
    }
  }

  void _cancelScan() {
    final scanId = _currentScanId ?? 'SCAN_UNKNOWN';
    debugPrint('[$scanId] CANCELLED by user after ${_elapsedSeconds}s');
    _activeClient?.close();
    _activeClient = null;
    _tickerTimer?.cancel();
    _isDisposed = true;
    _stage = ScannerStage.cancelled;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tickerTimer?.cancel();
    _activeClient?.close();
    super.dispose();
  }

  Future<void> _runDemoMock() async {
    setState(() => _stage = ScannerStage.extracting);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _isDisposed) return;

    setState(() => _stage = ScannerStage.success);
    _tickerTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AiReviewScreen(
          mode: widget.mode,
          logId: null,
          items: [
            ScannedItem(name: 'Milk', quantity: 10, purchasePrice: 120),
            ScannedItem(name: 'Bread', quantity: 20, purchasePrice: 15),
            ScannedItem(name: 'Sugar', quantity: 5, purchasePrice: 90),
          ],
        ),
      ),
    );
  }

  Future<void> _runRealScan(String imageBase64, String scanId) async {
    final l10n = AppLocalizations.of(context)!;
    final scanStart = DateTime.now();

    debugPrint('[$scanId] START mode=${widget.mode.name}');
    debugPrint('[$scanId] IMAGE_PROCESSING_END base64Length=${imageBase64.length}');

    if (!mounted || _isDisposed) return;
    setState(() => _stage = ScannerStage.uploading);
    debugPrint('[$scanId] UPLOADING_START (sending payload to POST /ai/invoices/scan)');

    _activeClient?.close();
    final client = http.Client();
    _activeClient = client;

    try {
      await ApiClient.detectBestBaseUrl();
      if (mounted && !_isDisposed) {
        setState(() => _stage = ScannerStage.extracting);
      }
      debugPrint('[$scanId] API_REQUEST_START awaiting backend OCR/AI response at ${ApiClient.baseUrl}');

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

      final elapsedMs = DateTime.now().difference(scanStart).inMilliseconds;
      debugPrint('[$scanId] API_RESPONSE_RECEIVED in ${elapsedMs}ms');

      if (!mounted || _isDisposed) return;

      setState(() => _stage = ScannerStage.parsing);
      debugPrint('[$scanId] PARSING_START');

      final data = response is Map ? (response['data'] as Map<String, dynamic>? ?? {}) : <String, dynamic>{};
      final logId = data['logId'] as String?;
      final rawItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final items = rawItems
          .map(
            (raw) => ScannedItem(
              name: (raw['name'] ?? '').toString(),
              quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
              purchasePrice: (raw['unitPrice'] as num?)?.toDouble() ?? 0.0,
            ),
          )
          .where((item) => item.name.trim().isNotEmpty)
          .toList();

      debugPrint('[$scanId] PARSING_COMPLETE itemCount=${items.length}');
      debugPrint('[$scanId] VALIDATION_COMPLETE');

      if (!mounted || _isDisposed) return;

      setState(() => _stage = ScannerStage.success);
      _tickerTimer?.cancel();
      debugPrint('[$scanId] SUCCESS totalElapsedMs=${DateTime.now().difference(scanStart).inMilliseconds}ms');

      if (items.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AiReviewScreen(
              mode: widget.mode,
              items: [ScannedItem(name: '', quantity: 1, purchasePrice: 0)],
              logId: logId,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noItemsDetected),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AiReviewScreen(mode: widget.mode, items: items, logId: logId),
        ),
      );
    } on ApiException catch (e) {
      final elapsedMs = DateTime.now().difference(scanStart).inMilliseconds;
      debugPrint('[$scanId] ERROR stage=${_stage.name} elapsedMs=${elapsedMs}ms code=${e.code} msg=${e.message}');
      _tickerTimer?.cancel();
      if (!mounted || _isDisposed) return;

      setState(() {
        if (e.code == 'TIMEOUT') {
          _stage = ScannerStage.timeout;
          _errorMessage = l10n.scanTimeoutMessage;
        } else {
          _stage = ScannerStage.error;
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      final elapsedMs = DateTime.now().difference(scanStart).inMilliseconds;
      debugPrint('[$scanId] GENERAL_ERROR stage=${_stage.name} elapsedMs=${elapsedMs}ms error=$e');
      _tickerTimer?.cancel();
      if (!mounted || _isDisposed) return;

      setState(() {
        _stage = ScannerStage.error;
        _errorMessage = l10n.networkError;
      });
    } finally {
      _activeClient = null;
    }
  }

  String _getStageText(AppLocalizations l10n) {
    switch (_stage) {
      case ScannerStage.imageProcessing:
      case ScannerStage.uploading:
        return l10n.scanStageUploading;
      case ScannerStage.extracting:
        return l10n.scanStageOcr;
      case ScannerStage.parsing:
        return l10n.scanStageExtracting;
      case ScannerStage.success:
        return l10n.scanStageFinalizing;
      default:
        return l10n.analyzingInvoice;
    }
  }

  double? _getStageProgress() {
    switch (_stage) {
      case ScannerStage.imageProcessing:
        return 0.15;
      case ScannerStage.uploading:
        return 0.35;
      case ScannerStage.extracting:
        return null; // Indeterminate spinner/progress bar while OCR model executes
      case ScannerStage.parsing:
        return 0.90;
      case ScannerStage.success:
        return 1.0;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isErrorState = _stage == ScannerStage.error || _stage == ScannerStage.timeout;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _cancelScan();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _cancelScan,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: isErrorState ? _buildErrorView(l10n) : _buildProcessingView(l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingView(AppLocalizations l10n) {
    final stageText = _getStageText(l10n);
    final progressValue = _getStageProgress();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.5),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.analyzingInvoice,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _elapsedSeconds > 0 ? '$stageText (${_elapsedSeconds}s)' : stageText,
            key: ValueKey<String>('${_stage.name}_$_elapsedSeconds'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 36),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.close_rounded),
          label: Text(l10n.cancelScanAction),
          onPressed: _cancelScan,
        ),
      ],
    );
  }

  Widget _buildErrorView(AppLocalizations l10n) {
    final isTimeout = _stage == ScannerStage.timeout;
    final errorText = _errorMessage ?? l10n.networkError;

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTimeout ? Icons.timer_off_outlined : Icons.warning_amber_rounded,
              color: isTimeout ? Colors.orange : AppColors.danger,
              size: 52,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.scanFailedTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              errorText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.imageBase64 != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retryScanAction),
                  onPressed: () {
                    setState(() {
                      _startScan();
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(l10n.addProductTitle),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AiReviewScreen(
                        mode: widget.mode,
                        items: [ScannedItem(name: '', quantity: 1, purchasePrice: 0)],
                        logId: null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _cancelScan,
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class AiReviewScreen extends ConsumerStatefulWidget {
  const AiReviewScreen({super.key, required this.mode, required this.items, required this.logId});
  final InvoiceScanMode mode;
  final List<ScannedItem> items;
  final String? logId;

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

  /// Marks the ai_logs entry for this scan as confirmed, now that its
  /// items were actually turned into real products/a real sale. Best-
  /// effort only: this is an audit-trail nicety (see ai_logs.confirmed
  /// in migration 012), not part of the critical path — the products/
  /// sale were already successfully created by the time this runs, so
  /// a failure here is logged and otherwise ignored rather than shown
  /// to the user or retried.
  Future<void> _confirmAiLogIfNeeded() async {
    final logId = widget.logId;
    if (logId == null) return;

    try {
      final client = ref.read(apiClientProvider);
      await client.post('/ai/invoices/scan/$logId/confirm');
    } catch (err) {
      // Deliberately swallowed — see doc comment above.
      // ignore: avoid_print
      print('Could not confirm ai_logs entry $logId: $err');
    }
  }

  // ---- Stock mode: unchanged original behavior. Also handles
  // restaurantInventory mode (Ch. 15) — same review UI, different
  // repository on confirm. ----

  Future<void> _confirmAndAddToInventory() async {
    final l10n = AppLocalizations.of(context)!;

    if (_items.isEmpty) return;

    for (final item in _items) {
      if (item.name.trim().isEmpty) {
        _showSnack(l10n.productNameFieldLabel);
        return;
      }
      if (item.quantity < 0 || item.purchasePrice < 0) {
        _showSnack(l10n.mustBeNonNegative);
        return;
      }
    }

    if (widget.mode == InvoiceScanMode.restaurantInventory) {
      setState(() => _isSubmitting = true);
      try {
        final repo = ref.read(restaurantRepositoryProvider);
        // Look up existing item by case-insensitive name first and adjusts it if found
        final existingItems = await repo.listInventoryItems();
        for (final item in _items) {
          final match = existingItems.where(
            (e) => e.name.trim().toLowerCase() == item.name.trim().toLowerCase(),
          );
          final targetId = match.isNotEmpty
              ? match.first.id
              : (await repo.createInventoryItem(name: item.name, purchasePrice: item.purchasePrice)).id;

          if (item.quantity != 0) {
            await repo.adjustInventoryQuantity(
              targetId,
              movementType: 'purchase',
              quantityChange: item.quantity.toDouble(),
              reference: 'AI-scanned invoice',
            );
          }
        }
        await _confirmAiLogIfNeeded();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.productsAddedToInventory(_items.length))),
          );
        }
      } catch (e) {
        _showSnack(l10n.networkError);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } else {
      // Validate that sale price is specified and non-negative for every item
      for (final item in _items) {
        if (item.sellingPrice == null || item.sellingPrice! < 0) {
          _showSnack(l10n.salePriceRequired);
          return;
        }
      }

      setState(() => _isSubmitting = true);
      try {
        final repo = ref.read(productsRepositoryProvider.notifier);
        final products = ref.read(productsRepositoryProvider).valueOrNull ?? [];

        for (final item in _items) {
          final existing = products.cast<Product?>().firstWhere(
            (p) =>
                p != null &&
                (p.id == item.matchedProductId ||
                    p.name.trim().toLowerCase() == item.name.trim().toLowerCase()),
            orElse: () => null,
          );

          if (existing != null) {
            await repo.updateProduct(
              existing.id,
              quantity: existing.quantity + item.quantity,
              purchasePrice: item.purchasePrice,
              sellingPrice: item.sellingPrice!,
              expirationDate: item.expirationDate ?? existing.expirationDate,
              size: item.size ?? existing.size,
              color: item.color ?? existing.color,
              brand: item.brand ?? existing.brand,
            );
          } else {
            await repo.addProduct(
              name: item.name.trim(),
              category: l10n.uncategorized,
              purchasePrice: item.purchasePrice,
              sellingPrice: item.sellingPrice!,
              quantity: item.quantity,
              expirationDate: item.expirationDate,
              size: item.size,
              color: item.color,
              brand: item.brand,
            );
          }
        }
        await _confirmAiLogIfNeeded();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.productsAddedToInventory(_items.length))),
          );
        }
      } catch (e) {
        _showSnack(l10n.networkError);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
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
      await _confirmAiLogIfNeeded();
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
      _showSnack(l10n.networkError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addNewItem() {
    setState(() {
      _items.add(ScannedItem(name: '', quantity: 1, purchasePrice: 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSales = widget.mode == InvoiceScanMode.sales;
    final businessType = ref.watch(companyInfoProvider).valueOrNull?.businessType;
    final products = ref.watch(productsRepositoryProvider).valueOrNull ?? [];

    if (products.isNotEmpty) {
      if (isSales) {
        for (final item in _items) {
          item.matchedProductId ??= _bestNameMatch(item.name, products)?.id;
        }
      } else if (widget.mode == InvoiceScanMode.stock) {
        for (final item in _items) {
          if (item.matchedProductId == null && item.sellingPrice == null) {
            final match = _bestNameMatch(item.name, products);
            if (match != null) {
              item.matchedProductId = match.id;
              item.sellingPrice = match.sellingPrice;
            }
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isSales ? l10n.salesInvoiceReviewTitle : l10n.reviewItemsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.addProductTitle,
            onPressed: _addNewItem,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(l10n.noItemsDetected, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.addProductTitle),
                            onPressed: _addNewItem,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        if (i == _items.length) {
                          return OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.addProductTitle),
                            onPressed: _addNewItem,
                          );
                        }
                        return isSales
                            ? _SalesReviewCard(
                                item: _items[i],
                                onRemove: () => setState(() => _items.removeAt(i)),
                                onMatchedProductChanged: (productId) =>
                                    setState(() => _items[i].matchedProductId = productId),
                                onQuantityChanged: (qty) => setState(() => _items[i].quantity = qty),
                              )
                            : _StockReviewCard(
                                key: ValueKey(_items[i]),
                                item: _items[i],
                                showSalePrice: widget.mode != InvoiceScanMode.restaurantInventory,
                                showExpirationDate: businessType == 'pharmacy',
                                showClothingAttributes: businessType == 'clothing',
                                onRemove: () => setState(() => _items.removeAt(i)),
                                onChanged: () => setState(() {}),
                              );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: _isSubmitting || _items.isEmpty
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

/// Stock-mode review card — name/quantity/purchase price/sale price, all editable.
/// Shows dedicated editable Sale Price field with live unit profit calculation,
/// warning if selling price is below purchase price, expiration-date picker
/// (pharmacy accounts) and size/color/brand fields (clothing accounts).
class _StockReviewCard extends StatefulWidget {
  const _StockReviewCard({
    super.key,
    required this.item,
    this.showSalePrice = true,
    this.showExpirationDate = false,
    this.showClothingAttributes = false,
    this.onRemove,
    required this.onChanged,
  });

  final ScannedItem item;
  final bool showSalePrice;
  final bool showExpirationDate;
  final bool showClothingAttributes;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  State<_StockReviewCard> createState() => _StockReviewCardState();
}

class _StockReviewCardState extends State<_StockReviewCard> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _sizeController;
  late TextEditingController _colorController;
  late TextEditingController _brandController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController = TextEditingController(text: '${widget.item.quantity}');
    _purchasePriceController = TextEditingController(
      text: widget.item.purchasePrice > 0 ? '${widget.item.purchasePrice}' : '0',
    );
    _sellingPriceController = TextEditingController(
      text: widget.item.sellingPrice != null ? '${widget.item.sellingPrice}' : '',
    );
    _sizeController = TextEditingController(text: widget.item.size ?? '');
    _colorController = TextEditingController(text: widget.item.color ?? '');
    _brandController = TextEditingController(text: widget.item.brand ?? '');
  }

  @override
  void didUpdateWidget(covariant _StockReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _nameController.text = widget.item.name;
      _quantityController.text = '${widget.item.quantity}';
      _purchasePriceController.text =
          widget.item.purchasePrice > 0 ? '${widget.item.purchasePrice}' : '0';
      _sellingPriceController.text =
          widget.item.sellingPrice != null ? '${widget.item.sellingPrice}' : '';
      _sizeController.text = widget.item.size ?? '';
      _colorController.text = widget.item.color ?? '';
      _brandController.text = widget.item.brand ?? '';
    } else {
      if (widget.item.sellingPrice != null && _sellingPriceController.text.trim().isEmpty) {
        _sellingPriceController.text = '${widget.item.sellingPrice}';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _pickExpirationDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.item.expirationDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      widget.item.expirationDate = picked;
      widget.onChanged();
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final hasSellingPrice = item.sellingPrice != null;
    final isSellingBelowPurchase = hasSellingPrice && item.sellingPrice! < item.purchasePrice;
    final unitProfit = hasSellingPrice ? item.sellingPrice! - item.purchasePrice : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: l10n.productNameFieldLabel),
                    onChanged: (v) {
                      item.name = v;
                      widget.onChanged();
                    },
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: l10n.removeItemLabel,
                    icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(labelText: l10n.quantityFieldLabel),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      item.quantity = int.tryParse(v) ?? item.quantity;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceController,
                    decoration: InputDecoration(
                      labelText: l10n.purchasePriceFieldLabel,
                      suffixText: 'DZD',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      item.purchasePrice = double.tryParse(v) ?? item.purchasePrice;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            if (widget.showSalePrice) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _sellingPriceController,
                decoration: InputDecoration(
                  labelText: l10n.salePriceFieldLabel,
                  hintText: '0.00',
                  suffixText: 'DZD',
                  helperText: hasSellingPrice
                      ? l10n.profitPerUnitValue(
                          unitProfit >= 0
                              ? '+${unitProfit.toStringAsFixed(2)}'
                              : unitProfit.toStringAsFixed(2),
                        )
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final trimmed = v.trim();
                  item.sellingPrice = trimmed.isEmpty ? null : double.tryParse(trimmed);
                  widget.onChanged();
                },
              ),
              if (isSellingBelowPurchase)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          l10n.sellingBelowPurchaseWarning,
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (widget.showExpirationDate) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.expirationDateLabel, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _pickExpirationDate(context),
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  item.expirationDate == null
                      ? l10n.selectDateHint
                      : _formatDate(item.expirationDate!),
                ),
              ),
            ],
            if (widget.showClothingAttributes) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sizeController,
                      decoration: InputDecoration(labelText: l10n.sizeLabel),
                      onChanged: (v) {
                        item.size = v;
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      decoration: InputDecoration(labelText: l10n.colorLabel),
                      onChanged: (v) {
                        item.color = v;
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(labelText: l10n.brandLabel),
                onChanged: (v) {
                  item.brand = v;
                  widget.onChanged();
                },
              ),
            ],
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
    final validProductId = products.any((p) => p.id == item.matchedProductId)
        ? item.matchedProductId
        : null;

    if (validProductId != null) {
      for (final p in products) {
        if (p.id == validProductId) {
          matched = p;
          break;
        }
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
                  child: TextFormField(
                    initialValue: item.name,
                    decoration: InputDecoration(
                      labelText: l10n.productNameFieldLabel,
                      isDense: true,
                    ),
                    onChanged: (v) => item.name = v,
                  ),
                ),
                IconButton(
                  tooltip: l10n.removeItemLabel,
                  icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              value: validProductId,
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
