import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/products_repository.dart';
import '../../domain/product.dart';

/// Add Product — Spec Ch. 10.2. Validates per the field table in the spec
/// and writes a real Product into [productsRepositoryProvider] on save.
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

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

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String? _requiredText(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _nonNegativeNumber(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n < 0) return 'Must be ≥ 0';
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(productsRepositoryProvider.notifier);
    final product = Product(
      id: repo.generateId(),
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? 'Uncategorized'
          : _categoryController.text.trim(),
      purchasePrice: double.parse(_purchasePriceController.text),
      sellingPrice: double.parse(_sellingPriceController.text),
      quantity: int.parse(_quantityController.text),
    );
    repo.addProduct(product);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Product name',
                  hint: 'e.g. Whole Milk 1L',
                  controller: _nameController,
                  validator: _requiredText,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Category',
                  hint: 'Dairy',
                  controller: _categoryController,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Purchase price (DZD)',
                  hint: '120',
                  controller: _purchasePriceController,
                  keyboardType: TextInputType.number,
                  validator: _nonNegativeNumber,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Selling price (DZD)',
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
                      '⚠ Selling price is below purchase price',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Quantity',
                  hint: '50',
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Enter a valid integer ≥ 0';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
