import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/barcode_scanner_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/companies_repository.dart';
import '../../data/products_repository.dart';

/// Add Product — Spec Ch. 10.2. Now calls POST /products for real
/// (Phase 5 wiring) instead of writing straight into local state.
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, this.initialBarcode});

  /// Prefills the barcode field — used when scanning a barcode on the
  /// Stock page finds no existing match, so the user isn't asked to
  /// scan (or type) the same code twice.
  final String? initialBarcode;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  late final _barcodeController = TextEditingController(text: widget.initialBarcode ?? '');
  // Clothing (Ch. 18) attributes — only rendered/sent for clothing accounts.
  final _sizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _brandController = TextEditingController();
  // Pharmacy (Ch. 15) — only rendered/sent for pharmacy accounts.
  DateTime? _expirationDate;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now,
      // A product being entered today can't have already expired, so
      // the picker doesn't offer past dates as a starting point.
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _requiredText(String? v) {
    final l10n = AppLocalizations.of(context)!;
    return (v == null || v.trim().isEmpty) ? l10n.requiredField : null;
  }

  String? _nonNegativeNumber(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return l10n.requiredField;
    final n = double.tryParse(v);
    if (n == null) return l10n.enterValidNumber;
    if (n < 0) return l10n.mustBeNonNegative;
    return null;
  }

  // Spec: selling price below purchase price is a WARNING, not a hard
  // block — so this stays out of the validator (which would prevent
  // submission) and is instead surfaced as a banner below the field.
  bool get _sellingBelowPurchase {
    final purchase = double.tryParse(_purchasePriceController.text);
    final selling = double.tryParse(_sellingPriceController.text);
    if (purchase == null || selling == null) return false;
    return selling < purchase;
  }

  bool _isLoading = false;

  void _save() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final businessType = ref.read(companyInfoProvider).valueOrNull?.businessType;
      await ref.read(productsRepositoryProvider.notifier).addProduct(
            name: _nameController.text.trim(),
            category: _categoryController.text.trim().isEmpty
                ? AppLocalizations.of(context)!.uncategorized
                : _categoryController.text.trim(),
            purchasePrice: double.parse(_purchasePriceController.text),
            sellingPrice: double.parse(_sellingPriceController.text),
            quantity: int.parse(_quantityController.text),
            barcode: _barcodeController.text.trim().isEmpty
                ? null
                : _barcodeController.text.trim(),
            expirationDate: businessType == 'pharmacy' ? _expirationDate : null,
            size: businessType == 'clothing' && _sizeController.text.trim().isNotEmpty
                ? _sizeController.text.trim()
                : null,
            color: businessType == 'clothing' && _colorController.text.trim().isNotEmpty
                ? _colorController.text.trim()
                : null,
            brand: businessType == 'clothing' && _brandController.text.trim().isNotEmpty
                ? _brandController.text.trim()
                : null,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final businessType = ref.watch(companyInfoProvider).valueOrNull?.businessType;
    final isPharmacy = businessType == 'pharmacy';
    final isClothing = businessType == 'clothing';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addProductTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: l10n.productNameLabel,
                  hint: l10n.productNameHint,
                  controller: _nameController,
                  validator: _requiredText,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.categoryLabel,
                  hint: l10n.categoryHint,
                  controller: _categoryController,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.barcodeFieldLabel,
                  hint: l10n.barcodeFieldHint,
                  controller: _barcodeController,
                  suffixIcon: IconButton(
                    tooltip: l10n.scanBarcodeTooltip,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () async {
                      final code = await Navigator.of(context).push<String>(
                        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                      );
                      if (code != null) {
                        setState(() => _barcodeController.text = code);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.purchasePriceLabel,
                  hint: '120',
                  controller: _purchasePriceController,
                  keyboardType: TextInputType.number,
                  validator: _nonNegativeNumber,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.sellingPriceLabel,
                  hint: '180',
                  controller: _sellingPriceController,
                  keyboardType: TextInputType.number,
                  validator: _nonNegativeNumber,
                  onChanged: (_) => setState(() {}),
                ),
                if (_sellingBelowPurchase)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.sellingBelowPurchaseWarning,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.quantityLabel,
                  hint: '50',
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.requiredField;
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return l10n.enterValidInteger;
                    return null;
                  },
                ),
                if (isPharmacy) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.expirationDateLabel, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _pickExpirationDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _expirationDate == null
                          ? l10n.selectDateHint
                          : _formatDate(_expirationDate!),
                    ),
                  ),
                  if (_expirationDate != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _expirationDate = null),
                        child: Text(l10n.clearDateAction),
                      ),
                    ),
                ],
                if (isClothing) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: l10n.sizeLabel,
                    controller: _sizeController,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: l10n.colorLabel,
                    controller: _colorController,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: l10n.brandLabel,
                    controller: _brandController,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.saveProduct),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
