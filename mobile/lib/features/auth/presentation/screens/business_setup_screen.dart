import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'business_type_screen.dart';

/// Business Setup — Spec Ch. 8.4
/// Business name, business type (pre-filled), phone, address, currency.
class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({
    super.key,
    required this.businessType,
    required this.onFinish,
  });

  final BusinessType businessType;
  final VoidCallback onFinish;

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _currencyController = TextEditingController(text: 'DZD');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _currencyController.dispose();
    super.dispose();
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
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.onFinish();
                    }
                  },
                  child: const Text('Finish Setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
