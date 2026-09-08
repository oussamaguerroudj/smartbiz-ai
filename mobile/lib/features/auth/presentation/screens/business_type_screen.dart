import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

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

  /// Localized label — matches the arb keys exactly (businessType* /
  /// businessType*Desc). Falls back to the English [label]/[description]
  /// above only if a locale is somehow missing a key.
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        BusinessType.clothing => l10n.businessTypeClothing,
        BusinessType.grocery => l10n.businessTypeGrocery,
        BusinessType.pharmacy => l10n.businessTypePharmacy,
        BusinessType.clinic => l10n.businessTypeClinic,
        BusinessType.restaurant => l10n.businessTypeRestaurant,
        BusinessType.company => l10n.businessTypeCompany,
        BusinessType.workshop => l10n.businessTypeWorkshop,
      };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
        BusinessType.clothing => l10n.businessTypeClothingDesc,
        BusinessType.grocery => l10n.businessTypeGroceryDesc,
        BusinessType.pharmacy => l10n.businessTypePharmacyDesc,
        BusinessType.clinic => l10n.businessTypeClinicDesc,
        BusinessType.restaurant => l10n.businessTypeRestaurantDesc,
        BusinessType.company => l10n.businessTypeCompanyDesc,
        BusinessType.workshop => l10n.businessTypeWorkshopDesc,
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

  /// Proper semantic icon per business type — replaces the old
  /// text-initials avatar (e.g. Pharmacy showing literal "PH") on the
  /// Business Type selection screen. [shortCode] above is kept in case
  /// anything else references it, but the tile below no longer uses it.
  IconData get icon => switch (this) {
        BusinessType.clothing => Icons.checkroom_outlined,
        BusinessType.grocery => Icons.storefront_outlined,
        BusinessType.pharmacy => Icons.local_pharmacy_outlined,
        BusinessType.clinic => Icons.local_hospital_outlined,
        BusinessType.restaurant => Icons.restaurant_outlined,
        BusinessType.company => Icons.business_outlined,
        BusinessType.workshop => Icons.build_outlined,
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectBusinessType),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.stepOf(3, 5),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.chooseBusinessTypeHint),
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
                child: Text(l10n.continueLabel),
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
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          boxShadow: AppSpacing.cardElevation,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(type.icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.localizedLabel(l10n), style: Theme.of(context).textTheme.titleMedium),
                  Text(type.localizedDescription(l10n), style: Theme.of(context).textTheme.bodyMedium),
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
