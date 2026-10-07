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
/// business types. All tabs and every More-menu destination are real,
/// data-wired screens (Phase 4 complete) — no more placeholders.
///
/// Business-specialization brief (Ch. 1-27): every business type must
/// see pages relevant to ITS activity — a clinic owner should never
/// land on a product-sales tab, and a retail owner never needs a
/// patient queue tab. Tab 0 (dashboard content), tabs 1-2 (which
/// screens they even are) and the More menu (which items exist at all)
/// are now all resolved from `businessType`, via three small
/// per-vertical functions below (`_dashboardTabFor`, `_middleTabsFor`,
/// `_middleNavItemsFor`) — CORE/unset business types keep the exact
/// original Sales/Inventory tabs and full More list; a vertical only
/// gets a branch once it actually has real pages to show there.
/// Clinic and Restaurant are both implemented this way now; adding the
/// next vertical (Pharmacy, ...) means adding one more branch to each
/// of these three, never touching the branches already there — same
/// "smallest possible blast radius" rule as before.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tabIndex = 0;

  /// Pharmacy (Ch. 15), Supérette/general-store (Ch. 16) and Clothing
  /// (Ch. 18) all deliberately have NO arm in `_middleTabsFor` /
  /// `_middleNavItemsFor` / `_MoreMenu._items` below — they fall
  /// through to the exact CORE default everywhere else, since Sales/
  /// Inventory/Suppliers/Customers/Reports already ARE what these
  /// verticals need (Ch. 21's "reuse existing APIs" rule). Only the
  /// dashboard tab's CONTENT is specialized, via
  /// `PharmacyMainDashboardScreen` / `SuperetteMainDashboardScreen` /
  /// `ClothingMainDashboardScreen`.
  ///
  /// Supérette/general-store maps from THREE business_type values —
  /// 'grocery', 'supermarket' and 'retail_store' — since Ch. 16 treats
  /// them as one and the same business model (Products, Stock, Sales,
  /// Purchases, Suppliers, Customers); splitting them into separate
  /// dashboards would mean duplicating this exact screen three times
  /// for zero benefit.
  Widget _dashboardTabFor(String? businessType) => switch (businessType) {
        // Dashboard-family simplification: 'dental_clinic' and 'cafe' are
        // legacy/compatibility DB values now folded into the Clinic and
        // Restaurant families respectively (see business_type_screen.dart's
        // kSelectableBusinessTypes + backend/SPECIALIZED_MODULES.md).
        'clinic' || 'dental_clinic' => const ClinicMainDashboardScreen(),
        'restaurant' || 'cafe' => const RestaurantMainDashboardScreen(),
        'pharmacy' => const PharmacyMainDashboardScreen(),
        'grocery' || 'supermarket' || 'retail_store' => const SuperetteMainDashboardScreen(),
        'clothing' => const ClothingMainDashboardScreen(),
        'company' => const EnterpriseMainDashboardScreen(),
        _ => const DashboardScreen(),
      };

  /// The 2 middle tabs (indices 1-2) — CORE keeps Sales/Inventory.
  /// Clinic replaces them with Appointments/Patients, since a clinic
  /// has no products to sell and no stock to track (Ch. 2/13).
  /// Restaurant replaces them with Orders/Tables (Ch. 17) — a
  /// restaurant's "sales" are orders and it has no product inventory,
  /// only tables and a menu, so the generic Sales/Inventory tabs would
  /// be meaningless here too.
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
    final l10n = AppLocalizations.of(context)!;
    final businessType = ref.watch(companyInfoProvider).valueOrNull?.businessType ??
        ref.watch(sessionProvider).businessType;

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

    // Android back-button fix (Phase 2 Finding, main_shell.dart):
    //
    // Root cause — this app's navigation is a single root Navigator
    // (MaterialApp's own; MainShell declares no Navigator of its own)
    // plus an IndexedStack that keeps all 4 tabs alive without ever
    // pushing/popping a route when switching tabs (see onTap above).
    // The `main` phase itself is never pushed either — main.dart's
    // `_AppFlow` swaps Login/Onboarding/MainShell in place via
    // AnimatedSwitcher + setState, not Navigator.push, so it is not
    // possible for the back button to pop past MainShell into
    // Login/Onboarding through the Navigator: there is nothing to pop
    // to there. What WAS actually missing is any handling at all for
    // "back pressed while sitting on a non-Dashboard tab with nothing
    // else pushed" — with no PopScope/WillPopScope anywhere in the
    // codebase, `Navigator.maybePop()` had nothing to pop (this is the
    // only route on the root Navigator at that point) and Android's
    // default behavior took over and closed the app immediately,
    // regardless of which tab the user was on.
    //
    // Fix: intercept the pop at the tab level. If the user is on any
    // tab other than Dashboard (index 0), the back button now returns
    // them to Dashboard first, matching standard bottom-nav behavior,
    // instead of exiting straight away. From Dashboard itself, back is
    // left alone (canPop: true) so the normal platform behavior
    // (exit / hand off to whatever is actually beneath this route)
    // still applies — this does not touch or need to touch anything
    // in main.dart's phase flow.
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

  /// When set, tapping this item runs this instead of pushing [builder]
  /// directly — used by the AI Scanner entry, which now needs to open
  /// the Sales/Stock chooser first rather than assume a mode.
  final void Function(BuildContext context)? onTapOverride;
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.businessType});

  final String? businessType;

  // Ch. 7 lists: Invoices, Expenses, Employees, Appointments, Reports,
  // AI Assistant, Notifications, Settings. Customers/Suppliers (Ch. 21)
  // and AI Invoice Scanner/Insights (Ch. 15/16) are part of the Main
  // Application per the Ch. 6 sitemap but need a reachable entry point
  // too — added here pragmatically rather than leaving them unreachable.
  //
  // Only the 8 labels covered by the .arb files are translated (l10n);
  // Customers/Suppliers/AI Scanner/AI Insights don't have arb keys yet
  // and stay hardcoded English pending a follow-up translation batch.
  //
  // `businessType` (Ch. 2 CORE + SPECIALIZED): for `clinic`, every
  // product/retail-only item (Invoices, Customers, Suppliers, Credit,
  // AI Invoice Scanner — none of which a clinic has any data for) is
  // dropped entirely rather than just hidden, and Appointments is
  // dropped too since it's now its own bottom-nav tab (see
  // `_middleTabsFor`) — keeping it here as well would just be the same
  // screen reachable two different ways. Waiting Room is added instead,
  // since it's a real, frequently-used clinic screen that doesn't have
  // a tab slot of its own. For `restaurant`, the same rule applies:
  // Invoices/Customers/Suppliers/Credit/AI Scanner are dropped (a
  // restaurant sells dishes, not invoiced products, per Ch. 17), Orders
  // and Tables are dropped since they're now bottom-nav tabs, and Menu
  // + Reservations are added since they're real restaurant screens
  // without a tab slot of their own. Every other business type
  // (including `null`/not-yet-set) keeps the exact original CORE list,
  // unchanged.
  List<_MoreMenuItemData> _items(AppLocalizations l10n, String? businessType) {
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

    return [
      ...specializedItems,
      _MoreMenuItemData(
        l10n.allPagesTitle,
        Icons.grid_view_rounded,
        (_) => const AllPagesScreen(),
      ),
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
          l10n.moreAppointments,
          Icons.event_outlined,
          (_) => const AppointmentsScreen(),
        ),
        _MoreMenuItemData(
          l10n.moreCustomers,
          Icons.people_outline,
          (_) => const CustomersScreen(),
        ),
        _MoreMenuItemData(
          l10n.creditPageTitle,
          Icons.credit_card_outlined,
          (_) => const CreditScreen(),
        ),
        _MoreMenuItemData(
          l10n.moreSuppliers,
          Icons.local_shipping_outlined,
          (_) => const SuppliersScreen(),
        ),
        _MoreMenuItemData(
          l10n.moreReports,
          Icons.bar_chart_outlined,
          (_) => const ReportsScreen(),
        ),
        _MoreMenuItemData(
          l10n.moreAiScanner,
          Icons.document_scanner_outlined,
          // Unused when onTapOverride is set — kept non-null just to
          // satisfy the required builder param without making every
          // other entry handle a nullable builder.
          (_) => const SizedBox.shrink(),
          onTapOverride: (ctx) => showScanInvoiceChooser(ctx),
        ),
        _MoreMenuItemData(
          l10n.moreAiAssistant,
          Icons.smart_toy_outlined,
          (_) => const AiAssistantScreen(),
        ),
        _MoreMenuItemData(
          l10n.moreAiInsights,
          Icons.insights_outlined,
          (_) => const AiInsightsScreen(),
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
      ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = _items(l10n, businessType);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) {
          final item = items[i];

          return FadeSlideIn(
            delay: Duration(milliseconds: 35 * i),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusCard,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusCard,
                ),
                onTap: () {
                  if (item.onTapOverride != null) {
                    item.onTapOverride!(context);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: item.builder,
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusCard,
                    ),
                    boxShadow: AppSpacing.cardElevation,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        item.icon,
                        size: 19,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    trailing: ForwardChevron(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
