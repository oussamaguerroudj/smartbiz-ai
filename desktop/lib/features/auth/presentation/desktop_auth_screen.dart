import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/desktop_theme.dart';
import '../../../core/widgets/modiri_background.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../data/desktop_google_oauth.dart';
import 'widgets/google_sign_in_button.dart';

class DesktopAuthScreen extends ConsumerStatefulWidget {
  const DesktopAuthScreen({super.key});

  @override
  ConsumerState<DesktopAuthScreen> createState() => _DesktopAuthScreenState();
}

class _DesktopAuthScreenState extends ConsumerState<DesktopAuthScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isRegister = false;
  bool _isVerifyingEmail = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _pendingEmail = '';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final remember = prefs.getBool('remember_me') ?? false;
        final rememberedEmail = prefs.getString('remembered_email');
        if (remember && rememberedEmail != null && rememberedEmail.isNotEmpty && mounted) {
          setState(() {
            _rememberMe = true;
            _emailController.text = rememberedEmail;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _validateName(String? value, ModiriLocalizations loc) {
    if (value == null || value.trim().length < 2) {
      return loc.get('name_required');
    }
    return null;
  }

  String? _validateEmail(String? value, ModiriLocalizations loc) {
    if (value == null || value.trim().isEmpty) {
      return loc.get('email_required');
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return loc.get('email_invalid');
    }
    return null;
  }

  String? _validatePassword(String? value, ModiriLocalizations loc) {
    if (value == null || value.isEmpty) {
      return loc.get('password_required');
    }
    if (value.length < 6) {
      return loc.get('password_too_short');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value, ModiriLocalizations loc) {
    if (value != _passwordController.text) {
      return loc.get('passwords_do_not_match');
    }
    return null;
  }

  Future<void> _applyAuthPayload(
    Map<dynamic, dynamic> data, {
    required String fallbackEmail,
    String? preferredCompanyName,
  }) async {
    final token = (data['accessToken'] ?? data['token'] ?? '').toString();
    final refreshToken = data['refreshToken']?.toString();
    final user = data['user'] is Map ? data['user'] as Map : {};
    final company = data['company'] is Map ? data['company'] as Map : {};

    final userId = (user['id'] ?? 'user_1').toString();
    final companyId =
        (company['id'] ?? user['companyId'] ?? user['company_id'] ?? 'comp_1')
            .toString();
    var companyName = (company['name'] ??
            user['companyName'] ??
            user['company_name'] ??
            preferredCompanyName ??
            'Modiri Business')
        .toString();
    final businessType = (company['businessType'] ??
            company['business_type'] ??
            user['businessType'] ??
            user['business_type'])
        ?.toString();
    final entitlementType =
        (company['entitlementType'] ?? company['entitlement_type'] ?? 'trial')
            .toString();
    final bool onboardingCompleted = company['onboardingCompleted'] == true ||
        company['onboarding_completed'] == true;

    if (preferredCompanyName != null &&
        preferredCompanyName.isNotEmpty &&
        (company['name'] == null || company['name'].toString().isEmpty)) {
      companyName = preferredCompanyName;
    }

    await ref.read(sessionProvider.notifier).applyLogin(
          accessToken: token.isNotEmpty ? token : 'session_token',
          refreshToken: refreshToken,
          userId: userId,
          companyId: companyId,
          companyName: companyName,
          email: (user['email'] ?? fallbackEmail).toString(),
          name: (user['name'] ?? _nameController.text.trim()).toString(),
          phone: user['phone']?.toString(),
          role: (user['role'] ?? 'owner').toString(),
          businessType: businessType,
          entitlementType: entitlementType,
          onboardingCompleted: onboardingCompleted,
        );

    // Pull authoritative cloud data immediately upon login so all data matches mobile
    if (onboardingCompleted == true && !Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(() async {
        await ref.read(desktopSyncServiceProvider.notifier).syncPending();
        await ref.read(desktopSyncServiceProvider.notifier).pullInitialData();
      }());
    }
  }

  Future<void> _submit() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      if (_isRegister) {
        final fullName = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Administrator';
        final res = await client.post('/auth/register', body: {
          'name': fullName,
          'email': email,
          'password': password,
        });

        final data = res is Map ? (res['data'] ?? res) : {};
        if (data is Map &&
            (data['pendingVerification'] == true ||
                (data['accessToken'] == null && data['token'] == null))) {
          setState(() {
            _isVerifyingEmail = true;
            _pendingEmail = (data['email'] ?? email).toString();
            _otpController.clear();
            _infoMessage = loc.get('verify_email_subtitle');
          });
          return;
        }

        if (data is Map) {
          await _applyAuthPayload(
            data,
            fallbackEmail: email,
            preferredCompanyName: '$fullName Business',
          );
        }
      } else {
        final res = await client.post('/auth/login', body: {
          'email': email,
          'password': password,
        });

        final data = res is Map ? (res['data'] ?? res) : {};
        if (data is Map) {
          // Persist remember me preferences
          try {
            final prefs = await SharedPreferences.getInstance();
            if (_rememberMe) {
              await prefs.setBool('remember_me', true);
              await prefs.setString('remembered_email', email);
            } else {
              await prefs.remove('remember_me');
              await prefs.remove('remembered_email');
            }
          } catch (_) {}

          await _applyAuthPayload(data, fallbackEmail: email);
        }
      }
    } on ApiException catch (e) {
      if (e.code == 'EMAIL_NOT_VERIFIED' ||
          (e.statusCode == 403 &&
              e.message.toLowerCase().contains('verif'))) {
        setState(() {
          _isVerifyingEmail = true;
          _pendingEmail = email;
          _otpController.clear();
          _infoMessage = e.message;
        });
      } else {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      setState(() => _errorMessage = loc.get('connection_failed_offline_hint'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = loc.get('enter_6digit_code'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.post('/auth/verify-email', body: {
        'email': _pendingEmail,
        'code': code,
      });
      final data = res is Map ? (res['data'] ?? res) : {};
      if (data is Map) {
        final fullName = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Administrator';
        await _applyAuthPayload(
          data,
          fallbackEmail: _pendingEmail,
          preferredCompanyName: '$fullName Business',
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      await client.post('/auth/resend-verification', body: {
        'email': _pendingEmail,
      });
      setState(() => _infoMessage = loc.get('code_resent'));
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final codeCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    bool codeSent = false;
    bool busy = false;
    String? dialogError;
    String? dialogInfo;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            loc.get('forgot_password_title'),
            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.get('forgot_password_desc'),
                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13),
                ),
                const SizedBox(height: 14),
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandRose.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(dialogError!,
                        style: const TextStyle(color: ModiriColors.brandRose, fontSize: 12)),
                  ),
                  const SizedBox(height: 10),
                ],
                if (dialogInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(dialogInfo!,
                        style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 12)),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: emailCtrl,
                  enabled: !codeSent,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(
                    labelText: loc.get('email'),
                    hintText: 'admin@company.com',
                  ),
                ),
                if (codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.get('verification_code'),
                      hintText: '123456',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPwdCtrl,
                    obscureText: true,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.get('new_password'),
                      hintText: '••••••••',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel')),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() {
                        busy = true;
                        dialogError = null;
                      });
                      try {
                        final client = ref.read(apiClientProvider);
                        if (!codeSent) {
                          await client.post('/auth/forgot-password', body: {'email': email});
                          setDialogState(() {
                            codeSent = true;
                            busy = false;
                            dialogInfo = loc.get('code_resent');
                          });
                        } else {
                          final code = codeCtrl.text.trim();
                          final newPassword = newPwdCtrl.text;
                          if (code.length < 6 || newPassword.length < 8) {
                            setDialogState(() {
                              busy = false;
                              dialogError = loc.get('enter_code_and_min_password');
                            });
                            return;
                          }
                          await client.post('/auth/reset-password', body: {
                            'email': email,
                            'code': code,
                            'newPassword': newPassword,
                          });
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            setState(() {
                              _emailController.text = email;
                              _infoMessage = loc.get('password_reset_success');
                              _errorMessage = null;
                            });
                          }
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          busy = false;
                          dialogError = e.message;
                        });
                      } catch (e) {
                        setDialogState(() {
                          busy = false;
                          dialogError = e.toString();
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(codeSent ? loc.get('reset_password') : loc.get('send_reset_code')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continueOffline() async {
    final existing = ref.read(sessionProvider);
    var savedCompanyId = existing.companyId;
    var savedUserId = existing.userId;
    var savedBusinessType = existing.businessType;
    var savedCompanyName = existing.companyName;

    if (savedCompanyId == null || savedCompanyId.isEmpty) {
      const storage = FlutterSecureStorage();
      savedCompanyId = await storage.read(key: 'modiri_desktop_company_id');
      savedUserId ??= await storage.read(key: 'modiri_desktop_user_id');
      savedBusinessType ??= await storage.read(key: 'modiri_desktop_business_type');
      savedCompanyName ??= await storage.read(key: 'modiri_desktop_company_name');
    }

    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (existing.userEmail ?? 'admin@modiri.local');
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (existing.userName ?? 'Administrator');
    final companyName = savedCompanyName ?? 'Modiri Local Business';

    await ref.read(sessionProvider.notifier).applyLogin(
          accessToken: 'local_offline_${DateTime.now().millisecondsSinceEpoch}',
          userId: savedUserId ?? 'local_user_1',
          companyId: (savedCompanyId != null && savedCompanyId.isNotEmpty) ? savedCompanyId : 'comp_1',
          companyName: companyName,
          email: email,
          name: name,
          role: existing.role ?? 'owner',
          businessType: savedBusinessType ?? 'company',
          onboardingCompleted: true,
          isOfflineSession: true,
        );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final authResult = await DesktopGoogleOAuth.authenticate(
        clientId: '128675361201-qhb7u121simtqfq3nubaek2nhk0qae2f.apps.googleusercontent.com',
      );
      if (authResult == null) {
        return;
      }

      final client = ref.read(apiClientProvider);
      final body = <String, dynamic>{};
      if (authResult.hasIdToken) {
        body['idToken'] = authResult.idToken;
      } else if (authResult.hasCode) {
        body['code'] = authResult.code;
        body['codeVerifier'] = authResult.codeVerifier;
        body['redirectUri'] = authResult.redirectUri;
        body['clientId'] = authResult.clientId;
      } else {
        throw ApiException(
          statusCode: 400,
          message: 'Failed to retrieve Google credentials from browser.',
          code: 'GOOGLE_CREDENTIALS_MISSING',
        );
      }

      final res = await client.post('/auth/google', body: body);

      final data = res is Map ? (res['data'] ?? res) : {};
      if (data is Map) {
        final user = data['user'] is Map ? data['user'] as Map : {};
        final email = user['email']?.toString() ?? 'google_user@modiri.ai';
        final name = user['name']?.toString();
        await _applyAuthPayload(
          data,
          fallbackEmail: email,
          preferredCompanyName: name != null && name.isNotEmpty
              ? '$name Business'
              : 'Modiri Business',
        );
      }
    } on ApiException catch (e) {
      if (e.code == 'ACCOUNT_EXISTS_WITH_PASSWORD') {
        setState(() => _errorMessage =
            'An account with this email already exists with a password. Please sign in with your email and password.');
      } else if (e.code == 'GOOGLE_CLIENT_SECRET_NOT_CONFIGURED') {
        setState(() => _errorMessage =
            'Google Sign-In is not configured on the backend server: GOOGLE_WINDOWS_CLIENT_SECRET is missing. Please set this environment variable in your backend environment.');
      } else if (e.code == 'NOT_FOUND' || e.statusCode == 404) {
        setState(() => _errorMessage =
            'The backend server has not been updated with Google Sign-In support yet. Please deploy the latest backend update.');
      } else {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (!msg.contains('cancelled') && !msg.contains('canceled')) {
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final activeLocale = ref.watch(desktopLocaleProvider);

    return Scaffold(
      backgroundColor: ModiriColors.canvas(isDark),
      body: ModiriBackground(
        child: Stack(
          children: [
            // Top Right Controls (Theme & Language Switcher)
            PositionedDirectional(
              top: 24,
              end: 24,
              child: Row(
                children: [
                  Tooltip(
                    message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    child: InkWell(
                      onTap: () {
                        ref.read(desktopThemeModeProvider.notifier).toggleTheme();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ModiriColors.border(isDark)),
                        ),
                        child: Icon(
                          isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                          size: 16,
                          color: isDark ? ModiriColors.brandAmber : ModiriColors.brandBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activeLocale.languageCode,
                        dropdownColor: ModiriColors.card(isDark),
                        icon: const Icon(Icons.language,
                            size: 16, color: ModiriColors.brandBlue),
                        style: TextStyle(
                            color: ModiriColors.textPrimary(isDark), fontSize: 12),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('English (EN)',
                                style: TextStyle(
                                    color: ModiriColors.textPrimary(isDark))),
                          ),
                          DropdownMenuItem(
                            value: 'fr',
                            child: Text('Français (FR)',
                                style: TextStyle(
                                    color: ModiriColors.textPrimary(isDark))),
                          ),
                          DropdownMenuItem(
                            value: 'ar',
                            child: Text('العربية (AR)',
                                style: TextStyle(
                                    color: ModiriColors.textPrimary(isDark))),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(desktopLocaleProvider.notifier).state =
                                Locale(val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Centered Auth Card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo & App Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 42,
                              height: 42,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: ModiriColors.brandBlue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.auto_awesome,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'MODIRI ',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: ModiriColors.textPrimary(isDark),
                            ),
                          ),
                          const Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: ModiriColors.brandBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      ModiriPanel(
                        padding: const EdgeInsets.all(32),
                        child: _isVerifyingEmail
                            ? _buildOtpCard(isDark, loc)
                            : (_isRegister
                                ? _buildRegisterCard(isDark, loc, activeLocale)
                                : _buildLoginCard(isDark, loc, activeLocale)),
                      ),

                      const SizedBox(height: 20),

                      // Bottom Mode Switcher (Matching Mobile App)
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isRegister
                                ? loc.get('already_have_account')
                                : loc.get('dont_have_account'),
                            style: TextStyle(
                              color: ModiriColors.textSecondary(isDark),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRegister = !_isRegister;
                                _isVerifyingEmail = false;
                                _errorMessage = null;
                                _infoMessage = null;
                                _passwordController.clear();
                                _confirmPasswordController.clear();
                              });
                            },
                            child: Text(
                              _isRegister
                                  ? loc.get('sign_in_link')
                                  : loc.get('create_one'),
                              style: const TextStyle(
                                color: ModiriColors.brandBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Login View Card (Matching Mobile App LoginScreen)
  Widget _buildLoginCard(bool isDark, ModiriLocalizations loc, Locale activeLocale) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.get('welcome_back'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModiriColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.get('sign_in_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: ModiriColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            _buildErrorBanner(),
            const SizedBox(height: 16),
          ],
          if (_infoMessage != null) ...[
            _buildInfoBanner(),
            const SizedBox(height: 16),
          ],

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => _validateEmail(v, loc),
            style: TextStyle(
              color: ModiriColors.textPrimary(isDark),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: loc.get('email'),
              hintText: 'you@business.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (v) => _validatePassword(v, loc),
            style: TextStyle(
              color: ModiriColors.textPrimary(isDark),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: loc.get('password'),
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: ModiriColors.textMuted(isDark),
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),

          // Remember Me + Forgot Password Row (Matching Mobile App)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: ModiriColors.brandBlue,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Text(
                      loc.get('remember_me'),
                      style: TextStyle(
                        color: ModiriColors.textSecondary(isDark),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  loc.get('forgot_password'),
                  style: const TextStyle(
                    color: ModiriColors.brandBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Login Button
          ElevatedButton(
            onPressed: (_isLoading || _isGoogleLoading) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: ModiriColors.brandBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login, size: 18),
                      const SizedBox(width: 8),
                      Text(loc.get('login')),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // Divider
          _buildDivider(isDark, activeLocale),
          const SizedBox(height: 14),

          // Google Sign-In Button
          GoogleSignInButton(
            isLoading: _isGoogleLoading,
            onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
          ),
        ],
      ),
    );
  }

  /// Register View Card (Matching Mobile App RegisterScreen: Full Name, Email, Password, Confirm Password)
  Widget _buildRegisterCard(bool isDark, ModiriLocalizations loc, Locale activeLocale) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.get('create_business_title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModiriColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.get('create_business_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: ModiriColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            _buildErrorBanner(),
            const SizedBox(height: 16),
          ],
          if (_infoMessage != null) ...[
            _buildInfoBanner(),
            const SizedBox(height: 16),
          ],

          // 1. Full Name (Matching Mobile App)
          TextFormField(
            controller: _nameController,
            validator: (v) => _validateName(v, loc),
            style: TextStyle(
              color: ModiriColors.textPrimary(isDark),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: loc.get('full_name'),
              hintText: loc.get('your_name_hint'),
              prefixIcon: const Icon(Icons.person_outline, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Email (Matching Mobile App)
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => _validateEmail(v, loc),
            style: TextStyle(
              color: ModiriColors.textPrimary(isDark),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: loc.get('email'),
              hintText: 'you@business.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Password (Matching Mobile App)
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (v) => _validatePassword(v, loc),
            style: TextStyle(
              color: ModiriColors.textPrimary(isDark),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: loc.get('password'),
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: ModiriColors.textMuted(isDark),
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Confirm Password (Matching Mobile App)
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            validator: (v) => _validateConfirmPassword(v, loc),
            style: TextStyle(
              color: ModiriColors.textPrimary(isDark),
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: loc.get('confirm_password'),
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  color: ModiriColors.textMuted(isDark),
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),

          // Create Account Button
          ElevatedButton(
            onPressed: (_isLoading || _isGoogleLoading) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: ModiriColors.brandBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_add, size: 18),
                      const SizedBox(width: 8),
                      Text(loc.get('register')),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // Divider
          _buildDivider(isDark, activeLocale),
          const SizedBox(height: 14),

          // Google Sign-In Button
          GoogleSignInButton(
            isLoading: _isGoogleLoading,
            onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
          ),
        ],
      ),
    );
  }

  /// OTP Email Verification Card
  Widget _buildOtpCard(bool isDark, ModiriLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          loc.get('verify_email_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ModiriColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${loc.get('verify_email_subtitle')}\n($_pendingEmail)',
          style: TextStyle(
            fontSize: 13,
            color: ModiriColors.textSecondary(isDark),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null) ...[
          _buildErrorBanner(),
          const SizedBox(height: 14),
        ],
        if (_infoMessage != null) ...[
          _buildInfoBanner(),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: TextStyle(
            color: ModiriColors.textPrimary(isDark),
            fontSize: 16,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: loc.get('verification_code'),
            hintText: '123456',
            counterText: '',
          ),
          onSubmitted: (_) => _verifyOtp(),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _verifyOtp,
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: Text(loc.get('verify_and_continue')),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isLoading ? null : _resendOtp,
              child: Text(loc.get('resend_code')),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _isVerifyingEmail = false;
                        _errorMessage = null;
                        _infoMessage = null;
                      }),
              child: Text(loc.get('sign_in_link')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ModiriColors.brandRose.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ModiriColors.brandRose, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: ModiriColors.brandRose, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ModiriColors.brandTeal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.3)),
      ),
      child: Text(
        _infoMessage!,
        style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 13),
      ),
    );
  }

  Widget _buildDivider(bool isDark, Locale activeLocale) {
    return Row(
      children: [
        Expanded(child: Divider(color: ModiriColors.border(isDark))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            activeLocale.languageCode == 'ar'
                ? 'أو'
                : (activeLocale.languageCode == 'fr' ? 'OU' : 'OR'),
            style: TextStyle(
              color: ModiriColors.textMuted(isDark),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: ModiriColors.border(isDark))),
      ],
    );
  }
}
