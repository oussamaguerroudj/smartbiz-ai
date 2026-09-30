import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/superette_models.dart';

class SuperetteRepository {
  SuperetteRepository(this._ref);
  final Ref _ref;

  Future<SuperetteDashboardStats> dashboard() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/superette/dashboard');
    return SuperetteDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
  }
}

final superetteRepositoryProvider = Provider<SuperetteRepository>((ref) => SuperetteRepository(ref));
