import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/dashboard_data.dart';

export '../domain/dashboard_data.dart';

class DashboardRepository extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<void> load() async {
    final companyId = _companyId;
    // TENANT ISOLATION: return empty/loading when no account is active.
    if (companyId == null) {
      if (!mounted) return;
      state = const AsyncValue.loading();
      return;
    }

    // 1. Immediately calculate from authoritative local SQLite — scoped to this company
    try {
      final local = await LocalFinancialCalculator.calculateDashboard(
        companyId: companyId,
      );
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {}

    // 2. Fetch authoritative dashboard from API in the background ONLY if online and no pending sync ops
    final status = _ref.read(connectionStatusProvider);
    final syncState = _ref.read(syncServiceProvider);
    if (status != ConnectionStatus.online || syncState.pendingCount > 0) {
      // While offline or having un-synced local mutations, SQLite is the ground truth
      return;
    }

    try {
      final client = _ref.read(apiClientProvider);
      final response = await client.get('/dashboard');
      if (!mounted) return;
      state = AsyncValue.data(DashboardData.fromJson(response['data'] as Map<String, dynamic>));
    } catch (e, st) {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current != null) {
        return; // Keep local calculated dashboard numbers
      }
      state = AsyncValue.error(e, st);
    }
  }
}

final dashboardRepositoryProvider =
    StateNotifierProvider<DashboardRepository, AsyncValue<DashboardData>>(
  (ref) {
    ref.watch(sessionProvider.select((s) => s.companyId));
    return DashboardRepository(ref);
  },
);
