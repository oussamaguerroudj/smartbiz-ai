import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Business types supported (Ch. 1 SPECIALIZED BUSINESS CONTENT).
/// This enum is the single source of truth used to drive the
/// feature-matrix elsewhere in the app, and mirrors backend
/// `business_type_enum` exactly (see migration 016_expand_business_types.sql)
///  -  `apiValue` below must match a DB enum label 1:1.
enum BusinessType {
  clothing,
  grocery,
  pharmacy,
  clinic,
  restaurant,
  company,
  workshop,
  // Ch. 1 additions (migration 016)  -  full AR/FR/EN translations exist
  // only for the 7 original types above; these 17 show their English
  // label/description regardless of app locale until translated (see
  // localizedLabel/localizedDescription below)  -  a real gap, flagged
  // rather than silently shipped as broken/mistranslated text.
  retailStore,
  cafe,
  beautySalon,
  barbershop,
  gym,
  hotel,
  dentalClinic,
  medicalLaboratory,
  carRepair,
  electronicsStore,
  supermarket,
  bakery,
  lawOffice,
  accountingOffice,
  realEstateAgency,
  educationCenter,
  other,
}

/// Dashboard-family simplification (post-Phase-4 architecture change,
/// corrected post-Phase-4.1 to restore Enterprise/Company  -  see
/// `backend/SPECIALIZED_MODULES.md` §15): the app used to expose all 24
/// `BusinessType` values as separate picker tiles. New signups now only
/// ever see these 6  -  one per actually-built dashboard family, Enterprise
/// included since it has always had a real, working dashboard
/// (`EnterpriseMainDashboardScreen`). Every other enum member (and every
/// legacy DB value like `cafe`/`dental_clinic`/`supermarket`/
/// `retail_store`/`workshop`/...) is kept for backward compatibility
/// (existing accounts, `fromApiValue`, `main_shell.dart`'s routing) but is
/// deliberately NOT offered to a new user anymore  -  see
/// `backend/SPECIALIZED_MODULES.md` for the full rationale and mapping.
const List<BusinessType> kSelectableBusinessTypes = [
  BusinessType.grocery, // "Market / Store"  -  covers supermarket/mini
  // market/grocery/convenience/general store; routes to the existing
  // Supérette dashboard, same as `supermarket`/`retail_store` already did.
  BusinessType.clothing, // "Clothing Store"  -  unchanged, already its own family.
  BusinessType.restaurant, // "Restaurant / Café"  -  now also covers `cafe`.
  BusinessType.clinic, // "Clinic / Medical"  -  now also covers `dental_clinic`.
  BusinessType.pharmacy, // "Pharmacy"  -  unchanged, already its own family.
  BusinessType.company, // "Enterprise / Company"  -  restored: has a real,
  // fully-implemented dashboard (`EnterpriseMainDashboardScreen`) and was
  // wrongly dropped from the picker in the prior pass despite that.
];

extension BusinessTypeApi on BusinessType {
  /// Exact string sent to/received from the backend  -  must match
  /// business_type_enum's labels (snake_case), not this enum's Dart
  /// (camelCase) member names.
  String get apiValue => switch (this) {
        BusinessType.clothing => 'clothing',
        BusinessType.grocery => 'grocery',
        BusinessType.pharmacy => 'pharmacy',
        BusinessType.clinic => 'clinic',
        BusinessType.restaurant => 'restaurant',
        BusinessType.company => 'company',
        BusinessType.workshop => 'workshop',
        BusinessType.retailStore => 'retail_store',
        BusinessType.cafe => 'cafe',
        BusinessType.beautySalon => 'beauty_salon',
        BusinessType.barbershop => 'barbershop',
        BusinessType.gym => 'gym',
        BusinessType.hotel => 'hotel',
        BusinessType.dentalClinic => 'dental_clinic',
        BusinessType.medicalLaboratory => 'medical_laboratory',
        BusinessType.carRepair => 'car_repair',
        BusinessType.electronicsStore => 'electronics_store',
        BusinessType.supermarket => 'supermarket',
        BusinessType.bakery => 'bakery',
        BusinessType.lawOffice => 'law_office',
        BusinessType.accountingOffice => 'accounting_office',
        BusinessType.realEstateAgency => 'real_estate_agency',
        BusinessType.educationCenter => 'education_center',
        BusinessType.other => 'other',
      };

