import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/desktop_shortcuts.dart';
import '../../dashboard/presentation/desktop_dashboard_screen.dart';
import '../../inventory/presentation/desktop_inventory_screen.dart';
import '../../invoices/presentation/desktop_invoices_screen.dart';
import '../../pos_sales/presentation/desktop_pos_screen.dart';
import '../../reports/presentation/desktop_reports_screen.dart';
import '../../settings/presentation/desktop_settings_screen.dart';

enum DesktopNavSection {
  dashboard,
  pos,
  inventory,
  invoices,
  reports,
  settings,
}

class DesktopNavigationShell extends ConsumerStatefulWidget {
  const DesktopNavigationShell({super.key});

  @override
  ConsumerState<DesktopNavigationShell> createState() =>
      _DesktopNavigationShellState();
}

class _DesktopNavigationShellState extends ConsumerState<DesktopNavigationShell> {
  DesktopNavSection _activeSection = DesktopNavSection.dashboard;
  bool _isSidebarCollapsed = false;

  void _onQuickSearch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevatedDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Quick Command Palette (Ctrl+K)',
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search actions, products, invoices, or settings...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.electricBlue),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 16),
              _buildPaletteItem(Icons.point_of_sale, 'Open POS & New Sale', () {
                Navigator.of(ctx).pop();
                setState(() => _activeSection = DesktopNavSection.pos);
              }),
              _buildPaletteItem(Icons.inventory_2_outlined, 'Open Product Inventory', () {
                Navigator.of(ctx).pop();
                setState(() => _activeSection = DesktopNavSection.inventory);
              }),
              _buildPaletteItem(Icons.analytics_outlined, 'Open Financial Reports', () {
                Navigator.of(ctx).pop();
                setState(() => _activeSection = DesktopNavSection.reports);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.electricBlue, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      dense: true,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: AppColors.surfaceHighlight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final sidebarWidth = _isSidebarCollapsed ? 74.0 : 250.0;

    return DesktopShortcutsWrapper(
      onQuickSearch: _onQuickSearch,
      onNewSale: () => setState(() => _activeSection = DesktopNavSection.pos),
      onEscape: () {
        if (_activeSection != DesktopNavSection.dashboard) {
          setState(() => _activeSection = DesktopNavSection.dashboard);
        }
      },
      child: Scaffold(
        body: AmbientBackground(
          child: Row(
            children: [
              // 1. Desktop Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: sidebarWidth,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.95),
                  border: const Border(
                    right: BorderSide(color: AppColors.borderDark, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: AppColors.aiGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          ),
                          if (!_isSidebarCollapsed) ...[
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MODIRI AI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    'ENTERPRISE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                      color: AppColors.electricBlue,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(color: AppColors.borderDark, height: 1),

                    // Quick Action Button
                    if (!_isSidebarCollapsed)
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _activeSection = DesktopNavSection.pos),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Sale (Ctrl+N)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.electricBlue,
                            foregroundColor: AppColors.cyberNavyDeep,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.add, color: AppColors.electricBlue),
                            onPressed: () => setState(() => _activeSection = DesktopNavSection.pos),
                            tooltip: 'New Sale (Ctrl+N)',
                          ),
                        ),
                      ),

                    // Navigation Links
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        children: [
                          _buildNavItem(
                            section: DesktopNavSection.dashboard,
                            icon: Icons.dashboard_outlined,
                            label: 'Dashboard',
                          ),
                          _buildNavItem(
                            section: DesktopNavSection.pos,
                            icon: Icons.point_of_sale_outlined,
                            label: 'POS & Sales',
                          ),
                          _buildNavItem(
                            section: DesktopNavSection.inventory,
                            icon: Icons.inventory_2_outlined,
                            label: 'Inventory',
                          ),
                          _buildNavItem(
                            section: DesktopNavSection.invoices,
                            icon: Icons.receipt_long_outlined,
                            label: 'Invoices',
                          ),
                          _buildNavItem(
                            section: DesktopNavSection.reports,
                            icon: Icons.insights_outlined,
                            label: 'Financial Reports',
                          ),
                          _buildNavItem(
                            section: DesktopNavSection.settings,
                            icon: Icons.settings_outlined,
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: AppColors.borderDark, height: 1),

                    // User Profile & Tenant Footer
                    Container(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.surfaceElevatedDark,
                            child: Text(
                              (session.userName != null && session.userName!.isNotEmpty)
                                  ? session.userName![0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                color: AppColors.electricBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (!_isSidebarCollapsed) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.userName ?? 'Administrator',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    session.companyName ?? 'Main Branch',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, size: 16, color: AppColors.textMuted),
                              tooltip: 'Sign Out',
                              onPressed: () => ref.read(sessionProvider.notifier).logout(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Sidebar Collapse Toggle
                    InkWell(
                      onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        color: AppColors.surfaceElevatedDark.withOpacity(0.5),
                        child: Icon(
                          _isSidebarCollapsed
                              ? Icons.keyboard_double_arrow_right
                              : Icons.keyboard_double_arrow_left,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Main Content View Area
              Expanded(
                child: Column(
                  children: [
                    // Top App Bar
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark.withOpacity(0.8),
                        border: const Border(
                          bottom: BorderSide(color: AppColors.borderDark, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Global Search Pill (Ctrl+K)
                          InkWell(
                            onTap: _onQuickSearch,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 320,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevatedDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.borderDark),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.search, size: 16, color: AppColors.textMuted),
                                  SizedBox(width: 8),
                                  Text(
                                    'Quick Search & Commands...',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                  Spacer(),
                                  Text(
                                    'Ctrl+K',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Status indicators
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.neonEmerald.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.neonEmerald.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: AppColors.neonEmerald),
                                SizedBox(width: 6),
                                Text(
                                  'SQLite & Cloud Synced',
                                  style: TextStyle(fontSize: 11, color: AppColors.neonEmerald, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Tenant Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.electricBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.electricBlue.withOpacity(0.3)),
                            ),
                            child: Text(
                              session.companyName ?? 'Enterprise',
                              style: const TextStyle(fontSize: 11, color: AppColors.electricBlue, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main View Content
                    Expanded(
                      child: _buildActiveView(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required DesktopNavSection section,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeSection == section;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: () => setState(() => _activeSection = section),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.electricBlue.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.electricBlue.withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.electricBlue : AppColors.textSecondary,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
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

  Widget _buildActiveView() {
    switch (_activeSection) {
      case DesktopNavSection.dashboard:
        return const DesktopDashboardScreen();
      case DesktopNavSection.pos:
        return const DesktopPosScreen();
      case DesktopNavSection.inventory:
        return const DesktopInventoryScreen();
      case DesktopNavSection.invoices:
        return const DesktopInvoicesScreen();
      case DesktopNavSection.reports:
        return const DesktopReportsScreen();
      case DesktopNavSection.settings:
        return const DesktopSettingsScreen();
    }
  }
}
