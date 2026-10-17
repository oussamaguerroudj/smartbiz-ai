import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/desktop_database.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/desktop_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/desktop_localizations.dart';
import '../../../core/widgets/modiri_panel.dart';
import '../../../core/widgets/modiri_stat_card.dart';
import '../../../core/utils/modiri_formatters.dart';

class DesktopDashboardScreen extends ConsumerStatefulWidget {
  final Function(String route)? onNavigate;

  const DesktopDashboardScreen({super.key, this.onNavigate});

  @override
  ConsumerState<DesktopDashboardScreen> createState() => _DesktopDashboardScreenState();
}

class _DesktopDashboardScreenState extends ConsumerState<DesktopDashboardScreen> {
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: 'DZD ', decimalDigits: 2);
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _stats;
  List<dynamic> _activeOrders = [];
  Map<String, dynamic>? _queueData;
  List<dynamic> _expiringProducts = [];
  bool _isOfflineData = false;
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final session = ref.read(sessionProvider);
    final bType = session.businessType ?? 'company';
    final client = ref.read(apiClientProvider);

    bool remoteSuccess = false;
    if (!session.isOfflineSession) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          await ref.read(desktopSyncServiceProvider.notifier).pullInitialData();
        } catch (_) {}
      }
      try {
        if (bType == 'restaurant' || bType == 'cafe') {
        final res = await Future.wait([
          client.get('/restaurant/dashboard'),
          client.get('/restaurant/orders', query: {'status': 'active'}),
        ]);
        final dashMap = res[0] is Map ? (res[0]['data'] ?? res[0]) : {};
        final ordersList = res[1] is List ? res[1] : (res[1] is Map ? (res[1]['data'] ?? []) : []);
        _stats = Map<String, dynamic>.from(dashMap is Map ? dashMap : {});
        _activeOrders = List<dynamic>.from(ordersList is List ? ordersList : []);
        remoteSuccess = true;
      } else if (bType == 'clinic' || bType == 'dental_clinic') {
        final res = await Future.wait([
          client.get('/clinic/dashboard'),
          client.get('/clinic/queue'),
        ]);
        final dashMap = res[0] is Map ? (res[0]['data'] ?? res[0]) : {};
        final qMap = res[1] is Map ? (res[1]['data'] ?? res[1]) : {};
        _stats = Map<String, dynamic>.from(dashMap is Map ? dashMap : {});
        _queueData = Map<String, dynamic>.from(qMap is Map ? qMap : {});
        remoteSuccess = true;
      } else if (bType == 'pharmacy') {
        final res = await Future.wait([
          client.get('/pharmacy/dashboard'),
          client.get('/pharmacy/expiring-products', query: {'days': '30'}),
        ]);
        final dashMap = res[0] is Map ? (res[0]['data'] ?? res[0]) : {};
        final expList = res[1] is List ? res[1] : (res[1] is Map ? (res[1]['data'] ?? []) : []);
        _stats = Map<String, dynamic>.from(dashMap is Map ? dashMap : {});
        _expiringProducts = List<dynamic>.from(expList is List ? expList : []);
        remoteSuccess = true;
      } else if (bType == 'superette' || bType == 'grocery' || bType == 'supermarket') {
        final res = await client.get('/superette/dashboard');
        final dashMap = res is Map ? (res['data'] ?? res) : {};
        _stats = Map<String, dynamic>.from(dashMap is Map ? dashMap : {});
        remoteSuccess = true;
      } else if (bType == 'clothing') {
        final res = await client.get('/clothing/dashboard');
        final dashMap = res is Map ? (res['data'] ?? res) : {};
        _stats = Map<String, dynamic>.from(dashMap is Map ? dashMap : {});
        remoteSuccess = true;
      } else if (bType == 'company') {
        final res = await client.get('/enterprise/dashboard');
        final dashMap = res is Map ? (res['data'] ?? res) : {};
        _stats = Map<String, dynamic>.from(dashMap is Map ? dashMap : {});
        remoteSuccess = true;
      } else {
        final res = await client.get('/dashboard/summary');
        final dashMap = res is Map ? (res['data'] ?? res) : {};
        _stats = Map<String, dynamic>.from(dashMap is Map ? dashMap : {});
        remoteSuccess = true;
      }
    } catch (_) {
      remoteSuccess = false;
    }
  }

    // Authoritative offline calculation from local SQLite
    final companyId = session.companyId;
    if (companyId != null) {
      try {
        final db = await ModiriDesktopDatabase.instance.database;
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final report = await DesktopLocalFinancialCalculator.calculateReport(
          period: 'daily',
          companyId: companyId,
          date: todayStr,
          customDb: db,
        );
        final lowStockRes = await db.rawQuery(
          'SELECT COUNT(*) as count FROM products WHERE company_id = ? AND stock_quantity <= minimum_stock',
          [companyId],
        );
        final unpaidRes = await db.rawQuery(
          "SELECT COUNT(*) as count FROM invoices WHERE company_id = ? AND status != 'paid'",
          [companyId],
        );
        final debtRes = await db.rawQuery(
          'SELECT COALESCE(SUM(credit_balance), 0.0) as debt FROM customers WHERE company_id = ?',
          [companyId],
        );
        final prodRes = await db.rawQuery(
          'SELECT COUNT(*) as count, COALESCE(SUM(stock_quantity), 0) as pieces FROM products WHERE company_id = ?',
          [companyId],
        );
        final projRes = await db.rawQuery(
          "SELECT COUNT(*) as count FROM enterprise_projects WHERE company_id = ? AND status != 'completed'",
          [companyId],
        );
        final payrollRes = await db.rawQuery(
          'SELECT COALESCE(SUM(base_salary), 0.0) as payroll FROM employees WHERE company_id = ?',
          [companyId],
        );
        final tablesTotalRes = await db.rawQuery(
          'SELECT COUNT(*) as count FROM restaurant_tables WHERE company_id = ?',
          [companyId],
        );
        final tablesOccRes = await db.rawQuery(
          "SELECT COUNT(*) as count FROM restaurant_tables WHERE company_id = ? AND status = 'occupied'",
          [companyId],
        );
        final aptTodayRes = await db.rawQuery(
          "SELECT COUNT(*) as count FROM appointments WHERE company_id = ? AND substr(appointment_date, 1, 10) = ?",
          [companyId, todayStr],
        );
        final aptDoneRes = await db.rawQuery(
          "SELECT COUNT(*) as count FROM appointments WHERE company_id = ? AND substr(appointment_date, 1, 10) = ? AND status = 'completed'",
          [companyId, todayStr],
        );

        final totalProds = (prodRes.first['count'] as num?)?.toInt() ?? 0;
        final localDefaults = {
          'todayRevenue': report.periodRevenue,
          'todayExpenses': report.periodExpenses,
          'todayProfit': report.periodNetProfit,
          'salesCount': report.salesCount,
          'lowStockCount': (lowStockRes.first['count'] as num?)?.toInt() ?? 0,
          'unpaidInvoicesCount': (unpaidRes.first['count'] as num?)?.toInt() ?? 0,
          'totalCreditDue': (debtRes.first['debt'] as num?)?.toDouble() ?? 0.0,
          'totalProducts': totalProds,
          'totalVariants': totalProds,
          'totalPiecesInStock': (prodRes.first['pieces'] as num?)?.toInt() ?? 0,
          'monthlyRevenue': report.periodRevenue,
          'monthlyExpenses': report.periodExpenses,
          'monthlyPayroll': (payrollRes.first['payroll'] as num?)?.toDouble() ?? 0.0,
          'activeProjectsCount': (projRes.first['count'] as num?)?.toInt() ?? 0,
          'ordersToday': report.salesCount,
          'activeOrders': _activeOrders.length,
          'tablesOccupied': (tablesOccRes.first['count'] as num?)?.toInt() ?? 0,
          'tablesTotal': (tablesTotalRes.first['count'] as num?)?.toInt() ?? 0,
          'reservationsToday': (aptTodayRes.first['count'] as num?)?.toInt() ?? 0,
          'outstandingPayments': (debtRes.first['debt'] as num?)?.toDouble() ?? 0.0,
          'appointmentsToday': (aptTodayRes.first['count'] as num?)?.toInt() ?? 0,
          'queueCount': (_queueData?['queue'] as List?)?.length ?? 0,
          'completedVisitsToday': (aptDoneRes.first['count'] as num?)?.toInt() ?? 0,
        };

        if (!remoteSuccess) {
          _stats = localDefaults;
          _isOfflineData = true;
        } else {
          _stats ??= {};
          localDefaults.forEach((k, v) {
            _stats!.putIfAbsent(k, () => v);
          });
          _isOfflineData = false;
        }
      } catch (localErr) {
        if (!remoteSuccess) {
          _error = 'Offline database error: $localErr';
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reconnectOnline() async {
    setState(() => _isReconnecting = true);
    final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
    try {
      final health = await ApiClient.checkHealth();
      if (health['healthy'] == true) {
        final session = ref.read(sessionProvider);
        if (session.isOfflineSession) {
          await ref.read(sessionProvider.notifier).updateTokens(
            accessToken: 'session_online_${session.companyId}_${DateTime.now().millisecondsSinceEpoch}',
          );
        }
        await ref.read(desktopSyncServiceProvider.notifier).syncPending();
        await _loadDashboardData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.get('online_connected')} (${health['latencyMs']}ms)'),
              backgroundColor: ModiriColors.brandTeal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.get('server_offline')}: ${health['error'] ?? 'Timeout'}'),
              backgroundColor: ModiriColors.brandAmber,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.get('server_offline')}: $e'),
            backgroundColor: ModiriColors.brandRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReconnecting = false);
    }
  }

  Future<void> _callNextPatient() async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/clinic/queue/call-next', body: {});
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        final loc = ModiriLocalizations(ref.read(desktopLocaleProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.get('call_next_failed')} $e'), backgroundColor: ModiriColors.brandRose),
        );
      }
    }
  }

  Widget _buildHeroBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required List<String> statusChips,
  }) {
    final now = DateTime.now();
    final locale = ref.watch(desktopLocaleProvider);
    final loc = ModiriLocalizations(locale);
    final greeting = now.hour < 12 ? loc.get('good_morning') : loc.get('hello');
    String dateStr;
    try {
      dateStr = ModiriFormatters.toLatinDigits(DateFormat('EEE, MMM d, yyyy', locale.languageCode).format(now));
    } catch (_) {
      dateStr = ModiriFormatters.toLatinDigits(DateFormat('EEE, MMM d, yyyy', 'en_US').format(now));
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33FFFFFF)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF070A1A),
            Color(0xFF05060F),
            Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ModiriColors.brandBlue.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: ModiriColors.brandBlue.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14, color: ModiriColors.brandBlue),
                                const SizedBox(width: 6),
                                Text(
                                  badge,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$greeting ☀️',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF05060F).withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: ModiriColors.brandBlue),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.15), height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ModiriColors.brandTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  loc.get('live_operations'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                  ),
                ),
                ...statusChips.map((chip) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Text(
                        chip,
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  StatCardTone _resolveTone(dynamic tone) {
    if (tone is StatCardTone) return tone;
    if (tone == ModiriColors.brandBlue) return StatCardTone.blue;
    if (tone == ModiriColors.brandViolet) return StatCardTone.violet;
    if (tone == ModiriColors.brandTeal) return StatCardTone.teal;
    if (tone == ModiriColors.brandAmber) return StatCardTone.amber;
    return StatCardTone.neutral;
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String sublabel,
    dynamic tone = StatCardTone.neutral,
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    return ModiriStatCard(
      icon: icon,
      label: label,
      value: value,
      sublabel: sublabel,
      tone: _resolveTone(tone),
      highlight: highlight,
      onTap: onTap,
    );
  }

  Widget _buildStatGrid({
    required List<Widget> children,
    int maxCols = 4,
    double targetHeight = 120.0,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = maxCols == 3
            ? (constraints.maxWidth > 1050 ? 3 : (constraints.maxWidth > 650 ? 2 : 1))
            : (constraints.maxWidth > 1150 ? 4 : (constraints.maxWidth > 750 ? 2 : 1));
        final itemWidth = (constraints.maxWidth - (cols - 1) * 16) / cols;
        final ratio = (itemWidth / targetHeight).clamp(1.2, 2.5);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: ratio,
          children: children,
        );
      },
    );
  }

  String _formatAmount(num? amount, Locale locale) {
    return ModiriFormatters.formatCurrency(amount, languageCode: locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(sessionProvider);
    final bType = session.businessType ?? 'company';
    final companyName = session.companyName ?? 'Modiri Business';
    final loc = ModiriLocalizations(ref.watch(desktopLocaleProvider));
    final locale = ref.watch(desktopLocaleProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Business-specific HeroBanner
          if (bType == 'restaurant' || bType == 'cafe') ...[
            _buildHeroBanner(
              title: companyName,
              subtitle: loc.get('hero_restaurant_subtitle'),
              icon: Icons.restaurant,
              badge: loc.get('hero_restaurant_badge'),
              statusChips: [
                '🔥 ${loc.get('hero_restaurant_chip1')}',
                '🍽️ ${loc.get('hero_restaurant_chip2')}',
                '🍷 ${loc.get('hero_restaurant_chip3')}',
              ],
            ),
          ] else if (bType == 'clinic' || bType == 'dental_clinic') ...[
            _buildHeroBanner(
              title: companyName,
              subtitle: loc.get('hero_clinic_subtitle'),
              icon: Icons.medical_services,
              badge: loc.get('hero_clinic_badge'),
              statusChips: [
                '🩺 ${loc.get('hero_clinic_chip1')}',
                '📋 ${loc.get('hero_clinic_chip2')}',
                '🕒 ${loc.get('hero_clinic_chip3')}',
              ],
            ),
          ] else if (bType == 'pharmacy') ...[
            _buildHeroBanner(
              title: companyName,
              subtitle: loc.get('hero_pharmacy_subtitle'),
              icon: Icons.medication,
              badge: loc.get('hero_pharmacy_badge'),
              statusChips: [
                '💊 ${loc.get('hero_pharmacy_chip1')}',
                '❄️ ${loc.get('hero_pharmacy_chip2')}',
                '📦 ${loc.get('hero_pharmacy_chip3')}',
              ],
            ),
          ] else if (bType == 'superette' || bType == 'grocery' || bType == 'supermarket') ...[
            _buildHeroBanner(
              title: companyName,
              subtitle: loc.get('hero_superette_subtitle'),
              icon: Icons.shopping_basket,
              badge: loc.get('hero_superette_badge'),
              statusChips: [
                '🛒 ${loc.get('hero_superette_chip1')}',
                '📦 ${loc.get('hero_superette_chip2')}',
                '💳 ${loc.get('hero_superette_chip3')}',
              ],
            ),
          ] else if (bType == 'clothing') ...[
            _buildHeroBanner(
              title: companyName,
              subtitle: loc.get('hero_clothing_subtitle'),
              icon: Icons.checkroom,
              badge: loc.get('hero_clothing_badge'),
              statusChips: [
                '👗 ${loc.get('hero_clothing_chip1')}',
                '🏷️ ${loc.get('hero_clothing_chip2')}',
                '✨ ${loc.get('hero_clothing_chip3')}',
              ],
            ),
          ] else if (bType == 'company') ...[
            _buildHeroBanner(
              title: companyName,
              subtitle: loc.get('hero_company_subtitle'),
              icon: Icons.business,
              badge: loc.get('hero_company_badge'),
              statusChips: [
                '📊 ${loc.get('hero_company_chip1')}',
                '💼 ${loc.get('hero_company_chip2')}',
                '👥 ${loc.get('hero_company_chip3')}',
              ],
            ),
          ] else ...[
            _buildHeroBanner(
              title: companyName,
              subtitle: loc.get('hero_general_subtitle'),
              icon: Icons.storefront,
              badge: loc.get('hero_general_badge'),
              statusChips: [
                '📈 ${loc.get('hero_general_chip1')}',
                '💼 ${loc.get('hero_general_chip2')}',
                '🤖 ${loc.get('hero_general_chip3')}',
              ],
            ),
          ],

          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModiriColors.brandRose.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ModiriColors.brandRose.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: ModiriColors.brandRose, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: ModiriColors.brandRose, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_isOfflineData) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ModiriColors.brandAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ModiriColors.brandAmber.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: ModiriColors.brandAmber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.get('working_offline'),
                      style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isReconnecting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sync, size: 16),
                    label: Text(_isReconnecting ? loc.get('checking_connection') : loc.get('reconnect_online')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModiriColors.brandBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isReconnecting ? null : _reconnectOnline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. StatCards Grid
          if (_isLoading) ...[
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: ModiriColors.brandBlue))),
          ] else ...[
            if (bType == 'restaurant' || bType == 'cafe') ...[
              _buildStatGrid(
                maxCols: 3,
                children: [
                  _buildStatCard(
                    icon: Icons.receipt_long,
                    label: loc.get('todays_orders'),
                    value: '${_stats?['ordersToday'] ?? 0}',
                    sublabel: loc.get('completed_and_in_progress'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.kitchen,
                    label: loc.get('active_kitchen_orders'),
                    value: '${_stats?['activeOrders'] ?? _activeOrders.length}',
                    sublabel: loc.get('currently_preparing'),
                    tone: ModiriColors.brandViolet,
                  ),
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: loc.get('todays_revenue'),
                    value: _formatAmount((_stats?['todayRevenue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('dining_takeaway_total'),
                    tone: ModiriColors.brandTeal,
                  ),
                  _buildStatCard(
                    icon: Icons.table_restaurant,
                    label: loc.get('occupied_tables'),
                    value: '${_stats?['tablesOccupied'] ?? 0}/${_stats?['tablesTotal'] ?? 0}',
                    sublabel: loc.get('dining_floor_occupancy'),
                    tone: ModiriColors.brandAmber,
                    highlight: true,
                  ),
                  _buildStatCard(
                    icon: Icons.book_online,
                    label: loc.get('reservations_today'),
                    value: '${_stats?['reservationsToday'] ?? 0}',
                    sublabel: loc.get('reservations_today_sublabel'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.pending_actions,
                    label: loc.get('unpaid_open_checks'),
                    value: _formatAmount((_stats?['outstandingPayments'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('awaiting_settlement'),
                    tone: ModiriColors.brandRose,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Restaurant Active Kitchen Orders Panel
              ModiriPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.kitchen, color: ModiriColors.brandAmber, size: 20),
                            const SizedBox(width: 8),
                            Text(loc.get('active_kitchen_orders'),
                                style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(loc.get('live_dispatch'), style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_activeOrders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(loc.get('no_active_kitchen_orders'),
                              style: TextStyle(color: ModiriColors.textSecondary(isDark), fontSize: 13)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _activeOrders.take(5).length,
                        separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 16),
                        itemBuilder: (ctx, i) {
                          final o = _activeOrders[i];
                          final table = o['table_label'] ?? o['tableLabel'] ?? 'Takeaway';
                          final status = (o['status'] ?? 'preparing').toString().toUpperCase();
                          final total = (o['total'] as num?)?.toDouble() ?? 0.0;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.table_restaurant, color: ModiriColors.brandBlue, size: 18),
                                  const SizedBox(width: 10),
                                  Text(table, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ModiriColors.brandAmber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(status, style: const TextStyle(color: ModiriColors.brandAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              Text(_formatAmount(total, locale), style: const TextStyle(color: ModiriColors.brandTeal, fontWeight: FontWeight.bold)),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ] else if (bType == 'clinic' || bType == 'dental_clinic') ...[
              _buildStatGrid(
                maxCols: 4,
                children: [
                  _buildStatCard(
                    icon: Icons.calendar_today,
                    label: loc.get('todays_appointments_label'),
                    value: '${_stats?['appointmentsToday'] ?? 0}',
                    sublabel: loc.get('scheduled_consultations_sublabel'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.people_outline,
                    label: loc.get('waiting_room_queue_label'),
                    value: '${_stats?['queueCount'] ?? (_queueData?['queue'] as List?)?.length ?? 0}',
                    sublabel: loc.get('patients_in_clinic_sublabel'),
                    tone: ModiriColors.brandAmber,
                    highlight: true,
                  ),
                  _buildStatCard(
                    icon: Icons.check_circle_outline,
                    label: loc.get('visits_completed_label'),
                    value: '${_stats?['completedVisitsToday'] ?? 0}',
                    sublabel: loc.get('consultations_finished_sublabel'),
                    tone: ModiriColors.brandTeal,
                  ),
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: loc.get('clinical_revenue_label'),
                    value: _formatAmount((_stats?['todayRevenue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('consultation_fees_sublabel'),
                    tone: ModiriColors.brandViolet,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Clinic Next In Line Queue Banner
              ModiriPanel(
                padding: const EdgeInsets.all(22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ModiriColors.brandBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.person_search, color: ModiriColors.brandBlue, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.get('next_in_line_consultation'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ModiriColors.brandBlue, letterSpacing: 0.8)),
                            const SizedBox(height: 4),
                            Text(
                              _queueData?['nextPatient'] is String
                                  ? _queueData!['nextPatient']
                                  : (_queueData?['nextPatient']?['patient_name'] ??
                                      _queueData?['nextPatient']?['fullName'] ??
                                      loc.get('no_patients_waiting')),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ModiriColors.textPrimary(isDark)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(_queueData?['queue'] as List?)?.length ?? 0} ${loc.get('patients_remaining_waiting_room')}',
                              style: TextStyle(fontSize: 12, color: ModiriColors.textSecondary(isDark)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.campaign, size: 18),
                      label: Text(loc.get('call_next_patient')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModiriColors.brandBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: _callNextPatient,
                    ),
                  ],
                ),
              ),
            ] else if (bType == 'pharmacy') ...[
              _buildStatGrid(
                maxCols: 4,
                children: [
                  _buildStatCard(
                    icon: Icons.warning_amber,
                    label: loc.get('expiring_30_days_label'),
                    value: '${_stats?['expiringSoonCount'] ?? _expiringProducts.length}',
                    sublabel: loc.get('medications_attention_sublabel'),
                    tone: ModiriColors.brandAmber,
                    highlight: true,
                  ),
                  _buildStatCard(
                    icon: Icons.inventory_2_outlined,
                    label: loc.get('low_stock_formulations_label'),
                    value: '${_stats?['lowStockCount'] ?? 0}',
                    sublabel: loc.get('below_min_threshold_sublabel'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: loc.get('dispensary_sales_label'),
                    value: _formatAmount((_stats?['todayRevenue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('dispensary_tx_sublabel'),
                    tone: ModiriColors.brandTeal,
                  ),
                  _buildStatCard(
                    icon: Icons.medication_outlined,
                    label: loc.get('active_medications_label'),
                    value: '${_stats?['totalProducts'] ?? 0}',
                    sublabel: loc.get('formulary_cataloged_sublabel'),
                    tone: ModiriColors.brandViolet,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Expiring Medications Alert Table
              ModiriPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber, color: ModiriColors.brandAmber, size: 20),
                        const SizedBox(width: 8),
                        Text(loc.get('expiring_medications_30_days'),
                            style: TextStyle(color: ModiriColors.textPrimary(isDark), fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_expiringProducts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(loc.get('no_medications_expiring'),
                              style: const TextStyle(color: ModiriColors.brandTeal, fontSize: 13)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _expiringProducts.take(4).length,
                        separatorBuilder: (_, __) => Divider(color: ModiriColors.border(isDark), height: 16),
                        itemBuilder: (ctx, i) {
                          final item = _expiringProducts[i];
                          final name = item['name'] ?? 'Medication';
                          final qty = item['quantity'] ?? 0;
                          final exp = item['expiration_date'] ?? '2026-11-01';
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: TextStyle(color: ModiriColors.textPrimary(isDark), fontWeight: FontWeight.bold)),
                              Text('${loc.get('stock_units_prefix')}$qty units', style: const TextStyle(color: ModiriColors.brandAmber)),
                              Text('${loc.get('expires_prefix')}$exp', style: const TextStyle(color: ModiriColors.brandRose, fontFamily: 'monospace')),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ] else if (bType == 'clothing') ...[
              _buildStatGrid(
                maxCols: 4,
                children: [
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: loc.get('boutique_sales_label'),
                    value: _formatAmount((_stats?['todayRevenue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('retail_garment_sublabel'),
                    tone: ModiriColors.brandTeal,
                  ),
                  _buildStatCard(
                    icon: Icons.checkroom,
                    label: loc.get('garments_in_stock_label'),
                    value: '${_stats?['totalPiecesInStock'] ?? 0}',
                    sublabel: loc.get('total_inventory_items_sublabel'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.style,
                    label: loc.get('unique_models_label'),
                    value: '${_stats?['totalVariants'] ?? 0}',
                    sublabel: loc.get('catalog_models_sublabel'),
                    tone: ModiriColors.brandViolet,
                  ),
                  _buildStatCard(
                    icon: Icons.warning_amber,
                    label: loc.get('low_stock_garments_label'),
                    value: '${_stats?['lowStockCount'] ?? 0}',
                    sublabel: loc.get('sizes_replenishment_sublabel'),
                    tone: ModiriColors.brandAmber,
                    highlight: true,
                  ),
                ],
              ),
            ] else if (bType == 'superette' || bType == 'grocery' || bType == 'supermarket') ...[
              _buildStatGrid(
                maxCols: 4,
                children: [
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: loc.get('gross_sales_label'),
                    value: _formatAmount((_stats?['todayRevenue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('cash_card_credit_sublabel'),
                    tone: ModiriColors.brandTeal,
                  ),
                  _buildStatCard(
                    icon: Icons.receipt_long,
                    label: loc.get('transactions_today_label'),
                    value: '${_stats?['salesCount'] ?? 0}',
                    sublabel: loc.get('cash_register_sublabel'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.warning_amber,
                    label: loc.get('low_stock_groceries_label'),
                    value: '${_stats?['lowStockCount'] ?? 0}',
                    sublabel: loc.get('items_below_threshold_sublabel'),
                    tone: ModiriColors.brandAmber,
                    highlight: true,
                  ),
                  _buildStatCard(
                    icon: Icons.credit_score,
                    label: loc.get('customer_credit_due_label'),
                    value: _formatAmount((_stats?['totalCreditDue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('outstanding_ledger_sublabel'),
                    tone: ModiriColors.brandViolet,
                  ),
                ],
              ),
            ] else if (bType == 'company') ...[
              _buildStatGrid(
                maxCols: 4,
                children: [
                  _buildStatCard(
                    icon: Icons.folder_special,
                    label: loc.get('active_projects_label'),
                    value: '${_stats?['activeProjectsCount'] ?? 0}',
                    sublabel: loc.get('corporate_accounts_sublabel'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: loc.get('monthly_invoiced_label'),
                    value: _formatAmount((_stats?['monthlyRevenue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('client_billings_sublabel'),
                    tone: ModiriColors.brandTeal,
                  ),
                  _buildStatCard(
                    icon: Icons.badge,
                    label: loc.get('monthly_payroll_label'),
                    value: _formatAmount((_stats?['monthlyPayroll'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('staff_compensation_sublabel'),
                    tone: ModiriColors.brandViolet,
                  ),
                  _buildStatCard(
                    icon: Icons.trending_down,
                    label: loc.get('operating_expenses_label'),
                    value: _formatAmount((_stats?['monthlyExpenses'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('operating_expenses_sublabel'),
                    tone: ModiriColors.brandAmber,
                    highlight: true,
                  ),
                ],
              ),
            ] else ...[
              // Standard / Generic Retail Dashboard
              _buildStatGrid(
                maxCols: 3,
                children: [
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: loc.get('todays_revenue'),
                    value: _formatAmount((_stats?['todayRevenue'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('recorded_operational_costs'),
                    tone: ModiriColors.brandTeal,
                  ),
                  _buildStatCard(
                    icon: Icons.trending_down,
                    label: loc.get('todays_expenses'),
                    value: _formatAmount((_stats?['todayExpenses'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('recorded_operational_costs'),
                    tone: ModiriColors.brandViolet,
                  ),
                  _buildStatCard(
                    icon: Icons.trending_up,
                    label: loc.get('todays_net_profit'),
                    value: _formatAmount((_stats?['todayProfit'] as num?)?.toDouble() ?? 0.0, locale),
                    sublabel: loc.get('revenue_minus_expenses'),
                    tone: ModiriColors.brandBlue,
                  ),
                  _buildStatCard(
                    icon: Icons.shopping_cart,
                    label: loc.get('sales_transactions'),
                    value: '${_stats?['salesCount'] ?? 0}',
                    sublabel: loc.get('completed_purchases'),
                    tone: ModiriColors.brandAmber,
                  ),
                  _buildStatCard(
                    icon: Icons.inventory_2,
                    label: loc.get('low_stock_products'),
                    value: '${_stats?['lowStockCount'] ?? 0}',
                    sublabel: loc.get('items_needing_restock'),
                    tone: ModiriColors.brandRose,
                  ),
                  _buildStatCard(
                    icon: Icons.receipt,
                    label: loc.get('unpaid_invoices_label'),
                    value: '${_stats?['unpaidInvoicesCount'] ?? 0}',
                    sublabel: loc.get('pending_client_payments'),
                    tone: ModiriColors.brandViolet,
                  ),
                ],
              ),
            ],
          ],

          const SizedBox(height: 28),

          // 3. Quick Action Buttons Bar matching website
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (bType == 'restaurant' || bType == 'cafe') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.restaurant_menu, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('orders_tables'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModiriColors.brandBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('restaurantOrders'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('kitchen_stock'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('restaurantInventory'),
                ),
              ] else if (bType == 'clinic' || bType == 'dental_clinic') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('appointments'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModiriColors.brandBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('appointments'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.medical_services_outlined, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('patients_queue'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('clinicPatients'),
                ),
              ] else if (bType == 'company') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_special_outlined, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('projects'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModiriColors.brandBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('enterpriseProjects'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('company_assets'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('inventory'),
                ),
              ] else if (bType == 'pharmacy') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.point_of_sale, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('open_pos_new_sale'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModiriColors.brandBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('pos'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.medication_outlined, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('medication_batches'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('pharmacyBatches'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.point_of_sale, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('open_pos_new_sale'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModiriColors.brandBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('pos'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.get('inventory_stock_button'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => widget.onNavigate?.call('inventory'),
                ),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart, size: 18),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.get('financial_reports_button'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => widget.onNavigate?.call('reports'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18, color: ModiriColors.brandViolet),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.get('ask_ai_advisor_button'), style: const TextStyle(fontWeight: FontWeight.bold, color: ModiriColors.brandViolet)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 14, color: ModiriColors.brandViolet),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  side: const BorderSide(color: ModiriColors.brandViolet),
                ),
                onPressed: () => widget.onNavigate?.call('aiAssistant'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
