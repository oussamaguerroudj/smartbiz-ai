import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/auth_repository.dart';

/// Login Screen  -  Spec Ch. 8.3
/// Now wired to the real backend (Phase 5): calls POST /auth/login via
/// AuthRepository, shows a loading state, and surfaces backend errors
/// (e.g. wrong password) as a snackbar instead of always succeeding.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onGoToRegister,
    required this.onGoToForgotPassword,
    required this.onGoToVerify,
  });

  final VoidCallback onLoginSuccess;
  final VoidCallback onGoToRegister;
  final VoidCallback onGoToForgotPassword;

  /// Called (with the email just typed in) when the backend rejects the
  /// login attempt because the account hasn't been verified yet. Takes
  /// the user straight to the "enter your code" screen instead of
  /// leaving them stuck with no way forward  -  they don't have a token
  /// (login failed) so re-registering was previously the only escape
  /// hatch, which then wrongly complained the email was already taken.
  final void Function(String email) onGoToVerify;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(sessionProvider).isLoggedIn) {
        widget.onLoginSuccess();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return l10n.emailRequired;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) return l10n.emailInvalid;
    return null;
  }

  String? _validatePassword(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return l10n.passwordRequired;
    if (value.length < 6) return l10n.passwordTooShort;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(authRepositoryProvider).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) widget.onLoginSuccess();
    } on ApiException catch (e) {
      if (mounted) {
        if (e.code == 'EMAIL_NOT_VERIFIED') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          widget.onGoToVerify(_emailController.text.trim());
        } else if (e.code == 'INVALID_CREDENTIALS' || e.statusCode == 400 || e.statusCode == 401) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        } else if (e.code == 'TIMEOUT' || e.statusCode == 408 || e.statusCode == 504) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message.isNotEmpty
                    ? e.message
                    : 'Server connection timed out. The server may be waking up, please retry.',
              ),
            ),
          );
        } else if (e.code == 'PERMISSION_DENIED') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        } else if (e.code == 'CONNECTION_ERROR' ||
            e.code == 'NETWORK_ERROR' ||
            e.code == 'CLIENT_ERROR' ||
            e.statusCode == 0) {
          final isFirstTime = !ref.read(sessionProvider).isLoggedIn;
          final errorMsg = isFirstTime
              ? '${l10n.firstTimeAuthInternetRequired}\n(${e.message})'
              : e.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.loginTitle, style: AppTypography.screenTitle(Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  l10n.loginSubtitle,
                  style: AppTypography.body(Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: l10n.email,
                          hint: 'you@business.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          label: l10n.password,
                          hint: '••••••••',
                          controller: _passwordController,
                          obscureText: _obscure,
                          validator: _validatePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) =>
                                      setState(() => _rememberMe = v ?? false),
                                ),
                                Text(l10n.rememberMe),
                              ],
                            ),
                            TextButton(
                              // FIX (reported bug): this was a no-op
                              // `onPressed: () {}`  -  the link did nothing.
                              onPressed: widget.onGoToForgotPassword,
                              child: Text(l10n.forgotPassword),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    key: ValueKey(_isLoading),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.login),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: widget.onGoToRegister,
                    child: Text(l10n.noAccount),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


