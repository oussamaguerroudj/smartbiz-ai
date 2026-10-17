import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../reports/data/reports_repository.dart' show invalidateAllReports;
import '../../dashboard/data/dashboard_repository.dart' show dashboardRepositoryProvider;
import '../../expenses/data/expenses_repository.dart' show expensesRepositoryProvider;
import '../../sales/data/sales_repository.dart' show salesRepositoryProvider;
import '../../products/data/products_repository.dart' show productsRepositoryProvider;
import '../../customers/data/customers_repository.dart' show customersRepositoryProvider;
import '../../suppliers/presentation/screens/suppliers_screen.dart' show suppliersRepositoryProvider;
import '../../employees/data/employees_repository.dart' show employeesRepositoryProvider;
import '../../appointments/data/appointments_repository.dart' show appointmentsRepositoryProvider;
import '../../invoices/data/invoices_repository.dart' show invoicesRepositoryProvider;
import '../../credit/data/credit_repository.dart' show creditRepositoryProvider;
import '../../superette/presentation/screens/superette_main_dashboard_screen.dart' show superetteDashboardProvider;
import '../../clothing/presentation/screens/clothing_main_dashboard_screen.dart' show clothingDashboardProvider;
import '../../pharmacy/presentation/screens/pharmacy_main_dashboard_screen.dart' show pharmacyDashboardProvider;
import '../../restaurant/data/restaurant_repository.dart' show restaurantDashboardProvider;
import '../../clinic/presentation/screens/clinic_dashboard_screen.dart' show clinicDashboardProvider;
import '../../enterprise/presentation/screens/enterprise_main_dashboard_screen.dart' show enterpriseDashboardProvider;
import 'companies_repository.dart';


class AuthRepository {
  AuthRepository(this._ref);
  final Ref _ref;

