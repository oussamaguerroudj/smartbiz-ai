import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/mini_bar_chart.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/reports_repository.dart';
import '../../domain/report.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _periods = ['daily', 'monthly', 'yearly'];

  String _period = 'monthly';
  DateTime _selectedDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  ReportFilter get _currentFilter {
    if (_period == 'daily') {
      final d = _selectedDate;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return ReportFilter(period: 'daily', date: dateStr);
    } else if (_period == 'monthly') {
      final monthStr =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      return ReportFilter(period: 'monthly', month: monthStr);
    } else {
      return ReportFilter(period: 'yearly', year: _selectedYear);
    }
  }

  List<String> _periodLabels(AppLocalizations l10n) => [
        l10n.periodDaily,
        l10n.periodMonthly,
        l10n.periodYearly,
      ];

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _pickMonth(BuildContext context, AppLocalizations l10n) async {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final monthNames = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setDialogState(() => tempYear--),
                  ),
                  Text('$tempYear', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setDialogState(() => tempYear++),
                  ),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(12, (index) {
                    final m = index + 1;
                    final isSelected = m == tempMonth;
                    return ChoiceChip(
                      label: Text(monthNames[index]),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => tempMonth = m);
                          Navigator.of(ctx).pop({'year': tempYear, 'month': tempMonth});
                        }
                      },
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedYear = result['year']!;
        _selectedMonth = result['month']!;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  Future<void> _pickYear(BuildContext context, AppLocalizations l10n) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.selectYear),
          content: SizedBox(
            width: 250,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              selectedDate: DateTime(_selectedYear),
              onChanged: (DateTime date) {
                Navigator.of(ctx).pop(date.year);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedYear = picked);
    }
  }

  void _previousYear() {
    setState(() => _selectedYear--);
  }

  void _nextYear() {
    setState(() => _selectedYear++);
  }

  String _formatDateString(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month >= 1 && month <= 12) return names[month - 1];
    return '$month';
  }

  @override
  Widget build(BuildContext context) {
    final filter = _currentFilter;
    final reportAsync = ref.watch(filteredReportProvider(filter));
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(filteredReportProvider(filter).future),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          children: [
            // ==========================================
            // 1. GLOBAL / ALL-TIME NET PROFIT BANNER CARD
            // Unaffected by date/month/year selectors
            // ==========================================
            reportAsync.when(
              loading: () => const _GlobalNetProfitCardSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
              data: (report) => _GlobalNetProfitCard(
                report: report,
                l10n: l10n,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Section Divider / Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.financialOverview,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ==========================================
            // 2. PERIOD SWITCHER TABS: [ Daily ] [ Monthly ] [ Yearly ]
            // ==========================================
            Center(
              child: PillTabs(
                labels: _periodLabels(l10n),
                selectedIndex: _periods.indexOf(_period),
                onChanged: (i) => setState(() => _period = _periods[i]),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ==========================================
            // 3. PERIOD-SPECIFIC SELECTOR
            // ==========================================
            _buildPeriodSelector(context, l10n),

            const SizedBox(height: AppSpacing.sm),

            // ==========================================
            // 4. PERIOD REPORT CONTENT
            // ==========================================
            reportAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, st) => Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.errorPrefix(err),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () => ref.refresh(filteredReportProvider(filter)),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
              data: (report) => Column(
                key: ValueKey('${_period}_${report.rangeStart}_${report.rangeEnd}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Period Label & Exact Date Range
                  _buildPeriodHeader(context, report, l10n),

                  const SizedBox(height: AppSpacing.xs),

                  // A. Primary Financial KPI Cards for the Selected Period
                  FadeSlideIn(
                    child: Row(
                      children: [
                        Expanded(
                          child: _FinancialStatCard(
                            label: l10n.reportRevenueLabel,
                            value: report.revenue,
                            color: AppColors.primary,
                            icon: Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _FinancialStatCard(
                            label: l10n.reportExpensesLabel,
                            value: report.expenses,
                            color: AppColors.danger,
                            icon: Icons.trending_down,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _FinancialStatCard(
                            label: report.netProfit >= 0
                                ? l10n.reportNetProfitLabel
                                : l10n.netLossLabel,
                            value: report.netProfit,
                            color: report.netProfit >= 0
                                ? AppColors.info
                                : AppColors.danger,
                            icon: report.netProfit >= 0
                                ? Icons.account_balance_wallet
                                : Icons.warning_amber_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // B. Profit Calculation Formula Card (Period Revenue - Period Expenses = Net Profit)
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 30),
                    child: _ProfitCalculationCard(
                      report: report,
                      l10n: l10n,
                      isDark: isDark,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // C. Revenue Breakdown Section
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: _RevenueBreakdownCard(
                      report: report,
                      l10n: l10n,
                      isDark: isDark,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // D. Expenses Breakdown Section (Operating Expenses + Employee Salaries)
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 90),
                    child: _ExpensesBreakdownCard(
                      report: report,
                      l10n: l10n,
                      isDark: isDark,
                    ),
                  ),

                  // E. Yearly Report Monthly Breakdown (Jan..Dec)
                  if (_period == 'yearly' && report.monthlyBreakdown.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: _MonthlyBreakdownCard(
                        breakdown: report.monthlyBreakdown,
                        l10n: l10n,
                        year: _selectedYear,
                        isDark: isDark,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.sm),

                  // F. Activity Summary
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: _ActivitySummaryCard(
                      summary: report.activitySummary,
                      l10n: l10n,
                    ),
                  ),

                  // G. Top Selling Products
                  if (report.topProducts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 160),
                      child: _TopProductsCard(
                        topProducts: report.topProducts,
                        l10n: l10n,
                      ),
                    ),
                  ],

                  // H. Actual Transactions Detail List
                  const SizedBox(height: AppSpacing.sm),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: _ActualTransactionsCard(
                      transactions: report.recentTransactions,
                      l10n: l10n,
                    ),
                  ),

                  // Empty State if no activity at all
                  if (report.salesCount == 0 &&
                      report.revenue == 0 &&
                      report.expenses == 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          l10n.noTransactionsForPeriod,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, AppLocalizations l10n) {
    if (_period == 'daily') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 22),
              tooltip: 'Previous Day',
              onPressed: _previousDay,
            ),
            Expanded(
              child: InkWell(
                onTap: _pickDay,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _formatDateString(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 22),
              tooltip: 'Next Day',
              onPressed: _nextDay,
            ),
          ],
        ),
      );
    } else if (_period == 'monthly') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 22),
              tooltip: 'Previous Month',
              onPressed: _previousMonth,
            ),
            Expanded(
              child: InkWell(
                onTap: () => _pickMonth(context, l10n),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.date_range_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${_monthName(_selectedMonth)} $_selectedYear',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 22),
              tooltip: 'Next Month',
              onPressed: _nextMonth,
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 22),
              tooltip: 'Previous Year',
              onPressed: _previousYear,
            ),
            Expanded(
              child: InkWell(
                onTap: () => _pickYear(context, l10n),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_note_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$_selectedYear',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 22),
              tooltip: 'Next Year',
              onPressed: _nextYear,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPeriodHeader(BuildContext context, ReportData report, AppLocalizations l10n) {
    String title;
    if (_period == 'daily') {
      title = '${l10n.dailyReportTitle} — ${_formatDateString(_selectedDate)}';
    } else if (_period == 'monthly') {
      title = '${l10n.monthlyReportTitle} — ${_monthName(_selectedMonth)} $_selectedYear';
    } else {
      title = '${l10n.yearlyReportTitle} — $_selectedYear';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (report.rangeStart.isNotEmpty && report.rangeEnd.isNotEmpty)
            Text(
              '${report.rangeStart} → ${report.rangeEnd}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// GLOBAL / ALL-TIME NET PROFIT WIDGET
// ==========================================
class _GlobalNetProfitCard extends StatelessWidget {
  const _GlobalNetProfitCard({
    required this.report,
    required this.l10n,
    required this.isDark,
  });

  final ReportData report;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final profit = report.globalNetProfit;
    final isProfit = profit >= 0;
    final profitColor = isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.globalNetProfitTitle.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.globalBalanceLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${isProfit ? "+" : ""}${profit.toStringAsFixed(0)} DZD',
                        style: TextStyle(
                          color: profitColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.profitFormulaExplanation,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isProfit ? Icons.account_balance_wallet : Icons.trending_down,
                  color: profitColor,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.allRevenueLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${report.allRevenue.toStringAsFixed(0)} DZD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.allExpensesLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        '${report.allExpenses.toStringAsFixed(0)} DZD',
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlobalNetProfitCardSkeleton extends StatelessWidget {
  const _GlobalNetProfitCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ==========================================
// FINANCIAL STAT CARD
// ==========================================
class _FinancialStatCard extends StatelessWidget {
  const _FinancialStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedCounter(
              value: value,
              style: AppTypography.statValue(color).copyWith(fontSize: 15),
              suffix: ' DA',
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PROFIT CALCULATION CARD
// ==========================================
class _ProfitCalculationCard extends StatelessWidget {
  const _ProfitCalculationCard({
    required this.report,
    required this.l10n,
    required this.isDark,
  });

  final ReportData report;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isProfit = report.netProfit >= 0;
    final profitColor = isProfit ? AppColors.info : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.profitCalculationTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${l10n.profitMarginLabel}: ${report.profitMargin.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: profitColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _FormulaBlock(
                    label: l10n.reportRevenueLabel,
                    amount: report.revenue,
                    color: AppColors.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: _FormulaBlock(
                    label: l10n.totalExpensesLabel,
                    amount: report.expenses,
                    color: AppColors.danger,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '=',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: _FormulaBlock(
                    label: isProfit ? l10n.reportNetProfitLabel : l10n.netLossLabel,
                    amount: report.netProfit,
                    color: profitColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.profitFormulaExplanation,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }
}

class _FormulaBlock extends StatelessWidget {
  const _FormulaBlock({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${amount.toStringAsFixed(0)} DA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}


// ==========================================
// REVENUE BREAKDOWN
// ==========================================
class _RevenueBreakdownCard extends StatelessWidget {
  const _RevenueBreakdownCard({
    required this.report,
    required this.l10n,
    required this.isDark,
  });

  final ReportData report;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final rev = report.revenueBreakdown;
    final total = rev.totalRevenue > 0 ? rev.totalRevenue : 1.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.revenueBreakdownTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${report.revenue.toStringAsFixed(0)} DA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBarRow(
            label: l10n.coreSalesLabel,
            amount: rev.sales,
            ratio: (rev.sales / total).clamp(0.0, 1.0),
            color: AppColors.primary,
          ),
          if (rev.creditPayments > 0) ...[
            const SizedBox(height: 8),
            _ProgressBarRow(
              label: l10n.creditPaymentsLabel,
              amount: rev.creditPayments,
              ratio: (rev.creditPayments / total).clamp(0.0, 1.0),
              color: AppColors.info,
            ),
          ],
          if (rev.clinicRevenue > 0) ...[
            const SizedBox(height: 8),
            _ProgressBarRow(
              label: l10n.businessTypeClinic,
              amount: rev.clinicRevenue,
              ratio: (rev.clinicRevenue / total).clamp(0.0, 1.0),
              color: AppColors.primaryLight,
            ),
          ],
          if (rev.restaurantRevenue > 0) ...[
            const SizedBox(height: 8),
            _ProgressBarRow(
              label: l10n.businessTypeRestaurant,
              amount: rev.restaurantRevenue,
              ratio: (rev.restaurantRevenue / total).clamp(0.0, 1.0),
              color: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// EXPENSES BREAKDOWN
// ==========================================
class _ExpensesBreakdownCard extends StatelessWidget {
  const _ExpensesBreakdownCard({
    required this.report,
    required this.l10n,
    required this.isDark,
  });

  final ReportData report;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final exp = report.expensesBreakdown;
    final total = exp.totalExpenses > 0 ? exp.totalExpenses : 1.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.expensesBreakdownTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${report.expenses.toStringAsFixed(0)} DA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBarRow(
            label: l10n.operatingExpensesLabel,
            amount: exp.operatingExpenses,
            ratio: (exp.operatingExpenses / total).clamp(0.0, 1.0),
            color: AppColors.danger,
          ),
          const SizedBox(height: 8),
          _ProgressBarRow(
            label: l10n.employeeSalariesLabel,
            amount: exp.employeeSalaries,
            ratio: (exp.employeeSalaries / total).clamp(0.0, 1.0),
            color: AppColors.warning,
          ),

          const Divider(height: 20),

          // Business Categories Breakdown
          Text(
            l10n.categoryBreakdownTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 6),
          if (exp.byCategory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                l10n.noExpensesFound,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            )
          else
            ...exp.byCategory.map(
              (cat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cat.category,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${cat.amount.toStringAsFixed(0)} DA',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),

          if (exp.byEmployee.isNotEmpty) ...[
            const Divider(height: 20),
            Text(
              l10n.employeeBreakdownTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 6),
            ...exp.byEmployee.map(
              (emp) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (emp.salaryPeriod != null)
                            Text(
                              emp.salaryPeriod!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${emp.periodSalary.toStringAsFixed(0)} DA',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// YEARLY REPORT: MONTHLY BREAKDOWN TABLE (Jan..Dec)
// ==========================================
class _MonthlyBreakdownCard extends StatelessWidget {
  const _MonthlyBreakdownCard({
    required this.breakdown,
    required this.l10n,
    required this.year,
    required this.isDark,
  });

  final List<MonthlyBreakdownItem> breakdown;
  final AppLocalizations l10n;
  final int year;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${l10n.monthlyBreakdownTitle} ($year)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_view_month, size: 18, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 36,
              columnSpacing: 18,
              horizontalMargin: 8,
              columns: [
                DataColumn(label: Text(l10n.selectMonth, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text(l10n.reportRevenueLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text(l10n.reportExpensesLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text(l10n.salaryExpenseLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text(l10n.reportNetProfitLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: breakdown.map((item) {
                final isNetProfit = item.netProfit >= 0;
                final profitColor = isNetProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                return DataRow(
                  cells: [
                    DataCell(Text(item.monthName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    DataCell(Text('${item.revenue.toStringAsFixed(0)} DA', style: const TextStyle(fontSize: 11, color: AppColors.primary))),
                    DataCell(Text('${item.expenses.toStringAsFixed(0)} DA', style: const TextStyle(fontSize: 11, color: AppColors.danger))),
                    DataCell(Text('${item.salaryExpenses.toStringAsFixed(0)} DA', style: const TextStyle(fontSize: 11, color: AppColors.warning))),
                    DataCell(Text(
                      '${item.netProfit.toStringAsFixed(0)} DA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: profitColor),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PROGRESS BAR ROW
// ==========================================
class _ProgressBarRow extends StatelessWidget {
  const _ProgressBarRow({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.color,
  });

  final String label;
  final double amount;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = (ratio * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${amount.toStringAsFixed(0)} DA ($percentage%)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// ACTIVITY SUMMARY CARD
// ==========================================
class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.summary,
    required this.l10n,
  });

  final ActivitySummary summary;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.activitySummaryTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActivityGridItem(
                  label: l10n.salesCountLabel,
                  count: summary.salesCount,
                  icon: Icons.point_of_sale,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ActivityGridItem(
                  label: l10n.invoicesCountLabel,
                  count: summary.invoicesCount,
                  icon: Icons.receipt_long,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ActivityGridItem(
                  label: l10n.expensesCountLabel,
                  count: summary.expensesCount,
                  icon: Icons.payment,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _ActivityGridItem(
                  label: l10n.employeesCountLabel,
                  count: summary.employeesCount,
                  icon: Icons.people_outline,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityGridItem extends StatelessWidget {
  const _ActivityGridItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TOP PRODUCTS CARD
// ==========================================
class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({
    required this.topProducts,
    required this.l10n,
  });

  final List<TopProduct> topProducts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final values = _normalized(topProducts.map((p) => p.unitsSold.toDouble()).toList());

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.topProductsTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          MiniBarChart(values: values),
          const SizedBox(height: 10),
          ...topProducts.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    l10n.unitsSoldLabel(p.unitsSold),
                    style: AppTypography.bodyStrong(AppColors.primary).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _normalized(List<double> values) {
    if (values.isEmpty) return values;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    if (maxV <= 0) return values.map((_) => 0.0).toList();
    return values.map((v) => v / maxV).toList();
  }
}

// ==========================================
// ACTUAL TRANSACTIONS LIST CARD (Requirement 16)
// ==========================================
class _ActualTransactionsCard extends StatelessWidget {
  const _ActualTransactionsCard({
    required this.transactions,
    required this.l10n,
  });

  final List<ReportTransaction> transactions;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentTransactionsTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${transactions.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...transactions.take(20).map((tx) {
            final isSale = tx.type == 'sale';
            final isSalary = tx.type == 'salary';
            Color color;
            IconData icon;
            String sign;

            if (isSale) {
              color = AppColors.primary;
              icon = Icons.arrow_upward;
              sign = '+';
            } else if (isSalary) {
              color = AppColors.warning;
              icon = Icons.badge_outlined;
              sign = '-';
            } else {
              color = AppColors.danger;
              icon = Icons.arrow_downward;
              sign = '-';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.employeeName != null
                              ? '${tx.employeeName} (${tx.salaryPeriod ?? l10n.salaryExpenseLabel})'
                              : tx.title,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (tx.date != null)
                              Text(
                                '${tx.date!.day.toString().padLeft(2, '0')}/${tx.date!.month.toString().padLeft(2, '0')}/${tx.date!.year}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                              ),
                            if (tx.description != null && tx.description!.isNotEmpty) ...[
                              Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tx.description!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$sign${tx.amount.toStringAsFixed(0)} DA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
