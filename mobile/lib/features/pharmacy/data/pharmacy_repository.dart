import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/pharmacy_models.dart';

class PharmacyRepository {
  PharmacyRepository(this._ref);
  final Ref _ref;

  Future<PharmacyDashboardStats> dashboard() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/pharmacy/dashboard');
    return PharmacyDashboardStats.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<PharmacyExpiringProduct>> expiringProducts({int days = 30}) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/pharmacy/expiring-products', query: {'days': '$days'});
    final rows = (response['data'] as List).cast<Map<String, dynamic>>();
    return rows.map(PharmacyExpiringProduct.fromJson).toList();
  }
}

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) => PharmacyRepository(ref));
