import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/sync_status_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../../ai/presentation/screens/ai_scanner_screen.dart';
import '../../../appointments/presentation/screens/appointments_screen.dart';
import '../../../auth/data/companies_repository.dart';
import '../../../clinic/presentation/screens/clinic_patients_screen.dart';
import '../../../clinic/presentation/screens/clinic_queue_screen.dart';
import '../../../credit/presentation/screens/credit_screen.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../employees/presentation/screens/employees_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../products/presentation/screens/products_list_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../restaurant/presentation/screens/restaurant_inventory_screen.dart';
import '../../../restaurant/presentation/screens/restaurant_menu_screen.dart';
import '../../../restaurant/presentation/screens/restaurant_orders_screen.dart';
import '../../../restaurant/presentation/screens/restaurant_reservations_screen.dart';
import '../../../restaurant/presentation/screens/restaurant_tables_screen.dart';
import '../../../sales/presentation/screens/sales_list_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../suppliers/presentation/screens/suppliers_screen.dart';
import 'dashboard_screen.dart' show showScanInvoiceChooser;

/// Complete Directory of All Pages across the entire Modiri Application.
/// Accessible for ALL business types.
class AllPagesScreen extends ConsumerWidget {
  const AllPagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final businessType = ref.watch(companyInfoProvider).valueOrNull?.businessType;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allPagesTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // Section 1: Core Operations
          _buildCategoryHeader(context, l10n.allPagesSubtitle),
          const SizedBox(height: AppSpacing.xs),
          _buildGrid(context, [
            _PageItem(
              label: l10n.moreInvoices,
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF3D55F5),
              onTap: () => _open(context, const InvoicesScreen()),
            ),
            _PageItem(
              label: l10n.moreExpenses,
              icon: Icons.payments_outlined,
              color: const Color(0xFFF0654A),
              onTap: () => _open(context, const ExpensesScreen()),
            ),
            _PageItem(
              label: l10n.moreEmployees,
              icon: Icons.badge_outlined,
              color: const Color(0xFF0EA5E9),
              onTap: () => _open(context, const EmployeesScreen()),
            ),
            _PageItem(
              label: l10n.moreCustomers,
              icon: Icons.people_outline,
              color: const Color(0xFF10B981),
              onTap: () => _open(context, const CustomersScreen()),
            ),
            _PageItem(
              label: l10n.moreAppointments,
              icon: Icons.event_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => _open(context, const AppointmentsScreen()),
            ),
            _PageItem(
              label: l10n.creditPageTitle,
              icon: Icons.credit_card_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () => _open(context, const CreditScreen()),
            ),
            _PageItem(
              label: l10n.moreSuppliers,
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFF6366F1),
              onTap: () => _open(context, const SuppliersScreen()),
            ),
            _PageItem(
              label: l10n.moreReports,
              icon: Icons.bar_chart_outlined,
              color: const Color(0xFFEC4899),
              onTap: () => _open(context, const ReportsScreen()),
            ),
          ]),

          const SizedBox(height: AppSpacing.md),

          // Section 2: AI & Smart Operations
          _buildCategoryHeader(context, l10n.moreAiAssistant),
          const SizedBox(height: AppSpacing.xs),
          _buildGrid(context, [
            _PageItem(
              label: l10n.moreAiAssistant,
              icon: Icons.smart_toy_outlined,
              color: const Color(0xFF06B6D4),
              onTap: () => _open(context, const AiAssistantScreen()),
            ),
            _PageItem(
              label: l10n.moreAiScanner,
              icon: Icons.document_scanner_outlined,
              color: const Color(0xFF3B82F6),
              onTap: () => showScanInvoiceChooser(context),
            ),
            _PageItem(
              label: l10n.moreAiInsights,
              icon: Icons.insights_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => _open(context, const AiInsightsScreen()),
            ),
          ]),

          const SizedBox(height: AppSpacing.md),

          // Section 3: Sales POS & Products Inventory
          _buildCategoryHeader(context, '${l10n.navSales} & ${l10n.navInventory}'),
          const SizedBox(height: AppSpacing.xs),
          _buildGrid(context, [
            _PageItem(
              label: l10n.salesPosTitle,
              icon: Icons.point_of_sale_outlined,
              color: const Color(0xFF10B981),
              onTap: () => _open(context, const SalesListScreen()),
            ),
            _PageItem(
              label: l10n.navInventory,
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFFF97316),
              onTap: () => _open(context, const ProductsListScreen()),
            ),
          ]),

          // Section 4: Specialized Vertical Modules
          if (businessType == 'clinic' || businessType == 'dental_clinic') ...[
            const SizedBox(height: AppSpacing.md),
            _buildCategoryHeader(context, l10n.clinicDashboardTitle),
            const SizedBox(height: AppSpacing.xs),
            _buildGrid(context, [
              _PageItem(
                label: l10n.clinicQueueTitle,
                icon: Icons.groups_outlined,
                color: const Color(0xFF3B82F6),
                onTap: () => _open(context, const ClinicQueueScreen()),
              ),
              _PageItem(
                label: l10n.clinicPatientsTitle,
                icon: Icons.people_alt_outlined,
                color: const Color(0xFF10B981),
                onTap: () => _open(context, const ClinicPatientsScreen()),
              ),
            ]),
          ] else if (businessType == 'restaurant' || businessType == 'cafe') ...[
            const SizedBox(height: AppSpacing.md),
            _buildCategoryHeader(context, l10n.restaurantDashboardTitle),
            const SizedBox(height: AppSpacing.xs),
            _buildGrid(context, [
              _PageItem(
                label: l10n.ordersTitle,
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => _open(context, const RestaurantOrdersScreen()),
              ),
              _PageItem(
                label: l10n.tablesTitle,
                icon: Icons.table_restaurant_outlined,
                color: const Color(0xFF3B82F6),
                onTap: () => _open(context, const RestaurantTablesScreen()),
              ),
              _PageItem(
                label: l10n.menuTitle,
                icon: Icons.restaurant_menu_outlined,
                color: const Color(0xFF10B981),
                onTap: () => _open(context, const RestaurantMenuScreen()),
              ),
              _PageItem(
                label: l10n.reservationsTitle,
                icon: Icons.event_seat_outlined,
                color: const Color(0xFF8B5CF6),
                onTap: () => _open(context, const RestaurantReservationsScreen()),
              ),
              _PageItem(
                label: l10n.navInventory,
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFFF97316),
                onTap: () => _open(context, const RestaurantInventoryScreen()),
              ),
            ]),
          ],

          const SizedBox(height: AppSpacing.md),

          // Section 5: Preferences & App Maintenance
          _buildCategoryHeader(context, l10n.moreSettings),
          const SizedBox(height: AppSpacing.xs),
          _buildGrid(context, [
            _PageItem(
              label: l10n.moreNotifications,
              icon: Icons.notifications_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () => _open(context, const NotificationsScreen()),
            ),
            _PageItem(
              label: l10n.syncDetails,
              icon: Icons.sync_alt_rounded,
              color: const Color(0xFF0EA5E9),
              onTap: () => showDialog(
                context: context,
                builder: (_) => const SyncStatusDialog(),
              ),
            ),
            _PageItem(
              label: l10n.moreSettings,
              icon: Icons.settings_outlined,
              color: const Color(0xFF64748B),
              onTap: () => _open(context, const SettingsScreen()),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<_PageItem> items) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 360 ? 4 : 3;
          final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 8) / crossAxisCount;

          return Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (int i = 0; i < items.length; i++)
                SizedBox(
                  width: itemWidth,
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 20 * i),
                    child: InkWell(
                      onTap: items[i].onTap,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: items[i].color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(items[i].icon, color: items[i].color, size: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            items[i].label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PageItem {
  const _PageItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
