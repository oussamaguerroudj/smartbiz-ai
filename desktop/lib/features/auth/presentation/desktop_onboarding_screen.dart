import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modiri_background.dart';
import '../../../core/widgets/modiri_panel.dart';

class DesktopOnboardingScreen extends ConsumerStatefulWidget {
  const DesktopOnboardingScreen({super.key});

  @override
  ConsumerState<DesktopOnboardingScreen> createState() => _DesktopOnboardingScreenState();
}

class _BusinessOption {
  final String key;
  final String labelKey;
  final String descKey;
  final IconData icon;

  const _BusinessOption({
    required this.key,
    required this.labelKey,
    required this.descKey,
    required this.icon,
  });
}

const List<_BusinessOption> _kBusinessOptions = [
  _BusinessOption(
    key: 'grocery',
    labelKey: 'type_superette',
    descKey: 'desc_superette',
    icon: Icons.storefront_outlined,
  ),
  _BusinessOption(
    key: 'clothing',
    labelKey: 'type_clothing',
    descKey: 'desc_clothing',
    icon: Icons.checkroom_outlined,
  ),
  _BusinessOption(
    key: 'restaurant',
    labelKey: 'type_restaurant',
    descKey: 'desc_restaurant',
    icon: Icons.restaurant_outlined,
  ),
  _BusinessOption(
    key: 'clinic',
    labelKey: 'type_clinic',
    descKey: 'desc_clinic',
    icon: Icons.medical_services_outlined,
  ),
  _BusinessOption(
    key: 'pharmacy',
    labelKey: 'type_pharmacy',
    descKey: 'desc_pharmacy',
    icon: Icons.local_pharmacy_outlined,
  ),
  _BusinessOption(
    key: 'company',
    labelKey: 'type_company',
    descKey: 'desc_company',
    icon: Icons.business_outlined,
  ),
];

class _DesktopOnboardingScreenState extends ConsumerState<DesktopOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _currencyController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  String _selectedBusinessType = 'grocery';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    final initialName = (session.companyName != null && session.companyName!.isNotEmpty && session.companyName != 'Modiri Business')
        ? session.companyName!
        : ((session.userName != null && session.userName!.isNotEmpty)
            ? '${session.userName} Business'
            : 'Modiri Business');

    _nameController = TextEditingController(text: initialName);
    _currencyController = TextEditingController(text: 'DZD');
    _phoneController = TextEditingController(text: session.userPhone ?? '');
    _addressController = TextEditingController();

    if (session.businessType != null &&
        _kBusinessOptions.any((opt) => opt.key == session.businessType)) {
      _selectedBusinessType = session.businessType!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currencyController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final companyName = _nameController.text.trim();
      final currency = _currencyController.text.trim().isNotEmpty
          ? _currencyController.text.trim()
          : 'DZD';
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();

      await client.put('/companies/me', body: {
        'name': companyName,
        'businessType': _selectedBusinessType,
        'currency': currency,
        if (phone.isNotEmpty) 'phone': phone,
        if (address.isNotEmpty) 'address': address,
        'onboardingCompleted': true,
      });

      await ref.read(sessionProvider.notifier).updateBusinessType(
            _selectedBusinessType,
            companyName: companyName,
          );

      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        unawaited(() async {
          await ref.read(desktopSyncServiceProvider.notifier).syncPending();
          await ref.read(desktopSyncServiceProvider.notifier).pullInitialData();
        }());
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: ModiriColors.canvas(isDark),
      body: ModiriBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ModiriPanel(
                  padding: const EdgeInsets.all(36),
                  borderRadius: BorderRadius.circular(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: ModiriColors.brandTeal.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: ModiriColors.brandTeal.withOpacity(0.3),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.rocket_launch_outlined,
                                          color: ModiriColors.brandTeal,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              loc.get('onboarding_welcome'),
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: ModiriColors.textPrimary(isDark),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              loc.get('onboarding_subtitle'),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: ModiriColors.textSecondary(isDark),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // User badge and logout
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (session.userEmail != null) ...[
                                  Text(
                                    session.userEmail!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ModiriColors.textMuted(isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                TextButton.icon(
                                  onPressed: () => ref.read(sessionProvider.notifier).logout(),
                                  icon: const Icon(Icons.logout, size: 16),
                                  label: Text(loc.get('logout')),
                                  style: TextButton.styleFrom(
                                    foregroundColor: ModiriColors.textMuted(isDark),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Error Banner if present
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF43F5E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF43F5E).withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFF43F5E), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFF43F5E),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Step 1: Business Type Selection
                        Text(
                          loc.get('choose_business_vertical'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ModiriColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loc.get('choose_business_vertical_desc'),
                          style: TextStyle(
                            fontSize: 12,
                            color: ModiriColors.textMuted(isDark),
                          ),
                        ),
                        const SizedBox(height: 16),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 580 ? 3 : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.45,
                              ),
                              itemCount: _kBusinessOptions.length,
                              itemBuilder: (context, index) {
                                final opt = _kBusinessOptions[index];
                                final isSelected = _selectedBusinessType == opt.key;
                                final label = loc.get(opt.labelKey);

                                return InkWell(
                                  onTap: () {
                                    setState(() => _selectedBusinessType = opt.key);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? ModiriColors.brandTeal.withOpacity(isDark ? 0.16 : 0.08)
                                          : (isDark
                                              ? const Color(0xFF1E293B).withOpacity(0.5)
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? ModiriColors.brandTeal
                                            : (isDark
                                                ? ModiriColors.lineDark
                                                : ModiriColors.lineLight),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: ModiriColors.brandTeal.withOpacity(0.2),
                                                blurRadius: 12,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? ModiriColors.brandTeal.withOpacity(0.25)
                                                    : (isDark
                                                        ? Colors.white10
                                                        : const Color(0xFFF1F5F9)),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                opt.icon,
                                                size: 20,
                                                color: isSelected
                                                    ? ModiriColors.brandTeal
                                                    : ModiriColors.textPrimary(isDark),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (isSelected)
                                              const Icon(
                                                Icons.check_circle,
                                                size: 18,
                                                color: ModiriColors.brandTeal,
                                              ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? ModiriColors.brandTeal
                                                : ModiriColors.textPrimary(isDark),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          loc.get(opt.descKey),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ModiriColors.textMuted(isDark),
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 28),

                        // Step 2: Business Profile Information
                        Text(
                          loc.get('business_profile_details'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ModiriColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nameController,
                                style: TextStyle(
                                  color: ModiriColors.textPrimary(isDark),
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.get('company_name_label'),
                                  prefixIcon: const Icon(Icons.business_outlined, size: 18),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().length < 2) {
                                    return loc.get('business_name_min_chars');
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _currencyController,
                                style: TextStyle(
                                  color: ModiriColors.textPrimary(isDark),
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.get('currency'),
                                  prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return loc.get('required');
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                style: TextStyle(
                                  color: ModiriColors.textPrimary(isDark),
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.get('phone'),
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _addressController,
                                style: TextStyle(
                                  color: ModiriColors.textPrimary(isDark),
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: loc.get('address'),
                                  prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ModiriColors.brandTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        loc.get('complete_setup_button'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
