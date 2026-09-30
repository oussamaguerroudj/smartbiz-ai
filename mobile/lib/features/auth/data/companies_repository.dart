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

  Future<CompanyInfo> updateMe({
    required String name,
    required String businessType,
    String? currency,
    String? phone,
    String? address,
  }) async {
    final client = _ref.read(apiClientProvider);
    final response = await client.put('/companies/me', body: {
      'name': name,
      'businessType': businessType,
      if (currency != null) 'currency': currency,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
    });
    _ref.invalidate(companyInfoProvider);
    return CompanyInfo.fromJson(response['data'] as Map<String, dynamic>);
  }
}

class CompanyInfo {
  CompanyInfo({
    required this.name,
    required this.businessType,
    this.currency = 'DZD',
    this.phone,
    this.address,
  });
  final String name;
  final String businessType;
  final String currency;
  final String? phone;
  final String? address;

  factory CompanyInfo.fromJson(Map<String, dynamic> json) => CompanyInfo(
        name: (json['name'] as String?) ?? '',
        businessType: (json['businessType'] as String?) ?? (json['business_type'] as String?) ?? '',
        currency: (json['currency'] as String?) ?? 'DZD',
        phone: json['phone'] as String?,
        address: json['address'] as String?,
      );
}

final companiesRepositoryProvider = Provider<CompaniesRepository>((ref) => CompaniesRepository(ref));

/// Loaded once per session for the Dashboard header. Deliberately
/// tolerant of failure (endpoint might 404 on older backends) — Dashboard
/// falls back to just the user's name with no business-type suffix
/// rather than crashing or showing fake text.
///
/// FIX (multi-user data isolation bug): this used to be a plain
/// FutureProvider, which Riverpod never disposes on its own. It fetched
/// once for whichever account was logged in first and then kept that
/// value cached for the lifetime of the app process — so logging out
/// and logging back in as a *different* account on the same device (no
/// full app restart) could show the *previous* user's business type on
/// the Dashboard/MainShell header. autoDispose ties this provider's
/// lifetime to whether anything is actually watching it: MainShell only
/// exists while `_AppPhase.main` is active, so logging out tears the
/// whole authenticated subtree down (see main.dart's AnimatedSwitcher +
/// KeyedSubtree), which disposes this provider; the next login rebuilds
/// MainShell and this refetches fresh for whichever account is now
/// signed in.
final companyInfoProvider = FutureProvider.autoDispose<CompanyInfo?>((ref) async {
  try {
    return await ref.read(companiesRepositoryProvider).getMe();
  } catch (_) {
    return null;
  }
});
