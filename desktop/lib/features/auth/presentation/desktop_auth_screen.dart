import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/desktop_theme.dart';
import '../../../core/widgets/modiri_background.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopAuthScreen extends ConsumerStatefulWidget {
  const DesktopAuthScreen({super.key});

  @override
  ConsumerState<DesktopAuthScreen> createState() => _DesktopAuthScreenState();
}

class _DesktopAuthScreenState extends ConsumerState<DesktopAuthScreen> {
  bool _isRegister = false;
  bool _isVerifyingEmail = false;
  bool _obscurePassword = true;
  String _pendingEmail = '';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _otpController = TextEditingController();
  String _selectedBusinessType = 'company';

  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _applyAuthPayload(
    Map<dynamic, dynamic> data, {
    required String fallbackEmail,
    String? preferredCompanyName,
    String? preferredBusinessType,
    bool syncCompanyProfile = false,
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
    var businessType = (company['businessType'] ??
            company['business_type'] ??
            user['businessType'] ??
            user['business_type'] ??
            preferredBusinessType ??
            'company')
        .toString();
    final entitlementType =
        (company['entitlementType'] ?? company['entitlement_type'] ?? 'trial')
            .toString();
    final onboardingCompleted = company['onboardingCompleted'] != false;

    if (preferredCompanyName != null && preferredCompanyName.isNotEmpty) {
      companyName = preferredCompanyName;
    }
    if (preferredBusinessType != null && preferredBusinessType.isNotEmpty) {
      businessType = preferredBusinessType;
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
          onboardingCompleted: true,
        );

    if (syncCompanyProfile && token.isNotEmpty) {
      try {
        final client = ref.read(apiClientProvider);
        await client.put('/companies/me', body: {
          'name': companyName,
          'businessType': businessType,
          'onboardingCompleted': true,
        });
      } catch (_) {}
    } else if (!onboardingCompleted && token.isNotEmpty) {
      try {
        final client = ref.read(apiClientProvider);
        await client.put('/companies/me', body: {
          'name': companyName,
          'businessType': businessType,
          'onboardingCompleted': true,
        });
      } catch (_) {}
    }
  }

  Future<void> _submit() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = loc.get('auth_validation_required'));
      return;
    }

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
            preferredCompanyName: _companyController.text.trim().isNotEmpty
                ? _companyController.text.trim()
                : '$fullName Business',
            preferredBusinessType: _selectedBusinessType,
            syncCompanyProfile: true,
          );
        }
      } else {
        final res = await client.post('/auth/login', body: {
          'email': email,
          'password': password,
        });

        final data = res is Map ? (res['data'] ?? res) : {};
        if (data is Map) {
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
      setState(() => _errorMessage =
          loc.get('connection_failed_offline_hint'));
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
          preferredCompanyName: _companyController.text.trim().isNotEmpty
              ? _companyController.text.trim()
              : '$fullName Business',
          preferredBusinessType: _selectedBusinessType,
          syncCompanyProfile: true,
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

  Future<void> _showForgotPasswordDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final codeCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    bool codeSent = false;
    bool busy = false;
    String? dialogError;
    String? dialogInfo;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Text(
            loc.get('reset_password'),
            style: TextStyle(
              color: ModiriColors.textPrimary(isDark),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandRose.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(color: ModiriColors.brandRose, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (dialogInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dialogInfo!,
                      style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: emailCtrl,
                  enabled: !codeSent,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('email')),
                ),
                if (codeSent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: loc.get('verification_code')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPwdCtrl,
                    obscureText: true,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: loc.get('new_password')),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'),
                  style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) {
                        setDialogState(() => dialogError = 'Email is required.');
                        return;
                      }
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
      final storage = FlutterSecureStorage();
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
    final companyName = _companyController.text.trim().isNotEmpty
        ? _companyController.text.trim()
        : (savedCompanyName ?? 'Modiri Local Business');

    await ref.read(sessionProvider.notifier).applyLogin(
          accessToken: 'local_offline_${DateTime.now().millisecondsSinceEpoch}',
          userId: savedUserId ?? 'local_user_1',
          companyId: (savedCompanyId != null && savedCompanyId.isNotEmpty) ? savedCompanyId : 'comp_1',
          companyName: companyName,
          email: email,
          name: name,
          role: existing.role ?? 'owner',
          businessType: savedBusinessType ?? _selectedBusinessType,
        );
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
            // Top Right Controls matching website AuthLayout.jsx
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
                            ? Column(
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: ModiriColors.brandRose
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: ModiriColors.brandRose
                                                .withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                            color: ModiriColors.brandRose,
                                            fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  if (_infoMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: ModiriColors.brandTeal
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: ModiriColors.brandTeal
                                                .withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _infoMessage!,
                                        style: const TextStyle(
                                            color: ModiriColors.brandTeal,
                                            fontSize: 13),
                                      ),
                                    ),
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
                                    icon: const Icon(Icons.verified_outlined,
                                        size: 18),
                                    label: Text(loc.get('verify_and_continue')),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed:
                                            _isLoading ? null : _resendOtp,
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
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isRegister
                                        ? loc.get('create_business_title')
                                        : loc.get('welcome_back'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: ModiriColors.textPrimary(isDark),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isRegister
                                        ? loc.get('create_business_subtitle')
                                        : loc.get('sign_in_subtitle'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: ModiriColors.textSecondary(isDark),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: ModiriColors.brandRose
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: ModiriColors.brandRose
                                                .withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: ModiriColors.brandRose,
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(
                                                  color: ModiriColors.brandRose,
                                                  fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_infoMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: ModiriColors.brandTeal
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: ModiriColors.brandTeal
                                                .withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _infoMessage!,
                                        style: const TextStyle(
                                            color: ModiriColors.brandTeal,
                                            fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_isRegister) ...[
                                    TextField(
                                      controller: _nameController,
                                      style: TextStyle(
                                          color:
                                              ModiriColors.textPrimary(isDark),
                                          fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: loc.get('full_name'),
                                        hintText: 'Sarah Connor',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _companyController,
                                      style: TextStyle(
                                          color:
                                              ModiriColors.textPrimary(isDark),
                                          fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText:
                                            loc.get('company_name_label'),
                                        hintText: 'Apex Supermarket',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      value: _selectedBusinessType,
                                      dropdownColor: ModiriColors.card(isDark),
                                      style: TextStyle(
                                          color:
                                              ModiriColors.textPrimary(isDark),
                                          fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: loc.get('business_type'),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'superette',
                                            child: Text(
                                                loc.get('type_superette'))),
                                        DropdownMenuItem(
                                            value: 'restaurant',
                                            child: Text(
                                                loc.get('type_restaurant'))),
                                        DropdownMenuItem(
                                            value: 'cafe',
                                            child: Text(loc.get('type_cafe'))),
                                        DropdownMenuItem(
                                            value: 'clinic',
                                            child:
                                                Text(loc.get('type_clinic'))),
                                        DropdownMenuItem(
                                            value: 'dental_clinic',
                                            child: Text(
                                                loc.get('type_dental_clinic'))),
                                        DropdownMenuItem(
                                            value: 'pharmacy',
                                            child:
                                                Text(loc.get('type_pharmacy'))),
                                        DropdownMenuItem(
                                            value: 'clothing',
                                            child:
                                                Text(loc.get('type_clothing'))),
                                        DropdownMenuItem(
                                            value: 'company',
                                            child:
                                                Text(loc.get('type_company'))),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() =>
                                              _selectedBusinessType = val);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(
                                        color: ModiriColors.textPrimary(isDark),
                                        fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: loc.get('email'),
                                      hintText: 'admin@company.com',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: TextStyle(
                                        color: ModiriColors.textPrimary(isDark),
                                        fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: loc.get('password'),
                                      hintText: '••••••••',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: ModiriColors.textMuted(isDark),
                                          size: 18,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                  if (!_isRegister) ...[
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: TextButton(
                                        onPressed: _showForgotPasswordDialog,
                                        child: Text(
                                          loc.get('forgot_password'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ModiriColors.brandBlue,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                  _isRegister
                                                      ? Icons.person_add
                                                      : Icons.login,
                                                  size: 18),
                                              const SizedBox(width: 8),
                                              Text(_isRegister
                                                  ? loc.get('register')
                                                  : loc.get('login')),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ModiriColors.brandTeal,
                                      side: const BorderSide(
                                          color: ModiriColors.brandTeal),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.cloud_off, size: 16),
                                    label: Text(loc.get('work_offline')),
                                    onPressed: _continueOffline,
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 20),
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
                                fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRegister = !_isRegister;
                                _isVerifyingEmail = false;
                                _errorMessage = null;
                                _infoMessage = null;
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
}
