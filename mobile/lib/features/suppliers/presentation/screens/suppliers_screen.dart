import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';

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
}

final suppliersRepositoryProvider =
    StateNotifierProvider<SuppliersRepository, AsyncValue<List<Supplier>>>(
  (ref) => SuppliersRepository(ref),
);

/// Suppliers — Spec Ch. 21.2. Real API-backed (Phase 5 wiring).
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (suppliers) => RefreshIndicator(
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
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      foregroundColor: AppColors.primary,
                      child: Text(s.name.substring(0, 1)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                          Text('${s.productsSupplied} products supplied'),
                        ],
                      ),
                    ),
                    if (s.phone != null)
                      IconButton(
                        icon: const Icon(Icons.call_outlined, color: AppColors.primary),
                        onPressed: () {},
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddSupplierSheet(),
        ),
        child: const Icon(Icons.add, color: Colors.white),
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

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(suppliersRepositoryProvider.notifier).addSupplier(
            _nameController.text,
            _phoneController.text.isEmpty ? null : _phoneController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach the server — check your connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text('Add Supplier', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Name', controller: _nameController),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Phone', controller: _phoneController),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Supplier'),
          ),
        ],
      ),
    );
  }
}
