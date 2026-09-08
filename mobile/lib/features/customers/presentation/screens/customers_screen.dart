import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../l10n/app_localizations.dart';

class Customer {
  Customer({required this.id, required this.name, this.phone, this.balanceDue = 0});
  final String id;
  final String name;
  final String? phone;
  final double balanceDue;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        balanceDue: double.parse((json['balance_due'] ?? 0).toString()),
      );
}

class CustomersRepository extends StateNotifier<AsyncValue<List<Customer>>> {
  CustomersRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }
  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/customers');
      state = AsyncValue.data(
        (response['data'] as List).map((j) => Customer.fromJson(j as Map<String, dynamic>)).toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCustomer(String name, String? phone) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/customers', body: {'name': name, if (phone != null) 'phone': phone});
    await load();
  }
}

final customersRepositoryProvider =
    StateNotifierProvider<CustomersRepository, AsyncValue<List<Customer>>>(
  (ref) => CustomersRepository(ref),
);

/// Customers — Spec Ch. 21.1. Real API-backed (Phase 5 wiring).
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreCustomers)),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text(l10n.errorPrefix(err))),
        data: (customers) => RefreshIndicator(
          onRefresh: () => ref.read(customersRepositoryProvider.notifier).load(),
          child: ListView.separated(
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
                  boxShadow: AppSpacing.cardElevation,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      foregroundColor: AppColors.primary,
                      child: Text(c.name.substring(0, 1)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleMedium)),
                    Text(
                      owes ? l10n.balanceDue(c.balanceDue.toStringAsFixed(0)) : l10n.noBalanceDue,
                      style: TextStyle(color: owes ? AppColors.danger : AppColors.primary),
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
          builder: (_) => const _AddCustomerSheet(),
        ),
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
  bool _isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(customersRepositoryProvider.notifier).addCustomer(
            _nameController.text,
            _phoneController.text.isEmpty ? null : _phoneController.text,
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
          Text(l10n.addCustomer, style: Theme.of(context).textTheme.titleLarge),
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
                : Text(l10n.saveCustomer),
          ),
        ],
      ),
    );
  }
}
