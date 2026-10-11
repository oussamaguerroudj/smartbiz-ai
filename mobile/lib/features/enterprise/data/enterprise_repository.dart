import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/local_financial_calculator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../domain/enterprise_models.dart';

class EnterpriseRepository {
  EnterpriseRepository(this._ref);
  final Ref _ref;

  String? get _companyId =>
      _ref.read(sessionProvider).companyId ?? _ref.read(sessionProvider).userId;

  Future<EnterpriseDashboardStats> dashboard() async {
    final companyId = _companyId;
    final isOnline = _ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (isOnline) {
      try {
        final client = _ref.read(apiClientProvider);
        dynamic response;
        try {
          response = await client.get('/enterprise/dashboard');
        } on ApiException catch (e) {
          if (e.statusCode == 404) {
            response = await client.get('/analytics/dashboard');
          } else {
            rethrow;
          }
        }
        final raw = response['data'] ?? response;
        final data = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
        return EnterpriseDashboardStats.fromJson(data);
      } catch (_) {}
    }

    if (companyId == null) return EnterpriseDashboardStats.empty;

    // Offline authoritative calculation from SQLite
    try {
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final dailyReport = await LocalFinancialCalculator.calculateReport(
        period: 'daily',
        companyId: companyId,
        date: todayStr,
      );
      final weeklyReport = await LocalFinancialCalculator.calculateReport(
        period: 'weekly',
        companyId: companyId,
      );
      final monthlyReport = await LocalFinancialCalculator.calculateReport(
        period: 'monthly',
        companyId: companyId,
      );
      return EnterpriseDashboardStats(
        todayRevenue: dailyReport.revenue,
        todayExpenses: dailyReport.expenses,
        todayNetProfit: dailyReport.netProfit,
        weekRevenue: weeklyReport.revenue,
        monthRevenue: monthlyReport.revenue,
        monthExpenses: monthlyReport.expenses,
        monthOperatingExpenses: monthlyReport.operatingExpenses,
        monthPayroll: monthlyReport.employeeSalaries,
        monthNetProfit: monthlyReport.netProfit,
        unpaidInvoicesCount: 0,
        unpaidInvoicesAmount: 0,
        unpaidInvoices: const [],
        clientBalancesOutstanding: 0,
        clientsCount: 0,
        employeesCount: monthlyReport.activitySummary.employeesCount,
        suppliersCount: 0,
        projects: EnterpriseProjectSummary(
          total: 0,
          active: 0,
          completed: 0,
          onHold: 0,
          cancelled: 0,
          planned: 0,
          overdue: 0,
        ),
        openProjects: const [],
      );
    } catch (_) {
      return EnterpriseDashboardStats.empty;
    }
  }

  Future<List<EnterpriseProject>> listProjects() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/enterprise/projects');
    return (response['data'] as List).cast<Map<String, dynamic>>().map(EnterpriseProject.fromJson).toList();
  }

  Future<EnterpriseProject> createProject({
    required String name,
    String? customerId,
    String? description,
    double? budget,
    String? startDate,
    String? dueDate,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.post('/enterprise/projects', body: {
      'name': name,
      if (customerId != null) 'customerId': customerId,
      if (description != null && description.isNotEmpty) 'description': description,
      if (budget != null) 'budget': budget,
      if (startDate != null) 'startDate': startDate,
      if (dueDate != null) 'dueDate': dueDate,
    });
    return EnterpriseProject.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateProjectStatus(String id, EnterpriseProjectStatus status) async {
    final client = _ref.read(apiClientProvider);
    await client.patch('/enterprise/projects/$id/status', body: {'status': status.apiValue});
  }
}

final enterpriseRepositoryProvider = Provider<EnterpriseRepository>((ref) => EnterpriseRepository(ref));
