import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscriptions/data/subscriptions_repository.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  String _category = 'ux_feedback';
  int _rating = 5;
  bool _isLoading = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(subscriptionsRepositoryProvider).submitFeedback(
            category: _category,
            message: _messageCtrl.text.trim(),
            rating: _rating,
          );

      if (mounted) {
        setState(() => _isSubmitted = true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feedbackTitle),
        leading: widget.onBack != null
            ? IconButton(
                icon: const PreviousChevron(),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FadeSlideIn(
            child: _isSubmitted
                ? _buildSuccessView(context)
                : _buildForm(context, l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.thumb_up_alt_rounded, color: AppColors.success, size: 64),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Thank You! | شكراً جزيلاً',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Your feedback helps us continuously improve Modiri AI for all Algerian businesses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
              child: const Text('Return | رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We value your feedback | نقدّر رأيك وملاحظاتك',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Feedback Type / نوع الملاحظة',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'ux_feedback', child: Text('User Experience (تجربة المستخدم)')),
              DropdownMenuItem(value: 'feature_request', child: Text('Feature Request (اقتراح ميزة جديدة)')),
              DropdownMenuItem(value: 'bug_report', child: Text('Bug Report (مشكلة أو خطأ)')),
              DropdownMenuItem(value: 'general_feedback', child: Text('General Feedback (ملاحظة عامة)')),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'ux_feedback'),
          ),
          const SizedBox(height: AppSpacing.md),

          // 1-5 Star Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.feedbackRatingLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  return IconButton(
                    icon: Icon(
                      starNum <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => _rating = starNum),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          TextFormField(
            controller: _messageCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your Feedback / ملاحظاتك',
              hintText: 'Tell us what you liked or how we can improve...',
              alignLabelWithHint: true,
            ),
            validator: (v) => v == null || v.trim().length < 5 ? 'Please enter at least 5 characters' : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.submitFeedbackAction, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
