import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modiri_ai/core/theme/app_colors.dart';
import 'package:modiri_ai/core/widgets/ambient_background.dart';
import 'package:modiri_ai/core/connectivity/connectivity_service.dart';
import 'package:modiri_ai/core/network/session.dart';
import 'package:modiri_ai/l10n/app_localizations.dart';
import 'package:modiri_ai/features/settings/data/settings_providers.dart';
import 'package:modiri_ai/features/auth/data/auth_repository.dart';
import 'package:modiri_ai/features/auth/data/companies_repository.dart';
import 'package:modiri_ai/features/sales/data/cart_manager.dart';
import 'package:modiri_ai/features/sales/presentation/screens/create_sale_screen.dart';
import 'package:modiri_ai/features/sales/presentation/screens/sales_list_screen.dart';
import 'package:modiri_ai/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:modiri_ai/features/products/presentation/screens/products_list_screen.dart';
import 'package:modiri_ai/features/invoices/presentation/screens/invoices_screen.dart';
import 'package:modiri_ai/features/expenses/presentation/screens/expenses_screen.dart';
import 'package:modiri_ai/features/reports/presentation/screens/reports_screen.dart';
import 'package:modiri_ai/features/settings/presentation/screens/settings_screen.dart';
import 'package:modiri_ai/features/settings/presentation/screens/profile_screen.dart';
import 'package:modiri_ai/features/ai/presentation/screens/ai_assistant_screen.dart';
import 'package:modiri_ai/features/ai/presentation/screens/ai_scanner_screen.dart';
import 'package:modiri_ai/features/restaurant/presentation/screens/restaurant_orders_screen.dart';
import 'package:modiri_ai/features/appointments/presentation/screens/appointments_screen.dart';
import 'package:modiri_ai/features/employees/presentation/screens/employees_screen.dart';

/// Navigation item definition for the desktop sidebar
class _DesktopNavItem {
  const _DesktopNavItem({
    required this.index,
    required this.label,
    required this.icon,
    this.badgeCount = 0,
    this.section = 'OPERATIONS',
  });

  final int index;
  final String label;
  final IconData icon;
  final int badgeCount;
  final String section;
}

/// The Desktop Enterprise Application Shell for Windows & Web
class DesktopAppShell extends ConsumerStatefulWidget {
  const DesktopAppShell({
    super.key,
    required this.onNavigateToBusinessSelection,
  });

  final VoidCallback onNavigateToBusinessSelection;

  @override
  ConsumerState<DesktopAppShell> createState() => _DesktopAppShellState();
}

