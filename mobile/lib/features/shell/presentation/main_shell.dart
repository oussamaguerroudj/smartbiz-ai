import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../products/presentation/screens/products_list_screen.dart';
import '../../sales/presentation/screens/sales_list_screen.dart';

/// Main App Shell — Spec Ch. 7 (Navigation)
/// 4-item bottom nav: Dashboard, Sales, Inventory, More.
/// Sales/Inventory tabs are placeholders here — full screens land
/// in later Phase-2 batches (Inventory/Sales feature folders).
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), label: 'Sales'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _MoreMenuItemData {
  const _MoreMenuItemData(this.code, this.label, this.icon);
  final String code;
  final String label;
  final IconData icon;
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  static const _items = [
    _MoreMenuItemData('IN', 'Invoices', Icons.receipt_long_outlined),
    _MoreMenuItemData('EX', 'Expenses', Icons.payments_outlined),
    _MoreMenuItemData('EM', 'Employees', Icons.badge_outlined),
    _MoreMenuItemData('AP', 'Appointments', Icons.event_outlined),
    _MoreMenuItemData('RP', 'Reports', Icons.bar_chart_outlined),
    _MoreMenuItemData('AI', 'AI Assistant', Icons.auto_awesome_outlined),
    _MoreMenuItemData('NT', 'Notifications', Icons.notifications_outlined),
    _MoreMenuItemData('ST', 'Settings', Icons.settings_outlined),
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
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
