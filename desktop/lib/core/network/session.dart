import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionState {
  final bool isLoggedIn;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? companyId;
  final String? companyName;
  final String? userEmail;
  final String? userName;
  final String? role;

  const SessionState({
    this.isLoggedIn = false,
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.companyId,
    this.companyName,
    this.userEmail,
    this.userName,
    this.role,
  });

  SessionState copyWith({
    bool? isLoggedIn,
    String? accessToken,
    String? refreshToken,
    String? userId,
    String? companyId,
    String? companyName,
    String? userEmail,
    String? userName,
    String? role,
  }) {
    return SessionState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      role: role ?? this.role,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SessionNotifier() : super(const SessionState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final token = await _storage.read(key: 'modiri_access_token');
      final refreshToken = await _storage.read(key: 'modiri_refresh_token');
      final userId = await _storage.read(key: 'modiri_user_id');
      final companyId = await _storage.read(key: 'modiri_company_id');
      final companyName = await _storage.read(key: 'modiri_company_name');
      final email = await _storage.read(key: 'modiri_user_email');
      final name = await _storage.read(key: 'modiri_user_name');
      final role = await _storage.read(key: 'modiri_user_role');

      if (token != null && token.isNotEmpty) {
        state = SessionState(
          isLoggedIn: true,
          accessToken: token,
          refreshToken: refreshToken,
          userId: userId,
          companyId: companyId,
          companyName: companyName,
          userEmail: email,
          userName: name,
          role: role,
        );
      }
    } catch (_) {}
  }

  Future<void> applyLogin({
    required String accessToken,
    String? refreshToken,
    required String userId,
    required String companyId,
    String? companyName,
    required String email,
    String? name,
    String? role,
  }) async {
    state = SessionState(
      isLoggedIn: true,
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      companyId: companyId,
      companyName: companyName,
      userEmail: email,
      userName: name,
      role: role,
    );

    try {
      await _storage.write(key: 'modiri_access_token', value: accessToken);
      if (refreshToken != null) {
        await _storage.write(key: 'modiri_refresh_token', value: refreshToken);
      }
      await _storage.write(key: 'modiri_user_id', value: userId);
      await _storage.write(key: 'modiri_company_id', value: companyId);
      if (companyName != null) {
        await _storage.write(key: 'modiri_company_name', value: companyName);
      }
      await _storage.write(key: 'modiri_user_email', value: email);
      if (name != null) {
        await _storage.write(key: 'modiri_user_name', value: name);
      }
      if (role != null) {
        await _storage.write(key: 'modiri_user_role', value: role);
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    state = const SessionState();
    try {
      await _storage.delete(key: 'modiri_access_token');
      await _storage.delete(key: 'modiri_refresh_token');
      await _storage.delete(key: 'modiri_user_id');
      await _storage.delete(key: 'modiri_company_id');
      await _storage.delete(key: 'modiri_company_name');
      await _storage.delete(key: 'modiri_user_email');
      await _storage.delete(key: 'modiri_user_name');
      await _storage.delete(key: 'modiri_user_role');
    } catch (_) {}
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
