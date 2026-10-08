import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/session.dart';
import '../../../core/sync/sync_service.dart';
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
    await _ref.read(sessionProvider.notifier).clear();
    _ref.invalidate(companyInfoProvider);
    // DO NOT call AppDatabase.instance.clearAllData() here.
    // Isolation is enforced by company_id scoping in all repository reads.
  }

  Future<void> _applySession(Map<String, dynamic> data) async {
    await _ref.read(sessionProvider.notifier).apply(data);
    _ref.invalidate(companyInfoProvider);
    // Background pull all company data into local SQLite so app is instantly ready offline!
    unawaited(_ref.read(syncServiceProvider.notifier).pullInitialData());
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref));
