import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../customers/presentation/screens/customers_screen.dart'
    show Customer, customersRepositoryProvider;
import '../../data/credit_repository.dart';
import 'credit_screen.dart';
import '../../../../l10n/app_localizations.dart';

/// Transaction History for one customer (Ch. 14/20)  -  every credit
/// purchase and every payment shown as its own line, running balance
/// visible after each, plus the ability to record a new payment
/// against the current outstanding balance.
class CustomerCreditHistoryScreen extends ConsumerStatefulWidget {
  const CustomerCreditHistoryScreen({super.key, required this.customer});
  final Customer customer;

  @override
  ConsumerState<CustomerCreditHistoryScreen> createState() =>
      _CustomerCreditHistoryScreenState();
}

class _CustomerCreditHistoryScreenState extends ConsumerState<CustomerCreditHistoryScreen> {
  late Future<List<CustomerTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(creditRepositoryProvider).customerTransactions(widget.customer.id);
  }

  void _reload() {
    setState(() {
      _future = ref.read(creditRepositoryProvider).customerTransactions(widget.customer.id);
    });
  }

  Future<void> _recordPayment() async {
    final l10n = AppLocalizations.of(context)!;
    final customers = ref.read(customersRepositoryProvider).valueOrNull ?? [];
    final current = customers.firstWhere(
      (c) => c.id == widget.customer.id,
      orElse: () => widget.customer,
    );

    if (current.balanceDue <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noOutstandingBalanceForCustomer)));
      return;
    }

    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.recordPaymentTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.amountDzdLabel,
            helperText: l10n.currentBalanceHelper(current.balanceDue.toStringAsFixed(0)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(double.tryParse(controller.text)),
            child: Text(l10n.saveExpense), // reused "Save" wording
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !mounted) return;

    try {
      await ref.read(creditRepositoryProvider).recordPayment(
            customerId: widget.customer.id,
            amount: amount,
          );
      await ref.read(customersRepositoryProvider.notifier).load();
      ref.invalidate(creditSummaryProvider);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.paymentRecorded)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.customer.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _recordPayment,
        icon: const Icon(Icons.payments_outlined),
        label: Text(l10n.recordPaymentTitle),
      ),
      body: FutureBuilder<List<CustomerTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.networkError));
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return Center(child: Text(l10n.noTransactionsYet));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, i) {
              final t = transactions[i];
              final isDebt = t.amount > 0;

              return Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  boxShadow: AppSpacing.cardElevation,
                ),
                child: Row(
                  children: [
                    Icon(
                      isDebt ? Icons.shopping_bag_outlined : Icons.payments_outlined,
                      color: isDebt ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.isPurchase ? l10n.creditPurchaseLabel : l10n.paymentLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (t.description != null) Text(t.description!),
                          Text(
                            l10n.balanceAfterLabel(t.balanceAfter.toStringAsFixed(0)),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isDebt ? '+' : ''}${t.amount.toStringAsFixed(0)} DZD',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDebt ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
