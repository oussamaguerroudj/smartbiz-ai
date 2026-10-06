import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/auth_repository.dart';

/// Register Screen — Spec Ch. 8.3
/// Now calls POST /auth/register for real (Phase 5 wiring).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onRegisterSuccess,
    required this.onGoToLogin,
  });

  /// Called with the registered email so the next screen (account
  /// verification) knows which address the code was sent to.
  final void Function(String email) onRegisterSuccess;
  final VoidCallback onGoToLogin;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().length < 2) return l10n.nameRequired;
    return null;
  }

  String? _validateEmail(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return l10n.emailRequired;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v)) return l10n.emailInvalid;
    return null;
  }

  String? _validatePassword(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.length < 6) return l10n.passwordTooShort;
    return null;
  }

  String? _validateConfirm(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v != _passwordController.text) return l10n.passwordsDoNotMatch;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final email = _emailController.text.trim();
      await ref.read(authRepositoryProvider).register(
            name: _nameController.text.trim(),
            email: email,
            password: _passwordController.text,
          );
      if (mounted) widget.onRegisterSuccess(email);
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 0 ||
            e.code == 'CONNECTION_ERROR' ||
            e.code == 'NETWORK_ERROR' ||
            e.code == 'TIMEOUT' ||
            e.code == 'CLIENT_ERROR') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.firstTimeRegisterInternetRequired)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.firstTimeRegisterInternetRequired)),
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
      appBar: AppBar(title: Text(l10n.registerTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: l10n.fullName,
                  hint: l10n.yourNameHint,
                  controller: _nameController,
                  validator: _validateName,
                ),
                const SizedBox(height: AppSpacing.sm),
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
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: l10n.confirmPassword,
                  hint: '••••••••',
                  controller: _confirmController,
                  obscureText: true,
                  validator: _validateConfirm,
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
                      : Text(l10n.createAccount),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: widget.onGoToLogin,
                    child: Text(l10n.haveAccount),
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

