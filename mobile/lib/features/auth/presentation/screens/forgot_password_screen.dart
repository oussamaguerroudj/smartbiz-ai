import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/auth_repository.dart';

/// Forgot Password Screen
/// Two-step flow on a single page:
///   1) enter the account email -> POST /auth/forgot-password (sends a
///      reset code to that email)
///   2) enter the received code + a new password -> POST
///      /auth/reset-password
/// Kept as one screen (instead of two) since the steps share state and
/// the user never needs to navigate back and forth between them.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onResetSuccess,
    required this.onGoToLogin,
  });

  final VoidCallback onResetSuccess;
  final VoidCallback onGoToLogin;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _ForgotStep { requestCode, resetPassword }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ForgotStep _step = _ForgotStep.requestCode;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return l10n.emailRequired;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) return l10n.emailInvalid;
    return null;
  }

  String? _validateCode(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().length != 6) return l10n.verifyEnterFullCode;
    return null;
  }

  String? _validatePassword(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.length < 6) return l10n.passwordTooShort;
    return null;
  }

  String? _validateConfirm(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value != _newPasswordController.text) return l10n.passwordsDoNotMatch;
    return null;
  }

  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.verifyCodeResent)));
        setState(() => _step = _ForgotStep.resetPassword);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _newPasswordController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.passwordResetSuccess)));
        widget.onResetSuccess();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.networkError)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _step == _ForgotStep.requestCode
                ? _buildRequestStep(l10n)
                : _buildResetStep(l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStep(AppLocalizations l10n) {
    return FadeSlideIn(
      key: const ValueKey('request'),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.forgotPasswordSubtitle,
              style: AppTypography.body(Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: l10n.email,
              hint: 'you@business.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                key: ValueKey(_isLoading),
                onPressed: _isLoading ? null : _requestCode,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.sendResetCode),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: widget.onGoToLogin,
                child: Text(l10n.backToLogin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetStep(AppLocalizations l10n) {
    return FadeSlideIn(
      key: const ValueKey('reset'),
      child: Form(
        key: _resetFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.resetPasswordSubtitle(_emailController.text.trim()),
              style: AppTypography.body(Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: l10n.verifyCodeLabel,
              hint: '000000',
              controller: _codeController,
              keyboardType: TextInputType.number,
              validator: _validateCode,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: l10n.newPassword,
              hint: '••••••••',
              controller: _newPasswordController,
              obscureText: _obscure,
              validator: _validatePassword,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: l10n.confirmPassword,
              hint: '••••••••',
              controller: _confirmPasswordController,
              obscureText: _obscure,
              validator: _validateConfirm,
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                key: ValueKey(_isLoading),
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.resetPasswordButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _step = _ForgotStep.requestCode),
                child: Text(l10n.useAnotherEmail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