  /// Registering does NOT create the account yet and does NOT return a
  /// session  -  the backend only stores a pending signup + emails a code.
  /// The account (and a usable session) only comes into existence once
  /// [verifyAccount] confirms the right code. So there is nothing to
  /// apply to the session here; the caller just moves on to the "enter
  /// your code" screen.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final client = _ref.read(apiClientProvider);
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    await client.post('/auth/register', body: body);
  }

  Future<void> login({required String email, required String password}) async {
    final client = _ref.read(apiClientProvider);
    final data = await client.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    if (data is Map<String, dynamic>) {
      await _applySession(data);
    } else if (data is Map) {
      await _applySession(Map<String, dynamic>.from(data));
    } else {
      throw ApiException(
        statusCode: 200,
        message: 'Invalid response format from server.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  /// Confirms the 6-digit code emailed to [email]. This is the moment the
  /// account is actually created on the backend  -  success always comes
  /// back with a real session (user + tokens), which we apply here so
  /// the user lands straight in the app already signed in.
  Future<void> verifyAccount({required String email, required String code}) async {
    final client = _ref.read(apiClientProvider);
    final data = await client.post('/auth/verify-email', body: {
      'email': email,
      'code': code,
    });
    if (data is Map<String, dynamic>) {
      await _applySession(data);
    } else if (data is Map) {
      await _applySession(Map<String, dynamic>.from(data));
    } else {
      throw ApiException(
        statusCode: 200,
        message: 'Invalid response format from server.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  /// Asks the backend to (re)send a fresh verification code to [email].
  /// Used both right after registration and from the "Resend code" link.
  Future<void> resendVerificationCode({required String email}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/auth/resend-verification', body: {'email': email});
  }

  /// Step 1 of "Forgot password": asks the backend to email a reset code
  /// to [email]. Always succeeds from the UI's point of view even if the
  /// email isn't registered, unless the backend says otherwise  -  that
  /// choice is left to the backend's error response.
  Future<void> requestPasswordReset({required String email}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/auth/forgot-password', body: {'email': email});
  }

  /// Step 2 of "Forgot password": exchanges the emailed [code] for a new
  /// password on the account matching [email].
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/auth/reset-password', body: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> getProfile() async {
    final client = _ref.read(apiClientProvider);
    final data = await client.get('/auth/profile');
    return data['data'] as Map<String, dynamic>;
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    final client = _ref.read(apiClientProvider);
    final res = await client.put('/auth/profile', body: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    final updated = res['data'] as Map<String, dynamic>;
    await _ref.read(sessionProvider.notifier).updateUser(
      name: updated['name'] as String?,
      email: updated['email'] as String?,
      phone: updated['phone'] as String?,
      avatarUrl: updated['avatarUrl'] as String?,
    );
    _ref.invalidate(companyInfoProvider);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> deleteAccount({required String password}) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/auth/account', body: {'password': password});
    await logout();
  }

  Future<void> verifyPassword({required String password}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/auth/verify-password', body: {'password': password});
  }

  /// Resets the current authenticated company's business data completely
  /// while preserving the user account, login session, tokens, company identity,
  /// profile, and other companies' data.
  Future<Map<String, dynamic>> clearBusinessData({required String password}) async {
    final session = _ref.read(sessionProvider);
    final companyId = session.companyId ?? session.userId;
    if (companyId == null) {
      throw ApiException(
        statusCode: 400,
        message: 'No active company found for this session.',
        code: 'NO_ACTIVE_COMPANY',
      );
    }

    final connStatus = _ref.read(connectionStatusProvider);
    final isOnline = connStatus == ConnectionStatus.online;

    if (!isOnline) {
      throw ApiException(
        statusCode: 0,
        message: 'An active internet connection is required to clear business data. Server verification and deletion must occur before local data can be cleared.',
        code: 'NETWORK_REQUIRED',
      );
    }

    final client = _ref.read(apiClientProvider);
    // 1. Authoritative server reset scoped strictly to req.user.companyId
    final response = await client.post('/companies/me/clear-business-data', body: {
      'password': password,
    });

    if (response is Map && response['success'] == false) {
      throw ApiException(
        statusCode: 400,
        message: response['message']?.toString() ?? 'Failed to clear business data',
        code: 'CLEAR_FAILED',
      );
    }

    // 2. Clear local SQLite records for this company only, strictly after confirmed backend success
    await AppDatabase.instance.clearCompanyBusinessData(companyId);

    // Invalidate providers so UI instantly reflects empty state
    _invalidateBusinessProviders();

    return {'cleared': true, 'isOffline': false};
  }

  void _invalidateBusinessProviders() {
    _ref.invalidate(companyInfoProvider);
    invalidateAllReports(_ref);
    _ref.invalidate(dashboardRepositoryProvider);
    _ref.invalidate(expensesRepositoryProvider);
    _ref.invalidate(salesRepositoryProvider);
    _ref.invalidate(productsRepositoryProvider);
    _ref.invalidate(customersRepositoryProvider);
    _ref.invalidate(suppliersRepositoryProvider);
    _ref.invalidate(employeesRepositoryProvider);
    _ref.invalidate(appointmentsRepositoryProvider);
    _ref.invalidate(invoicesRepositoryProvider);
    _ref.invalidate(creditRepositoryProvider);
    _ref.invalidate(clothingDashboardProvider);
    _ref.invalidate(superetteDashboardProvider);
    _ref.invalidate(pharmacyDashboardProvider);
    _ref.invalidate(restaurantDashboardProvider);
    _ref.invalidate(clinicDashboardProvider);
    _ref.invalidate(enterpriseDashboardProvider);
  }

  /// Backward-compatible alias for existing code
  Future<void> clearApplicationData({required String password}) async {
    await clearBusinessData(password: password);
  }

  /// Ends the current session. SQLite data is intentionally NOT deleted.
  ///
  /// DATA ISOLATION is achieved through company_id scoping in every
  /// repository's _fetchFromLocal(), not by wiping the database.
  ///
  /// When Account A logs out:
  ///   - Session is cleared (companyId becomes null)
  ///   - All repository reads check companyId == null → return []
  ///   - A's local data survives in SQLite tagged with A's companyId
  ///
  /// When Account B logs in next:
  ///   - Session is set to B's companyId
  ///   - All repository reads return only WHERE company_id = B's id
  ///   - A's data is invisible to B (still in DB, not deleted)
  ///
  /// When A logs back in:
  ///   - A's rows reappear because company_id = A matches again
  ///   - A's offline work and sync queue are fully preserved
  Future<void> logout() async {
    await _ref.read(notificationServiceProvider).unregisterOnLogout();
    await _ref.read(sessionProvider.notifier).clear();
    _invalidateBusinessProviders();
    // DO NOT call AppDatabase.instance.clearAllData() here.
    // Isolation is enforced by company_id scoping in all repository reads.
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    await _ref.read(sessionProvider.notifier).apply(data);
    _invalidateBusinessProviders();
    // Push any pending offline mutations first, then pull authoritative server data
    unawaited(() async {
      await _ref.read(syncServiceProvider.notifier).syncPending();
      await _ref.read(syncServiceProvider.notifier).pullInitialData();
    }());
    // Register FCM device token with newly authenticated session
    unawaited(_ref.read(notificationServiceProvider).initialize());
  }

}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref));
