import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/companies_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _businessFormKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarUrlController;

  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  late TextEditingController _businessNameController;
  late TextEditingController _currencyController;
  late TextEditingController _businessPhoneController;
  late TextEditingController _businessAddressController;
  String _selectedBusinessType = 'retail_store';

  bool _isLoadingProfile = false;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _isSavingBusiness = false;
  bool _isDeletingAccount = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _nameController = TextEditingController(text: session.userName ?? '');
    _emailController = TextEditingController(text: session.email ?? '');
    _phoneController = TextEditingController(text: session.phone ?? '');
    _avatarUrlController = TextEditingController(text: session.avatarUrl ?? '');

    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _businessNameController = TextEditingController();
    _currencyController = TextEditingController(text: 'DZD');
    _businessPhoneController = TextEditingController();
    _businessAddressController = TextEditingController();

    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _businessNameController.dispose();
    _currencyController.dispose();
    _businessPhoneController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await ref.read(authRepositoryProvider).getProfile();
      final user = profile['user'] as Map<String, dynamic>;
      final company = profile['company'] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _nameController.text = (user['name'] as String?) ?? '';
          _emailController.text = (user['email'] as String?) ?? '';
          _phoneController.text = (user['phone'] as String?) ?? '';
          _avatarUrlController.text = (user['avatarUrl'] as String?) ?? '';

          _businessNameController.text = (company['name'] as String?) ?? '';
          _currencyController.text = (company['currency'] as String?) ?? 'DZD';
          _selectedBusinessType = (company['businessType'] as String?) ?? 'retail_store';
          _businessPhoneController.text = (company['phone'] as String?) ?? '';
          _businessAddressController.text = (company['address'] as String?) ?? '';
        });
      }
    } catch (_) {
      // Fall back to session values if GET fails
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _pickAvatarImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _avatarUrlController.text = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            avatarUrl: _avatarUrlController.text.trim(),
          );
      ref.invalidate(companyInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdatedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorUpdatingProfile(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.passwordsDoNotMatch)),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.passwordChangedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorChangingPassword(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _saveBusiness() async {
    if (!_businessFormKey.currentState!.validate()) return;

    setState(() => _isSavingBusiness = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(companiesRepositoryProvider).updateMe(
            name: _businessNameController.text.trim(),
            businessType: _selectedBusinessType,
            currency: _currencyController.text.trim(),
            phone: _businessPhoneController.text.trim(),
            address: _businessAddressController.text.trim(),
          );
      ref.invalidate(companyInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.businessInfoUpdatedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorUpdatingBusiness(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBusiness = false);
    }
  }

  void _confirmDeleteAccount() {
    final passwordConfirmController = TextEditingController();
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        title: Text(l10n.deleteAccountPermanently, style: const TextStyle(color: AppColors.danger)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deleteAccountWarning,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: passwordConfirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.enterPasswordToConfirm,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final pwd = passwordConfirmController.text;
              if (pwd.isEmpty) return;
              Navigator.of(dialogCtx).pop();

              setState(() => _isDeletingAccount = true);
              try {
                await ref.read(authRepositoryProvider).deleteAccount(password: pwd);
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.accountDeletionFailed(e.toString()))),
                  );
                }
              } finally {
                if (mounted) setState(() => _isDeletingAccount = false);
              }
            },
            child: Text(l10n.deletePermanentlyAction, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.businessProfileTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.businessProfileTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. Personal Profile Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            l10n.personalProfileTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: _avatarUrlController.text.isNotEmpty
                                ? NetworkImage(_avatarUrlController.text) as ImageProvider
                                : null,
                            child: _avatarUrlController.text.isEmpty
                                ? const Icon(Icons.person, size: 42, color: AppColors.primary)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickAvatarImage,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.fullName,
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? l10n.nameRequired : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || !val.contains('@') ? l10n.emailInvalid : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: l10n.phoneNumber,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        icon: _isSavingProfile
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(l10n.saveProfile),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Business Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _businessFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            l10n.businessInfoTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(
                        labelText: l10n.businessName,
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? l10n.businessNameRequired : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedBusinessType,
                      decoration: InputDecoration(
                        labelText: l10n.businessTypeLabel,
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'clothing', child: Text(l10n.businessTypeClothing, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'grocery', child: Text(l10n.businessTypeGrocery, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'pharmacy', child: Text(l10n.businessTypePharmacy, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'clinic', child: Text(l10n.businessTypeClinic, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'restaurant', child: Text(l10n.businessTypeRestaurant, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'retail_store', child: Text(l10n.businessTypeRetail, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'company', child: Text(l10n.businessTypeCompany, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBusinessType = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _currencyController,
                      decoration: InputDecoration(
                        labelText: l10n.currency,
                        prefixIcon: const Icon(Icons.attach_money_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _businessPhoneController,
                      decoration: InputDecoration(
                        labelText: l10n.businessPhoneLabel,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _businessAddressController,
                      decoration: InputDecoration(
                        labelText: l10n.businessAddressLabel,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingBusiness ? null : _saveBusiness,
                        icon: _isSavingBusiness
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(l10n.updateBusinessInfo),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. Password Security Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            l10n.changePasswordTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.currentPassword,
                        prefixIcon: const Icon(Icons.lock_clock_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? l10n.enterCurrentPassword : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.newPassword,
                        prefixIcon: const Icon(Icons.key_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.length < 6 ? l10n.passwordTooShort : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.confirmNewPassword,
                        prefixIcon: const Icon(Icons.key_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? l10n.confirmYourNewPassword : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isChangingPassword ? null : _changePassword,
                        icon: _isChangingPassword
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.security_outlined),
                        label: Text(l10n.updatePasswordAction),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 4. Danger Zone (Delete Account)
          Card(
            elevation: 2,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.dangerZoneTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    l10n.deleteAccountWarning,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: _isDeletingAccount ? null : _confirmDeleteAccount,
                      icon: _isDeletingAccount
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(l10n.deleteAccountPermanently),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

