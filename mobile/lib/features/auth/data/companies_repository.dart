import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Backs the Business Setup screen (Ch. 8.4) — persists the real
/// business name/type/currency/phone/address onto the placeholder
/// company that auth.service.js created during registration.
class CompaniesRepository {
  CompaniesRepository(this._ref);
  final Ref _ref;

  /// Real company name/business type for the Dashboard header
  /// ("Amine · Grocery Store") — added alongside the existing [updateMe]
  /// write method rather than as a new feature: the data already exists
  /// server-side (Setup writes it via PUT below), this just reads it
  /// back, the same pattern as every other GET in this app.
  Future<CompanyInfo> getMe() async {
    final client = _ref.read(apiClientProvider);
    final response = await client.get('/companies/me');
    return CompanyInfo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> updateMe({
    required String name,
    required String businessType,
    String? currency,
    String? phone,
    String? address,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/companies/me', body: {
      'name': name,
      'businessType': businessType,
      if (currency != null) 'currency': currency,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
    });
  }
}

class CompanyInfo {
  CompanyInfo({required this.name, required this.businessType});
  final String name;
  final String businessType;

  factory CompanyInfo.fromJson(Map<String, dynamic> json) => CompanyInfo(
        name: (json['name'] as String?) ?? '',
        businessType: (json['businessType'] as String?) ?? (json['business_type'] as String?) ?? '',
      );
}

final companiesRepositoryProvider = Provider<CompaniesRepository>((ref) => CompaniesRepository(ref));

/// Loaded once per session for the Dashboard header. Deliberately
/// tolerant of failure (endpoint might 404 on older backends) — Dashboard
/// falls back to just the user's name with no business-type suffix
/// rather than crashing or showing fake text.
final companyInfoProvider = FutureProvider<CompanyInfo?>((ref) async {
  try {
    return await ref.read(companiesRepositoryProvider).getMe();
  } catch (_) {
    return null;
  }
});
