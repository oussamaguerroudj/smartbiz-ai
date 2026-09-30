import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/clothing_models.dart';

class ClothingRepository {
  ClothingRepository(this._ref);
  final Ref _ref;

  Future<ClothingDashboardStats> dashboard() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/clothing/dashboard');
    return ClothingDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
  }
}

final clothingRepositoryProvider = Provider<ClothingRepository>((ref) => ClothingRepository(ref));
