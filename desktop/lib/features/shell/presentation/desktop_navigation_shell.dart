import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/desktop_theme.dart';
import '../../../core/widgets/modiri_background.dart';
import '../../ai/presentation/desktop_ai_assistant_screen.dart';
import '../../ai/presentation/desktop_ai_invoice_scanner_screen.dart';
import '../../appointments/presentation/desktop_appointments_screen.dart';
import '../../clinic/presentation/desktop_clinic_patients_screen.dart';
import '../../credit/presentation/desktop_credit_screen.dart';
import '../../customers/presentation/desktop_customers_screen.dart';
import '../../dashboard/presentation/desktop_dashboard_screen.dart';
import '../../employees/presentation/desktop_employees_screen.dart';
import '../../enterprise/presentation/desktop_enterprise_projects_screen.dart';
import '../../expenses/presentation/desktop_expenses_screen.dart';
import '../../invoices/presentation/desktop_invoices_screen.dart';
import '../../notifications/presentation/desktop_notifications_screen.dart';
import '../../pos_sales/presentation/desktop_pos_screen.dart';
import '../../products/presentation/desktop_inventory_screen.dart';
import '../../pharmacy/presentation/desktop_pharmacy_batches_screen.dart';
import '../../reports/presentation/desktop_reports_screen.dart';
import '../../restaurant/presentation/desktop_restaurant_orders_screen.dart';
import '../../restaurant/presentation/desktop_restaurant_inventory_screen.dart';
import '../../settings/presentation/desktop_settings_screen.dart';
import '../../suppliers/presentation/desktop_suppliers_screen.dart';

enum DesktopSection {
  dashboard,
  pos,
  inventory,
  restaurantInventory,
  restaurantOrders,
  clinicPatients,
  enterpriseProjects,
  appointments,
  pharmacyBatches,
  notifications,
  invoices,
  customers,
  suppliers,
  credit,
  expenses,
  employees,
  reports,
  aiScanInvoice,
  aiAssistant,
  settings,
}

class DesktopNavigationShell extends ConsumerStatefulWidget {
  const DesktopNavigationShell({super.key});

  @override
  ConsumerState<DesktopNavigationShell> createState() => _DesktopNavigationShellState();
}

class _DesktopNavigationShellState extends ConsumerState<DesktopNavigationShell> {
  DesktopSection _activeSection = DesktopSection.dashboard;
  bool _isCollapsed = false;
  bool _hasInternet = true;
  Timer? _netCheckTimer;

