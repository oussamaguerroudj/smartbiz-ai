import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/desktop_components.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../sales/domain/sale.dart';
import '../../../products/data/products_repository.dart';
import '../../../products/domain/product.dart';
import '../../../sales/presentation/screens/create_sale_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_data.dart';

/// Desktop Enterprise Dashboard View
class DesktopDashboardView extends ConsumerWidget {
  const DesktopDashboardView({
    super.key,
    required this.onRefresh,
  });

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dashboardAsync = ref.watch(dashboardRepositoryProvider);
    final salesAsync = ref.watch(salesRepositoryProvider);
    final productsAsync = ref.watch(productsRepositoryProvider);

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.errorRose),
            const SizedBox(height: 12),
            Text('Failed to load dashboard data: $e'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRefresh, child: const Text('Retry')),
          ],
        ),
      ),
      data: (dashboard) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Page Header with Status Badge & Quick Actions
              DesktopPageHeader(
                title: l10n.navDashboard,
                subtitle: 'Real-time financial performance, inventory health, and operational KPIs.',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.electricBlue.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'LIVE SYNCED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.electricBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                actions: [
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 16),
                    label: Text(l10n.expensesTitle),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateSaleScreen()),
                    ),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                    label: Text(l10n.newSaleTitle),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),

              // 2. Responsive 4-Column KPI Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final colCount = isWide ? 4 : 2;

                  return GridView.count(
                    crossAxisCount: colCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isWide ? 1.7 : 1.5,
                    children: [
                      // Revenue
                      DesktopKpiCard(
                        title: l10n.todayRevenueLabel,
                        value: '${dashboard.todayRevenue.toStringAsFixed(0)} DZD',
                        subtitle: '${dashboard.salesCount} transactions today',
                        icon: Icons.payments_rounded,
                        accentColor: AppColors.electricBlue,
                        trend: '+12%',
                        isPositiveTrend: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        ),
                      ),
                      // Net Profit
                      DesktopKpiCard(
                        title: l10n.netProfitLabel,
                        value: '${dashboard.todayProfit.toStringAsFixed(0)} DZD',
                        subtitle: 'Expenses: ${dashboard.todayExpenses.toStringAsFixed(0)} DZD',
                        icon: Icons.trending_up_rounded,
                        accentColor: AppColors.successGreen,
                        trend: dashboard.todayProfit >= 0 ? 'Profitable' : 'Loss',
                        isPositiveTrend: dashboard.todayProfit >= 0,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        ),
                      ),
                      // Total Sales Count
                      DesktopKpiCard(
                        title: l10n.salesCountLabel,
                        value: '${dashboard.salesCount}',
                        subtitle: 'Completed sales transactions',
                        icon: Icons.receipt_long_rounded,
                        accentColor: AppColors.indigo,
                      ),
                      // Low Stock / Alerts
                      DesktopKpiCard(
                        title: l10n.dashboardLowStock,
                        value: '${dashboard.lowStockCount}',
                        subtitle: dashboard.lowStockCount > 0 ? 'Requires reorder attention' : 'Inventory healthy',
                        icon: Icons.inventory_2_rounded,
                        accentColor: dashboard.lowStockCount > 0 ? AppColors.warningAmber : AppColors.successTeal,
                        trend: dashboard.lowStockCount > 0 ? 'Action required' : 'Optimal',
                        isPositiveTrend: dashboard.lowStockCount == 0,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // 3. Middle Section: Recent Transactions Table & Low Stock Alerts
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Recent Transactions Table (65%)
                  Expanded(
                    flex: 65,
                    child: salesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error loading sales: $e')),
                      data: (sales) {
                        final recentSales = sales.take(8).toList();
                        return _buildRecentSalesTable(context, recentSales, l10n, isDark);
                      },
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Right: Low Stock Alerts & Quick AI Summary (35%)
                  Expanded(
                    flex: 35,
                    child: Column(
                      children: [
                        // AI Quick Action Card
                        GlassPanel(
                          borderColor: AppColors.aiViolet.withValues(alpha: 0.35),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.aiViolet.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.auto_awesome, color: AppColors.aiViolet, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AI Business Insights',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        'Live computed intelligence',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Your today\'s revenue is trending positive. You have ${dashboard.lowStockCount} products requiring restock attention.',
                                style: const TextStyle(fontSize: 12, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                  label: const Text('Ask AI Assistant'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.aiViolet,
                                    side: BorderSide(color: AppColors.aiViolet.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Low Stock Products Panel
                        productsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (products) {
                            final lowStockProducts = products
                                .where((p) => p.quantity <= p.minimumStock)
                                .take(5)
                                .toList();

                            return _buildLowStockPanel(context, lowStockProducts, isDark);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSalesTable(
    BuildContext context,
    List<Sale> sales,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.recentTransactionsTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            Text(
              '${sales.length} transactions',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DesktopDataTable<Sale>(
          columns: const [
            DesktopDataColumn(label: 'TRANSACTION', flex: 2),
            DesktopDataColumn(label: 'CUSTOMER', flex: 2),
            DesktopDataColumn(label: 'TOTAL (DZD)', flex: 2, textAlign: TextAlign.end),
            DesktopDataColumn(label: 'STATUS', flex: 2, textAlign: TextAlign.center),
          ],
          items: sales,
          emptyMessage: l10n.noSalesInPeriod,
          rowBuilder: (context, sale) => [
            Row(
              children: [
                const Icon(Icons.receipt_outlined, size: 16, color: AppColors.electricBlue),
                const SizedBox(width: 8),
                Text(
                  sale.id.length > 8 ? sale.id.substring(0, 8).toUpperCase() : sale.id,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            Text(
              sale.customerName ?? l10n.walkInCustomer,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${sale.total.toStringAsFixed(2)} DZD',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              textAlign: TextAlign.end,
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sale.paymentStatus.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLowStockPanel(
    BuildContext context,
    List<Product> products,
    bool isDark,
  ) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warningAmber),
                  SizedBox(width: 8),
                  Text(
                    'Low Stock Attention',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '${products.length} items',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'All items are adequately stocked.',
                  style: TextStyle(fontSize: 12, color: AppColors.successGreen),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => Divider(
                height: 12,
                color: isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.borderLight,
              ),
              itemBuilder: (context, i) {
                final p = products[i];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Min required: ${p.minimumStock}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Stock: ${p.quantity}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningAmber,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
