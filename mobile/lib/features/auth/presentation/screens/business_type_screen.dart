import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Business types supported at launch (Spec Ch. 4 / Ch. 5).
/// This enum is the single source of truth used to drive the
/// feature-matrix (Ch. 4, Table 4.1) elsewhere in the app.
enum BusinessType {
  clothing,
  grocery,
  pharmacy,
  clinic,
  restaurant,
  company,
  workshop,
}

extension BusinessTypeLabels on BusinessType {
  String get label => switch (this) {
        BusinessType.clothing => 'Clothing Store',
        BusinessType.grocery => 'Grocery Store',
        BusinessType.pharmacy => 'Pharmacy',
        BusinessType.clinic => 'Clinic / Doctor',
        BusinessType.restaurant => 'Restaurant',
        BusinessType.company => 'Company',
        BusinessType.workshop => 'Workshop / Artisan',
      };

  String get description => switch (this) {
        BusinessType.clothing => 'Sizes, colors, barcode',
        BusinessType.grocery => 'Expiration, suppliers',
        BusinessType.pharmacy => 'Stock, expiration alerts',
        BusinessType.clinic => 'Patients, appointments',
        BusinessType.restaurant => 'Menu, ingredients',
        BusinessType.company => 'Employees, invoices',
        BusinessType.workshop => 'Orders, services',
      };

  String get shortCode => switch (this) {
        BusinessType.clothing => 'CL',
        BusinessType.grocery => 'GR',
        BusinessType.pharmacy => 'PH',
        BusinessType.clinic => 'CN',
        BusinessType.restaurant => 'RS',
        BusinessType.company => 'CO',
        BusinessType.workshop => 'WK',
      };
}

/// Business Type Selection — Spec Ch. 5, screen shown on p.10 of the spec.
class BusinessTypeScreen extends StatefulWidget {
  const BusinessTypeScreen({super.key, required this.onContinue});

  final void Function(BusinessType selected) onContinue;

  @override
  State<BusinessTypeScreen> createState() => _BusinessTypeScreenState();
}

class _BusinessTypeScreenState extends State<BusinessTypeScreen> {
  BusinessType? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Business Type'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(20),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Step 3 of 5',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose the option that best matches your business'),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                itemCount: BusinessType.values.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final type = BusinessType.values[i];
                  final isSelected = _selected == type;
                  return _BusinessTypeTile(
                    type: type,
                    selected: isSelected,
                    onTap: () => setState(() => _selected = type),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => widget.onContinue(_selected!),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessTypeTile extends StatelessWidget {
  const _BusinessTypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BusinessType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
              child: Text(type.shortCode, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: Theme.of(context).textTheme.titleMedium),
                  Text(type.description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
