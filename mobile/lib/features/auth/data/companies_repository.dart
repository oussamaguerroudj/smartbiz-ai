import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';

/// Backs the Business Setup screen (Ch. 8.4) — persists the real
/// business name/type/currency/phone/address onto the placeholder
/// company that auth.service.js created during registration.
class CompaniesRepository {
  CompaniesRepository(this._ref);
  final Ref _ref;

  /// Real company name/business type for the Dashboard header
  /// Reads from local SQLite sync_metadata when offline, and caches network responses.
  Future<CompanyInfo> getMe() async {
    final session = _ref.read(sessionProvider);
    final companyId = session.companyId ?? session.userId ?? 'default';
    final metadataKey = 'company_info_$companyId';

    // 1. Try tenant-scoped local cache first
    CompanyInfo? cached;
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        'sync_metadata',
        where: 'key = ?',
        whereArgs: [metadataKey],
      );
      if (rows.isNotEmpty && rows.first['value'] != null) {
        final json = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
        cached = CompanyInfo.fromJson(json);
      }
    } catch (_) {}

    final fallback = CompanyInfo(
      name: (session.userName?.isNotEmpty == true) ? session.userName! : 'My Business',
      businessType: session.businessType ?? cached?.businessType ?? 'company',
      currency: 'DZD',
      phone: session.phone,
    );

    // 2. Only attempt network if logged in and online
    final status = _ref.read(connectionStatusProvider);
    if (!session.isLoggedIn || status != ConnectionStatus.online) {
      return cached ?? fallback;
    }

    // 3. Fetch fresh from backend: try /companies/me, fallback to /business/me, /business
    try {
      final client = _ref.read(apiClientProvider);
      dynamic response;
      try {
        response = await client.get('/companies/me');
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          try {
            response = await client.get('/business/me');
          } on ApiException catch (e2) {
            if (e2.statusCode == 404) {
              response = await client.get('/business');
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      final rawData = response['data'] ?? response;
      final data = rawData is Map<String, dynamic>
          ? rawData
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{});
      final info = CompanyInfo.fromJson(data);

      try {
        final db = await AppDatabase.instance.database;
        await db.insert(
          'sync_metadata',
          {
            'key': metadataKey,
            'value': jsonEncode(data),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}

      return info;
    } catch (e) {
      return cached ?? fallback;
    }
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
    final data = response['data'] as Map<String, dynamic>;
    final info = CompanyInfo.fromJson(data);

    final companyId = _ref.read(sessionProvider).companyId;
    if (companyId != null) {
      try {
        final db = await AppDatabase.instance.database;
        await db.insert(
          'sync_metadata',
          {
            'key': 'company_info_$companyId',
            'value': jsonEncode(data),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }

    _ref.invalidate(companyInfoProvider);
    return info;
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
        name: (json['name'] as String?) ??
            (json['businessName'] as String?) ??
            (json['business_name'] as String?) ??
            '',
        businessType: (json['businessType'] as String?) ??
            (json['business_type'] as String?) ??
            (json['type'] as String?) ??
            (json['industry'] as String?) ??
            'company',
        currency: (json['currency'] as String?) ?? 'DZD',
        phone: json['phone'] as String?,
        address: json['address'] as String?,
      );
}

final companiesRepositoryProvider = Provider<CompaniesRepository>((ref) => CompaniesRepository(ref));

final companyInfoProvider = FutureProvider.autoDispose<CompanyInfo?>((ref) async {
  ref.watch(sessionProvider.select((s) => s.companyId));
  final session = ref.watch(sessionProvider);
  if (!session.isLoggedIn) return null;
  try {
    return await ref.read(companiesRepositoryProvider).getMe();
  } catch (_) {
    return CompanyInfo(
      name: (session.userName?.isNotEmpty == true) ? session.userName! : 'My Business',
      businessType: session.businessType ?? 'company',
      currency: 'DZD',
      phone: session.phone,
    );
  }
});
