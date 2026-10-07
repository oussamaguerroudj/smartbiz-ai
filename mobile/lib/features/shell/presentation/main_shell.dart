import '../../../core/widgets/directional_chevron.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/futuristic_nav_bar.dart';
import '../../../core/widgets/offline_status_bar.dart';
import '../../../core/widgets/sync_status_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/presentation/screens/super_admin_dashboard_screen.dart';
import '../../admin/presentation/screens/support_dashboard_screen.dart';
import '../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../products/presentation/screens/products_list_screen.dart';
import '../../sales/presentation/screens/sales_list_screen.dart';
import '../../invoices/presentation/screens/invoices_screen.dart';
import '../../expenses/presentation/screens/expenses_screen.dart';
import '../../employees/presentation/screens/employees_screen.dart';
import '../../appointments/presentation/screens/appointments_screen.dart';
import '../../customers/presentation/screens/customers_screen.dart';
import '../../suppliers/presentation/screens/suppliers_screen.dart';
import '../../reports/presentation/screens/reports_screen.dart';
import '../../notifications/presentation/screens/notifications_screen.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../../settings/presentation/screens/profile_screen.dart';
import '../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../ai/presentation/screens/ai_scanner_screen.dart';
import '../../credit/presentation/screens/credit_screen.dart';
import '../../clinic/presentation/screens/clinic_main_dashboard_screen.dart';
import '../../clinic/presentation/screens/clinic_patients_screen.dart';
import '../../clinic/presentation/screens/clinic_queue_screen.dart';
import '../../restaurant/presentation/screens/restaurant_main_dashboard_screen.dart';
import '../../restaurant/presentation/screens/restaurant_orders_screen.dart';
import '../../restaurant/presentation/screens/restaurant_tables_screen.dart';
import '../../restaurant/presentation/screens/restaurant_menu_screen.dart';
import '../../restaurant/presentation/screens/restaurant_reservations_screen.dart';
import '../../restaurant/presentation/screens/restaurant_inventory_screen.dart';
import '../../pharmacy/presentation/screens/pharmacy_main_dashboard_screen.dart';
import '../../superette/presentation/screens/superette_main_dashboard_screen.dart';
import '../../clothing/presentation/screens/clothing_main_dashboard_screen.dart';
import '../../enterprise/presentation/screens/enterprise_main_dashboard_screen.dart';
import '../../enterprise/presentation/screens/enterprise_projects_screen.dart';
import '../../dashboard/presentation/screens/all_pages_screen.dart';
import '../../auth/data/companies_repository.dart';
import '../../../core/network/session.dart';

