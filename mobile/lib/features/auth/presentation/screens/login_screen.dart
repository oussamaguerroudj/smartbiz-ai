import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_client.dart';
import 'package:http/http.dart' as http;
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/auth_repository.dart';

/// Login Screen — Spec Ch. 8.3
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
  /// leaving them stuck with no way forward — they don't have a token
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
    try {
      await ref.read(authRepositoryProvider).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) widget.onLoginSuccess();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        if (e.code == 'EMAIL_NOT_VERIFIED') {
          widget.onGoToVerify(_emailController.text.trim());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.networkError)),
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
                              // `onPressed: () {}` — the link did nothing.
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
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: InkWell(
                    onTap: () => _showServerConfigDialog(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.dns_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            ApiClient.baseUrl.replaceFirst('http://', '').replaceFirst('/api', ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.settings_outlined, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: ApiClient.baseUrl);
    String? testResult;
    bool isTesting = false;
    bool isSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> runTest() async {
            setDialogState(() {
              isTesting = true;
              testResult = null;
            });
            try {
              var url = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
              if (!url.endsWith('/api')) url = '$url/api';
              final res = await http.get(Uri.parse('$url/ai/health')).timeout(const Duration(seconds: 4));
              if (res.statusCode == 200) {
                setDialogState(() {
                  isTesting = false;
                  isSuccess = true;
                  testResult = '✓ Connected to server successfully (200 OK)!';
                });
              } else {
                setDialogState(() {
                  isTesting = false;
                  isSuccess = false;
                  testResult = 'Server returned HTTP ${res.statusCode}';
                });
              }
            } catch (e) {
              setDialogState(() {
                isTesting = false;
                isSuccess = false;
                testResult = 'Cannot reach server: $e';
              });
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.dns_rounded, size: 22),
                const SizedBox(width: 8),
                Text(l10n.serverSettingsTitle, style: const TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Configure backend API address:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: l10n.serverBaseUrlLabel,
                      hintText: 'http://192.168.1.4:4000/api',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('192.168.1.4 (Wi-Fi)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          controller.text = 'http://192.168.1.4:4000/api';
                          setDialogState(() {});
                        },
                      ),
                      ActionChip(
                        label: const Text('localhost (USB)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          controller.text = 'http://192.168.1.3:4000/api';
                          setDialogState(() {});
                        },
                      ),
                      ActionChip(
                        label: const Text('10.0.2.2 (Emulator)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          controller.text = 'http://10.0.2.2:4000/api';
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isTesting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(l10n.testConnectionAction),
                      onPressed: runTest,
                    ),
                  if (testResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        testResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  await ApiClient.setBaseUrl(controller.text);
                  setState(() {});
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(l10n.saveAction),
              ),
            ],
          );
        },
      ),
    );
  }
}


