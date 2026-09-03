import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined), label: 'Sales'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _MoreMenuItemData {
  const _MoreMenuItemData(this.code, this.label, this.icon, this.builder);
  final String code;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  // Ch. 7 lists: Invoices, Expenses, Employees, Appointments, Reports,
  // AI Assistant, Notifications, Settings. Customers/Suppliers (Ch. 21)
  // and AI Invoice Scanner/Insights (Ch. 15/16) are part of the Main
  // Application per the Ch. 6 sitemap but need a reachable entry point
  // too — added here pragmatically rather than leaving them unreachable.
  static final _items = [
    _MoreMenuItemData('IN', 'Invoices', Icons.receipt_long_outlined,
        (_) => const InvoicesScreen()),
    _MoreMenuItemData('EX', 'Expenses', Icons.payments_outlined,
        (_) => const ExpensesScreen()),
    _MoreMenuItemData('EM', 'Employees', Icons.badge_outlined,
        (_) => const EmployeesScreen()),
    _MoreMenuItemData('AP', 'Appointments', Icons.event_outlined,
        (_) => const AppointmentsScreen()),
    _MoreMenuItemData('CU', 'Customers', Icons.people_outline,
        (_) => const CustomersScreen()),
    _MoreMenuItemData('SU', 'Suppliers', Icons.local_shipping_outlined,
        (_) => const SuppliersScreen()),
    _MoreMenuItemData('RP', 'Reports', Icons.bar_chart_outlined,
        (_) => const ReportsScreen()),
    _MoreMenuItemData('SC', 'AI Invoice Scanner',
        Icons.document_scanner_outlined, (_) => const AiScannerScreen()),
    _MoreMenuItemData('AI', 'AI Assistant', Icons.auto_awesome_outlined,
        (_) => const AiAssistantScreen()),
    _MoreMenuItemData('IS', 'AI Insights', Icons.insights_outlined,
        (_) => const AiInsightsScreen()),
    _MoreMenuItemData('NT', 'Notifications', Icons.notifications_outlined,
        (_) => const NotificationsScreen()),
    _MoreMenuItemData('ST', 'Settings', Icons.settings_outlined,
        (_) => const SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) {
          final item = _items[i];
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                foregroundColor: AppColors.primary,
                child: Icon(item.icon, size: 20),
              ),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: item.builder)),
            ),
          );
        },
      ),
    );
  }
}