/// Main App Shell — Spec Ch. 7 (Navigation)
/// 4-item bottom nav: Dashboard, Sales, Inventory, More — for CORE/retail
/// business types.
///
/// Business-specialization brief (Ch. 1-27): every business type sees pages
/// relevant to ITS activity, resolved authoritatively from backend organization data.
///
/// Super Admin and Support roles are strictly partitioned with dedicated dashboards.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tabIndex = 0;

  Widget _dashboardTabFor(String? businessType) => switch (businessType) {
        'clinic' || 'dental_clinic' => const ClinicMainDashboardScreen(),
        'restaurant' || 'cafe' => const RestaurantMainDashboardScreen(),
        'pharmacy' => const PharmacyMainDashboardScreen(),
        'grocery' || 'supermarket' || 'retail_store' => const SuperetteMainDashboardScreen(),
        'clothing' => const ClothingMainDashboardScreen(),
        'company' => const EnterpriseMainDashboardScreen(),
        _ => const DashboardScreen(),
      };

  List<Widget> _middleTabsFor(String? businessType) => switch (businessType) {
        'clinic' || 'dental_clinic' => const [AppointmentsScreen(), ClinicPatientsScreen()],
        'restaurant' || 'cafe' => const [RestaurantOrdersScreen(), RestaurantTablesScreen()],
        _ => const [SalesListScreen(), ProductsListScreen()],
      };

  List<PillNavItem> _middleNavItemsFor(AppLocalizations l10n, String? businessType) => switch (businessType) {
        'clinic' || 'dental_clinic' => [
            PillNavItem(
              icon: Icons.event_outlined,
              activeIcon: Icons.event_rounded,
              label: l10n.moreAppointments,
            ),
            PillNavItem(
              icon: Icons.people_alt_outlined,
              activeIcon: Icons.people_alt_rounded,
              label: l10n.clinicPatientsTitle,
            ),
          ],
        'restaurant' || 'cafe' => [
            PillNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: l10n.ordersTitle,
            ),
            PillNavItem(
              icon: Icons.table_restaurant_outlined,
              activeIcon: Icons.table_restaurant_rounded,
              label: l10n.tablesTitle,
            ),
          ],
        _ => [
            PillNavItem(
              icon: Icons.point_of_sale_outlined,
              activeIcon: Icons.point_of_sale_rounded,
              label: l10n.navSales,
            ),
            PillNavItem(
              icon: Icons.inventory_2_outlined,
              activeIcon: Icons.inventory_2_rounded,
              label: l10n.navInventory,
            ),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // Super Admin & Support user role separation:
    // A super admin or support agent must NEVER see normal business operational dashboards.
    // A normal business user must NEVER see administrative tools.
    if (session.role == 'super_admin') {
      return const SuperAdminDashboardScreen();
    }
    if (session.role == 'support') {
      return const SupportDashboardScreen();
    }

    final l10n = AppLocalizations.of(context)!;
    final businessType = ref.watch(companyInfoProvider).valueOrNull?.businessType ??
        session.businessType;

    final tabs = [
      _dashboardTabFor(businessType),
      ..._middleTabsFor(businessType),
      _MoreMenu(businessType: businessType),
    ];

    final navItems = [
      PillNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: l10n.navDashboard,
      ),
      ..._middleNavItemsFor(l10n, businessType),
      PillNavItem(
        icon: Icons.more_horiz_rounded,
        activeIcon: Icons.more_horiz_rounded,
        label: l10n.navMore,
      ),
    ];

    return PopScope(
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _tabIndex = 0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const OfflineStatusBar(),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: tabs,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: FuturisticNavBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          onAiAssistant: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AiAssistantScreen(),
              ),
            );
          },
          items: navItems,
        ),
      ),
    );
  }
}

class _MoreMenuItemData {
  const _MoreMenuItemData(this.label, this.icon, this.builder, {this.onTapOverride});

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final void Function(BuildContext context)? onTapOverride;
}

class _MoreSectionData {
  const _MoreSectionData({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_MoreMenuItemData> items;
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.businessType});

  final String? businessType;

