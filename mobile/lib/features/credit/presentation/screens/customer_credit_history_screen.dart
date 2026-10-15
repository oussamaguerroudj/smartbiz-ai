import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../customers/presentation/screens/customers_screen.dart'
    show Customer, customersRepositoryProvider;
import '../../data/credit_repository.dart';
import 'credit_screen.dart';

/// Comprehensive Customer Credit Profile (Ch. 14/15/20)
/// Includes customer profile header, 4-stat financial summary,
/// 3-tab layout (Statement, Unpaid Invoices with item inspection, Repayments),
/// and an offline-first repayment workflow with overpayment protection.
class CustomerCreditHistoryScreen extends ConsumerStatefulWidget {
  const CustomerCreditHistoryScreen({super.key, required this.customer});
  final Customer customer;

  @override
  ConsumerState<CustomerCreditHistoryScreen> createState() =>
      _CustomerCreditHistoryScreenState();
}

class _CustomerCreditHistoryScreenState
    extends ConsumerState<CustomerCreditHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<CustomerCreditProfile> _profileFuture;
  bool _isRecordingPayment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadProfile() {
    setState(() {
      _profileFuture = ref
          .read(creditRepositoryProvider)
          .getCustomerCreditProfile(widget.customer.id);
    });
  }

  Future<void> _openRepaymentSheet(CustomerCreditProfile profile) async {
    final l10n = AppLocalizations.of(context)!;
    final currentDebt = profile.remainingBalance;

    if (currentDebt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noOutstandingBalanceForCustomer)),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusCard)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final entered = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final isOverpaying = entered > currentDebt + 0.01;

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.md,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.recordPaymentTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Current debt highlight banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.remainingCreditLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${currentDebt.toStringAsFixed(0)} DZD',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Quick shortcut buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              amountCtrl.text = currentDebt.toStringAsFixed(0);
                            });
                          },
                          child: Text(
                            l10n.payFullBalanceShortcut(currentDebt.toStringAsFixed(0)),
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              amountCtrl.text = (currentDebt * 0.5).toStringAsFixed(0);
                            });
                          },
                          child: Text(
                            l10n.payHalfBalanceShortcut,
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Amount Input
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.amountDzdLabel,
                      suffixText: 'DZD',
                      border: const OutlineInputBorder(),
                      errorText: isOverpaying ? l10n.amountExceedsTotalDebt : null,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Note / Ref Input
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.repaymentNoteOptional,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Confirm button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isRecordingPayment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      l10n.confirmRepaymentAction,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isRecordingPayment || isOverpaying || entered <= 0
                        ? null
                        : () async {
                            setSheetState(() => _isRecordingPayment = true);
                            final nav = Navigator.of(sheetCtx);
                            try {
                              await ref.read(creditRepositoryProvider).recordPayment(
                                    customerId: widget.customer.id,
                                    amount: entered,
                                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                  );
                              await ref.read(customersRepositoryProvider.notifier).load();
                              ref.invalidate(creditSummaryProvider);
                              if (mounted) {
                                nav.pop();
                                _loadProfile();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.paymentRecorded),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } on ApiException catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
                                );
                              }
                            } catch (_) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(l10n.networkError), backgroundColor: AppColors.danger),
                                );
                              }
                            } finally {
                              setSheetState(() => _isRecordingPayment = false);
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInvoiceDetailsModal(CustomerInvoiceDetail invoice) {
    final l10n = AppLocalizations.of(context)!;
    final isUnpaid = invoice.remainingBalance > 0.005;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusCard)),
      ),
      builder: (bCtx) => SizedBox(
        height: MediaQuery.of(bCtx).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${invoice.date.year}-${invoice.date.month.toString().padLeft(2, '0')}-${invoice.date.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isUnpaid ? AppColors.warning : AppColors.success).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isUnpaid ? l10n.unpaidCreditTitle : l10n.paidInFullTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isUnpaid ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Financial row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(label: l10n.totalLabel, value: '${invoice.total.toStringAsFixed(0)} DZD'),
                  _MiniStat(label: l10n.amountPaidLabel, value: '${invoice.amountPaid.toStringAsFixed(0)} DZD'),
                  _MiniStat(
                    label: l10n.remainingCreditLabel,
                    value: '${invoice.remainingBalance.toStringAsFixed(0)} DZD',
                    color: isUnpaid ? AppColors.warning : AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${l10n.itemsListTitle} (${invoice.items.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: invoice.items.isEmpty
                    ? Center(child: Text(l10n.noItemsDetected))
                    : ListView.separated(
                        itemCount: invoice.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = invoice.items[i];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${item.quantity.toStringAsFixed(0)} x ${item.unitPrice.toStringAsFixed(0)} DZD'),
                            trailing: Text(
                              '${item.lineTotal.toStringAsFixed(0)} DZD',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<CustomerCreditProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.customer.name)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.customer.name)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text(l10n.networkError),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadProfile, child: Text(l10n.retry)),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data!;
        final customer = profile.customer;
        final hasDebt = profile.remainingBalance > 0.005;

        return Scaffold(
          appBar: AppBar(
            title: Text(customer.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.retry,
                onPressed: _loadProfile,
              ),
            ],
          ),
          floatingActionButton: hasDebt
              ? FloatingActionButton.extended(
                  onPressed: () => _openRepaymentSheet(profile),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.recordPaymentTitle),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async {
              _loadProfile();
              await _profileFuture;
            },
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Customer Details Header
                        _buildCustomerHeader(context, l10n, customer, profile),
                        const SizedBox(height: AppSpacing.sm),

                        // 2. 4-Stat Financial Cards Grid
                        _buildFinancialSummaryGrid(context, l10n, profile),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      tabs: [
                        Tab(text: l10n.customerStatementTab),
                        Tab(text: l10n.unpaidInvoicesTab(profile.unpaidInvoices.length)),
                        Tab(text: l10n.paymentsHistoryTab),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Chronological Ledger / Statement
                  _buildStatementTab(context, l10n, profile),

                  // Tab 2: Unpaid Invoices
                  _buildUnpaidInvoicesTab(context, l10n, profile),

                  // Tab 3: Repayment History
                  _buildRepaymentsTab(context, l10n, profile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerHeader(
    BuildContext context,
    AppLocalizations l10n,
    Customer customer,
    CustomerCreditProfile profile,
  ) {
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
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundColor: AppColors.primary,
            child: Text(
              customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        customer.phone!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (customer.phone != null && customer.phone!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.phone, color: AppColors.primary, size: 20),
              tooltip: 'Call',
              onPressed: () async {
                final uri = Uri.parse('tel:${customer.phone}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.success, size: 20),
              tooltip: 'WhatsApp',
              onPressed: () => ExternalLauncher.launchWhatsApp(
                context,
                phone: customer.phone!,
                message: 'Hello ${customer.name}',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryGrid(
    BuildContext context,
    AppLocalizations l10n,
    CustomerCreditProfile profile,
  ) {
    final oldestDateStr = profile.oldestDebtDate != null
        ? '${profile.oldestDebtDate!.year}-${profile.oldestDebtDate!.month.toString().padLeft(2, '0')}-${profile.oldestDebtDate!.day.toString().padLeft(2, '0')}'
        : l10n.noOldestDebt;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: l10n.remainingCreditLabel,
                value: '${profile.remainingBalance.toStringAsFixed(0)} DZD',
                color: profile.remainingBalance > 0.005 ? AppColors.danger : AppColors.success,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _MetricCard(
                label: l10n.totalCreditIncurred,
                value: '${profile.totalCreditSales.toStringAsFixed(0)} DZD',
                color: AppColors.primary,
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: l10n.totalRepaidLabel,
                value: '${profile.totalRepayments.toStringAsFixed(0)} DZD',
                color: AppColors.success,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _MetricCard(
                label: l10n.oldestDebtLabel,
                value: oldestDateStr,
                color: AppColors.warning,
                icon: Icons.calendar_today_outlined,
                isSmallText: profile.oldestDebtDate != null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatementTab(
    BuildContext context,
    AppLocalizations l10n,
    CustomerCreditProfile profile,
  ) {
    if (profile.transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(l10n.noTransactionsYet),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: profile.transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        final t = profile.transactions[i];
        final isDebt = t.amount > 0;
        final dateStr = '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}-${t.createdAt.day.toString().padLeft(2, '0')}';

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
                radius: 18,
                backgroundColor: (isDebt ? AppColors.warning : AppColors.success).withValues(alpha: 0.12),
                child: Icon(
                  isDebt ? Icons.shopping_bag_outlined : Icons.payments_outlined,
                  color: isDebt ? AppColors.warning : AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.isPurchase ? l10n.creditPurchaseLabel : l10n.paymentLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (t.description != null && t.description!.isNotEmpty)
                      Text(t.description!, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr · ${l10n.balanceAfterLabel(t.balanceAfter.toStringAsFixed(0))}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '${isDebt ? '+' : ''}${t.amount.toStringAsFixed(0)} DZD',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDebt ? AppColors.warning : AppColors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnpaidInvoicesTab(
    BuildContext context,
    AppLocalizations l10n,
    CustomerCreditProfile profile,
  ) {
    if (profile.unpaidInvoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
              const SizedBox(height: 12),
              Text(l10n.noUnpaidInvoicesFound, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: profile.unpaidInvoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        final inv = profile.unpaidInvoices[i];
        final dateStr = '${inv.date.year}-${inv.date.month.toString().padLeft(2, '0')}-${inv.date.day.toString().padLeft(2, '0')}';

        return InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          onTap: () => _showInvoiceDetailsModal(inv),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppSpacing.cardElevation,
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$dateStr · ${inv.items.length} items',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${inv.remainingBalance.toStringAsFixed(0)} DZD',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                    ),
                    Text(
                      'Total: ${inv.total.toStringAsFixed(0)} DZD',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRepaymentsTab(
    BuildContext context,
    AppLocalizations l10n,
    CustomerCreditProfile profile,
  ) {
    final repayments = profile.transactions.where((t) => t.amount < 0).toList();

    if (repayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(l10n.noTransactionsYet),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: repayments.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        final t = repayments[i];
        final dateStr = '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}-${t.createdAt.day.toString().padLeft(2, '0')}';

        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            boxShadow: AppSpacing.cardElevation,
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0x1F22C55E),
                child: Icon(Icons.payments_outlined, color: AppColors.success, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.description ?? l10n.paymentLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${t.amount.abs().toStringAsFixed(0)} DZD',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isSmallText = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isSmallText;

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
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isSmallText ? 13 : 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
