import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../products/data/products_repository.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../../l10n/app_localizations.dart';

/// AI Assistant — Spec Ch. 16.1.
///
/// SCOPE NOTE: question-matching here is simple keyword routing, not a
/// real LLM call (that's Phase 6, via POST /ai/chat once the backend
/// exists). What's real and non-negotiable per the spec's own guardrail
/// ("AI MUST NEVER INVENT FINANCIAL NUMBERS") is enforced already: every
/// numeric answer below is computed live from ProductsRepository /
/// SalesRepository / ExpensesRepository — never a hardcoded figure.
///
/// Design System v2: gradient hero background + styled bubbles, matching
/// the approved redesign. A short, deterministic "typing" pause plays
/// before the bot bubble appears — purely presentational; the answer
/// itself is still computed instantly and never altered by the delay.
class _ChatMessage {
  _ChatMessage(this.text, this.isUser);

  final String text;
  final bool isUser;
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() =>
      _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  String _answer(String question) {
    final q = question.toLowerCase();
    final sales = ref.read(salesRepositoryProvider).valueOrNull ?? [];
    final products =
        ref.read(productsRepositoryProvider).valueOrNull ?? [];
    final expensesState =
        ref.read(expensesRepositoryProvider).valueOrNull;
    final monthExpensesTotal =
        expensesState?.thisMonthTotal ?? 0;

    final now = DateTime.now();

    final monthSales = sales.where(
      (s) =>
          s.soldAt.year == now.year &&
          s.soldAt.month == now.month,
    );

    final monthRevenue = monthSales.fold<double>(
      0,
      (sum, s) => sum + s.total,
    );

    if (q.contains('earn') ||
        q.contains('revenue') ||
        q.contains('profit')) {
      return 'So far this month you\'ve earned '
          '${monthRevenue.toStringAsFixed(0)} DZD in revenue '
          '(${monthSales.length} sale(s)). Ask the Reports screen '
          'for exact gross-profit figures.';
    }

    if (q.contains('low') || q.contains('stock')) {
      final low = products
          .where((p) => p.isLowStock || p.isOutOfStock)
          .toList();

      if (low.isEmpty) {
        return 'No products are currently low in stock.';
      }

      return '${low.length} product(s) are below their minimum stock: '
          '${low.map((p) => p.name).join(", ")}.';
    }

    if (q.contains('best') || q.contains('selling')) {
      if (sales.isEmpty) {
        return 'No sales recorded yet, so I can\'t determine '
            'a best-seller.';
      }

      return 'Best-seller ranking needs per-item sales history — '
          'open the Reports screen for the real "Top Products" '
          'breakdown computed server-side.';
    }

    if (q.contains('spend') || q.contains('expense')) {
      return 'Total expenses recorded this month: '
          '${monthExpensesTotal.toStringAsFixed(0)} DZD.';
    }

    return 'I don\'t have enough recorded data to answer that '
        'confidently yet — try asking about revenue, profit, '
        'low stock, best-sellers, or expenses.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    final answer = _answer(text);

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Brief, deterministic pause so the typing indicator is perceptible —
    // the answer above was already computed from real data; this delay
    // only affects when it's revealed, never what it says.
    await Future.delayed(
      const Duration(milliseconds: 550),
    );

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(answer, false));
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientHero(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ask about your business',
                            style: AppTypography.sectionTitle(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Answers are computed live from your real data',
                            style: AppTypography.caption(
                              Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            'Ask about your business — e.g. '
                            '"How much did I earn this month?" '
                            'or "Which products are low in stock?"',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding:
                            const EdgeInsets.all(AppSpacing.sm),
                        itemCount:
                            _messages.length +
                                (_isTyping ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length) {
                            return const _TypingBubble();
                          }

                          final msg = _messages[i];

                          return _ChatBubble(
                            message: msg,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusPill,
                          ),

                          // Keep the original glass border.
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),

                        // Prevent the app theme from adding the
                        // blue focused outline/underline.
                        child: TextSelectionTheme(
                          data: TextSelectionThemeData(
                            cursorColor: Colors.white,
                            selectionColor:
                                Colors.white.withValues(
                              alpha: 0.28,
                            ),
                            selectionHandleColor:
                                Colors.white,
                          ),
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              hintText:
                                  'Ask about your business…',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                              filled: false,

                              // Remove ALL TextField focus borders.
                              border: InputBorder.none,
                              enabledBorder:
                                  InputBorder.none,
                              focusedBorder:
                                  InputBorder.none,
                              disabledBorder:
                                  InputBorder.none,
                              errorBorder:
                                  InputBorder.none,
                              focusedErrorBorder:
                                  InputBorder.none,

                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_upward_rounded,
                          color: AppColors.primaryDark,
                        ),
                        // Default Material ripple picks up the theme's
                        // blue primary color. Keep it neutral instead.
                        style: ButtonStyle(
                          overlayColor:
                              WidgetStateProperty.all(
                            AppColors.primaryDark.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
  });

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: Align(
        alignment: message.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(AppSpacing.sm),
          constraints: const BoxConstraints(
            maxWidth: 280,
          ),
          decoration: BoxDecoration(
            color: message.isUser
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(
              AppSpacing.radiusCard,
            ),
            border: message.isUser
                ? null
                : Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.14,
                    ),
                  ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: message.isUser
                  ? AppColors.primaryDark
                  : Colors.white,
              fontWeight: message.isUser
                  ? FontWeight.w600
                  : FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() =>
      _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(
            AppSpacing.radiusCard,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t =
                    ((_controller.value + (i * 0.2)) % 1.0);
                final bounce =
                    (t < 0.5 ? t : 1 - t) * 2;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -3 * bounce),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.4 + 0.6 * bounce,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
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
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync =
        ref.watch(productsRepositoryProvider);
    final expensesAsync =
        ref.watch(expensesRepositoryProvider);
    final reportAsync =
        ref.watch(reportProvider('monthly'));

    final insights = <_Insight>[];

    reportAsync.whenData((report) {
      if (report.topProducts.isNotEmpty) {
        final top = report.topProducts.first;

        insights.add(
          _Insight(
            'Best seller this month',
            '${top.name} — ${top.unitsSold} units sold',
            InsightSeverity.info,
          ),
        );
      }
    });

    productsAsync.whenData((products) {
      final outOfStock =
          products.where((p) => p.isOutOfStock).toList();

      if (outOfStock.isNotEmpty) {
        insights.add(
          _Insight(
            'Stock warning',
            '${outOfStock.map((p) => p.name).join(", ")} '
            'out of stock',
            InsightSeverity.alert,
          ),
        );
      }

      final lowStock =
          products.where((p) => p.isLowStock).toList();

      if (lowStock.isNotEmpty) {
        insights.add(
          _Insight(
            'Low stock',
            '${lowStock.length} product(s) below '
            'minimum threshold',
            InsightSeverity.watch,
          ),
        );
      }
    });

    expensesAsync.whenData((state) {
      if (state.expenses.isNotEmpty) {
        insights.add(
          _Insight(
            'Expenses',
            'Total this month: '
            '${state.thisMonthTotal.toStringAsFixed(0)} DZD',
            InsightSeverity.info,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiInsightsTitle),
      ),
      body: insights.isEmpty
          ? Center(
              child: Text(
                l10n.notEnoughDataForInsights,
              ),
            )
          : ListView.separated(
              padding:
                  const EdgeInsets.all(AppSpacing.sm),
              itemCount: insights.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final insight = insights[i];

                return Container(
                  padding:
                      const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusCard,
                    ),
                    boxShadow:
                        AppSpacing.cardElevation,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            Text(insight.detail),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          insight.severity.name,
                        ),
                        backgroundColor:
                            _colorFor(
                          insight.severity,
                        ).withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: _colorFor(
                            insight.severity,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}