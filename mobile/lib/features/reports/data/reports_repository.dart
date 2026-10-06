import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_financial_calculator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session.dart';
import '../domain/report.dart';

class ReportFilter {
  final String period; // 'daily' | 'monthly' | 'yearly'
  final String? date; // 'YYYY-MM-DD'
  final String? month; // 'YYYY-MM'
  final int? year; // 2026

  const ReportFilter({
    required this.period,
    this.date,
    this.month,
    this.year,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportFilter &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          date == other.date &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode =>
      period.hashCode ^
      (date?.hashCode ?? 0) ^
      (month?.hashCode ?? 0) ^
      (year?.hashCode ?? 0);
}

class ReportsRepository {
  ReportsRepository(this._ref);
  final Ref _ref;

  String? get _companyId => _ref.read(sessionProvider).companyId;

  Future<ReportData> getReport({
    required String period,
    String? date,
    String? month,
    int? year,
  }) async {
    final companyId = _companyId;

    // 1. Calculate locally from SQLite first (guarantees offline support!)
    // TENANT ISOLATION: every query in calculateReport is scoped by companyId.
    // Returns an empty report when companyId is null (not logged in).
    ReportData? localReport;
    try {
      localReport = await LocalFinancialCalculator.calculateReport(
        period: period,
        companyId: companyId ?? '',
        date: date,
        month: month,
        year: year,
      );
    } catch (_) {}

    // 2. If online, try fetching authoritative server report
    try {
      final client = _ref.read(apiClientProvider);
      final query = <String, String>{'period': period};
      if (date != null && date.isNotEmpty) query['date'] = date;
      if (month != null && month.isNotEmpty) query['month'] = month;
      if (year != null) query['year'] = year.toString();

      final response = await client.get('/reports', query: query);
      final data = response['data'] as Map<String, dynamic>;
      return ReportData.fromJson(data);
    } catch (e) {
      // If server is unreachable or offline, return local report
      if (localReport != null) {
        return localReport;
      }
      rethrow;
    }
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref);
});

final reportProvider =
    FutureProvider.autoDispose.family<ReportData, String>((ref, period) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getReport(period: period);
});

final filteredReportProvider =
    FutureProvider.autoDispose.family<ReportData, ReportFilter>((ref, filter) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getReport(
    period: filter.period,
    date: filter.date,
    month: filter.month,
    year: filter.year,
  );
});
