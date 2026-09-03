import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';

class Customer {
  Customer(
      {required this.id, required this.name, this.phone, this.balanceDue = 0});
  final String id;
  final String name;
  final String? phone;
  final double balanceDue;
}

class CustomersRepository extends StateNotifier<List<Customer>> {
  CustomersRepository()
      : super([
          Customer(
              id: 'c1',
              name: 'Amine K.',
              phone: '+213 55 66 11 22',
              balanceDue: 0),
          Customer(
              id: 'c2',
              name: 'Sara B.',
              phone: '+213 55 77 33 44',
              balanceDue: 6750),
        ]);

  int _nextId = 3;

  void addCustomer(String name, String? phone) {
    state = [...state, Customer(id: 'c${_nextId++}', name: name, phone: phone)];
  }
}

final customersRepositoryProvider =
    StateNotifierProvider<CustomersRepository, List<Customer>>(
        (ref) => CustomersRepository());

/// Customers — Spec Ch. 21.1. Relabeled to "Patients" for clinic
/// business_type at the UI-copy layer once Business Type is threaded
/// through app-wide state (deferred — see Settings screen note).
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) {
          final c = customers[i];
          final owes = c.balanceDue > 0;
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
                  child: Text(c.name.substring(0, 1)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text(c.name,
                        style: Theme.of(context).textTheme.titleMedium)),
                Text(
                  owes
                      ? '${c.balanceDue.toStringAsFixed(0)} DZD due'
                      : '0 DZD due',
                  style: TextStyle(
                      color: owes ? AppColors.danger : AppColors.primary),
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
          builder: (_) => const _AddCustomerSheet(),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _AddCustomerSheet extends ConsumerStatefulWidget {
  const _AddCustomerSheet();
  @override
  ConsumerState<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends ConsumerState<_AddCustomerSheet> {
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
          Text('Add Customer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Name', controller: _nameController),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(label: 'Phone', controller: _phoneController),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isEmpty) return;
              ref.read(customersRepositoryProvider.notifier).addCustomer(
                    _nameController.text,
                    _phoneController.text.isEmpty
                        ? null
                        : _phoneController.text,
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }
}
