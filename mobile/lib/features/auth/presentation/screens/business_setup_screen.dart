import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/session.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/companies_repository.dart';
import 'business_type_screen.dart';

/// Business Setup  -  Spec Ch. 8.4
/// Persists to the real backend via PUT /companies/me (Phase 5 wiring),
/// filling in the placeholder company auth.service.js created at
/// registration time.
///
/// FIX (reported bug  -  "Finish Setup" not navigating to Dashboard):
/// the save/validate/navigate flow below was already structurally
/// correct (validate → await the real PUT → only call onFinish() after
/// it succeeds → show a real error and stay put on failure)  -  this pass
/// hardened it rather than rewriting it:
///   - the read-only "Business type" field used to build a brand new
///     TextEditingController on every single rebuild without disposing
///     the old one (a real leak, and a classic source of flaky/dropped
///     state in a field that's rebuilt while a submit is in flight).
///     Fixed: one controller, created once, disposed in dispose().
///   - failures now also print an actionable debugPrint (status code +
///     backend message) so a stuck submit is diagnosable from `flutter
///     logs` instead of only a snackbar the user might miss.
///   - the most likely actual root cause, if this still doesn't
///     navigate on your device: the top-level app-phase guard in
///     main.dart was mutating state during build() (a real anti-pattern)
///     in a way that could re-override a just-set "go to Dashboard"
///     transition  -  see main.dart's _AppFlowState for that fix. If the
///     issue persists after both fixes, check the actual network
///     response for PUT /companies/me (auth header validity, route
///     existing, 4xx/5xx body)  -  that's the next thing to inspect.
class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({
    super.key,
    required this.businessType,
    required this.onFinish,
  });

  final BusinessType businessType;
  final VoidCallback onFinish;

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _currencyController = TextEditingController(text: 'DZD');
  late final TextEditingController _businessTypeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // FIX: was `TextEditingController(text: widget.businessType.label)`
    // created inline inside build()  -  a new controller every rebuild,
    // never disposed. Created once here instead.
    _businessTypeController = TextEditingController(text: widget.businessType.label);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currencyController.dispose();
    _businessTypeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return; // guard against double-submit (e.g. double-tap)
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(companiesRepositoryProvider).updateMe(
            name: _nameController.text.trim(),
            businessType: widget.businessType.apiValue, // matches backend business_type_enum exactly (see BusinessTypeApi)
            currency: _currencyController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          );
      ref.invalidate(companyInfoProvider);
      await ref.read(sessionProvider.notifier).updateBusinessType(widget.businessType.apiValue);
      // Only reachable if the PUT above actually succeeded (didn't throw).
      if (mounted) widget.onFinish();
    } on ApiException catch (e) {
      debugPrint('BusinessSetup: PUT /companies/me failed — '
          'status=${e.statusCode} code=${e.code} message=${e.message}');
      if (mounted) {
        await _showErrorDialog(e.message);
      }
    } catch (e, st) {
      debugPrint('BusinessSetup: PUT /companies/me threw unexpectedly: $e\n$st');
      if (mounted) {
        await _showErrorDialog('Could not reach the server — check your connection and try again.');
      }
    } finally {
      // Always reached whether the request succeeded, failed, or threw  - 
      // the button can never get stuck permanently disabled.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showErrorDialog(String message) {
    final l10n = AppLocalizations.of(context)!;
    // A dialog is harder to miss than a snackbar for a blocking failure
    // like this one, where the user is otherwise left wondering why
    // nothing happened.
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.setupSaveFailedTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessSetupTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: l10n.businessName,
                  hint: l10n.businessNameHint,
                  controller: _nameController,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.businessTypeLabel,
                  controller: _businessTypeController,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.phoneNumber,
                  hint: '+213 ...',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.address,
                  hint: l10n.addressHint,
                  controller: _addressController,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.currency,
                  controller: _currencyController,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.finishSetup),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