class _DesktopAppShellState extends ConsumerState<DesktopAppShell> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(sessionProvider);
    final companyAsync = ref.watch(companyInfoProvider);
    final companyName = companyAsync.value?.name ?? (session.userName ?? 'Business');
    final businessType = companyAsync.value?.businessType ?? 'retail';

    final connectionStatus = ref.watch(connectionStatusProvider);
    final cartState = ref.watch(multiCartProvider);
    final activeCartCount = cartState.activeCarts.length;

    // Categorized desktop navigation items
    final navItems = [
      // Section: Operations
      _DesktopNavItem(index: 0, label: l10n.navDashboard, icon: Icons.dashboard_rounded, section: 'OPERATIONS'),
      _DesktopNavItem(
        index: 1,
        label: l10n.salesPosTitle,
        icon: Icons.point_of_sale_rounded,
        badgeCount: activeCartCount > 1 ? activeCartCount : 0,
        section: 'OPERATIONS',
      ),
      _DesktopNavItem(index: 2, label: l10n.navSales, icon: Icons.receipt_long_rounded, section: 'OPERATIONS'),
      _DesktopNavItem(index: 3, label: l10n.inventoryTitle, icon: Icons.inventory_2_rounded, section: 'OPERATIONS'),
      _DesktopNavItem(index: 4, label: l10n.moreInvoices, icon: Icons.request_quote_rounded, section: 'OPERATIONS'),
      _DesktopNavItem(index: 5, label: l10n.moreExpenses, icon: Icons.add_card_rounded, section: 'OPERATIONS'),

      // Section: Specialized Modules
      if (businessType == 'restaurant' || businessType == 'cafe')
        const _DesktopNavItem(index: 6, label: 'Table Orders', icon: Icons.restaurant_rounded, section: 'SPECIALIZED'),
      if (businessType == 'clinic')
        const _DesktopNavItem(index: 7, label: 'Appointments', icon: Icons.calendar_month_rounded, section: 'SPECIALIZED'),
      _DesktopNavItem(index: 8, label: l10n.moreEmployees, icon: Icons.people_alt_rounded, section: 'SPECIALIZED'),

      // Section: Intelligence
      const _DesktopNavItem(index: 9, label: 'AI Assistant', icon: Icons.auto_awesome, section: 'INTELLIGENCE'),
      const _DesktopNavItem(index: 10, label: 'AI Scanner', icon: Icons.document_scanner_rounded, section: 'INTELLIGENCE'),
      _DesktopNavItem(index: 11, label: l10n.moreReports, icon: Icons.analytics_rounded, section: 'INTELLIGENCE'),

      // Section: System
      _DesktopNavItem(index: 12, label: l10n.settingsTitle, icon: Icons.settings_rounded, section: 'SYSTEM'),
      _DesktopNavItem(index: 13, label: l10n.personalProfileTitle, icon: Icons.person_rounded, section: 'SYSTEM'),
    ];

    return Scaffold(
      body: AmbientBackground(
        child: Row(
          children: [
            // 1. Persistent 256px Collapsible Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarCollapsed ? 72 : 256,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Sidebar Header & Tenant Branding
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: AppColors.aiGradient,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        ),
                        if (!_isSidebarCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  companyName.isNotEmpty ? companyName : 'Modiri AI',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  businessType.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.electricBlue,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.borderLight,
                  ),

                  // Sidebar Menu Items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: navItems.length,
                      itemBuilder: (context, idx) {
                        final item = navItems[idx];
                        final isSelected = _selectedIndex == item.index;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = item.index),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.electricBlue.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: AppColors.electricBlue.withValues(alpha: 0.35))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 20,
                                    color: isSelected
                                        ? AppColors.electricBlue
                                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                  ),
                                  if (!_isSidebarCollapsed) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          color: isSelected
                                              ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                                              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.badgeCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.electricBlue,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${item.badgeCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Sidebar Collapse / Expand Toggle
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.borderLight,
                  ),
                  IconButton(
                    icon: Icon(
                      _isSidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                    tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // 2. Main Fluid Content Area with Sticky 64px Header
            Expanded(
              child: Column(
                children: [
                  // Sticky Desktop Top Bar (64px)
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Quick POS Action Button
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _selectedIndex = 1),
                          icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                          label: const Text('Open POS (F2)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.electricBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),

                        // System Status & User Shortcuts
                        Row(
                          children: [
                            // Offline Sync Indicator
                            _SyncStatusPill(status: connectionStatus),
                            const SizedBox(width: 16),

                            // Language Switcher Dropdown
                            const _LanguageSelectorDropdown(),
                            const SizedBox(width: 12),

                            // Theme Toggle
                            IconButton(
                              icon: Icon(
                                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                ref.read(themeModeProvider.notifier).state =
                                    isDark ? ThemeMode.light : ThemeMode.dark;
                              },
                              tooltip: 'Toggle Theme',
                            ),
                            const SizedBox(width: 12),

                            // AI Assistant Quick Action
                            IconButton(
                              icon: const Icon(Icons.auto_awesome, color: AppColors.aiViolet, size: 20),
                              onPressed: () => setState(() => _selectedIndex = 9),
                              tooltip: 'Ask AI Assistant',
                            ),
                            const SizedBox(width: 12),

                            // User Profile Avatar & Sign Out
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'profile') {
                                  setState(() => _selectedIndex = 13);
                                } else if (value == 'switch_business') {
                                  widget.onNavigateToBusinessSelection();
                                } else if (value == 'logout') {
                                  await ref.read(authRepositoryProvider).logout();
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'profile',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 18),
                                      const SizedBox(width: 8),
                                      Text((session.userName != null && session.userName!.isNotEmpty) ? session.userName! : 'My Account'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'switch_business',
                                  child: Row(
                                    children: [
                                      Icon(Icons.storefront_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Switch Business'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout_rounded, size: 18, color: AppColors.errorRose),
                                      SizedBox(width: 8),
                                      Text('Sign Out', style: TextStyle(color: AppColors.errorRose)),
                                    ],
                                  ),
                                ),
                              ],
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.electricBlue.withValues(alpha: 0.15),
                                child: Text(
                                  (session.userName != null && session.userName!.isNotEmpty) ? session.userName!.substring(0, 1).toUpperCase() : 'M',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.electricBlue),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Fluid Active View Content
                  Expanded(
                    child: _buildCurrentView(_selectedIndex),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(int index) {
    return switch (index) {
      0 => const DashboardScreen(),
      1 => const CreateSaleScreen(),
      2 => const SalesListScreen(),
      3 => const ProductsListScreen(),
      4 => const InvoicesScreen(),
      5 => const ExpensesScreen(),
      6 => const RestaurantOrdersScreen(),
      7 => const AppointmentsScreen(),
      8 => const EmployeesScreen(),
      9 => const AiAssistantScreen(),
      10 => const AiScannerScreen(mode: InvoiceScanMode.stock),
      11 => const ReportsScreen(),
      12 => const SettingsScreen(),
      13 => const ProfileScreen(),
      _ => const DashboardScreen(),
    };
  }
}

class _SyncStatusPill extends StatelessWidget {
  const _SyncStatusPill({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (status) {
      ConnectionStatus.online => (AppColors.successGreen, 'Online & Synced', Icons.cloud_done_rounded),
      ConnectionStatus.syncing => (AppColors.electricBlue, 'Syncing...', Icons.sync_rounded),
      ConnectionStatus.offline => (AppColors.warningAmber, 'Offline Mode', Icons.cloud_off_rounded),
      ConnectionStatus.serverUnavailable => (AppColors.errorRose, 'Server Reachable', Icons.cloud_queue_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelectorDropdown extends ConsumerWidget {
  const _LanguageSelectorDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return PopupMenuButton<Locale>(
      tooltip: 'Language',
      initialValue: currentLocale,
      onSelected: (Locale locale) {
        ref.read(localeProvider.notifier).setLocale(locale);
      },
      itemBuilder: (BuildContext context) => const [
        PopupMenuItem(
          value: Locale('en'),
          child: Text('English (EN)'),
        ),
        PopupMenuItem(
          value: Locale('fr'),
          child: Text('Français (FR)'),
        ),
        PopupMenuItem(
          value: Locale('ar'),
          child: Text('العربية (AR)'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 18),
            const SizedBox(width: 4),
            Text(
              currentLocale?.languageCode.toUpperCase() ?? 'EN',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
