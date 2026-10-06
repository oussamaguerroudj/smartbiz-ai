import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ai/presentation/screens/ai_assistant_screen.dart';
import '../../../appointments/presentation/screens/appointments_screen.dart';
import '../../../credit/presentation/screens/credit_screen.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../employees/presentation/screens/employees_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../suppliers/presentation/screens/suppliers_screen.dart';
import '../screens/all_pages_screen.dart';

/// Quick-access "Pages" section surfaced directly on ALL business type dashboards.
/// Provides immediate, one-tap navigation to:
/// - Invoices
/// - Expenses
/// - Employees
/// - Clients (Customers)
/// - Appointments
/// - Debt (Credit)
/// - Mwardin (Suppliers)
/// - Reports
/// - AI Assistant
/// - Extra / All Pages
class DashboardPagesSection extends StatelessWidget {
  const DashboardPagesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final items = [
      _DashboardPageItem(
        label: l10n.moreInvoices,
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF3D55F5), // Indigo
        onTap: () => _open(context, const InvoicesScreen()),
      ),
      _DashboardPageItem(
        label: l10n.moreExpenses,
        icon: Icons.payments_outlined,
        color: const Color(0xFFF0654A), // Coral
        onTap: () => _open(context, const ExpensesScreen()),
      ),
      _DashboardPageItem(
        label: l10n.moreEmployees,
        icon: Icons.badge_outlined,
        color: const Color(0xFF0EA5E9), // Sky
        onTap: () => _open(context, const EmployeesScreen()),
      ),
      _DashboardPageItem(
        label: l10n.moreCustomers,
        icon: Icons.people_outline,
        color: const Color(0xFF10B981), // Emerald
        onTap: () => _open(context, const CustomersScreen()),
      ),
      _DashboardPageItem(
        label: l10n.moreAppointments,
        icon: Icons.event_outlined,
        color: const Color(0xFF8B5CF6), // Purple
        onTap: () => _open(context, const AppointmentsScreen()),
      ),
      _DashboardPageItem(
        label: l10n.creditPageTitle,
        icon: Icons.credit_card_outlined,
        color: const Color(0xFFF59E0B), // Amber
        onTap: () => _open(context, const CreditScreen()),
      ),
      _DashboardPageItem(
        label: l10n.moreSuppliers,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF6366F1), // Indigo violet
        onTap: () => _open(context, const SuppliersScreen()),
      ),
      _DashboardPageItem(
        label: l10n.moreReports,
        icon: Icons.bar_chart_outlined,
        color: const Color(0xFFEC4899), // Pink
        onTap: () => _open(context, const ReportsScreen()),
      ),
      _DashboardPageItem(
        label: l10n.moreAiAssistant,
        icon: Icons.smart_toy_outlined,
        color: const Color(0xFF06B6D4), // Cyan
        onTap: () => _open(context, const AiAssistantScreen()),
      ),
      _DashboardPageItem(
        label: l10n.extraPagesTitle,
        icon: Icons.apps_rounded,
        color: const Color(0xFF475569), // Slate
        onTap: () => _open(context, const AllPagesScreen()),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppSpacing.cardElevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.grid_view_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.dashboardPagesTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                onTap: () => _open(context, const AllPagesScreen()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        l10n.viewAllAction,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 360;
              final crossAxisCount = isWide ? 5 : 4;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 6,
                  mainAxisExtent: 76,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.label,
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
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _DashboardPageItem {
  const _DashboardPageItem({
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
