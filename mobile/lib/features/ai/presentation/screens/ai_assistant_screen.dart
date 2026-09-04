import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../products/data/products_repository.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../reports/presentation/screens/reports_screen.dart';

/// AI Assistant — Spec Ch. 16.1.
///
/// SCOPE NOTE: question-matching here is simple keyword routing, not a
/// real LLM call (that's Phase 6, via POST /ai/chat once the backend
/// exists). What's real and non-negotiable per the spec's own guardrail
/// ("AI MUST NEVER INVENT FINANCIAL NUMBERS") is enforced already: every
/// numeric answer below is computed live from ProductsRepository /
/// SalesRepository / ExpensesRepository — never a hardcoded figure.
class _ChatMessage {
  _ChatMessage(this.text, this.isUser);
  final String text;
  final bool isUser;
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];

  String _answer(String question) {
    final q = question.toLowerCase();
    final sales = ref.read(salesRepositoryProvider).valueOrNull ?? [];
    final products = ref.read(productsRepositoryProvider).valueOrNull ?? [];
    final expensesState = ref.read(expensesRepositoryProvider).valueOrNull;
    final monthExpensesTotal = expensesState?.thisMonthTotal ?? 0;

    final now = DateTime.now();
    final monthSales = sales.where((s) => s.soldAt.year == now.year && s.soldAt.month == now.month);
    final monthRevenue = monthSales.fold<double>(0, (sum, s) => sum + s.total);

    if (q.contains('earn') || q.contains('revenue') || q.contains('profit')) {
      return 'So far this month you\'ve earned ${monthRevenue.toStringAsFixed(0)} DZD in revenue '
          '(${monthSales.length} sale(s)). Ask the Reports screen for exact gross-profit figures.';
    }
    if (q.contains('low') || q.contains('stock')) {
      final low = products.where((p) => p.isLowStock || p.isOutOfStock).toList();
      if (low.isEmpty) return 'No products are currently low in stock.';
      return '${low.length} product(s) are below their minimum stock: '
          '${low.map((p) => p.name).join(", ")}.';
    }
    if (q.contains('best') || q.contains('selling')) {
      if (sales.isEmpty) return 'No sales recorded yet, so I can\'t determine a best-seller.';
      return 'Best-seller ranking needs per-item sales history — open the Reports screen '
          'for the real "Top Products" breakdown computed server-side.';
    }
    if (q.contains('spend') || q.contains('expense')) {
      return 'Total expenses recorded this month: ${monthExpensesTotal.toStringAsFixed(0)} DZD.';
    }
    return 'I don\'t have enough recorded data to answer that confidently yet — '
        'try asking about revenue, profit, low stock, best-sellers, or expenses.';
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _messages.add(_ChatMessage(_answer(text), false));
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Ask about your business — e.g. "How much did I earn this month?" '
                        'or "Which products are low in stock?"',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      return Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: msg.isUser
                                ? AppColors.primary
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                            border: msg.isUser
                                ? null
                                : Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(color: msg.isUser ? Colors.white : null),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Ask about your business...'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum InsightSeverity { info, watch, alert }

class _Insight {
  _Insight(this.title, this.detail, this.severity);
  final String title;
  final String detail;
  final InsightSeverity severity;
}

/// AI Insights — Spec Ch. 16.2. Every insight below is derived from a
/// real backend query (GET /reports, GET /products) — kept deliberately
/// simple per the spec's own MVP guidance ("avoid overstating AI
/// capability").
class AiInsightsScreen extends ConsumerWidget {
  const AiInsightsScreen({super.key});

  Color _colorFor(InsightSeverity s) => switch (s) {
        InsightSeverity.info => AppColors.info,
        InsightSeverity.watch => AppColors.warning,
        InsightSeverity.alert => AppColors.danger,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsRepositoryProvider);
    final expensesAsync = ref.watch(expensesRepositoryProvider);
    final reportAsync = ref.watch(reportProvider('monthly'));

    final insights = <_Insight>[];

    reportAsync.whenData((report) {
      if (report.topProducts.isNotEmpty) {
        final top = report.topProducts.first;
        insights.add(_Insight(
          'Best seller this month',
          '${top.name} — ${top.unitsSold} units sold',
          InsightSeverity.info,
        ));
      }
    });

    productsAsync.whenData((products) {
      final outOfStock = products.where((p) => p.isOutOfStock).toList();
      if (outOfStock.isNotEmpty) {
        insights.add(_Insight(
          'Stock warning',
          '${outOfStock.map((p) => p.name).join(", ")} out of stock',
          InsightSeverity.alert,
        ));
      }
      final lowStock = products.where((p) => p.isLowStock).toList();
      if (lowStock.isNotEmpty) {
        insights.add(_Insight(
          'Low stock',
          '${lowStock.length} product(s) below minimum threshold',
          InsightSeverity.watch,
        ));
      }
    });

    expensesAsync.whenData((state) {
      if (state.expenses.isNotEmpty) {
        insights.add(_Insight(
          'Expenses',
          'Total this month: ${state.thisMonthTotal.toStringAsFixed(0)} DZD',
          InsightSeverity.info,
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('AI Insights')),
      body: insights.isEmpty
          ? const Center(child: Text('Not enough data yet to generate insights'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: insights.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final insight = insights[i];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(insight.title, style: Theme.of(context).textTheme.titleMedium),
                            Text(insight.detail),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(insight.severity.name),
                        backgroundColor: _colorFor(insight.severity).withValues(alpha: 0.12),
                        labelStyle: TextStyle(color: _colorFor(insight.severity)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
