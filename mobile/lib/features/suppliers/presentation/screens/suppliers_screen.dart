import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';

class Supplier {
  Supplier({required this.id, required this.name, this.phone, this.productsSupplied = 0});
  final String id;
  final String name;
  final String? phone;
  final int productsSupplied;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        productsSupplied: (json['products_supplied'] as num?)?.toInt() ?? 0,
      );
}

class SuppliersRepository extends StateNotifier<AsyncValue<List<Supplier>>> {
  SuppliersRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/suppliers');
      state = AsyncValue.data(
        (response['data'] as List).map((j) => Supplier.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addSupplier(String name, String? phone) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/suppliers', body: {'name': name, if (phone != null) 'phone': phone});
    await load();
  }

  Future<void> updateSupplier(String id, String name, String? phone) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/suppliers/$id', body: {'name': name, if (phone != null) 'phone': phone});
    await load();
  }

  Future<void> deleteSupplier(String id) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/suppliers/$id');
    await load();
  }
}

final suppliersRepositoryProvider =
    StateNotifierProvider.autoDispose<SuppliersRepository, AsyncValue<List<Supplier>>>(
  (ref) => SuppliersRepository(ref),
);

/// Suppliers — Spec Ch. 21.2. Real API-backed with full CRUD support.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreSuppliers)),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (suppliers) => suppliers.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.noProductsYetMessage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(suppliersRepositoryProvider.notifier).load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: suppliers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final s = suppliers[i];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        boxShadow: AppSpacing.cardElevation,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            foregroundColor: AppColors.primary,
                            child: Text(s.name.isNotEmpty ? s.name.substring(0, 1) : '?'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                                Text(
                                  l10n.productsSuppliedCount(s.productsSupplied),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => _EditSupplierSheet(supplier: s),
                                );
                              } else if (val == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l10n.deleteSupplierTitle),
                                    content: Text(l10n.deleteConfirmMessage(s.name)),
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
                                if (confirmed == true && context.mounted) {
                                  try {
                                    await ref.read(suppliersRepositoryProvider.notifier).deleteSupplier(s.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${l10n.supplierFallback} "${s.name}" ${l10n.delete.toLowerCase()}')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(l10n.editAction),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                    const SizedBox(width: 8),
                                    Text(l10n.delete, style: const TextStyle(color: AppColors.danger)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddSupplierSheet(),
        ),
      ),
    );
  }
}

class _AddSupplierSheet extends ConsumerStatefulWidget {
  const _AddSupplierSheet();
  @override
  ConsumerState<_AddSupplierSheet> createState() => _AddSupplierSheetState();
}

class _AddSupplierSheetState extends ConsumerState<_AddSupplierSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(suppliersRepositoryProvider.notifier).addSupplier(
            _nameController.text.trim(),
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addSupplier, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.nameLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.phoneLabel, controller: _phoneController),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.saveSupplier),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSupplierSheet extends ConsumerStatefulWidget {
  const _EditSupplierSheet({required this.supplier});
  final Supplier supplier;

  @override
  ConsumerState<_EditSupplierSheet> createState() => _EditSupplierSheetState();
}

class _EditSupplierSheetState extends ConsumerState<_EditSupplierSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier.name);
    _phoneController = TextEditingController(text: widget.supplier.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(suppliersRepositoryProvider.notifier).updateSupplier(
            widget.supplier.id,
            _nameController.text.trim(),
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editAction, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.nameLabel, controller: _nameController),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: l10n.phoneLabel, controller: _phoneController),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _isLoading ? null : _update,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.editAction),
            ),
          ],
        ),
      ),
    );
  }
}
