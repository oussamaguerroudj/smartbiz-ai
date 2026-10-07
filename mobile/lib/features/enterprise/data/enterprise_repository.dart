import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/enterprise_models.dart';

class EnterpriseRepository {
  EnterpriseRepository(this._ref);
  final Ref _ref;

  Future<EnterpriseDashboardStats> dashboard() async {
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
