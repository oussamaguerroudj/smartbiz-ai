import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/dashboard_data.dart';

export '../domain/dashboard_data.dart';

class DashboardRepository extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardRepository(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  Future<void> load() async {
    final session = _ref.read(sessionProvider);
    if (!session.isLoggedIn) {
      if (!mounted) return;
      state = const AsyncValue.loading();
      return;
    }

    final companyId = _companyId ?? 'default';

    // 1. Immediately calculate from authoritative local SQLite  -  scoped to this company
    DashboardData? local;
    try {
      local = await LocalFinancialCalculator.calculateDashboard(
        companyId: companyId,
      );
      if (!mounted) return;
      state = AsyncValue.data(local);
    } catch (_) {
      local = DashboardData.empty;
      if (!mounted) return;
      state = AsyncValue.data(local);
    }

    // 2. Fetch authoritative dashboard from API in the background ONLY if online and no pending sync ops
    final status = _ref.read(connectionStatusProvider);
    final syncState = _ref.read(syncServiceProvider);
    if (status != ConnectionStatus.online || syncState.pendingCount > 0) {
      // While offline or having un-synced local mutations, SQLite is the ground truth
      return;
    }

    try {
      final client = _ref.read(apiClientProvider);
      dynamic response;
      try {
        response = await client.get('/dashboard');
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          try {
            response = await client.get('/analytics/dashboard');
          } on ApiException catch (e2) {
            if (e2.statusCode == 404) {
              response = await client.get('/analytics');
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      final rawData = response['data'] ?? response;
      final data = rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{});
      state = AsyncValue.data(DashboardData.fromJson(data));
    } catch (_) {
      if (!mounted) return;
      final current = state.valueOrNull;
      if (current != null) {
        return; // Keep local calculated or empty dashboard numbers
      }
      state = AsyncValue.data(local);
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
