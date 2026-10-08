import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../customers/presentation/screens/customers_screen.dart'
    show Customer, customersRepositoryProvider;
import '../../data/credit_repository.dart';
import 'create_credit_sale_screen.dart';
import 'customer_credit_history_screen.dart';
import '../../../../l10n/app_localizations.dart';

/// Credit page — Ch. 15/16. Refetched (not cached) every time this
/// screen is opened, since balances change the moment any Credit Sale
/// or payment is recorded elsewhere in the app.
final creditSummaryProvider = FutureProvider.autoDispose<CreditSummary>((ref) async {
  return ref.read(creditRepositoryProvider).summary();
});

class CreditScreen extends ConsumerWidget {
  const CreditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(creditSummaryProvider);
    final customersAsync = ref.watch(customersRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditPageTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateCreditSaleScreen()),
          );
          ref.invalidate(creditSummaryProvider);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.newCreditSaleAction),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(creditSummaryProvider);
          await ref.read(customersRepositoryProvider.notifier).load();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            summaryAsync.when(
              data: (summary) => _SummaryCards(summary: summary),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(l10n.networkError),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.customersWithCreditTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            customersAsync.when(
              data: (customers) {
                final withCredit = customers.where((c) => c.balanceDue > 0).toList()
                  ..sort((a, b) => b.balanceDue.compareTo(a.balanceDue));

                if (withCredit.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(child: Text(l10n.noOutstandingCredit)),
                  );
                }

                return Column(
                  children: withCredit.map((c) => _CustomerCreditTile(customer: c)).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(l10n.networkError),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final CreditSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: l10n.totalCreditLabel,
            value: summary.totalCredit,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _StatCard(
            label: l10n.totalPaidLabel,
            value: summary.totalPaid,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _StatCard(
            label: l10n.remainingCreditLabel,
            value: summary.totalOutstanding,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)} DZD',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CustomerCreditTile extends StatelessWidget {
  const _CustomerCreditTile({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        title: Text(customer.name),
        subtitle: customer.phone != null ? Text(customer.phone!) : null,
        trailing: Text(
          '${customer.balanceDue.toStringAsFixed(0)} DZD',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CustomerCreditHistoryScreen(customer: customer)),
        ),
      ),
    );
  }
}
