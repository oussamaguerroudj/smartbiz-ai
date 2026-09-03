import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';

class Supplier {
  Supplier(
      {required this.id,
      required this.name,
      this.phone,
      this.productsSupplied = 0});
  final String id;
  final String name;
  final String? phone;
  final int productsSupplied;
}

class SuppliersRepository extends StateNotifier<List<Supplier>> {
  SuppliersRepository()
      : super([
          Supplier(
              id: 'sup1',
              name: 'Central Dairy Supplier',
              phone: '+213 55 11 22 33',
              productsSupplied: 18),
          Supplier(
              id: 'sup2',
              name: 'Fresh Bakery Co.',
              phone: '+213 55 22 33 44',
              productsSupplied: 4),
        ]);

  int _nextId = 3;

  void addSupplier(String name, String? phone) {
    state = [
      ...state,
      Supplier(id: 'sup${_nextId++}', name: name, phone: phone)
    ];
  }
}

final suppliersRepositoryProvider =
    StateNotifierProvider<SuppliersRepository, List<Supplier>>(
        (ref) => SuppliersRepository());

/// Suppliers — Spec Ch. 21.2.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      body: ListView.separated(
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
                      Text(s.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${s.productsSupplied} products supplied'),
                    ],
                  ),
                ),
                if (s.phone != null)
                  IconButton(
                    icon: const Icon(Icons.call_outlined,
                        color: AppColors.primary),
                    onPressed: () {},
                  ),
              ],
            ),
          );
        },
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
            onPressed: () {
              if (_nameController.text.isEmpty) return;
              ref.read(suppliersRepositoryProvider.notifier).addSupplier(
                    _nameController.text,
                    _phoneController.text.isEmpty
                        ? null
                        : _phoneController.text,
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );
  }
}
