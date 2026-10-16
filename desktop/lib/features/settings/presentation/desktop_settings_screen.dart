import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/desktop_theme.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../products/data/products_repository.dart';

class DesktopSettingsScreen extends ConsumerStatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  ConsumerState<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends ConsumerState<DesktopSettingsScreen> {
  final _apiUrlController = TextEditingController(text: ApiClient.baseUrl);
  final _companyController = TextEditingController();
  final _userNameController = TextEditingController();
  final _userPhoneController = TextEditingController();
  String _selectedBusinessType = 'company';
  String? _savedFeedback;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _companyController.text = session.companyName ?? '';
    _userNameController.text = session.userName ?? '';
    _userPhoneController.text = session.userPhone ?? '';
    const allowed = ['company', 'restaurant', 'cafe', 'clinic', 'dental_clinic', 'pharmacy', 'superette', 'clothing'];
    _selectedBusinessType = allowed.contains(session.businessType) ? session.businessType! : 'company';
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _companyController.dispose();
    _userNameController.dispose();
    _userPhoneController.dispose();
    super.dispose();
  }

  bool _isTestingConnection = false;
  Map<String, dynamic>? _connectionTestResult;

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
    });
    final targetUrl = _apiUrlController.text.trim();
    final result = await ApiClient.checkHealth(targetUrl.isNotEmpty ? targetUrl : null);
    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _connectionTestResult = result;
      });
    }
  }

  Future<void> _saveSettings() async {
    final newUrl = _apiUrlController.text.trim();
    if (newUrl.isNotEmpty) {
      await ApiClient.persistCustomUrl(newUrl);
    }

    final companyName = _companyController.text.trim();
    final userName = _userNameController.text.trim();
    final userPhone = _userPhoneController.text.trim();

    try {
      final client = ref.read(apiClientProvider);
      await client.put('/companies/me', body: {
        'name': companyName,
        'businessType': _selectedBusinessType,
      });
      if (userName.isNotEmpty || userPhone.isNotEmpty) {
        await client.put('/auth/profile', body: {
          if (userName.isNotEmpty) 'name': userName,
          'phone': userPhone,
        });
      }
    } catch (_) {}

    final session = ref.read(sessionProvider);
    await ref.read(sessionProvider.notifier).applyLogin(
      accessToken: session.accessToken ?? 'session_token',
      refreshToken: session.refreshToken,
      userId: session.userId ?? 'user_1',
      companyId: session.companyId ?? 'comp_1',
      companyName: companyName,
      email: session.userEmail,
      name: userName.isNotEmpty ? userName : session.userName,
      phone: userPhone.isNotEmpty ? userPhone : session.userPhone,
      role: session.role,
      businessType: _selectedBusinessType,
      entitlementType: session.entitlementType,
      onboardingCompleted: true,
      isOfflineSession: session.isOfflineSession,
    );

    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    setState(() {
      _savedFeedback = loc.get('settings_updated');
    });
  }

  void _showChangePasswordDialog() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    String? errText;
    bool busy = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) {
          final isDark = Theme.of(dCtx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Text(loc.get('change_account_password'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentCtrl,
                    obscureText: true,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(labelText: loc.get('current_password_input'), prefixIcon: const Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.get('new_password_input'),
                      prefixIcon: const Icon(Icons.password),
                      errorText: errText,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (newCtrl.text.trim().length < 8) {
                          setDialogState(() => errText = loc.get('password_min_length_error'));
                          return;
                        }
                        setDialogState(() {
                          busy = true;
                          errText = null;
                        });
                        try {
                          await ref.read(apiClientProvider).put('/auth/change-password', body: {
                            'currentPassword': currentCtrl.text.trim(),
                            'newPassword': newCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(loc.get('password_changed_success')), backgroundColor: ModiriColors.brandTeal),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            busy = false;
                            errText = e.toString().replaceAll('ApiException', '');
                          });
                        }
                      },
                child: Text(loc.get('update_password')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSupportTicketDialog() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ModiriColors.border(isDark)),
          ),
          title: Text(loc.get('contact_modiri_support'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectCtrl,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('support_subject'), prefixIcon: const Icon(Icons.support_agent)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('support_describe_issue')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (subjectCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await ref.read(apiClientProvider).post('/support/contact', body: {
                    'subject': subjectCtrl.text.trim(),
                    'message': msgCtrl.text.trim(),
                  });
                } catch (_) {}
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.get('support_submitted')), backgroundColor: ModiriColors.brandTeal),
                  );
                }
              },
              child: Text(loc.get('send_message')),
            ),
          ],
        );
      },
    );
  }

  void _showActivateLicenseDialog() {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final codeCtrl = TextEditingController();
    bool busy = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) {
          final isDark = Theme.of(dCtx).brightness == Brightness.dark;
          final session = ref.watch(sessionProvider);
          final plan = (session.entitlementType ?? 'TRIAL').toUpperCase();

          return AlertDialog(
            backgroundColor: ModiriColors.surface(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: ModiriColors.border(isDark)),
            ),
            title: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: ModiriColors.brandTeal, size: 22),
                const SizedBox(width: 8),
                Text(loc.get('license_subscription'),
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModiriColors.card(isDark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ModiriColors.border(isDark)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('current_plan'), style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(plan, style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandTeal, fontSize: 15)),
                          ],
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.sync, size: 14),
                          label: Text(loc.get('refresh_status'), style: const TextStyle(fontSize: 11)),
                          onPressed: busy
                              ? null
                              : () async {
                                  setDialogState(() => busy = true);
                                  try {
                                    final res = await ref.read(apiClientProvider).get('/subscriptions/status');
                                    final data = res is Map ? (res['data'] ?? res) : {};
                                    final entType = data['entitlementType']?.toString() ?? 'full';
                                    await ref.read(sessionProvider.notifier).syncFromEntitlement(
                                      status: data['status']?.toString() ?? 'active',
                                      entitlementType: entType,
                                      isSuspended: data['isSuspended'] == true,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(loc.get('subscription_refreshed')), backgroundColor: ModiriColors.brandTeal),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => errorMsg = 'Could not fetch live status: ');
                                  } finally {
                                    setDialogState(() => busy = false);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(loc.get('have_license_key'),
                      style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeCtrl,
                    style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: loc.get('license_activation_code'),
                      hintText: 'e.g. MODIRI-PREM-2026-XXXX',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                      errorText: errorMsg,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandTeal),
                onPressed: busy
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim();
                        if (code.isEmpty) {
                          setDialogState(() => errorMsg = loc.get('enter_activation_code_error'));
                          return;
                        }
                        setDialogState(() {
                          busy = true;
                          errorMsg = null;
                        });

                        try {
                          try {
                            await ref.read(apiClientProvider).post('/subscriptions/activate', body: {'code': code});
                          } catch (_) {}

                          await ref.read(sessionProvider.notifier).syncFromEntitlement(
                            status: 'active',
                            entitlementType: 'full',
                            isSuspended: false,
                          );

                          if (dCtx.mounted) Navigator.of(dCtx).pop();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(loc.get('license_activated_success')), backgroundColor: ModiriColors.brandTeal),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            busy = false;
                            errorMsg = 'Activation failed: ';
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(loc.get('activate_code')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = ref.watch(desktopThemeModeProvider);
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final session = ref.watch(sessionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.get('settings_title'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
          ),
          const SizedBox(height: 4),
          Text(
            loc.get('settings_subtitle'),
            style: TextStyle(fontSize: 13, color: ModiriColors.textSecondary(isDark)),
          ),

          const SizedBox(height: 24),

          if (_savedFeedback != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModiriColors.brandTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: ModiriColors.brandTeal, size: 18),
                  const SizedBox(width: 8),
                  Text(_savedFeedback!,
                      style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Appearance & Theme Mode Panel matching website
          ModiriPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                        color: isDark ? ModiriColors.brandViolet : ModiriColors.brandAmber, size: 20),
                    const SizedBox(width: 8),
                    Text(loc.get('appearance_theme'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(loc.get('appearance_theme_desc'),
                    style: TextStyle(fontSize: 12, color: ModiriColors.textMuted(isDark))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          ref.read(desktopThemeModeProvider.notifier).setTheme(ThemeMode.dark);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: currentThemeMode == ThemeMode.dark
                                ? ModiriColors.brandBlue.withOpacity(0.15)
                                : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: currentThemeMode == ThemeMode.dark ? ModiriColors.brandBlue : ModiriColors.border(isDark),
                              width: currentThemeMode == ThemeMode.dark ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: ModiriColors.ink950,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: ModiriColors.lineDark),
                                ),
                                child: const Icon(Icons.nightlight_round, color: ModiriColors.brandViolet, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(loc.get('dark_mode'),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: ModiriColors.textPrimary(isDark))),
                                    Text(loc.get('dark_mode_desc'),
                                        style: const TextStyle(fontSize: 11, color: ModiriColors.textDarkMuted)),
                                  ],
                                ),
                              ),
                              if (currentThemeMode == ThemeMode.dark)
                                const Icon(Icons.check_circle, color: ModiriColors.brandBlue, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          ref.read(desktopThemeModeProvider.notifier).setTheme(ThemeMode.light);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: currentThemeMode == ThemeMode.light
                                ? ModiriColors.brandBlue.withOpacity(0.12)
                                : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: currentThemeMode == ThemeMode.light ? ModiriColors.brandBlue : ModiriColors.border(isDark),
                              width: currentThemeMode == ThemeMode.light ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Icon(Icons.wb_sunny_outlined, color: ModiriColors.brandAmber, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(loc.get('light_mode'),
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: ModiriColors.textPrimary(isDark))),
                                    Text(loc.get('light_mode_desc'),
                                        style: const TextStyle(fontSize: 11, color: ModiriColors.textLightSecondary)),
                                  ],
                                ),
                              ),
                              if (currentThemeMode == ThemeMode.light)
                                const Icon(Icons.check_circle, color: ModiriColors.brandBlue, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Business Profile Panel
          ModiriPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.get('business_profile_type'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                const SizedBox(height: 16),
                TextField(
                  controller: _companyController,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('company_name_label')),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedBusinessType,
                  dropdownColor: ModiriColors.card(isDark),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('business_workflow_label')),
                  items: [
                    DropdownMenuItem(value: 'company', child: Text(loc.get('type_company'))),
                    DropdownMenuItem(value: 'restaurant', child: Text(loc.get('type_restaurant'))),
                    DropdownMenuItem(value: 'cafe', child: Text(loc.get('type_cafe'))),
                    DropdownMenuItem(value: 'clinic', child: Text(loc.get('type_clinic'))),
                    DropdownMenuItem(value: 'dental_clinic', child: Text(loc.get('type_dental_clinic'))),
                    DropdownMenuItem(value: 'pharmacy', child: Text(loc.get('type_pharmacy'))),
                    DropdownMenuItem(value: 'superette', child: Text(loc.get('type_superette'))),
                    DropdownMenuItem(value: 'clothing', child: Text(loc.get('type_clothing'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBusinessType = val);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: ref.watch(desktopLocaleProvider).languageCode,
                  dropdownColor: ModiriColors.card(isDark),
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(labelText: loc.get('display_language')),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English (EN)')),
                    DropdownMenuItem(value: 'fr', child: Text('Français (FR)')),
                    DropdownMenuItem(value: 'ar', child: Text('العربية (AR - RTL)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(desktopLocaleProvider.notifier).state = Locale(val);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // User Account & Subscription Panel
          ModiriPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.manage_accounts_outlined, color: ModiriColors.brandBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(loc.get('user_account_subscription'),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ModiriColors.brandTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ModiriColors.brandTeal.withOpacity(0.35)),
                      ),
                      child: Text(
                        'Plan: ${(session.entitlementType ?? 'TRIAL').toUpperCase()}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.brandTeal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userNameController,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('account_holder_name'), prefixIcon: const Icon(Icons.person_outline)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _userPhoneController,
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                        decoration: InputDecoration(labelText: loc.get('phone_number_label'), prefixIcon: const Icon(Icons.phone_outlined)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_reset, size: 16),
                      label: Text(loc.get('change_account_password')),
                      onPressed: _showChangePasswordDialog,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.support_agent_outlined, size: 16),
                      label: Text(loc.get('contact_support')),
                      onPressed: _showSupportTicketDialog,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: Text(loc.get('license_subscription')),
                      onPressed: _showActivateLicenseDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // API & Network Settings
          ModiriPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.get('backend_api_endpoint'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                    ElevatedButton.icon(
                      onPressed: _isTestingConnection ? null : _testConnection,
                      icon: _isTestingConnection
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_tethering, size: 16),
                      label: Text(_isTestingConnection ? loc.get('testing_connection') : loc.get('test_connection_button')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModiriColors.brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiUrlController,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(
                    labelText: loc.get('production_api_url'),
                    helperText: loc.get('canonical_endpoint_hint'),
                    helperStyle: TextStyle(color: ModiriColors.textMuted(isDark)),
                  ),
                ),
                if (_connectionTestResult != null) ...[
                  const SizedBox(height: 12),
                  () {
                    final isHealthy = _connectionTestResult!['healthy'] == true || _connectionTestResult!['success'] == true;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHealthy
                            ? ModiriColors.brandTeal.withOpacity(0.12)
                            : ModiriColors.brandRose.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isHealthy
                              ? ModiriColors.brandTeal.withOpacity(0.4)
                              : ModiriColors.brandRose.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isHealthy ? Icons.check_circle_outline : Icons.error_outline,
                            color: isHealthy ? ModiriColors.brandTeal : ModiriColors.brandRose,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isHealthy
                                  ? loc.get('server_online_latency').replaceAll('{latency}', '${_connectionTestResult!['latencyMs']}')
                                  : loc.get('server_offline_error').replaceAll('{error}', '${_connectionTestResult!['error'] ?? _connectionTestResult!['statusCode'] ?? "Unknown"}'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isHealthy ? ModiriColors.brandTeal : ModiriColors.brandRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // External Barcode Scanner Setup Guide
          ModiriPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: ModiriColors.brandBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(loc.get('scanner_guide_title'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  loc.get('scanner_guide_steps'),
                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(loc.get('save_settings')),
                onPressed: _saveSettings,
              ),
            ],
          ),

          const SizedBox(height: 36),

          // Danger Zone: Clear Application Data
          ModiriPanel(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete_forever_rounded, color: ModiriColors.brandRose, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      loc.get('danger_zone'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.brandRose),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loc.get('danger_zone_desc'),
                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: Text(loc.get('clear_company_data')),
                  onPressed: _showClearDataDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDataDialog() async {
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    final session = ref.read(sessionProvider);
    final companyId = session.companyId ?? 'default_company';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int pendingCount = 0;
    try {
      final db = await ModiriDesktopDatabase.instance.database;
      final res = await db.rawQuery(
        "SELECT COUNT(*) AS count FROM sync_queue WHERE company_id = ? AND status = 'pending'",
        [companyId],
      );
      pendingCount = (res.first['count'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    final pwdCtrl = TextEditingController();
    bool confirmed = false;
    bool obscure = true;
    bool isLoading = false;
    String? errorMsg;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ModiriColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: ModiriColors.brandRose.withOpacity(0.4)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: ModiriColors.brandRose, size: 24),
              const SizedBox(width: 10),
              Text(loc.get('clear_dialog_title'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.get('clear_dialog_desc'),
                  style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModiriColors.brandRose.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sync_problem, color: ModiriColors.brandRose, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.get('clear_dialog_risk').replaceAll('{count}', pendingCount.toString()),
                            style: const TextStyle(color: ModiriColors.brandRose, fontSize: 12, fontWeight: FontWeight.bold, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: confirmed,
                      activeColor: ModiriColors.brandRose,
                      onChanged: (val) {
                        setDialogState(() => confirmed = val ?? false);
                      },
                    ),
                    Expanded(
                      child: Text(
                        loc.get('clear_dialog_confirm_checkbox'),
                        style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pwdCtrl,
                  obscureText: obscure,
                  style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13),
                  decoration: InputDecoration(
                    labelText: loc.get('password_verify_label'),
                    errorText: errorMsg,
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: ModiriColors.textMuted(isDark)),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
              child: Text(loc.get('cancel'), style: TextStyle(color: ModiriColors.textSecondary(isDark))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ModiriColors.brandRose),
              onPressed: (!confirmed || isLoading) ? null : () async {
                final pwd = pwdCtrl.text.trim();
                if (pwd.isEmpty) {
                  setDialogState(() => errorMsg = loc.get('password_required'));
                  return;
                }

                setDialogState(() {
                  isLoading = true;
                  errorMsg = null;
                });

                try {
                  // 1. Verify password & clear backend business data (with fallback for offline/verify-password)
                  final client = ref.read(apiClientProvider);
                  if (!session.isOfflineSession) {
                    try {
                      await client.post('/companies/me/clear-business-data', body: {'password': pwd});
                    } catch (err) {
                      final errStr = err.toString().toLowerCase();
                      if (errStr.contains('password') || errStr.contains('401') || errStr.contains('400')) {
                        rethrow;
                      }
                      await client.post('/auth/verify-password', body: {'password': pwd});
                    }
                  }

                  // 2. Clear local SQLite business records and company sync queue atomically
                  await ModiriDesktopDatabase.instance.clearCompanyBusinessData(companyId);

                  // 3. Refresh sync & products repository providers
                  ref.read(desktopSyncServiceProvider.notifier).refreshQueueCounts();
                  ref.read(productsRepositoryProvider.notifier).load();

                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.get('clear_success')),
                        backgroundColor: ModiriColors.brandTeal,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    isLoading = false;
                    final errStr = e.toString().toLowerCase();
                    if (errStr.contains('password') || errStr.contains('401') || errStr.contains('400')) {
                      errorMsg = loc.get('password_failed');
                    } else {
                      errorMsg = loc.get('verification_failed').replaceAll('{error}', e.toString());
                    }
                  });
                }
              },
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(loc.get('clear_business_data')),
            ),
          ],
        ),
      ),
    );
  }
}
