import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/directional_chevron.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscriptions/data/subscriptions_repository.dart';

class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _category = 'general';
  bool _isLoading = false;
  String? _successTicket;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await ref.read(subscriptionsRepositoryProvider).submitContactMessage(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
            category: _category,
            subject: _subjectCtrl.text.trim().isNotEmpty ? _subjectCtrl.text.trim() : null,
            message: _messageCtrl.text.trim(),
          );

      if (mounted) {
        setState(() {
          _successTicket = res['ticketNumber']?.toString();
        });
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
        title: Text(l10n.contactUsTitle),
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
            child: _successTicket != null
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
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Message Sent Successfully | تم إرسال رسالتك بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ticket Number: $_successTicket',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Our support team will get in touch with you shortly.',
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
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.contactNameLabel,
              prefixIcon: const Icon(Icons.person_rounded),
            ),
            validator: (v) => v == null || v.trim().length < 2 ? 'Please enter your name' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.contactEmailLabel,
              prefixIcon: const Icon(Icons.email_rounded),
            ),
            validator: (v) => v == null || !v.contains('@') ? 'Please enter a valid email' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.contactPhoneLabel,
              prefixIcon: const Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _category,
            decoration: InputDecoration(
              labelText: l10n.contactCategoryLabel,
              prefixIcon: const Icon(Icons.category_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('General Support (دعم عام)')),
              DropdownMenuItem(value: 'account_login', child: Text('Account & Login (الحساب والدخول)')),
              DropdownMenuItem(value: 'payment_license', child: Text('Payment & License (الدفع والتراخيص)')),
              DropdownMenuItem(value: 'technical', child: Text('Technical Problem (مشكلة تقنية)')),
              DropdownMenuItem(value: 'bug_report', child: Text('Bug Report (إبلاغ عن خطأ)')),
              DropdownMenuItem(value: 'feature_request', child: Text('Feature Request (اقتراح ميزة)')),
              DropdownMenuItem(value: 'other', child: Text('Other (أخرى)')),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _subjectCtrl,
            decoration: InputDecoration(
              labelText: l10n.contactSubjectLabel,
              prefixIcon: const Icon(Icons.subject_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _messageCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.contactMessageLabel,
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.message_rounded),
              ),
            ),
            validator: (v) => v == null || v.trim().length < 10 ? 'Please enter a detailed message (min 10 characters)' : null,
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
                : Text(l10n.submitMessageAction, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
