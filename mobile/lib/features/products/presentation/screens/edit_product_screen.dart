import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/barcode_scanner_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/companies_repository.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';

/// Edit Product — Phase 2 audit finding. Previously the app could only
/// change a product's photo (see ProductDetailsScreen/_ProductPhoto);
/// this screen lets every other editable column be changed too, and
/// saves through ProductsRepository.updateProduct, which calls the
/// backend's existing PUT /products/:id (already supported every one
/// of these fields via COALESCE partial-update — it just was never
/// called with anything but imageUrl from the client before).
///
/// Deliberately mirrors AddProductScreen's field set, order, labels and
/// validators 1:1 so editing feels like the same form, just pre-filled
/// — per the audit brief's "don't change existing UI/UX unless the fix
/// requires it" rule.
class EditProductScreen extends ConsumerStatefulWidget {
  const EditProductScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.product.name);
  late final _categoryController = TextEditingController(text: widget.product.category);
  late final _purchasePriceController =
      TextEditingController(text: _trimNum(widget.product.purchasePrice));
  late final _sellingPriceController =
      TextEditingController(text: _trimNum(widget.product.sellingPrice));
  late final _quantityController = TextEditingController(text: '${widget.product.quantity}');
  late final _barcodeController = TextEditingController(text: widget.product.barcode ?? '');
  late final _sizeController = TextEditingController(text: widget.product.size ?? '');
  late final _colorController = TextEditingController(text: widget.product.color ?? '');
  late final _brandController = TextEditingController(text: widget.product.brand ?? '');
  late DateTime? _expirationDate = widget.product.expirationDate;

  static String _trimNum(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();

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
      firstDate: DateTime(now.year - 5),
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

  bool get _sellingBelowPurchase {
    final purchase = double.tryParse(_purchasePriceController.text);
    final selling = double.tryParse(_sellingPriceController.text);
    if (purchase == null || selling == null) return false;
    return selling < purchase;
  }

  bool _isLoading = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final businessType = ref.read(companyInfoProvider).valueOrNull?.businessType;
      await ref.read(productsRepositoryProvider.notifier).updateProduct(
            widget.product.id,
            name: _nameController.text.trim(),
            // Empty string, not null, so an intentionally-cleared
            // category actually clears server-side (see updateProduct's
            // COALESCE note) instead of leaving the old value in place.
            category: _categoryController.text.trim().isEmpty
                ? AppLocalizations.of(context)!.uncategorized
                : _categoryController.text.trim(),
            purchasePrice: double.parse(_purchasePriceController.text),
            sellingPrice: double.parse(_sellingPriceController.text),
            quantity: int.parse(_quantityController.text),
            barcode: _barcodeController.text.trim(),
            expirationDate: businessType == 'pharmacy' ? _expirationDate : null,
            size: businessType == 'clothing' ? _sizeController.text.trim() : null,
            color: businessType == 'clothing' ? _colorController.text.trim() : null,
            brand: businessType == 'clothing' ? _brandController.text.trim() : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productUpdatedMessage)));
        Navigator.of(context).pop();
      }
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
      appBar: AppBar(title: Text(l10n.editProductTitle)),
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
                      : Text(l10n.saveChangesAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
