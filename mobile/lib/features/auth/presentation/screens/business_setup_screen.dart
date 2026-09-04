import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/companies_repository.dart';
import 'business_type_screen.dart';

/// Business Setup — Spec Ch. 8.4
/// Now persists to the real backend via PUT /companies/me (Phase 5
/// wiring), filling in the placeholder company auth.service.js created
/// at registration time.
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
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(companiesRepositoryProvider).updateMe(
            name: _nameController.text.trim(),
            businessType: widget.businessType.name, // enum names match backend's VALID_TYPES exactly
            currency: _currencyController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
          );
      if (mounted) widget.onFinish();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach the server — check your connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Business name',
                  hint: 'e.g. Amine Grocery',
                  controller: _nameController,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Business type',
                  controller: TextEditingController(
                    text: widget.businessType.label,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Phone number',
                  hint: '+213 ...',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Address',
                  hint: 'City, street',
                  controller: _addressController,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Currency',
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
                      : const Text('Finish Setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

