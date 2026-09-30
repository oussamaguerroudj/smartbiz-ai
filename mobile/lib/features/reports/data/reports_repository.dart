import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
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
  final ApiClient _client;

  ReportsRepository(this._client);

  Future<ReportData> getReport({
    required String period,
    String? date,
    String? month,
    int? year,
  }) async {
    final query = <String, String>{'period': period};
    if (date != null && date.isNotEmpty) query['date'] = date;
    if (month != null && month.isNotEmpty) query['month'] = month;
    if (year != null) query['year'] = year.toString();

    final response = await _client.get(
      '/reports',
      query: query,
    );
    final data = response['data'] as Map<String, dynamic>;
    return ReportData.fromJson(data);
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReportsRepository(client);
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
