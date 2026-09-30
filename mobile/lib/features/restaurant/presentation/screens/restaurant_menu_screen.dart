import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/authenticated_image.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/images_repository.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import 'restaurant_orders_screen.dart' show restaurantMenuItemsProvider;
import 'restaurant_menu_item_recipe_screen.dart';
import '../../../../l10n/app_localizations.dart';

/// Menu management (Ch. 17 — "Menu items"). Grouped by category, with
/// a switch to mark an item unavailable (e.g. sold out today) without
/// deleting it, and delete for items no longer on the menu at all.
class RestaurantMenuScreen extends ConsumerWidget {
  const RestaurantMenuScreen({super.key});

  Future<void> _toggleAvailability(WidgetRef ref, BuildContext context, RestaurantMenuItem item) async {
    try {
      await ref.read(restaurantRepositoryProvider).setMenuItemAvailability(item.id, !item.isAvailable);
      ref.invalidate(restaurantMenuItemsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    }
  }

  Future<void> _delete(WidgetRef ref, BuildContext context, RestaurantMenuItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteMenuItemTitle),
        content: Text(l10n.deleteConfirmMessage(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(restaurantRepositoryProvider).deleteMenuItem(item.id);
      ref.invalidate(restaurantMenuItemsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    }
  }

  Future<void> _editItem(WidgetRef ref, BuildContext context, RestaurantMenuItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditMenuItemSheet(item: item),
    );
    ref.invalidate(restaurantMenuItemsProvider);
  }

  /// Ch. 17/18 — same pattern as Restaurant Inventory's _changePhoto.
  Future<void> _changePhoto(WidgetRef ref, BuildContext context, RestaurantMenuItem item) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mimeType = picked.mimeType ?? 'image/jpeg';

    try {
      final imageUrl = await ref
          .read(imagesRepositoryProvider)
          .uploadImage(namespace: 'restaurant-menu', bytes: bytes, mimeType: mimeType);
      await ref.read(restaurantRepositoryProvider).setMenuItemImage(item.id, imageUrl);
      ref.invalidate(restaurantMenuItemsProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final menuAsync = ref.watch(restaurantMenuItemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddMenuItemSheet(),
          );
          ref.invalidate(restaurantMenuItemsProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: menuAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.noMenuItemsYetMessage));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(restaurantMenuItemsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(
                      onTap: () => _changePhoto(ref, context, item),
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
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        if (item.category != null && item.category!.isNotEmpty) item.category!,
                        '${item.price.toStringAsFixed(0)} DZD',
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.receipt_long_outlined),
                          tooltip: l10n.recipeIngredientsTooltip,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RestaurantMenuItemRecipeScreen(menuItem: item),
                            ),
                          ),
                        ),
                        Switch(
                          value: item.isAvailable,
                          onChanged: (_) => _toggleAvailability(ref, context, item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit item',
                          onPressed: () => _editItem(ref, context, item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(ref, context, item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.networkError)),
      ),
    );
  }
}

class _AddMenuItemSheet extends ConsumerStatefulWidget {
  const _AddMenuItemSheet();

  @override
  ConsumerState<_AddMenuItemSheet> createState() => _AddMenuItemSheetState();
}

class _AddMenuItemSheetState extends ConsumerState<_AddMenuItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(restaurantRepositoryProvider).createMenuItem(
            name: _nameController.text.trim(),
            category: _categoryController.text.trim(),
            price: double.tryParse(_priceController.text) ?? 0,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.addMenuItemTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.dishNameLabel,
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: l10n.categoryOptionalLabel, controller: _categoryController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.priceDzdLabel,
                controller: _priceController,
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? l10n.enterValidPriceMessage : null,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.saveAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditMenuItemSheet extends ConsumerStatefulWidget {
  const _EditMenuItemSheet({required this.item});
  final RestaurantMenuItem item;

  @override
  ConsumerState<_EditMenuItemSheet> createState() => _EditMenuItemSheetState();
}

class _EditMenuItemSheetState extends ConsumerState<_EditMenuItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _categoryController = TextEditingController(text: widget.item.category ?? '');
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(restaurantRepositoryProvider).updateMenuItem(
            itemId: widget.item.id,
            name: _nameController.text.trim(),
            category: _categoryController.text.trim(),
            price: double.tryParse(_priceController.text) ?? widget.item.price,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.editMenuItemTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.dishNameLabel,
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(label: l10n.categoryOptionalLabel, controller: _categoryController),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.priceDzdLabel,
                controller: _priceController,
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? l10n.enterValidPriceMessage : null,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.saveAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