  @override
  void initState() {
    super.initState();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _checkInternet();
      _netCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkInternet());
    }
  }

  @override
  void dispose() {
    _netCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInternet() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final res = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 3));
      final online = res.isNotEmpty && res[0].rawAddress.isNotEmpty;
      if (mounted && _hasInternet != online) {
        setState(() => _hasInternet = online);
      }
    } catch (_) {
      try {
        final res2 = await InternetAddress.lookup('one.one.one.one').timeout(const Duration(seconds: 3));
        final online2 = res2.isNotEmpty && res2[0].rawAddress.isNotEmpty;
        if (mounted && _hasInternet != online2) {
          setState(() => _hasInternet = online2);
        }
      } catch (_) {
        if (mounted && _hasInternet != false) {
          setState(() => _hasInternet = false);
        }
      }
    }
  }

  void _navigateTo(String route) {
    final session = ref.read(sessionProvider);
    final bType = session.businessType?.toLowerCase() ?? 'company';

    setState(() {
      switch (route) {
        case 'pos':
          if (bType == 'restaurant' || bType == 'cafe') {
            _activeSection = DesktopSection.restaurantOrders;
          } else if (bType == 'clinic' || bType == 'dental_clinic') {
            _activeSection = DesktopSection.appointments;
          } else if (bType == 'company') {
            _activeSection = DesktopSection.enterpriseProjects;
          } else {
            _activeSection = DesktopSection.pos;
          }
          break;
        case 'inventory':
          if (bType == 'restaurant' || bType == 'cafe') {
            _activeSection = DesktopSection.restaurantInventory;
          } else {
            _activeSection = DesktopSection.inventory;
          }
          break;
        case 'kitchenStock':
        case 'restaurantInventory':
          _activeSection = DesktopSection.restaurantInventory;
          break;
        case 'reports':
          _activeSection = DesktopSection.reports;
          break;
        case 'aiAssistant':
          _activeSection = DesktopSection.aiAssistant;
          break;
        case 'aiScanInvoice':
        case 'scanInvoice':
        case 'scanner':
          _activeSection = DesktopSection.aiScanInvoice;
          break;
        case 'notifications':
          _activeSection = DesktopSection.notifications;
          break;
        case 'invoices':
          _activeSection = DesktopSection.invoices;
          break;
        case 'customers':
          _activeSection = DesktopSection.customers;
          break;
        case 'suppliers':
          _activeSection = DesktopSection.suppliers;
          break;
        case 'credit':
          _activeSection = DesktopSection.credit;
          break;
        case 'expenses':
          _activeSection = DesktopSection.expenses;
          break;
        case 'employees':
          _activeSection = DesktopSection.employees;
          break;
        case 'restaurantOrders':
        case 'orders':
        case 'tables':
          _activeSection = DesktopSection.restaurantOrders;
          break;
        case 'clinicPatients':
        case 'patients':
          _activeSection = DesktopSection.clinicPatients;
          break;
        case 'enterpriseProjects':
        case 'projects':
          _activeSection = DesktopSection.enterpriseProjects;
          break;
        case 'appointments':
          _activeSection = DesktopSection.appointments;
          break;
        case 'pharmacyBatches':
        case 'batches':
          _activeSection = DesktopSection.pharmacyBatches;
          break;
        case 'settings':
          _activeSection = DesktopSection.settings;
          break;
        default:
          _activeSection = DesktopSection.dashboard;
      }
    });
  }

  Widget _buildActiveScreen() {
    switch (_activeSection) {
      case DesktopSection.dashboard:
        return DesktopDashboardScreen(onNavigate: _navigateTo);
      case DesktopSection.pos:
        return const DesktopPosScreen();
      case DesktopSection.inventory:
        return const DesktopInventoryScreen();
      case DesktopSection.restaurantInventory:
        return const DesktopRestaurantInventoryScreen();
      case DesktopSection.restaurantOrders:
        return const DesktopRestaurantOrdersScreen();
      case DesktopSection.clinicPatients:
        return const DesktopClinicPatientsScreen();
      case DesktopSection.enterpriseProjects:
        return const DesktopEnterpriseProjectsScreen();
      case DesktopSection.appointments:
        return const DesktopAppointmentsScreen();
      case DesktopSection.pharmacyBatches:
        return const DesktopPharmacyBatchesScreen();
      case DesktopSection.notifications:
        return const DesktopNotificationsScreen();
      case DesktopSection.invoices:
        return const DesktopInvoicesScreen();
      case DesktopSection.customers:
        return const DesktopCustomersScreen();
      case DesktopSection.suppliers:
        return const DesktopSuppliersScreen();
      case DesktopSection.credit:
        return const DesktopCreditScreen();
      case DesktopSection.expenses:
        return const DesktopExpensesScreen();
      case DesktopSection.employees:
        return const DesktopEmployeesScreen();
      case DesktopSection.reports:
        return const DesktopReportsScreen();
      case DesktopSection.aiScanInvoice:
        return const DesktopAiInvoiceScannerScreen();
      case DesktopSection.aiAssistant:
        return const DesktopAiAssistantScreen();
      case DesktopSection.settings:
        return const DesktopSettingsScreen();
    }
  }

  Widget _navItem(IconData icon, String label, DesktopSection section, bool isDark) {
    final isActive = _activeSection == section;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: () => setState(() => _activeSection = section),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isActive ? ModiriColors.brandGradient : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: ModiriColors.brandBlue.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : ModiriColors.textSecondary(isDark),
              ),
              if (!_isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? Colors.white : ModiriColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(sessionProvider);
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final bType = session.businessType ?? 'company';
    final companyName = session.companyName ?? 'Modiri Business';
    final userInitials = (session.userName ?? 'Modiri User')
        .split(' ')
        .map((p) => p.isNotEmpty ? p[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final sidebarWidth = _isCollapsed ? 76.0 : 255.0;

    return Scaffold(
      backgroundColor: ModiriColors.canvas(isDark),
      body: ModiriBackground(
        child: Row(
          children: [
            // Left Navigation Sidebar matching website Sidebar.jsx
            Container(
              width: sidebarWidth,
              decoration: BoxDecoration(
                color: ModiriColors.surface(isDark),
                border: BorderDirectional(
                    end: BorderSide(color: ModiriColors.border(isDark), width: 1)),
              ),
              child: Column(
                children: [
                  // Brand Header with official logo
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: AlignmentDirectional.centerStart,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: ModiriColors.border(isDark), width: 1)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: ModiriColors.brandBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'MODIRI ',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ModiriColors.textPrimary(isDark)),
                                    ),
                                    const Text(
                                      'AI',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModiriColors.brandBlue),
                                    ),
                                  ],
                                ),
                                Text(
                                  companyName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: ModiriColors.textMuted(isDark)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Menu Items dynamically configured per business type
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      children: [
                        _navItem(Icons.dashboard_outlined, loc.get('dashboard'), DesktopSection.dashboard, isDark),

                        if (bType == 'restaurant' || bType == 'cafe') ...[
                          _navItem(Icons.restaurant_menu, loc.get('orders_tables'), DesktopSection.restaurantOrders, isDark),
                          _navItem(Icons.inventory_2_outlined, loc.get('kitchen_stock'), DesktopSection.restaurantInventory, isDark),
                        ] else if (bType == 'clinic' || bType == 'dental_clinic') ...[
                          _navItem(Icons.calendar_month_outlined, loc.get('appointments'), DesktopSection.appointments, isDark),
                          _navItem(Icons.medical_services_outlined, loc.get('patients_queue'), DesktopSection.clinicPatients, isDark),
                          _navItem(Icons.inventory_2_outlined, loc.get('medical_supplies'), DesktopSection.inventory, isDark),
                        ] else if (bType == 'pharmacy') ...[
                          _navItem(Icons.point_of_sale_outlined, loc.get('pos'), DesktopSection.pos, isDark),
                          _navItem(Icons.medication_outlined, loc.get('medication_batches'), DesktopSection.pharmacyBatches, isDark),
                          _navItem(Icons.inventory_2_outlined, loc.get('products_stock'), DesktopSection.inventory, isDark),
                          _navItem(Icons.book_outlined, loc.get('credit_ledger'), DesktopSection.credit, isDark),
                        ] else if (bType == 'company') ...[
                          _navItem(Icons.folder_special_outlined, loc.get('projects'), DesktopSection.enterpriseProjects, isDark),
                          _navItem(Icons.inventory_2_outlined, loc.get('company_assets'), DesktopSection.inventory, isDark),
                        ] else ...[
                          _navItem(Icons.point_of_sale_outlined, loc.get('pos'), DesktopSection.pos, isDark),
                          _navItem(Icons.inventory_2_outlined, loc.get('products_stock'), DesktopSection.inventory, isDark),
                          _navItem(Icons.book_outlined, loc.get('credit_ledger'), DesktopSection.credit, isDark),
                        ],

                        _navItem(Icons.receipt_long_outlined, loc.get('billing_invoices'), DesktopSection.invoices, isDark),
                        _navItem(Icons.people_outline, loc.get('customers'), DesktopSection.customers, isDark),
                        _navItem(Icons.local_shipping_outlined, loc.get('suppliers'), DesktopSection.suppliers, isDark),
                        _navItem(Icons.wallet_outlined, loc.get('expenses'), DesktopSection.expenses, isDark),
                        _navItem(Icons.badge_outlined, loc.get('employees'), DesktopSection.employees, isDark),
                        _navItem(Icons.bar_chart_outlined, loc.get('reports'), DesktopSection.reports, isDark),
                        _navItem(Icons.document_scanner_outlined, loc.get('ai_scanner'), DesktopSection.aiScanInvoice, isDark),
                        _navItem(Icons.auto_awesome, loc.get('ai_advisor'), DesktopSection.aiAssistant, isDark),
                        _navItem(Icons.settings_outlined, loc.get('settings'), DesktopSection.settings, isDark),
                      ],
                    ),
                  ),

                  // Bottom "Business Plan" Card matching website Sidebar.jsx
                  if (!_isCollapsed) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: InkWell(
                        onTap: () => setState(() => _activeSection = DesktopSection.settings),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandAmber.withOpacity(isDark ? 0.08 : 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.workspace_premium, color: ModiriColors.brandAmber, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.entitlementType == 'lifetime'
                                          ? 'Lifetime License Active'
                                          : loc.get('business_plan_active'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: ModiriColors.textPrimary(isDark),
                                      ),
                                    ),
                                    Text(
                                      'DZD · ${bType.toUpperCase()}',
                                      style: TextStyle(fontSize: 10, color: ModiriColors.textMuted(isDark)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Collapse Toggle Button
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: ModiriColors.border(isDark), width: 1)),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                        color: ModiriColors.textSecondary(isDark),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area (Topbar + Active Screen)
            Expanded(
              child: Column(
                children: [
                  // Website-Matching Topbar
                  Container(
                    height: 65,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: ModiriColors.surface(isDark),
                      border: Border(bottom: BorderSide(color: ModiriColors.border(isDark), width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Business Type Pill
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.business, size: 18, color: ModiriColors.brandBlue),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  companyName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ModiriColors.textPrimary(isDark),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('·', style: TextStyle(color: ModiriColors.textMuted(isDark))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ModiriColors.border(isDark)),
                                ),
                                child: Text(
                                  bType.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: ModiriColors.brandBlue,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: Controls & User Profile
                        Row(
                          children: [
                            // Interactive Sun/Moon Theme Toggle matching website ThemeToggle.jsx
                            Tooltip(
                              message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                              child: InkWell(
                                onTap: () {
                                  ref.read(desktopThemeModeProvider.notifier).toggleTheme();
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: ModiriColors.border(isDark)),
                                  ),
                                  child: Icon(
                                    isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                                    size: 16,
                                    color: isDark ? ModiriColors.brandAmber : ModiriColors.brandBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Interactive Language Selector Dropdown
                            PopupMenuButton<Locale>(
                              tooltip: 'Language / Langue / اللغة',
                              color: ModiriColors.card(isDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: ModiriColors.border(isDark)),
                              ),
                              onSelected: (loc) {
                                ref.read(desktopLocaleProvider.notifier).state = loc;
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: const Locale('en'),
                                  child: Text('English (EN)', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                                ),
                                PopupMenuItem(
                                  value: const Locale('fr'),
                                  child: Text('Français (FR)', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                                ),
                                PopupMenuItem(
                                  value: const Locale('ar'),
                                  child: Text('العربية (AR - RTL)', style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13)),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: ModiriColors.border(isDark)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.language, size: 14, color: ModiriColors.textSecondary(isDark)),
                                    const SizedBox(width: 6),
                                    Text(
                                      ref.watch(desktopLocaleProvider).languageCode.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down, size: 14, color: ModiriColors.textMuted(isDark)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Network Connection Status Indicator
                            Tooltip(
                              message: _hasInternet ? loc.get('online_connected') : loc.get('server_offline'),
                              child: InkWell(
                                onTap: _checkInternet,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: (_hasInternet ? ModiriColors.brandTeal : ModiriColors.brandAmber).withOpacity(isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: (_hasInternet ? ModiriColors.brandTeal : ModiriColors.brandAmber).withOpacity(0.4)),
                                  ),
                                  child: Icon(
                                    _hasInternet ? Icons.cloud_done : Icons.cloud_off,
                                    size: 16,
                                    color: _hasInternet ? ModiriColors.brandTeal : ModiriColors.brandAmber,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // AI Assistant Quick Launcher matching website
                            InkWell(
                              onTap: () => setState(() => _activeSection = DesktopSection.aiAssistant),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ModiriColors.brandViolet.withOpacity(isDark ? 0.12 : 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: ModiriColors.brandViolet.withOpacity(0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.auto_awesome, color: ModiriColors.brandViolet, size: 14),
                                    const SizedBox(width: 6),
                                    Text(loc.get('ai_advisor'),
                                        style: const TextStyle(color: ModiriColors.brandViolet, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Notifications Button with Unread Badge
                            IconButton(
                              icon: Badge(
                                smallSize: 8,
                                backgroundColor: ModiriColors.brandRose,
                                child: Icon(Icons.notifications_none, size: 20, color: ModiriColors.textSecondary(isDark)),
                              ),
                              tooltip: loc.get('notifications_alerts'),
                              onPressed: () => setState(() => _activeSection = DesktopSection.notifications),
                            ),
                            const SizedBox(width: 8),

                            // User Account Avatar & Dropdown
                            PopupMenuButton<String>(
                              color: ModiriColors.card(isDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: ModiriColors.border(isDark)),
                              ),
                              onSelected: (val) {
                                if (val == 'settings') {
                                  setState(() => _activeSection = DesktopSection.settings);
                                } else if (val == 'logout') {
                                  ref.read(sessionProvider.notifier).logout();
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  enabled: false,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(session.userName ?? loc.get('admin'),
                                          style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(session.userEmail ?? 'admin@modiri.ai',
                                          style: TextStyle(color: ModiriColors.textMuted(isDark), fontSize: 11)),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'settings',
                                  child: Row(
                                    children: [
                                      Icon(Icons.settings, size: 16, color: ModiriColors.textSecondary(isDark)),
                                      const SizedBox(width: 8),
                                      Text(loc.get('settings'), style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.logout, size: 16, color: ModiriColors.brandRose),
                                      const SizedBox(width: 8),
                                      Text(loc.get('logout'), style: const TextStyle(color: ModiriColors.brandRose, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: ModiriColors.brandGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      userInitials.isNotEmpty ? userInitials : 'MD',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.keyboard_arrow_down, size: 16, color: ModiriColors.textDarkMuted),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Screen Body
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey('shell_screen_${_activeSection.name}'),
                      child: _buildActiveScreen(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