  static BusinessType? fromApiValue(String? value) {
    for (final type in BusinessType.values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

extension BusinessTypeLabels on BusinessType {
  String get label => switch (this) {
        BusinessType.clothing => 'Clothing Store',
        BusinessType.grocery => 'Market / Store',
        BusinessType.pharmacy => 'Pharmacy',
        BusinessType.clinic => 'Clinic / Medical',
        BusinessType.restaurant => 'Restaurant / Café',
        BusinessType.company => 'Enterprise / Company',
        BusinessType.workshop => 'Workshop / Artisan',
        BusinessType.retailStore => 'Retail Store',
        BusinessType.cafe => 'Café',
        BusinessType.beautySalon => 'Beauty Salon',
        BusinessType.barbershop => 'Barbershop',
        BusinessType.gym => 'Gym',
        BusinessType.hotel => 'Hotel',
        BusinessType.dentalClinic => 'Dental Clinic',
        BusinessType.medicalLaboratory => 'Medical Laboratory',
        BusinessType.carRepair => 'Car Repair',
        BusinessType.electronicsStore => 'Electronics Store',
        BusinessType.supermarket => 'Supermarket',
        BusinessType.bakery => 'Bakery',
        BusinessType.lawOffice => 'Law Office',
        BusinessType.accountingOffice => 'Accounting Office',
        BusinessType.realEstateAgency => 'Real Estate Agency',
        BusinessType.educationCenter => 'Education Center',
        BusinessType.other => 'Other Business',
      };

  String get description => switch (this) {
        BusinessType.clothing => 'Sizes, colors, barcode',
        BusinessType.grocery => 'Supermarket, mini market, grocery, convenience store',
        BusinessType.pharmacy => 'Stock, expiration alerts',
        BusinessType.clinic => 'Patients, appointments — medical & dental',
        BusinessType.restaurant => 'Menu, orders, tables — restaurants & cafés',
        BusinessType.company => 'Employees, invoices',
        BusinessType.workshop => 'Orders, services',
        BusinessType.retailStore => 'Products, stock, barcode',
        BusinessType.cafe => 'Tables, menu, orders',
        BusinessType.beautySalon => 'Clients, services, appointments',
        BusinessType.barbershop => 'Customers, queue, services',
        BusinessType.gym => 'Members, memberships, attendance',
        BusinessType.hotel => 'Rooms, reservations, check-in/out',
        BusinessType.dentalClinic => 'Patients, treatments, appointments',
        BusinessType.medicalLaboratory => 'Test orders, samples, results',
        BusinessType.carRepair => 'Vehicles, repair orders, mechanics',
        BusinessType.electronicsStore => 'Serial numbers, warranty, repairs',
        BusinessType.supermarket => 'POS, barcode, expiration dates',
        BusinessType.bakery => 'Recipes, production, ingredients',
        BusinessType.lawOffice => 'Clients, cases, documents',
        BusinessType.accountingOffice => 'Clients, files, deadlines',
        BusinessType.realEstateAgency => 'Properties, clients, contracts',
        BusinessType.educationCenter => 'Students, classes, attendance',
        BusinessType.other => 'General business management',
      };

  /// Localized label  -  matches the arb keys exactly (businessType* /
  /// businessType*Desc) for the 7 original types. The 17 newer types
  /// (Ch. 1) fall back to the plain English [label] regardless of
  /// locale  -  translating them is a follow-up, tracked in
  /// backend/SPECIALIZED_MODULES.md, not silently faked here.
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        BusinessType.clothing => l10n.businessTypeClothing,
        BusinessType.grocery => l10n.businessTypeGrocery,
        BusinessType.pharmacy => l10n.businessTypePharmacy,
        BusinessType.clinic => l10n.businessTypeClinic,
        BusinessType.restaurant => l10n.businessTypeRestaurant,
        BusinessType.company => l10n.businessTypeCompany,
        BusinessType.workshop => l10n.businessTypeWorkshop,
        _ => label,
      };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
        BusinessType.clothing => l10n.businessTypeClothingDesc,
        BusinessType.grocery => l10n.businessTypeGroceryDesc,
        BusinessType.pharmacy => l10n.businessTypePharmacyDesc,
        BusinessType.clinic => l10n.businessTypeClinicDesc,
        BusinessType.restaurant => l10n.businessTypeRestaurantDesc,
        BusinessType.company => l10n.businessTypeCompanyDesc,
        BusinessType.workshop => l10n.businessTypeWorkshopDesc,
        _ => description,
      };

  String get shortCode => switch (this) {
        BusinessType.clothing => 'CL',
        BusinessType.grocery => 'GR',
        BusinessType.pharmacy => 'PH',
        BusinessType.clinic => 'CN',
        BusinessType.restaurant => 'RS',
        BusinessType.company => 'CO',
        BusinessType.workshop => 'WK',
        BusinessType.retailStore => 'RT',
        BusinessType.cafe => 'CF',
        BusinessType.beautySalon => 'BS',
        BusinessType.barbershop => 'BB',
        BusinessType.gym => 'GY',
        BusinessType.hotel => 'HT',
        BusinessType.dentalClinic => 'DC',
        BusinessType.medicalLaboratory => 'ML',
        BusinessType.carRepair => 'CR',
        BusinessType.electronicsStore => 'ES',
        BusinessType.supermarket => 'SM',
        BusinessType.bakery => 'BK',
        BusinessType.lawOffice => 'LO',
        BusinessType.accountingOffice => 'AO',
        BusinessType.realEstateAgency => 'RE',
        BusinessType.educationCenter => 'EC',
        BusinessType.other => 'OT',
      };

  /// Proper semantic icon per business type  -  replaces the old
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
        BusinessType.retailStore => Icons.store_outlined,
        BusinessType.cafe => Icons.local_cafe_outlined,
        BusinessType.beautySalon => Icons.face_retouching_natural_outlined,
        BusinessType.barbershop => Icons.content_cut_outlined,
        BusinessType.gym => Icons.fitness_center_outlined,
        BusinessType.hotel => Icons.hotel_outlined,
        BusinessType.dentalClinic => Icons.medical_services_outlined,
        BusinessType.medicalLaboratory => Icons.biotech_outlined,
        BusinessType.carRepair => Icons.car_repair_outlined,
        BusinessType.electronicsStore => Icons.devices_outlined,
        BusinessType.supermarket => Icons.local_grocery_store_outlined,
        BusinessType.bakery => Icons.bakery_dining_outlined,
        BusinessType.lawOffice => Icons.gavel_outlined,
        BusinessType.accountingOffice => Icons.calculate_outlined,
        BusinessType.realEstateAgency => Icons.apartment_outlined,
        BusinessType.educationCenter => Icons.school_outlined,
        BusinessType.other => Icons.category_outlined,
      };
}

/// Business Type Selection  -  Spec Ch. 5, screen shown on p.10 of the spec.
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
                itemCount: kSelectableBusinessTypes.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final type = kSelectableBusinessTypes[i];
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
