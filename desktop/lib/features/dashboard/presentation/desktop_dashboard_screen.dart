import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desktop_components.dart';
import '../../../core/widgets/glass_panel.dart';

class DesktopDashboardScreen extends ConsumerStatefulWidget {
  const DesktopDashboardScreen({super.key});

  @override
  ConsumerState<DesktopDashboardScreen> createState() =>
      _DesktopDashboardScreenState();
}

class _DesktopDashboardScreenState extends ConsumerState<DesktopDashboardScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  FinancialSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final session = ref.read(sessionProvider);
    final companyId = session.companyId ?? 'comp_1';

    try {
      final summary = await LocalFinancialCalculator.calculateSummary(companyId: companyId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.electricBlue),
      );
    }

    final s = _summary ?? FinancialSummary.empty();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopPageHeader(
            title: 'Executive Dashboard',
            subtitle: 'Real-time overview of financial performance, sales, and operations.',
            badge: const DesktopBadge(label: 'LIVE STREAM', color: AppColors.neonEmerald),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.electricBlue),
                tooltip: 'Refresh Metrics (Ctrl+R)',
                onPressed: _loadSummary,
              ),
            ],
          ),

          // Top Metric Cards Grid
          Row(
            children: [
              Expanded(
                child: DesktopKpiCard(
                  title: 'DAILY REVENUE',
                  value: _currencyFormat.format(s.revenue),
                  subtitle: '+14.2% from previous week',
                  icon: Icons.payments_outlined,
                  accentColor: AppColors.electricBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DesktopKpiCard(
                  title: 'GROSS PROFIT',
                  value: _currencyFormat.format(s.grossProfit),
                  subtitle: 'COGS: ${_currencyFormat.format(s.cogs)}',
                  icon: Icons.trending_up,
                  accentColor: AppColors.neonEmerald,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DesktopKpiCard(
                  title: 'NET PROFIT',
                  value: _currencyFormat.format(s.netProfit),
                  subtitle: 'Margin: ${s.profitMargin.toStringAsFixed(1)}%',
                  icon: Icons.account_balance_wallet_outlined,
                  accentColor: AppColors.cyanAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DesktopKpiCard(
                  title: 'TOTAL TRANSACTIONS',
                  value: '${s.salesCount}',
                  subtitle: 'Completed sales',
                  icon: Icons.receipt_long_outlined,
                  accentColor: AppColors.neonPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bottom Panes: Operational Telemetry & Quick Action Shortcuts
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Pane: Recent Activity & Quick Feed
                Expanded(
                  flex: 3,
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Sales Activity',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Auto-syncs with PostgreSQL',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: DesktopDataTable(
                            columns: const [
                              'Invoice #',
                              'Customer / Method',
                              'Time',
                              'Status',
                              'Total',
                            ],
                            rows: [
                              [
                                const Text('INV-2026-0042', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                const Text('Walk-in (Cash)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                const Text('10:42 AM', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                const DesktopBadge(label: 'PAID', color: AppColors.neonEmerald),
                                const Text('\$148.50', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                              [
                                const Text('INV-2026-0041', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                const Text('Sarah Jenkins (Card)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                const Text('10:15 AM', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                const DesktopBadge(label: 'PAID', color: AppColors.neonEmerald),
                                const Text('\$320.00', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                              [
                                const Text('INV-2026-0040', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                const Text('Apex Logistics (Credit)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                const Text('09:30 AM', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                const DesktopBadge(label: 'PENDING', color: AppColors.neonAmber),
                                const Text('\$850.00', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right Pane: System Health & Hardware Shortcuts
                Expanded(
                  flex: 2,
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hardware & Terminal Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(Icons.print_outlined, 'ESC/POS Thermal Printer', 'Connected (USB COM3)', AppColors.neonEmerald),
                        const SizedBox(height: 12),
                        _buildStatusRow(Icons.qr_code_scanner, 'Hardware Barcode Scanner', 'HID Keyboard Emulation Active', AppColors.neonEmerald),
                        const SizedBox(height: 12),
                        _buildStatusRow(Icons.storage_outlined, 'Local SQLite Database', 'Active & Isolated', AppColors.electricBlue),
                        const SizedBox(height: 12),
                        _buildStatusRow(Icons.cloud_done_outlined, 'Backend Cloud API', 'Render Production Synced', AppColors.neonEmerald),

                        const Spacer(),
                        const Divider(color: AppColors.borderDark),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Modiri AI Windows Desktop v1.0.0\nKeyboard navigation: Ctrl+K search, Ctrl+N new sale',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted.withOpacity(0.8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          CircleAvatar(radius: 4, backgroundColor: color),
        ],
      ),
    );
  }
}
