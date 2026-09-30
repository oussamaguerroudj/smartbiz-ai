import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/restaurant_repository.dart';
import '../../domain/restaurant_models.dart';
import 'restaurant_orders_screen.dart' show restaurantTablesProvider;
import '../../../../l10n/app_localizations.dart';

Color _tableStatusColor(RestaurantTableStatus status) => switch (status) {
      RestaurantTableStatus.available => AppColors.success,
      RestaurantTableStatus.occupied => AppColors.warning,
      RestaurantTableStatus.reserved => AppColors.info,
      RestaurantTableStatus.cleaning => AppColors.danger,
    };

// NOTE (Ch. 19 localization pass): left hardcoded English — same
// no-BuildContext structural reason as restaurant_orders_screen's
// restaurantOrderStatusLabel; see that file's comment.
String _tableStatusLabel(RestaurantTableStatus status) => switch (status) {
      RestaurantTableStatus.available => 'Available',
      RestaurantTableStatus.occupied => 'Occupied',
      RestaurantTableStatus.reserved => 'Reserved',
      RestaurantTableStatus.cleaning => 'Cleaning',
    };

/// Table status board (Ch. 17 — "Tables / Occupied tables / Available
/// tables"). A tap on a table cycles it to the next reasonable status
/// rather than opening a full editor — this is meant to be a fast,
/// glanceable floor view, not a table-management form.
class RestaurantTablesScreen extends ConsumerWidget {
  const RestaurantTablesScreen({super.key});

  Future<void> _cycleStatus(WidgetRef ref, BuildContext context, RestaurantTable table) async {
    final next = switch (table.status) {
      RestaurantTableStatus.available => RestaurantTableStatus.occupied,
      RestaurantTableStatus.occupied => RestaurantTableStatus.cleaning,
      RestaurantTableStatus.cleaning => RestaurantTableStatus.available,
      RestaurantTableStatus.reserved => RestaurantTableStatus.occupied,
    };
    try {
      await ref.read(restaurantRepositoryProvider).updateTableStatus(table.id, next);
      ref.invalidate(restaurantTablesProvider);
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
    final tablesAsync = ref.watch(restaurantTablesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tablesTitle)),
      floatingActionButton: FloatingActionButton(
        // heroTag: null -> no Hero for this FAB. MainShell keeps every tab alive
        // in an IndexedStack, so two tab Scaffolds (each with a FAB) sit in ONE
        // route subtree; with Flutter's default shared FAB tag that throws
        // "There are multiple heroes that share the same tag within a subtree"
        // on every push/pop (seen repeatedly in flutter_runtime.log).
        heroTag: null,
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddTableSheet(),
          );
          ref.invalidate(restaurantTablesProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: tablesAsync.when(
        data: (tables) {
          if (tables.isEmpty) {
            return Center(child: Text(l10n.noTablesYetMessage));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(restaurantTablesProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 0.95,
              ),
              itemCount: tables.length,
              itemBuilder: (context, i) {
                final table = tables[i];
                final color = _tableStatusColor(table.status);
                return InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  onTap: () => _cycleStatus(ref, context, table),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_restaurant_outlined, color: color, size: 28),
                        const SizedBox(height: 4),
                        Text(table.name, style: Theme.of(context).textTheme.titleMedium),
                        Text('${table.seats} ${l10n.seatsLabel.toLowerCase()}',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          _tableStatusLabel(table.status),
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
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

class _AddTableSheet extends ConsumerStatefulWidget {
  const _AddTableSheet();

  @override
  ConsumerState<_AddTableSheet> createState() => _AddTableSheetState();
}

class _AddTableSheetState extends ConsumerState<_AddTableSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _seatsController = TextEditingController(text: '2');
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(restaurantRepositoryProvider).createTable(
            name: _nameController.text.trim(),
            seats: int.tryParse(_seatsController.text) ?? 2,
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
              Text(l10n.addTableTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.tableNameFieldLabel,
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: l10n.seatsLabel,
                controller: _seatsController,
                keyboardType: TextInputType.number,
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