  List<_MoreSectionData> _sections(AppLocalizations l10n, String? businessType) {
    // 1. Operations & Commerce
    final operationsItems = [
      _MoreMenuItemData(
        l10n.moreInvoices,
        Icons.receipt_long_outlined,
        (_) => const InvoicesScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreExpenses,
        Icons.payments_outlined,
        (_) => const ExpensesScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreEmployees,
        Icons.badge_outlined,
        (_) => const EmployeesScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreCustomers,
        Icons.people_outline,
        (_) => const CustomersScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreSuppliers,
        Icons.local_shipping_outlined,
        (_) => const SuppliersScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreAppointments,
        Icons.event_outlined,
        (_) => const AppointmentsScreen(),
      ),
      _MoreMenuItemData(
        l10n.creditPageTitle,
        Icons.credit_card_outlined,
        (_) => const CreditScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreReports,
        Icons.bar_chart_outlined,
        (_) => const ReportsScreen(),
      ),
    ];

    // 2. Specialized Business Tools
    final specializedItems = <_MoreMenuItemData>[
      if (businessType == 'clinic' || businessType == 'dental_clinic') ...[
        _MoreMenuItemData(
          l10n.clinicQueueTitle,
          Icons.groups_outlined,
          (_) => const ClinicQueueScreen(),
        ),
        _MoreMenuItemData(
          l10n.clinicPatientsTitle,
          Icons.people_alt_outlined,
          (_) => const ClinicPatientsScreen(),
        ),
      ] else if (businessType == 'restaurant' || businessType == 'cafe') ...[
        _MoreMenuItemData(
          l10n.ordersTitle,
          Icons.receipt_long_outlined,
          (_) => const RestaurantOrdersScreen(),
        ),
        _MoreMenuItemData(
          l10n.tablesTitle,
          Icons.table_restaurant_outlined,
          (_) => const RestaurantTablesScreen(),
        ),
        _MoreMenuItemData(
          l10n.menuTitle,
          Icons.restaurant_menu_outlined,
          (_) => const RestaurantMenuScreen(),
        ),
        _MoreMenuItemData(
          l10n.reservationsTitle,
          Icons.event_seat_outlined,
          (_) => const RestaurantReservationsScreen(),
        ),
        _MoreMenuItemData(
          l10n.navInventory,
          Icons.inventory_2_outlined,
          (_) => const RestaurantInventoryScreen(),
        ),
      ] else if (businessType == 'company') ...[
        _MoreMenuItemData(
          l10n.projectsTitle,
          Icons.work_outline_rounded,
          (_) => const EnterpriseProjectsScreen(),
        ),
      ],
    ];

    // 3. AI & Intelligence
    final aiItems = [
      _MoreMenuItemData(
        l10n.moreAiAssistant,
        Icons.smart_toy_outlined,
        (_) => const AiAssistantScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreAiScanner,
        Icons.document_scanner_outlined,
        (_) => const SizedBox.shrink(),
        onTapOverride: (ctx) => showScanInvoiceChooser(ctx),
      ),
      _MoreMenuItemData(
        l10n.moreAiInsights,
        Icons.insights_outlined,
        (_) => const AiInsightsScreen(),
      ),
    ];

    // 4. System & Account
    final systemItems = [
      _MoreMenuItemData(
        l10n.businessProfileTitle,
        Icons.person_outline_rounded,
        (_) => const ProfileScreen(),
      ),
      _MoreMenuItemData(
        l10n.moreNotifications,
        Icons.notifications_outlined,
        (_) => const NotificationsScreen(),
      ),
      _MoreMenuItemData(
        l10n.syncDetails,
        Icons.sync_alt_rounded,
        (_) => const SizedBox.shrink(),
        onTapOverride: (ctx) => showDialog(
          context: ctx,
          builder: (_) => const SyncStatusDialog(),
        ),
      ),
      _MoreMenuItemData(
        l10n.moreSettings,
        Icons.settings_outlined,
        (_) => const SettingsScreen(),
      ),
      _MoreMenuItemData(
        l10n.allPagesTitle,
        Icons.grid_view_rounded,
        (_) => const AllPagesScreen(),
      ),
    ];

    return [
      _MoreSectionData(
        title: l10n.moreSectionOperations,
        items: operationsItems,
      ),
      if (specializedItems.isNotEmpty)
        _MoreSectionData(
          title: l10n.moreSectionSpecialized,
          items: specializedItems,
        ),
      _MoreSectionData(
        title: l10n.moreSectionIntelligence,
        items: aiItems,
      ),
      _MoreSectionData(
        title: l10n.moreSectionSystem,
        items: systemItems,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sections = _sections(l10n, businessType);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        children: [
          for (int sIndex = 0; sIndex < sections.length; sIndex++) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 30 * sIndex),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, top: AppSpacing.sm, bottom: 6),
                child: Text(
                  sections[sIndex].title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
            ),
            FadeSlideIn(
              delay: Duration(milliseconds: 30 * sIndex + 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  boxShadow: AppSpacing.cardElevation,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < sections[sIndex].items.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        ),
                      ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            sections[sIndex].items[i].icon,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          sections[sIndex].items[i].label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        trailing: ForwardChevron(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        onTap: () {
                          if (sections[sIndex].items[i].onTapOverride != null) {
                            sections[sIndex].items[i].onTapOverride!(context);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: sections[sIndex].items[i].builder,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
