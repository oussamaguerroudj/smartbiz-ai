import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Mirrors GET /dashboard exactly (Phase 5 dashboard.routes.js, verified
/// working end-to-end in testing — every field matched hand-computed
/// expectations). All numeric fields — the backend returns real JS
/// numbers here (not NUMERIC strings), since dashboard.routes.js casts
/// via Number()/COUNT(*)::int before responding.
class DashboardData {
  DashboardData({
    required this.todayRevenue,
    required this.todayExpenses,
    required this.todayProfit,
    required this.salesCount,
    required this.lowStockCount,
    required this.unpaidInvoicesCount,
    required this.upcomingAppointmentsCount,
  });

  final double todayRevenue;
  final double todayExpenses;
  final double todayProfit;
  final int salesCount;
  final int lowStockCount;
  final int unpaidInvoicesCount;
  final int upcomingAppointmentsCount;

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        todayRevenue: (json['todayRevenue'] as num).toDouble(),
        todayExpenses: (json['todayExpenses'] as num).toDouble(),
        todayProfit: (json['todayProfit'] as num).toDouble(),
        salesCount: json['salesCount'] as int,
        lowStockCount: json['lowStockCount'] as int,
        unpaidInvoicesCount: json['unpaidInvoicesCount'] as int,
        upcomingAppointmentsCount: json['upcomingAppointmentsCount'] as int,
      );
}

class DashboardRepository extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/dashboard');
      state = AsyncValue.data(DashboardData.fromJson(response['data'] as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final dashboardRepositoryProvider =
    StateNotifierProvider<DashboardRepository, AsyncValue<DashboardData>>(
  (ref) => DashboardRepository(ref),
);
