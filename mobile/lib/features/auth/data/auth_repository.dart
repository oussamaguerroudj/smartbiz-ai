import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session.dart';

class AuthRepository {
  AuthRepository(this._ref);
  final Ref _ref;

  /// Registering does NOT create the account yet and does NOT return a
  /// session — the backend only stores a pending signup + emails a code.
  /// The account (and a usable session) only comes into existence once
  /// [verifyAccount] confirms the right code. So there is nothing to
  /// apply to the session here; the caller just moves on to the "enter
  /// your code" screen.
  Future<void> register({required String name, required String email, required String password}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<void> login({required String email, required String password}) async {
    final client = _ref.read(apiClientProvider);
    final data = await client.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    _applySession(data);
  }

  /// Confirms the 6-digit code emailed to [email]. This is the moment the
  /// account is actually created on the backend — success always comes
  /// back with a real session (user + tokens), which we apply here so
  /// the user lands straight in the app already signed in.
  Future<void> verifyAccount({required String email, required String code}) async {
    final client = _ref.read(apiClientProvider);
    final data = await client.post('/auth/verify-email', body: {
      'email': email,
      'code': code,
    });
    _applySession(data as Map<String, dynamic>);
  }

  /// Asks the backend to (re)send a fresh verification code to [email].
  /// Used both right after registration and from the "Resend code" link.
  Future<void> resendVerificationCode({required String email}) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/auth/resend-verification', body: {'email': email});
  }

  /// Step 1 of "Forgot password": asks the backend to email a reset code
  /// to [email]. Always succeeds from the UI's point of view even if the
  /// email isn't registered, unless the backend says otherwise — that
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

  void logout() {
    _ref.read(sessionProvider.notifier).state = Session.empty;
  }

  void _applySession(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    _ref.read(sessionProvider.notifier).state = Session(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user['id'] as String,
      companyId: user['companyId'] as String,
      userName: user['name'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref));
