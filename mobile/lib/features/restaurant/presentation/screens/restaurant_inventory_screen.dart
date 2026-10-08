import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/authenticated_image.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/images_repository.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import '../../../../l10n/app_localizations.dart';

/// Ch. 13 "Restaurant Inventory Page"  -  did not exist at all before
/// this audit pass (no backend table, no route, no screen). Raw
/// materials/commodities (ingredients, drinks, supplies)  -  see
/// RestaurantInventoryItem's doc comment for how this differs from the
/// menu and from CORE's Products/Stock tabs.
final restaurantInventoryProvider =
    FutureProvider.autoDispose<List<RestaurantInventoryItem>>((ref) {
  return ref.read(restaurantRepositoryProvider).listInventoryItems();
});

class RestaurantInventoryScreen extends ConsumerStatefulWidget {
  const RestaurantInventoryScreen({super.key});

  @override
  ConsumerState<RestaurantInventoryScreen> createState() => _RestaurantInventoryScreenState();
}

class _RestaurantInventoryScreenState extends ConsumerState<RestaurantInventoryScreen> {
  String _query = '';
  bool _lowStockOnly = false;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ch. 15  -  reuses the SAME AI invoice extraction screen the generic
  /// Stock module already has (AiScannerScreen/AiReviewScreen,
  /// POST /ai/invoices/scan) rather than building a second AI pipeline.
  /// InvoiceScanMode.restaurantInventory (new) makes AiReviewScreen's
  /// confirm step call restaurant inventory endpoints instead of
  /// ProductsRepository  -  nothing about extraction itself changes, and
  /// items are still never written anywhere until the user reviews and
  /// taps Confirm (Ch. 15's "AI must NEVER directly modify inventory
  /// without user confirmation").
  void _scanPurchaseInvoice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiScannerScreen(mode: InvoiceScanMode.restaurantInventory),
      ),
    );
  }

  Future<void> _addItem() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');
    final qtyController = TextEditingController(text: '0');
    final minController = TextEditingController(text: '0');
    final priceController = TextEditingController();
    final supplierController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addInventoryItemTitle),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: l10n.nameLabel,
                  controller: nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: l10n.categoryLabel, controller: categoryController),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: AppTextField(label: l10n.unitLabel, controller: unitController)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppTextField(
                        label: l10n.openingQuantityLabel,
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: l10n.minStockLabel,
                        controller: minController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppTextField(
                        label: l10n.purchasePriceLabel,
                        controller: priceController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: l10n.supplierLabel, controller: supplierController),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(dialogContext).pop(true);
            },
            child: Text(l10n.addAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(restaurantRepositoryProvider).createInventoryItem(
            name: nameController.text.trim(),
            category: categoryController.text.trim(),
            unit: unitController.text.trim(),
            openingQuantity: double.tryParse(qtyController.text.trim()),
            minimumStock: double.tryParse(minController.text.trim()),
            purchasePrice: double.tryParse(priceController.text.trim()),
            supplier: supplierController.text.trim(),
          );
      ref.invalidate(restaurantInventoryProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack(AppLocalizations.of(context)!.networkError);
    }
  }

  Future<void> _adjustStock(RestaurantInventoryItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.adjustItemTitle(item.name)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(
            labelText: l10n.adjustQuantityHint(item.unit),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.applyAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final change = double.tryParse(controller.text.trim());
    if (change == null || change == 0) {
      _showSnack(l10n.enterNonZeroAmountMessage);
      return;
    }

    try {
      await ref.read(restaurantRepositoryProvider).adjustInventoryQuantity(
            item.id,
            movementType: change > 0 ? 'purchase' : 'consumption',
            quantityChange: change,
            reference: l10n.manualAdjustmentLabel,
          );
      ref.invalidate(restaurantInventoryProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack(AppLocalizations.of(context)!.networkError);
    }
  }

  /// Ch. 17/18  -  pick a photo, upload it (ImagesRepository, namespace
  /// 'restaurant-inventory'), then save the returned storage key onto
  /// this item.
  Future<void> _changePhoto(RestaurantInventoryItem item) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType ?? 'image/jpeg';

    try {
      final imageUrl = await ref.read(imagesRepositoryProvider).uploadImage(
            namespace: 'restaurant-inventory',
            bytes: bytes,
            mimeType: mimeType,
          );
      await ref.read(restaurantRepositoryProvider).updateInventoryItemImage(item.id, imageUrl);
      ref.invalidate(restaurantInventoryProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack(AppLocalizations.of(context)!.networkError);
    }
  }

  Future<void> _deleteItem(RestaurantInventoryItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${l10n.removeAction} ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.removeAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(restaurantRepositoryProvider).archiveInventoryItem(item.id);
      ref.invalidate(restaurantInventoryProvider);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack(AppLocalizations.of(context)!.networkError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(restaurantInventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inventoryTitle),
        actions: [
          IconButton(
            tooltip: l10n.scanInvoice,
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: _scanPurchaseInvoice,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l10n.searchInventoryHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  child: IconButton(
                    tooltip: l10n.scanInvoice,
                    icon: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                    onPressed: _scanPurchaseInvoice,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilterChip(
                  label: Text(l10n.lowStockLabel),
                  selected: _lowStockOnly,
                  onSelected: (v) => setState(() => _lowStockOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                final filtered = items.where((item) {
                  if (_lowStockOnly && !item.isLowStock) return false;
                  if (_query.isNotEmpty && !item.name.toLowerCase().contains(_query.toLowerCase())) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.noInventoryItemsMessage));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        boxShadow: AppSpacing.cardElevation,
                      ),
                      child: InkWell(
                        onTap: () => _adjustStock(item),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _changePhoto(item),
                              child: item.imageUrl != null
                                  ? AuthenticatedImage(
                                      storageKey: item.imageUrl!,
                                      width: 44,
                                      height: 44,
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                                      ),
                                      child: const Icon(Icons.add_a_photo_outlined, size: 18),
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                                      if (item.isLowStock) ...[
                                        const SizedBox(width: AppSpacing.xs),
                                        const Icon(Icons.warning_amber_rounded,
                                            size: 16, color: AppColors.danger),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    [
                                      if (item.category != null) item.category!,
                                      '${item.quantity} ${item.unit}',
                                    ].join(' · '),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () => _deleteItem(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l10n.networkError)),
            ),
          ),
        ],
      ),
    );
  }
}
