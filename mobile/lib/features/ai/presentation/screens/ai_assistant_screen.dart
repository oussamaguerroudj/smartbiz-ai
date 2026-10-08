import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';

/// AI Assistant  -  Spec Ch. 16.1.
///
/// Phase 6 update: questions are now answered by a real POST /ai/chat
/// call (OpenAI, server-side) instead of local keyword routing. The
/// spec's own guardrail ("AI MUST NEVER INVENT FINANCIAL NUMBERS") is
/// enforced server-side there: the backend hands the model a snapshot
/// of the company's real current data and instructs it to never state
/// a figure that isn't in that snapshot (see ai.service.js
/// CHAT_SYSTEM_PROMPT)  -  the client here just displays whatever comes
/// back, the same as any other chat UI.
///
/// Design System v2: gradient hero background + styled bubbles, matching
/// the approved redesign. The typing indicator now reflects the actual
/// network request instead of a fixed deterministic delay.
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

    // Sent as conversation context so the assistant can handle
    // follow-up questions ("and how about expenses?")  -  capped
    // server-side too, but trimmed here as well to keep the request
    // itself small.
    final history = _messages
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    final l10n = AppLocalizations.of(context)!;
    String answer;

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post(
        '/ai/chat',
        body: {'message': text, 'history': history},
        timeout: const Duration(seconds: 30),
      );
      final data = response['data'] as Map<String, dynamic>;
      answer = (data['reply'] as String?)?.trim().isNotEmpty == true
          ? data['reply'] as String
          : l10n.networkError;
    } on ApiException catch (e) {
      // e.g. 503 AI_NOT_CONFIGURED if the server has no OpenAI key yet,
      // or AI_RATE_LIMIT  -  shown as the assistant's own reply so it
      // reads naturally in the conversation rather than as a toast.
      answer = e.message;
    } catch (_) {
      answer = l10n.networkError;
    }

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
    final l10n = AppLocalizations.of(context)!;
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
                            l10n.askAboutYourBusiness,
                            style: AppTypography.sectionTitle(
                              Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.aiAnswersComputedLive,
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

/// Fetches fresh each time the Insights screen is opened (autoDispose,
/// no caching across visits)  -  insights are meant to reflect the
/// business's current state, not a snapshot from an earlier session.
final _aiInsightsProvider = FutureProvider.autoDispose<List<_Insight>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/ai/insights');
  final data = response['data'] as Map<String, dynamic>;
  final rawInsights = (data['insights'] as List).cast<Map<String, dynamic>>();

  return rawInsights.map((raw) {
    final severityName = raw['severity'] as String? ?? 'info';
    final severity = InsightSeverity.values.firstWhere(
      (s) => s.name == severityName,
      orElse: () => InsightSeverity.info,
    );

    return _Insight(
      raw['title'] as String? ?? '',
      raw['detail'] as String? ?? '',
      severity,
    );
  }).toList();
});

/// AI Insights  -  Spec Ch. 16.2.
///
/// Phase 6 update: insights now come from a real GET /ai/insights call
/// (OpenAI, server-side), which is itself grounded in the same real
/// dashboard/report data the rule-based version used to read locally
/// (see ai.service.js gatherBusinessContext)  -  kept deliberately simple
/// per the spec's own MVP guidance ("avoid overstating AI capability").
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
    final insightsAsync = ref.watch(_aiInsightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiInsightsTitle),
      ),
      body: insightsAsync.when(
        data: (insights) => insights.isEmpty
            ? Center(
                child: Text(
                  l10n.notEnoughDataForInsights,
                ),
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(_aiInsightsProvider.future),
                child: ListView.separated(
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
                        boxShadow: AppSpacing.cardElevation,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  insight.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(insight.detail),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(insight.severity.name),
                            backgroundColor:
                                _colorFor(insight.severity).withValues(alpha: 0.12),
                            labelStyle: TextStyle(color: _colorFor(insight.severity)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  err is ApiException ? err.message : l10n.networkError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => ref.refresh(_aiInsightsProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}