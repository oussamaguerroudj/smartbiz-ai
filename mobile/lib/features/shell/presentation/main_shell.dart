import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/futuristic_nav_bar.dart';
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

/// Main App Shell — Spec Ch. 7 (Navigation)
/// 4-item bottom nav: Dashboard, Sales, Inventory, More.
/// All tabs and every More-menu destination are now real, data-wired
/// screens (Phase 4 complete) — no more placeholders.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  static const _tabs = [
    DashboardScreen(),
    SalesListScreen(),
    ProductsListScreen(),
    _MoreMenu(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final navItems = [
      PillNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: l10n.navDashboard,
      ),
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
      PillNavItem(
        icon: Icons.more_horiz_rounded,
        activeIcon: Icons.more_horiz_rounded,
        label: l10n.navMore,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: _tabs,
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

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  // Ch. 7 lists: Invoices, Expenses, Employees, Appointments, Reports,
  // AI Assistant, Notifications, Settings. Customers/Suppliers (Ch. 21)
  // and AI Invoice Scanner/Insights (Ch. 15/16) are part of the Main
  // Application per the Ch. 6 sitemap but need a reachable entry point
  // too — added here pragmatically rather than leaving them unreachable.
  //
  // Only the 8 labels covered by the .arb files are translated (l10n);
  // Customers/Suppliers/AI Scanner/AI Insights don't have arb keys yet
  // and stay hardcoded English pending a follow-up translation batch.
  List<_MoreMenuItemData> _items(AppLocalizations l10n) => [
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
          Icons.auto_awesome_outlined,
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
          l10n.moreSettings,
          Icons.settings_outlined,
          (_) => const SettingsScreen(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _items(l10n);

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
                    trailing: Icon(
                      Icons.chevron_right_rounded,
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
