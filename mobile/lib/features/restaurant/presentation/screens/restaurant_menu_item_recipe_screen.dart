import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import '../../../../l10n/app_localizations.dart';

/// Ch. 16 — lets the user define which inventory items (and how much
/// of each) one menu item consumes. Saving this is what makes
/// restaurant.repository.deductIngredientsForOrder able to auto-deduct
/// stock and compute real COGS when an order is completed — a menu
/// item with no recipe defined here just contributes 0 COGS (Ch. 16's
/// "display a clearly defined metric rather than pretending the
/// calculation is complete"), it does not block completing orders.
class RestaurantMenuItemRecipeScreen extends ConsumerStatefulWidget {
  const RestaurantMenuItemRecipeScreen({super.key, required this.menuItem});

  final RestaurantMenuItem menuItem;

  @override
  ConsumerState<RestaurantMenuItemRecipeScreen> createState() =>
      _RestaurantMenuItemRecipeScreenState();
}

class _RestaurantMenuItemRecipeScreenState extends ConsumerState<RestaurantMenuItemRecipeScreen> {
  bool _loading = true;
  String? _error;
  List<RestaurantInventoryItem> _inventoryItems = [];
  final Map<String, bool> _selected = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(restaurantRepositoryProvider);
      final results = await Future.wait([
        repo.listInventoryItems(),
        repo.getMenuItemIngredients(widget.menuItem.id),
      ]);
      final inventoryItems = results[0] as List<RestaurantInventoryItem>;
      final existing = results[1] as List<MenuItemIngredient>;

      for (final item in inventoryItems) {
        final match = existing.where((e) => e.inventoryItemId == item.id).toList();
        _selected[item.id] = match.isNotEmpty;
        _quantityControllers[item.id] =
            TextEditingController(text: match.isNotEmpty ? match.first.quantityRequired.toString() : '');
      }

      if (mounted) setState(() => _inventoryItems = inventoryItems);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.networkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final lines = <({String inventoryItemId, double quantityRequired})>[];
    for (final item in _inventoryItems) {
      if (_selected[item.id] != true) continue;
      final qty = double.tryParse(_quantityControllers[item.id]!.text.trim());
      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.enterValidQuantityFor(item.name))),
        );
        return;
      }
      lines.add((inventoryItemId: item.id, quantityRequired: qty));
    }

    setState(() => _saving = true);
    try {
      await ref.read(restaurantRepositoryProvider).setMenuItemIngredients(widget.menuItem.id, lines);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.recipeTitle(widget.menuItem.name))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _inventoryItems.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'No inventory items yet — add some in Inventory first, then come back to build this recipe.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: _inventoryItems.length,
                      itemBuilder: (context, i) {
                        final item = _inventoryItems[i];
                        return CheckboxListTile(
                          value: _selected[item.id] ?? false,
                          onChanged: (v) => setState(() => _selected[item.id] = v ?? false),
                          title: Text(item.name),
                          subtitle: (_selected[item.id] ?? false)
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: TextField(
                                    controller: _quantityControllers[item.id],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: AppLocalizations.of(context)!.quantityRequiredUnit(item.unit),
                                      isDense: true,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_outlined),
        label: Text(AppLocalizations.of(context)!.saveRecipeAction),
      ),
    );
  }
}
